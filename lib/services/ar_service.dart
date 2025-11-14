import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

/// Professional AR Service using Google ARCore Scene Viewer and ARKit Quick Look
/// Supports IPFS models via HTTP gateways
class ARService {
  static final ARService _instance = ARService._internal();
  factory ARService() => _instance;
  ARService._internal();

  bool _isInitialized = false;
  bool _hasARSupport = false;

  /// Launch ARCore Scene Viewer (Android) or AR Quick Look (iOS) with a 3D model
  /// 
  /// [modelUrl] - URL to the .glb or .gltf model (can be IPFS URL)
  /// [title] - Title of the artwork
  /// [link] - Optional link for more info
  /// [sound] - Optional sound URL
  Future<bool> launchARViewer({
    required String modelUrl,
    String? title,
    String? link,
    String? sound,
    bool resizable = true,
  }) async {
    try {
      // Handle IPFS URLs - convert to HTTP gateway
      String resolvedUrl = _resolveIPFSUrl(modelUrl);

      // For Android: Use ARCore Scene Viewer
      if (Platform.isAndroid) {
        return await _launchAndroidARViewer(
          resolvedUrl: resolvedUrl,
          title: title,
          link: link,
          sound: sound,
          resizable: resizable,
        );
      }
      
      // For iOS: Use AR Quick Look
      else if (Platform.isIOS) {
        return await _launchIOSARViewer(
          resolvedUrl: resolvedUrl,
          title: title,
        );
      }
      
      return false;
    } catch (e) {
      debugPrint('Error launching AR viewer: $e');
      return false;
    }
  }

  /// Launch Android ARCore Scene Viewer
  Future<bool> _launchAndroidARViewer({
    required String resolvedUrl,
    String? title,
    String? link,
    String? sound,
    required bool resizable,
  }) async {
    final Uri arUri = Uri.parse(
      'intent://arvr.google.com/scene-viewer/1.0'
      '?file=$resolvedUrl'
      '${title != null ? '&title=${Uri.encodeComponent(title)}' : ''}'
      '${link != null ? '&link=${Uri.encodeComponent(link)}' : ''}'
      '${sound != null ? '&sound=${Uri.encodeComponent(sound)}' : ''}'
      '&mode=ar_preferred'
      '&resizable=${resizable ? "true" : "false"}'
      '#Intent;'
      'scheme=https;'
      'package=com.google.android.googlequicksearchbox;'
      'action=android.intent.action.VIEW;'
      'S.browser_fallback_url=https://developers.google.com/ar;'
      'end;'
    );

    if (await canLaunchUrl(arUri)) {
      return await launchUrl(
        arUri,
        mode: LaunchMode.externalApplication,
      );
    }
    return false;
  }

  /// Launch iOS AR Quick Look
  Future<bool> _launchIOSARViewer({
    required String resolvedUrl,
    String? title,
  }) async {
    try {
      // Download model to temp directory for iOS (requires USDZ format)
      final tempDir = await getTemporaryDirectory();
      final modelPath = '${tempDir.path}/model.usdz';
      
      // Download the model
      final response = await http.get(Uri.parse(resolvedUrl));
      if (response.statusCode == 200) {
        final file = File(modelPath);
        await file.writeAsBytes(response.bodyBytes);
        
        final Uri arUri = Uri.parse('file://$modelPath');
        if (await canLaunchUrl(arUri)) {
          return await launchUrl(
            arUri,
            mode: LaunchMode.externalApplication,
          );
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error launching iOS AR viewer: $e');
      return false;
    }
  }

  /// Convert IPFS URLs to HTTP gateway URLs
  String _resolveIPFSUrl(String url) {
    if (url.startsWith('ipfs://')) {
      final cid = url.replaceFirst('ipfs://', '');
      return 'https://ipfs.io/ipfs/$cid';
    } else if (url.contains('/ipfs/') && !url.startsWith('http')) {
      return 'https://ipfs.io$url';
    }
    return url;
  }

  /// Check if the device supports AR features
  Future<bool> checkARSupport() async {
    if (Platform.isAndroid) {
      // Check if ARCore is installed via Google Play Services
      final uri = Uri.parse('market://details?id=com.google.ar.core');
      return await canLaunchUrl(uri);
    } else if (Platform.isIOS) {
      // ARKit is available on iOS 12+ with A9 chip or later
      return true; // Assume supported on iOS
    }
    return false;
  }

  /// Open Google Play to install ARCore
  Future<void> installARCore() async {
    if (Platform.isAndroid) {
      final uri = Uri.parse('market://details?id=com.google.ar.core');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Request necessary permissions for AR functionality
  Future<bool> requestARPermissions() async {
    try {
      // Request camera permission
      final cameraStatus = await Permission.camera.request();
      
      if (cameraStatus.isGranted) {
        return true;
      } else if (cameraStatus.isPermanentlyDenied) {
        // Guide user to app settings
        await openAppSettings();
        return false;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error requesting AR permissions: $e');
      return false;
    }
  }

  /// Initialize AR session
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _hasARSupport = await checkARSupport();
      
      if (!_hasARSupport) {
        debugPrint('AR not supported on this device');
        return false;
      }

      final hasPermissions = await requestARPermissions();
      if (!hasPermissions) {
        debugPrint('AR permissions not granted');
        return false;
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('AR initialization error: $e');
      return false;
    }
  }

  /// Check if AR is initialized and ready
  bool get isReady => _isInitialized && _hasARSupport;

  /// Get platform-specific AR information
  String get platformInfo {
    if (Platform.isAndroid) {
      return 'ARCore Scene Viewer (Android)';
    } else if (Platform.isIOS) {
      return 'AR Quick Look (iOS)';
    }
    return 'Unknown Platform';
  }

  /// Dispose AR resources
  void dispose() {
    _isInitialized = false;
  }
}

/// AR Artwork Model
class ARArtwork {
  final String id;
  final String title;
  final String artist;
  final String description;
  final String modelUrl; // URL to 3D model file
  final String thumbnailUrl;
  final double latitude;
  final double longitude;
  final double scale; // Scale factor for the 3D model
  final Map<String, dynamic> metadata;

  ARArtwork({
    required this.id,
    required this.title,
    required this.artist,
    required this.description,
    required this.modelUrl,
    required this.thumbnailUrl,
    required this.latitude,
    required this.longitude,
    this.scale = 1.0,
    this.metadata = const {},
  });

  factory ARArtwork.fromJson(Map<String, dynamic> json) {
    return ARArtwork(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      description: json['description'] ?? '',
      modelUrl: json['modelUrl'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      scale: (json['scale'] ?? 1.0).toDouble(),
      metadata: json['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'description': description,
      'modelUrl': modelUrl,
      'thumbnailUrl': thumbnailUrl,
      'latitude': latitude,
      'longitude': longitude,
      'scale': scale,
      'metadata': metadata,
    };
  }
}
