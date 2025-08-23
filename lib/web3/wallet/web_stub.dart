// Web stub for qr_code_scanner package
// This file provides dummy implementations for web platform compatibility

import 'package:flutter/material.dart';

class QRView extends StatelessWidget {
  final Key? key;
  final Function? onQRViewCreated;
  final dynamic overlay;

  const QRView({
    this.key,
    this.onQRViewCreated,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class QrScannerOverlayShape {
  final Color? borderColor;
  final double? borderRadius;
  final double? borderLength;
  final double? borderWidth;
  final double? cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor,
    this.borderRadius,
    this.borderLength,
    this.borderWidth,
    this.cutOutSize,
  });
}
