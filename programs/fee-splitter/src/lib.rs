pub mod error;
pub mod instruction;
pub mod processor;
pub mod state;

#[cfg(not(feature = "no-entrypoint"))]
pub mod entrypoint;

pub const CONFIG_SEED_PREFIX: &[u8] = b"fee-splitter-config";
pub const VAULT_SEED_PREFIX: &[u8] = b"fee-splitter-vault";
pub const TOTAL_BASIS_POINTS: u16 = 10_000;
pub const PROGRAM_STATE_VERSION: u8 = 1;
