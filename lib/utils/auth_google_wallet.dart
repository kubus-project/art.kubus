String? signerBackedGoogleWalletAddress({
  required bool hasSigner,
  String? currentWalletAddress,
}) {
  final normalizedWallet = (currentWalletAddress ?? '').trim();
  if (!hasSigner || normalizedWallet.isEmpty) {
    return null;
  }
  return normalizedWallet;
}
