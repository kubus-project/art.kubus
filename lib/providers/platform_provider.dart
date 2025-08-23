import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

enum PlatformCapability {
  camera,
  nfc,
  ar,
  gps,
  biometrics,
  notifications,
  fileSystem,
  bluetooth,
  vibration,
  orientation,
  background,
}

enum PlatformType {
  web,
  android,
  ios,
  windows,
  macos,
  linux,
  fuchsia,
}

class PlatformProvider with ChangeNotifier {
  static final PlatformProvider _instance = PlatformProvider._internal();
  factory PlatformProvider() => _instance;
  PlatformProvider._internal();

  // Platform detection
  PlatformType get currentPlatform {
    if (kIsWeb) return PlatformType.web;
    if (Platform.isAndroid) return PlatformType.android;
    if (Platform.isIOS) return PlatformType.ios;
    if (Platform.isWindows) return PlatformType.windows;
    if (Platform.isMacOS) return PlatformType.macos;
    if (Platform.isLinux) return PlatformType.linux;
    if (Platform.isFuchsia) return PlatformType.fuchsia;
    return PlatformType.web; // fallback
  }

  // Platform categories
  bool get isMobile => currentPlatform == PlatformType.android || currentPlatform == PlatformType.ios;
  bool get isDesktop => currentPlatform == PlatformType.windows || 
                       currentPlatform == PlatformType.macos || 
                       currentPlatform == PlatformType.linux;
  bool get isWeb => currentPlatform == PlatformType.web;
  bool get isApple => currentPlatform == PlatformType.ios || currentPlatform == PlatformType.macos;
  bool get isGoogle => currentPlatform == PlatformType.android || currentPlatform == PlatformType.fuchsia;

  // Capability checks
  Map<PlatformCapability, bool> get capabilities {
    switch (currentPlatform) {
      case PlatformType.android:
        return {
          PlatformCapability.camera: true,
          PlatformCapability.nfc: true,
          PlatformCapability.ar: true,
          PlatformCapability.gps: true,
          PlatformCapability.biometrics: true,
          PlatformCapability.notifications: true,
          PlatformCapability.fileSystem: true,
          PlatformCapability.bluetooth: true,
          PlatformCapability.vibration: true,
          PlatformCapability.orientation: true,
          PlatformCapability.background: true,
        };
      case PlatformType.ios:
        return {
          PlatformCapability.camera: true,
          PlatformCapability.nfc: true,
          PlatformCapability.ar: true,
          PlatformCapability.gps: true,
          PlatformCapability.biometrics: true,
          PlatformCapability.notifications: true,
          PlatformCapability.fileSystem: true,
          PlatformCapability.bluetooth: true,
          PlatformCapability.vibration: true,
          PlatformCapability.orientation: true,
          PlatformCapability.background: true,
        };
      case PlatformType.windows:
        return {
          PlatformCapability.camera: true,
          PlatformCapability.nfc: false,
          PlatformCapability.ar: false,
          PlatformCapability.gps: false,
          PlatformCapability.biometrics: true,
          PlatformCapability.notifications: true,
          PlatformCapability.fileSystem: true,
          PlatformCapability.bluetooth: true,
          PlatformCapability.vibration: false,
          PlatformCapability.orientation: false,
          PlatformCapability.background: true,
        };
      case PlatformType.macos:
        return {
          PlatformCapability.camera: true,
          PlatformCapability.nfc: false,
          PlatformCapability.ar: false,
          PlatformCapability.gps: false,
          PlatformCapability.biometrics: true,
          PlatformCapability.notifications: true,
          PlatformCapability.fileSystem: true,
          PlatformCapability.bluetooth: true,
          PlatformCapability.vibration: false,
          PlatformCapability.orientation: false,
          PlatformCapability.background: true,
        };
      case PlatformType.linux:
        return {
          PlatformCapability.camera: true,
          PlatformCapability.nfc: false,
          PlatformCapability.ar: false,
          PlatformCapability.gps: false,
          PlatformCapability.biometrics: false,
          PlatformCapability.notifications: true,
          PlatformCapability.fileSystem: true,
          PlatformCapability.bluetooth: true,
          PlatformCapability.vibration: false,
          PlatformCapability.orientation: false,
          PlatformCapability.background: true,
        };
      case PlatformType.web:
        return {
          PlatformCapability.camera: false, // Could be true with WebRTC but QR scanner package doesn't support it
          PlatformCapability.nfc: false,
          PlatformCapability.ar: false,
          PlatformCapability.gps: true, // Web geolocation API
          PlatformCapability.biometrics: false,
          PlatformCapability.notifications: true, // Web notifications
          PlatformCapability.fileSystem: false, // Limited access
          PlatformCapability.bluetooth: false,
          PlatformCapability.vibration: false,
          PlatformCapability.orientation: false,
          PlatformCapability.background: false,
        };
      case PlatformType.fuchsia:
        return {
          PlatformCapability.camera: true,
          PlatformCapability.nfc: true,
          PlatformCapability.ar: true,
          PlatformCapability.gps: true,
          PlatformCapability.biometrics: true,
          PlatformCapability.notifications: true,
          PlatformCapability.fileSystem: true,
          PlatformCapability.bluetooth: true,
          PlatformCapability.vibration: true,
          PlatformCapability.orientation: true,
          PlatformCapability.background: true,
        };
    }
  }

