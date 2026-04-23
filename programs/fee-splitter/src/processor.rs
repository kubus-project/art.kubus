use std::convert::TryFrom;

use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint::ProgramResult,
    program::{invoke, invoke_signed},
    program_error::ProgramError,
    program_pack::Pack,
    pubkey::Pubkey,
    rent::Rent,
    sysvar::Sysvar,
};
use solana_system_interface::{instruction as system_instruction, program as system_program};
use spl_associated_token_account::{
    get_associated_token_address_with_program_id,
    instruction::create_associated_token_account,
};
use spl_token::{
    instruction::transfer_checked,
    program::ID as spl_token_program_id,
    state::{Account as TokenAccount, AccountState, Mint},
};

use crate::{
    error::FeeSplitterError,
    instruction::FeeSplitterInstruction,
    state::{
        find_config_address, find_vault_authority_address, split_fee_amount, FeeSplitterConfig,
    },
    CONFIG_SEED_PREFIX, VAULT_SEED_PREFIX,
};

pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    match FeeSplitterInstruction::unpack(instruction_data)? {
        FeeSplitterInstruction::InitializeOrUpdate {
            team_wallet,
            treasury_wallet,
            team_share_bps,
            treasury_share_bps,
        } => process_initialize_or_update(
            program_id,
            accounts,
            team_wallet,
            treasury_wallet,
            team_share_bps,
            treasury_share_bps,
        ),
        FeeSplitterInstruction::Split {
            total_platform_fee_amount_raw,
        } => process_split(program_id, accounts, total_platform_fee_amount_raw),
    }
}

fn process_initialize_or_update(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    team_wallet: Pubkey,
    treasury_wallet: Pubkey,
    team_share_bps: u16,
    treasury_share_bps: u16,
) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();
    let payer = next_account_info(account_info_iter)?;
    let authority = next_account_info(account_info_iter)?;
    let config = next_account_info(account_info_iter)?;
    let incoming_system_program = next_account_info(account_info_iter)?;

    if !payer.is_signer || !authority.is_signer {
        return Err(FeeSplitterError::MissingRequiredSignature.into());
    }
    if incoming_system_program.key != &system_program::ID {
        return Err(FeeSplitterError::InvalidSystemProgram.into());
    }

    let (expected_config, config_bump) = find_config_address(program_id);
    if config.key != &expected_config {
        return Err(FeeSplitterError::InvalidConfigPda.into());
    }
    let (_, vault_authority_bump) = find_vault_authority_address(program_id);

    let config_is_uninitialized = config.owner == &system_program::ID
        && read_lamports(config)? == 0
        && read_data_len(config)? == 0;

    if config_is_uninitialized {
        let rent = Rent::get()?;
        let config_space =
            u64::try_from(FeeSplitterConfig::SERIALIZED_LEN).map_err(|_| FeeSplitterError::ArithmeticOverflow)?;
        let config_rent = rent.minimum_balance(FeeSplitterConfig::SERIALIZED_LEN);

        invoke_signed(
            &system_instruction::create_account(
                payer.key,
                config.key,
                config_rent,
                config_space,
                program_id,
            ),
            &[payer.clone(), config.clone(), incoming_system_program.clone()],
            &[&[CONFIG_SEED_PREFIX, &[config_bump]]],
        )?;
    } else {
        let current_config = load_config(program_id, config)?;
        if current_config.authority != *authority.key {
            return Err(FeeSplitterError::MissingRequiredSignature.into());
        }
    }

    let config_state = FeeSplitterConfig::new(
        *authority.key,
        config_bump,
        vault_authority_bump,
        team_wallet,
        treasury_wallet,
        team_share_bps,
        treasury_share_bps,
    )?;
    config_state.serialize_into(&mut config.try_borrow_mut_data()?)?;
    Ok(())
}

