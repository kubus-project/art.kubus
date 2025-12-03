import 'dart:math';

/// Represents a Jupiter swap quote with helper getters for UI-friendly values.
class SwapQuote {
  const SwapQuote({
    required this.inputMint,
    required this.outputMint,
    required this.inputDecimals,
    required this.outputDecimals,
    required this.inputAmountRaw,
    required this.outputAmountRaw,
    required this.minOutputAmountRaw,
    required this.priceImpactPct,
    required this.slippageBps,
    required this.marketInfos,
    required this.routePlan,
    required this.rawRoute,
    this.contextSlot,
    this.timeTakenMs,
  });

  final String inputMint;
  final String outputMint;
  final int inputDecimals;
  final int outputDecimals;
  final int inputAmountRaw;
  final int outputAmountRaw;
  final int minOutputAmountRaw;
  final double priceImpactPct;
  final int slippageBps;
  final List<dynamic> marketInfos;
  final List<dynamic> routePlan;
  final Map<String, dynamic> rawRoute;
  final int? contextSlot;
  final double? timeTakenMs;

  double get inputAmount => _toUiAmount(inputAmountRaw, inputDecimals);
  double get outputAmount => _toUiAmount(outputAmountRaw, outputDecimals);
  double get minOutputAmount => _toUiAmount(minOutputAmountRaw, outputDecimals);
  double get slippagePercent => slippageBps / 100;
  bool get hasRoute => outputAmountRaw > 0;

  static double _toUiAmount(int rawAmount, int decimals) {
    if (decimals <= 0) return rawAmount.toDouble();
    final divisor = pow(10, decimals).toDouble();
    return rawAmount / divisor;
  }

  factory SwapQuote.fromRoute({
    required Map<String, dynamic> route,
    required String inputMint,
    required String outputMint,
    required int inputDecimals,
    required int outputDecimals,
    required int slippageBps,
    int? contextSlot,
    double? timeTakenMs,
  }) {
    int parseAmount(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }

    return SwapQuote(
      inputMint: inputMint,
      outputMint: outputMint,
      inputDecimals: inputDecimals,
      outputDecimals: outputDecimals,
      inputAmountRaw: parseAmount(route['inAmount']),
      outputAmountRaw: parseAmount(route['outAmount']),
      minOutputAmountRaw: parseAmount(route['otherAmountThreshold']),
      priceImpactPct: (route['priceImpactPct'] as num?)?.toDouble() ?? 0,
      slippageBps: slippageBps,
      marketInfos: List<dynamic>.from(route['marketInfos'] as List? ?? const []),
      routePlan: List<dynamic>.from(route['routePlan'] as List? ?? const []),
      rawRoute: Map<String, dynamic>.from(route),
      contextSlot: contextSlot,
      timeTakenMs: timeTakenMs,
    );
  }
}
