# art.kubus Fee Splitter Program

Standalone Solana program crate for atomically splitting Jupiter SPL platform fees inside the user swap transaction.

This crate exists so the wallet can keep the swap and fee settlement in one transaction when the program is deployed, while the backend fallback path remains available for local and non-program environments.

## Scope

- SPL token fees only
- One global config PDA per deployed program
- One global vault-authority PDA per deployed program
- Two configured recipients: team and treasury
- On-chain share enforcement from the total platform fee amount

## PDA layout

- Config PDA seeds: `["fee-splitter-config"]`
- Vault authority PDA seeds: `["fee-splitter-vault"]`

The backend and Flutter client both derive these addresses from `program_id` only.

## Config account

Program-owned PDA storing:

- immutable `authority`
- `config_bump`
- `vault_authority_bump`
- `team_wallet`
- `treasury_wallet`
- `team_share_bps`
- `treasury_share_bps`

The vault authority is only a PDA signer. It does not need its own on-chain account.

## Instruction set

### `InitializeOrUpdate` (`tag = 0`)

Creates the global config PDA if missing or updates it if it already exists.

Accounts:

1. `payer` signer, writable
2. `authority` signer
3. `config_pda` writable
4. `system_program`

Data layout:

- `team_wallet: Pubkey`
- `treasury_wallet: Pubkey`
- `team_share_bps: u16`
- `treasury_share_bps: u16`

Constraints:

- team and treasury wallets must be distinct and non-default
- both shares must be non-zero
- shares must sum to exactly `10_000`
- updates require the stored authority signer

### `Split` (`tag = 1`)

Transfers the exact platform fee amount out of the Jupiter fee ATA owned by the vault-authority PDA, splitting it between team and treasury ATAs for the output mint.

Accounts:

1. `config_pda`
2. `vault_authority_pda`
3. `platform_fee_token_account` writable
4. `payer` signer, writable
5. `team_wallet`
6. `team_token_account` writable
7. `treasury_wallet`
8. `treasury_token_account` writable
9. `mint`
10. `token_program`
11. `associated_token_program`
12. `system_program`

Data layout:

- `total_platform_fee_amount_raw: u64`

Behavior:

- validates the fee ATA owner is the vault-authority PDA
- validates the fee ATA mint matches the swap output mint
- creates the team/treasury ATAs if they do not exist yet
- computes team and treasury raw amounts from the configured basis-point split
- transfers the exact requested raw amount from the fee ATA in two `transfer_checked` CPIs

## Wallet / backend contract

- Flutter gives Jupiter the vault-authority ATA as `feeAccount`
- Jupiter credits that ATA during the swap
- Flutter appends `Split` after the Jupiter swap instructions
- backend config endpoint exposes the program id plus the derived config/vault PDAs
- backend fallback remains the non-atomic recovery path when the program is not deployed

## Local build and test

From repo root:

```bash
cd programs
cargo test -p art-kubus-fee-splitter
cargo build -p art-kubus-fee-splitter
```

For SBF deployment builds, use the Solana toolchain command that matches your installed CLI version, for example:

```bash
cargo build-sbf -p art-kubus-fee-splitter
```

## Dependency notes

This crate uses plain Rust Solana program APIs and does not depend on Anchor.