fn process_split(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    total_platform_fee_amount_raw: u64,
) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();
    let config = next_account_info(account_info_iter)?;
    let vault_authority = next_account_info(account_info_iter)?;
    let platform_fee_token_account = next_account_info(account_info_iter)?;
    let payer = next_account_info(account_info_iter)?;
    let team_wallet = next_account_info(account_info_iter)?;
    let team_token_account = next_account_info(account_info_iter)?;
    let treasury_wallet = next_account_info(account_info_iter)?;
    let treasury_token_account = next_account_info(account_info_iter)?;
    let mint = next_account_info(account_info_iter)?;
    let token_program = next_account_info(account_info_iter)?;
    let ata_program = next_account_info(account_info_iter)?;
    let system_program_info = next_account_info(account_info_iter)?;

    if !payer.is_signer {
        return Err(FeeSplitterError::InvalidPayer.into());
    }
    if token_program.key != &spl_token_program_id {
        return Err(FeeSplitterError::InvalidTokenProgram.into());
    }
    if ata_program.key != &spl_associated_token_account::id() {
        return Err(FeeSplitterError::InvalidAssociatedTokenProgram.into());
    }
    if system_program_info.key != &system_program::ID {
        return Err(FeeSplitterError::InvalidSystemProgram.into());
    }

    let config_state = load_config(program_id, config)?;
    let (expected_config, _) = find_config_address(program_id);
    if config.key != &expected_config {
        return Err(FeeSplitterError::InvalidConfigPda.into());
    }
    let (expected_vault_authority, vault_authority_bump) =
        find_vault_authority_address(program_id);
    if vault_authority.key != &expected_vault_authority {
        return Err(FeeSplitterError::InvalidVaultAuthorityPda.into());
    }
    if config_state.vault_authority_bump != vault_authority_bump {
        return Err(FeeSplitterError::InvalidAccountState.into());
    }
    if team_wallet.key != &config_state.team_wallet
        || treasury_wallet.key != &config_state.treasury_wallet
    {
        return Err(FeeSplitterError::InvalidRecipientWallet.into());
    }

    let mint_state =
        Mint::unpack(&mint.try_borrow_data()?).map_err(|_| FeeSplitterError::InvalidMint)?;
    let source_state = TokenAccount::unpack(&platform_fee_token_account.try_borrow_data()?)
        .map_err(|_| FeeSplitterError::InvalidPlatformFeeTokenAccount)?;
    if source_state.mint != *mint.key {
        return Err(FeeSplitterError::InvalidMint.into());
    }
    if source_state.owner != *vault_authority.key {
        return Err(FeeSplitterError::InvalidVaultAuthority.into());
    }
    if source_state.state != AccountState::Initialized {
        return Err(FeeSplitterError::InvalidPlatformFeeTokenAccount.into());
    }
    if source_state.amount < total_platform_fee_amount_raw {
        return Err(FeeSplitterError::InsufficientPlatformFeeBalance.into());
    }

    ensure_associated_token_account(
        payer,
        team_wallet,
        team_token_account,
        mint,
        token_program,
        ata_program,
        system_program_info,
    )?;
    ensure_associated_token_account(
        payer,
        treasury_wallet,
        treasury_token_account,
        mint,
        token_program,
        ata_program,
        system_program_info,
    )?;

    let (team_amount_raw, treasury_amount_raw) =
        split_fee_amount(total_platform_fee_amount_raw, config_state.team_share_bps)?;
    let signer_seeds: &[&[u8]] = &[VAULT_SEED_PREFIX, &[config_state.vault_authority_bump]];

    if team_amount_raw > 0 {
        invoke_signed(
            &transfer_checked(
                token_program.key,
                platform_fee_token_account.key,
                mint.key,
                team_token_account.key,
                vault_authority.key,
                &[],
                team_amount_raw,
                mint_state.decimals,
            )?,
            &[
                platform_fee_token_account.clone(),
                mint.clone(),
                team_token_account.clone(),
                vault_authority.clone(),
                token_program.clone(),
            ],
            &[signer_seeds],
        )?;
    }

    if treasury_amount_raw > 0 {
        invoke_signed(
            &transfer_checked(
                token_program.key,
                platform_fee_token_account.key,
                mint.key,
                treasury_token_account.key,
                vault_authority.key,
                &[],
                treasury_amount_raw,
                mint_state.decimals,
            )?,
            &[
                platform_fee_token_account.clone(),
                mint.clone(),
                treasury_token_account.clone(),
                vault_authority.clone(),
                token_program.clone(),
            ],
            &[signer_seeds],
        )?;
    }

    Ok(())
}

fn load_config(program_id: &Pubkey, config: &AccountInfo) -> Result<FeeSplitterConfig, ProgramError> {
    if config.owner != program_id {
        return Err(FeeSplitterError::InvalidConfigOwner.into());
    }

    let data = config.try_borrow_data()?;
    FeeSplitterConfig::deserialize(&data)
}

fn ensure_associated_token_account(
    payer: &AccountInfo,
    wallet: &AccountInfo,
    token_account: &AccountInfo,
    mint: &AccountInfo,
    token_program: &AccountInfo,
    ata_program: &AccountInfo,
    system_program_info: &AccountInfo,
) -> ProgramResult {
    let expected = get_associated_token_address_with_program_id(
        wallet.key,
        mint.key,
        token_program.key,
    );
    if token_account.key != &expected {
        return Err(FeeSplitterError::InvalidRecipientTokenAccount.into());
    }

    let should_create =
        token_account.owner == &system_program::ID && read_data_len(token_account)? == 0;
    if should_create {
        invoke(
            &create_associated_token_account(
                payer.key,
                wallet.key,
                mint.key,
                token_program.key,
            ),
            &[
                payer.clone(),
                token_account.clone(),
                wallet.clone(),
                mint.clone(),
                system_program_info.clone(),
                token_program.clone(),
                ata_program.clone(),
            ],
        )?;
    }

    let token_state = TokenAccount::unpack(&token_account.try_borrow_data()?)
        .map_err(|_| FeeSplitterError::InvalidRecipientTokenAccount)?;
    if token_state.owner != *wallet.key || token_state.mint != *mint.key {
        return Err(FeeSplitterError::InvalidRecipientTokenAccount.into());
    }
    if token_state.state != AccountState::Initialized {
        return Err(FeeSplitterError::InvalidRecipientTokenAccount.into());
    }

    Ok(())
}

fn read_lamports(account: &AccountInfo) -> Result<u64, ProgramError> {
    Ok(**account.try_borrow_lamports()?)
}

fn read_data_len(account: &AccountInfo) -> Result<usize, ProgramError> {
    Ok(account.try_borrow_data()?.len())
}
