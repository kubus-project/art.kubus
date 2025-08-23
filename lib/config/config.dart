import 'package:flutter/foundation.dart';

/// Production-ready configuration for art.kubus app
/// Manages feature flags, debug settings, and environment configuration
class AppConfig {
  // ===========================================
  // ENVIRONMENT CONFIGURATION
  // ===========================================
  
  /// Current environment mode
  static const bool isProduction = kReleaseMode;
  static const bool isDevelopment = kDebugMode;
  static const bool isProfile = kProfileMode;
  
  // ===========================================
  // FEATURE FLAGS
  // ===========================================
  
  /// Enable/disable mock data for development
  static const bool useMockData = true; // Set to false for production
  
  /// Community features
  static const bool enableLiking = true;
  static const bool enableCommenting = true;
  static const bool enableSharing = true;
  static const bool enableReporting = true;
  
  /// Web3 and Marketplace features
  static const bool enableWeb3 = true;
  static const bool enableMarketplace = true;
  static const bool enableNFTMinting = true;
  static const bool enableWalletConnect = true;
  static const bool enforceWalletOnboarding = false; // Allow explore-only mode
  
  /// AR and Camera features
  static const bool enableARViewer = true;
  static const bool enableCameraCapture = true;
  static const bool enableLocationServices = true;
  
  /// Social features
  static const bool enableUserProfiles = true;
  static const bool enableFollowing = true;
  static const bool enableMessaging = false; // Future feature
  
  /// Analytics and tracking
  static const bool enableAnalytics = isProduction;
  static const bool enableCrashReporting = isProduction;
  static const bool enablePerformanceMonitoring = isProduction;
  
  // ===========================================
  // DEBUG AND DEVELOPMENT SETTINGS
  // ===========================================
  
  /// Debug prints and logging
  static const bool enableDebugPrints = isDevelopment;
  static const bool enableVerboseLogging = isDevelopment;
  static const bool enableNetworkLogging = isDevelopment;
  
  /// Development helpers
  static const bool showPerformanceOverlay = false;
  static const bool showDebugBanner = isDevelopment;
  static const bool enableInspector = isDevelopment;
  
  // ===========================================
  // USER EXPERIENCE SETTINGS
  // ===========================================
  
  /// Welcome and onboarding
  static const bool showWelcomeScreen = true;
  static const bool forceWalletOnboarding = true; // Prompt wallet for non-explore features
  static const bool enableGuestMode = true; // Allow explore without wallet
  
  /// Audio and haptics
  static const bool enableSoundEffects = true;
  static const bool enableHapticFeedback = true;
  static const bool enableBackgroundMusic = false;
  
  /// Animations and transitions
  static const bool enableAnimations = true;
  static const bool enablePageTransitions = true;
  static const bool reduceMotion = false; // Accessibility setting
  
  // ===========================================
  // NETWORK AND API CONFIGURATION
  // ===========================================
  
  /// API endpoints
  static const String baseApiUrl = isDevelopment 
    ? 'https://dev-api.artkubus.com' 
    : 'https://api.artkubus.com';
  
  /// IPFS configuration (future integration)
  static const String ipfsGateway = 'https://gateway.pinata.cloud/ipfs/';
  static const String ipfsApiUrl = 'https://api.pinata.cloud/pinning/';
  static const bool enableIPFS = false; // Future feature
  
  /// Blockchain networks
  static const String defaultNetwork = isDevelopment ? 'goerli' : 'mainnet';
  static const Map<String, String> rpcUrls = {
    'mainnet': 'https://mainnet.infura.io/v3/',
    'goerli': 'https://goerli.infura.io/v3/',
    'polygon': 'https://polygon-rpc.com/',
  };
  
  // ===========================================
  // CONTENT AND MEDIA SETTINGS
  // ===========================================
  
  /// Image and media limits
  static const int maxImageSizeMB = 10;
  static const int maxVideoSizeMB = 50;
  static const int maxAudioSizeMB = 20;
  static const List<String> supportedImageFormats = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
  static const List<String> supportedVideoFormats = ['mp4', 'mov', 'avi', 'webm'];
  static const List<String> supportedAudioFormats = ['mp3', 'wav', 'aac', 'ogg'];
  
  /// AR model limits
  static const int maxModelSizeMB = 25;
  static const List<String> supportedModelFormats = ['glb', 'gltf', 'obj', 'fbx'];
  
  // ===========================================
  // CACHE AND STORAGE SETTINGS
  // ===========================================
  
