use solana_program::program_error::ProgramError;

#[repr(u32)]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum FeeSplitterError {
    InvalidInstructionData = 0,
    InvalidRecipientShare = 1,
    InvalidConfigPda = 2,
    InvalidVaultAuthorityPda = 3,
    InvalidSystemProgram = 4,
    InvalidTokenProgram = 5,
    InvalidAssociatedTokenProgram = 6,
    MissingRequiredSignature = 7,
    InvalidConfigOwner = 8,
    InvalidAccountState = 9,
    ArithmeticOverflow = 10,
    InvalidMint = 11,
    InvalidPlatformFeeTokenAccount = 12,
    InvalidVaultAuthority = 13,
    InvalidRecipientWallet = 14,
    InvalidRecipientTokenAccount = 15,
    InsufficientPlatformFeeBalance = 16,
    InvalidPayer = 17,
}

impl From<FeeSplitterError> for ProgramError {
    fn from(error: FeeSplitterError) -> Self {
        ProgramError::Custom(error as u32)
    }
}
