import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Unified AR Service for cross-platform AR functionality
/// Supports both Android (ARCore) and iOS (ARKit)
class ARService {
  static final ARService _instance = ARService._internal();
  factory ARService() => _instance;
  ARService._internal();

  bool _isInitialized = false;
  bool _hasARSupport = false;

  /// Check if the device supports AR features
  Future<bool> checkARSupport() async {
    if (Platform.isAndroid) {
      // ARCore is available on Android 7.0+ with Google Play Services
      return true; // Most modern Android devices support ARCore
    } else if (Platform.isIOS) {
      // ARKit is available on iOS 11+ with A9 chip or later
      return true; // Most modern iOS devices support ARKit
    }
    return false;
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
      return 'ARCore (Android)';
    } else if (Platform.isIOS) {
      return 'ARKit (iOS)';
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