  /// Cache configuration
  static const int imageCacheMaxSizeMB = 100;
  static const int modelCacheMaxSizeMB = 500;
  static const Duration cacheExpiration = Duration(days: 7);
  
  /// Local storage
  static const int maxLocalStorageMB = 1000;
  static const bool enableOfflineMode = true;
  
  // ===========================================
  // SECURITY AND PRIVACY SETTINGS
  // ===========================================
  
  /// Security features
  static const bool enableBiometricAuth = true;
  static const bool enableEncryption = true;
  static const bool enableSecureStorage = true;
  
  /// Privacy settings
  static const bool enableLocationPrivacy = true;
  static const bool enableDataMinimization = true;
  static const bool enableAnonymousMode = false; // Future feature
  
  // ===========================================
  // PERFORMANCE SETTINGS
  // ===========================================
  
  /// Rendering and graphics
  static const int maxConcurrentDownloads = 3;
  static const int imageCompressionQuality = 85;
  static const bool enableImageOptimization = true;
  
  /// Memory management
  static const int maxCachedImages = 50;
  static const int maxCachedModels = 10;
  static const Duration memoryCleanupInterval = Duration(minutes: 5);
  
  // ===========================================
  // BUSINESS LOGIC SETTINGS
  // ===========================================
  
  /// Marketplace
  static const double platformFeePercentage = 2.5;
  static const double minPriceSOL = 0.001;
  static const double maxPriceSOL = 1000.0;
  
  /// Rewards and gamification
  static const int dailyLoginReward = 10;
  static const int artworkUploadReward = 50;
  static const int artworkDiscoveryReward = 5;
  
  // ===========================================
  // UI/UX CONFIGURATION
  // ===========================================
  
  /// Animation durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 400);
  static const Duration longAnimationDuration = Duration(milliseconds: 600);
  
  /// Loading and retry settings
  static const Duration requestTimeout = Duration(seconds: 30);
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // ===========================================
  // HELPER METHODS
  // ===========================================
  
  /// Check if feature is enabled
  static bool isFeatureEnabled(String feature) {
    switch (feature) {
      case 'mockData': return useMockData;
      case 'liking': return enableLiking;
      case 'commenting': return enableCommenting;
      case 'web3': return enableWeb3;
      case 'marketplace': return enableMarketplace;
      case 'ar': return enableARViewer;
      case 'analytics': return enableAnalytics;
      case 'debug': return enableDebugPrints;
      case 'sounds': return enableSoundEffects;
      case 'haptics': return enableHapticFeedback;
      case 'animations': return enableAnimations;
      case 'ipfs': return enableIPFS;
      default: return false;
    }
  }
  
  /// Get current environment string
  static String get environmentName {
    if (isProduction) return 'production';
    if (isDevelopment) return 'development';
    if (isProfile) return 'profile';
    return 'unknown';
  }
  
  /// Debug print helper
  static void debugPrint(String message) {
    if (enableDebugPrints) {
      if (kDebugMode) {
        print('[ArtKubus Debug] $message');
      }
    }
  }
  
  /// Verbose logging helper
  static void verboseLog(String category, String message) {
    if (enableVerboseLogging) {
      debugPrint('[$category] $message');
    }
  }
  
  /// Network logging helper
  static void networkLog(String method, String url, {Map<String, dynamic>? data}) {
    if (enableNetworkLogging) {
      debugPrint('[$method] $url ${data != null ? '- Data: $data' : ''}');
    }
  }
}

/// App version and build information
class AppInfo {
  static const String appName = 'art.kubus';
  static const String version = '0.0.1';
  static const int buildNumber = 1;
  static const String buildDate = '2025-08-22';
  
  /// Get full version string
  static String get fullVersion => '$version+$buildNumber';
  
  /// Get app info string
  static String get appInfo => '$appName v$fullVersion (${AppConfig.environmentName})';
}

/// Constants for shared preferences keys
class PreferenceKeys {
  static const String isFirstLaunch = 'is_first_launch';
  static const String hasSeenWelcome = 'has_seen_welcome';
  static const String hasCompletedOnboarding = 'has_completed_onboarding';
  static const String walletAddress = 'wallet_address';
  static const String selectedNetwork = 'selected_network';
  static const String soundEnabled = 'sound_enabled';
  static const String hapticsEnabled = 'haptics_enabled';
  static const String animationsEnabled = 'animations_enabled';
  static const String isDarkMode = 'is_dark_mode';
  static const String selectedLanguage = 'selected_language';
  static const String lastSync = 'last_sync';
  static const String userProfile = 'user_profile';
}
