use solana_program::{program_error::ProgramError, pubkey::Pubkey};

use crate::{error::FeeSplitterError, state::validate_wallets_and_shares};

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum FeeSplitterInstruction {
    InitializeOrUpdate {
        team_wallet: Pubkey,
        treasury_wallet: Pubkey,
        team_share_bps: u16,
        treasury_share_bps: u16,
    },
    Split {
        total_platform_fee_amount_raw: u64,
    },
}

impl FeeSplitterInstruction {
    pub fn unpack(data: &[u8]) -> Result<Self, ProgramError> {
        let (&tag, rest) = data
            .split_first()
            .ok_or(FeeSplitterError::InvalidInstructionData)?;
        match tag {
            0 => Self::unpack_initialize_or_update(rest),
            1 => Self::unpack_split(rest),
            _ => Err(FeeSplitterError::InvalidInstructionData.into()),
        }
    }

    fn unpack_initialize_or_update(data: &[u8]) -> Result<Self, ProgramError> {
        if data.len() != 68 {
            return Err(FeeSplitterError::InvalidInstructionData.into());
        }
        let team_wallet = Pubkey::new_from_array(
            data[0..32]
                .try_into()
                .map_err(|_| FeeSplitterError::InvalidInstructionData)?,
        );
        let treasury_wallet = Pubkey::new_from_array(
            data[32..64]
                .try_into()
                .map_err(|_| FeeSplitterError::InvalidInstructionData)?,
        );
        let team_share_bps = u16::from_le_bytes(
            data[64..66]
                .try_into()
                .map_err(|_| FeeSplitterError::InvalidInstructionData)?,
        );
        let treasury_share_bps = u16::from_le_bytes(
            data[66..68]
                .try_into()
                .map_err(|_| FeeSplitterError::InvalidInstructionData)?,
        );
        validate_wallets_and_shares(
            &team_wallet,
            &treasury_wallet,
            team_share_bps,
            treasury_share_bps,
        )?;
        Ok(Self::InitializeOrUpdate {
            team_wallet,
            treasury_wallet,
            team_share_bps,
            treasury_share_bps,
        })
    }

    fn unpack_split(data: &[u8]) -> Result<Self, ProgramError> {
        if data.len() != 8 {
            return Err(FeeSplitterError::InvalidInstructionData.into());
        }
        let total_platform_fee_amount_raw = u64::from_le_bytes(
            data.try_into()
                .map_err(|_| FeeSplitterError::InvalidInstructionData)?,
        );
        if total_platform_fee_amount_raw == 0 {
            return Err(FeeSplitterError::InvalidInstructionData.into());
        }
        Ok(Self::Split {
            total_platform_fee_amount_raw,
        })
    }
}
