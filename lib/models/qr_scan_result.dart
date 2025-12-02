import 'package:solana/solana.dart' show Ed25519HDPublicKey;

/// Represents the structured data embedded inside a scanned QR payload.
class QRScanResult {
  final String address;
  final double? amount;
  final String? tokenMint;
  final String? label;
  final String? message;
  final String rawValue;

  const QRScanResult({
    required this.address,
    this.amount,
    this.tokenMint,
    this.label,
    this.message,
    required this.rawValue,
  });

  bool get hasAmount => amount != null && amount! > 0;

  static QRScanResult? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('solana:')) {
      return _parseSolanaUri(trimmed);
    }

    if (_isValidSolanaAddress(trimmed)) {
      return QRScanResult(address: trimmed, rawValue: trimmed);
    }

    return null;
  }

  static QRScanResult? _parseSolanaUri(String value) {
    try {
      final uri = Uri.parse(value);
      var address = uri.path;

      if ((address.isEmpty || address == '/') && uri.host.isNotEmpty) {
        address = uri.host;
      }

      if (address.isEmpty || !_isValidSolanaAddress(address)) {
        return null;
      }

      final amountParam = uri.queryParameters['amount'] ?? uri.queryParameters['amt'];
      final amount = amountParam != null ? double.tryParse(amountParam) : null;

      return QRScanResult(
        address: address,
        amount: amount,
        tokenMint: uri.queryParameters['spl-token'],
        label: uri.queryParameters['label'],
        message: uri.queryParameters['message'] ?? uri.queryParameters['memo'],
        rawValue: value,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isValidSolanaAddress(String value) {
    try {
      Ed25519HDPublicKey.fromBase58(value);
      return true;
    } catch (_) {
      return false;
    }
  }
}