  // Convenience methods for specific capabilities
  bool get hasCamera => capabilities[PlatformCapability.camera] ?? false;
  bool get hasAR => capabilities[PlatformCapability.ar] ?? false;
  bool get hasNFC => capabilities[PlatformCapability.nfc] ?? false;
  bool get hasGPS => capabilities[PlatformCapability.gps] ?? false;
  bool get hasBiometrics => capabilities[PlatformCapability.biometrics] ?? false;
  bool get hasNotifications => capabilities[PlatformCapability.notifications] ?? false;
  bool get hasFileSystem => capabilities[PlatformCapability.fileSystem] ?? false;
  bool get hasBluetooth => capabilities[PlatformCapability.bluetooth] ?? false;
  bool get hasVibration => capabilities[PlatformCapability.vibration] ?? false;
  bool get hasOrientation => capabilities[PlatformCapability.orientation] ?? false;
  bool get hasBackground => capabilities[PlatformCapability.background] ?? false;

  // Feature-specific helpers
  bool get supportsQRScanning => hasCamera && !isWeb;
  bool get supportsARFeatures => hasAR && isMobile;
  bool get supportsWalletConnect => !isWeb; // WalletConnect works better on mobile/desktop
  bool get supportsClipboard => true; // All platforms support clipboard
  bool get supportsPushNotifications => hasNotifications && (isMobile || isDesktop);
  bool get supportsBackgroundSync => hasBackground && !isWeb;

  // Platform-specific UI helpers
  double get defaultPadding {
    if (isMobile) return 16.0;
    if (isDesktop) return 24.0;
    return 20.0; // web
  }

  double get defaultBorderRadius {
    if (isMobile) return 12.0;
    if (isDesktop) return 8.0;
    return 10.0; // web
  }

  EdgeInsets get defaultMargin {
    if (isMobile) return const EdgeInsets.all(16);
    if (isDesktop) return const EdgeInsets.all(24);
    return const EdgeInsets.all(20); // web
  }

  // Responsive breakpoints
  bool isSmallScreen(double width) => width < 600;
  bool isMediumScreen(double width) => width >= 600 && width < 1200;
  bool isLargeScreen(double width) => width >= 1200;

  // Platform-specific messages
  String getUnsupportedFeatureMessage(String feature) {
    switch (currentPlatform) {
      case PlatformType.web:
        return '$feature is not available on web browsers. Please use the mobile or desktop app for this feature.';
      case PlatformType.windows:
      case PlatformType.macos:
      case PlatformType.linux:
        return '$feature is not available on desktop platforms. Please use the mobile app for this feature.';
      default:
        return '$feature is not supported on this platform.';
    }
  }

  // Platform-specific icons
  IconData getQRScannerIcon() {
    if (supportsQRScanning) return Icons.qr_code_scanner;
    return Icons.qr_code_scanner_outlined; // Grayed out version
  }

  IconData getARIcon() {
    if (supportsARFeatures) return Icons.view_in_ar;
    return Icons.view_in_ar_outlined; // Grayed out version
  }

  // Platform-specific colors
  Color getUnsupportedFeatureColor(BuildContext context) {
    return Theme.of(context).disabledColor;
  }

  Color getSupportedFeatureColor(BuildContext context) {
    return Theme.of(context).primaryColor;
  }

  // Debug info
  Map<String, dynamic> get debugInfo => {
    'platform': currentPlatform.toString(),
    'isMobile': isMobile,
    'isDesktop': isDesktop,
    'isWeb': isWeb,
    'capabilities': capabilities.map((key, value) => MapEntry(key.toString(), value)),
  };

  @override
  String toString() => 'PlatformProvider(${currentPlatform.toString()})';
}
