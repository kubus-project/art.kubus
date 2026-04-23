use borsh::{BorshDeserialize, BorshSerialize};
use solana_program::{program_error::ProgramError, pubkey::Pubkey};

use crate::{
    error::FeeSplitterError, CONFIG_SEED_PREFIX, PROGRAM_STATE_VERSION, TOTAL_BASIS_POINTS,
    VAULT_SEED_PREFIX,
};

#[derive(Clone, Copy, Debug, Eq, PartialEq, BorshSerialize, BorshDeserialize)]
pub struct FeeSplitterConfig {
    pub version: u8,
    pub config_bump: u8,
    pub vault_authority_bump: u8,
    pub authority: Pubkey,
    pub team_wallet: Pubkey,
    pub treasury_wallet: Pubkey,
    pub team_share_bps: u16,
    pub treasury_share_bps: u16,
}

impl Default for FeeSplitterConfig {
    fn default() -> Self {
        Self {
            version: PROGRAM_STATE_VERSION,
            config_bump: 0,
            vault_authority_bump: 0,
            authority: Pubkey::default(),
            team_wallet: Pubkey::default(),
            treasury_wallet: Pubkey::default(),
            team_share_bps: 0,
            treasury_share_bps: 0,
        }
    }
}

impl FeeSplitterConfig {
    pub const SERIALIZED_LEN: usize = 1 + 1 + 1 + 32 + 32 + 32 + 2 + 2;

    pub fn new(
        authority: Pubkey,
        config_bump: u8,
        vault_authority_bump: u8,
        team_wallet: Pubkey,
        treasury_wallet: Pubkey,
        team_share_bps: u16,
        treasury_share_bps: u16,
    ) -> Result<Self, ProgramError> {
        validate_wallets_and_shares(
            &team_wallet,
            &treasury_wallet,
            team_share_bps,
            treasury_share_bps,
        )?;
        Ok(Self {
            version: PROGRAM_STATE_VERSION,
            config_bump,
            vault_authority_bump,
            authority,
            team_wallet,
            treasury_wallet,
            team_share_bps,
            treasury_share_bps,
        })
    }

    pub fn validate(&self) -> Result<(), ProgramError> {
        if self.version != PROGRAM_STATE_VERSION {
            return Err(FeeSplitterError::InvalidAccountState.into());
        }
        validate_wallets_and_shares(
            &self.team_wallet,
            &self.treasury_wallet,
            self.team_share_bps,
            self.treasury_share_bps,
        )
    }

    pub fn deserialize(data: &[u8]) -> Result<Self, ProgramError> {
        if data.len() != Self::SERIALIZED_LEN {
            return Err(FeeSplitterError::InvalidAccountState.into());
        }

        let config =
            Self::try_from_slice(data).map_err(|_| FeeSplitterError::InvalidAccountState)?;
        config.validate()?;
        Ok(config)
    }

    pub fn serialize_into(&self, data: &mut [u8]) -> Result<(), ProgramError> {
        if data.len() != Self::SERIALIZED_LEN {
            return Err(FeeSplitterError::InvalidAccountState.into());
        }

        data.fill(0);
        self.serialize(&mut &mut data[..])
            .map_err(|_| FeeSplitterError::InvalidAccountState.into())
    }
}

pub fn find_config_address(program_id: &Pubkey) -> (Pubkey, u8) {
    Pubkey::find_program_address(&[CONFIG_SEED_PREFIX], program_id)
}

pub fn find_vault_authority_address(program_id: &Pubkey) -> (Pubkey, u8) {
    Pubkey::find_program_address(&[VAULT_SEED_PREFIX], program_id)
}

pub fn validate_wallets_and_shares(
    team_wallet: &Pubkey,
    treasury_wallet: &Pubkey,
    team_share_bps: u16,
    treasury_share_bps: u16,
) -> Result<(), ProgramError> {
    if *team_wallet == Pubkey::default()
        || *treasury_wallet == Pubkey::default()
        || *team_wallet == *treasury_wallet
    {
        return Err(FeeSplitterError::InvalidRecipientWallet.into());
    }

    if team_share_bps == 0
        || treasury_share_bps == 0
        || u32::from(team_share_bps) + u32::from(treasury_share_bps)
            != u32::from(TOTAL_BASIS_POINTS)
    {
        return Err(FeeSplitterError::InvalidRecipientShare.into());
    }

    Ok(())
}

pub fn split_fee_amount(
    total_platform_fee_amount_raw: u64,
    team_share_bps: u16,
) -> Result<(u64, u64), ProgramError> {
    if total_platform_fee_amount_raw == 0 {
        return Err(FeeSplitterError::InvalidInstructionData.into());
    }

    let team_amount = ((u128::from(total_platform_fee_amount_raw)
        * u128::from(team_share_bps))
        / u128::from(TOTAL_BASIS_POINTS)) as u64;
    let treasury_amount = total_platform_fee_amount_raw
        .checked_sub(team_amount)
        .ok_or(FeeSplitterError::ArithmeticOverflow)?;
    Ok((team_amount, treasury_amount))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn split_fee_amount_preserves_total() {
        let (team, treasury) = split_fee_amount(11, 4_000).unwrap();
        assert_eq!(team, 4);
        assert_eq!(treasury, 7);
    }

    #[test]
    fn config_serialized_size_is_stable() {
        let config = FeeSplitterConfig::new(
            Pubkey::new_unique(),
            1,
            2,
            Pubkey::new_unique(),
            Pubkey::new_unique(),
            4_000,
            6_000,
        )
        .unwrap();
        let bytes = borsh::to_vec(&config).unwrap();
        assert_eq!(bytes.len(), FeeSplitterConfig::SERIALIZED_LEN);
    }
}
