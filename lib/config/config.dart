import 'package:flutter/foundation.dart' as foundation;
import 'api_keys.dart';

/// Production-ready configuration for art.kubus app
/// Manages feature flags, debug settings, and environment configuration
class AppConfig {
  // ===========================================
  // ENVIRONMENT CONFIGURATION
  // ===========================================
  
  /// Current environment mode
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
  static const bool isProfile = bool.fromEnvironment('dart.vm.profile');
  static const bool isDevelopment = !isProduction && !isProfile;
  
  // ===========================================
  // FEATURE FLAGS
  // ===========================================
  
  /// Use backend mock data endpoint (controlled by backend .env)
  static const bool useBackendMockData = false; // Backend serves mock data when USE_MOCK_DATA=true
  
  /// Use real blockchain connections by default
  static const bool useRealBlockchain = true;
  
  /// Community features
  static const bool enableLiking = true;
  static const bool enableCommenting = true;
  static const bool enableSharing = true;
  static const bool enableReporting = true;
  static const bool enableSupportTickets = true;
  
  /// Web3 and Marketplace features
  static const bool enableWeb3 = true;
  static const bool enableMarketplace = true;
  static const bool enableNFTMinting = true;
  static const bool enableEvents = true;
  static const bool enableExhibitions = true;
  static const bool enableCollections = true;
  static const bool enableInstitutions = true;
  static const bool enableDaoOnchainTreasury = true;
  static const bool enableDaoReviewDecisions = true;
  static const bool enableWalletConnect = true;
  static const bool enableEmailAuth = true;
  static const bool enableGoogleAuth = true;
  static const bool enableMultiAuthEntry = true;
  static const bool enforceWalletOnboarding = false; // Don't force wallet during onboarding - let users set it up when needed
  
  /// AR and Camera features
  static const bool enableARViewer = true;
  static const bool enableCameraCapture = true;
  static const bool enableLocationServices = true;
  
  /// Social features
  static const bool enableUserProfiles = true;
  static const bool enableFollowing = true;
  static const bool enableMessaging = true; // Future feature
  static const bool enablePresence = true;
  static const bool enablePresenceLastVisitedLocation = true;

  /// Web: proxy external images via backend to avoid CORS failures in CanvasKit.
  ///
  /// This should generally stay enabled for web builds; the backend still enforces
  /// SSRF protections + byte limits.
  static const bool enableExternalImageProxy = true;

  // Auth UX: re-prompt login when backend token expires.
  static const bool enableRePromptLoginOnExpiry = true;

  /// Collaboration (events/exhibitions)
  static const bool enableCollabInvites = true;
  static const bool enableCollabInviteNotifications = true;

  /// Season 0 beta program
  static const bool enableSeason0 = true;

  /// Labs section (advanced Web3 surfaces: marketplace/minting/DAO terminology)
  static const bool enableLabs = true;
  
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

  /// Debug-only endpoint access
  ///
  /// NOTE: /api/profiles/issue-token is API-key/admin gated on the backend.
  /// Production clients should not rely on it.
  static const bool enableDebugIssueToken = isDevelopment;
  
  /// Development helpers
  static const bool showPerformanceOverlay = false;
  static const bool showDebugBanner = isDevelopment;
  static const bool enableInspector = isDevelopment;
  
  // ===========================================
  // USER EXPERIENCE SETTINGS
  // ===========================================
  
  /// Welcome and onboarding
  static const bool showWelcomeScreen = true;
  static const bool skipOnboardingForReturningUsers = true; 
  static const bool skipWeb3OnboardingForReturningUsers = true; 
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
  static const String baseApiUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: isDevelopment ? 'https://api.kubus.site' : 'https://api.kubus.site',
  );

  /// Canonical app base URL used for share links (web + deep links).
  ///
  /// Example: https://app.kubus.site
  static const String appBaseUrl = String.fromEnvironment(
    'APP_BASE_URL',
    defaultValue: 'https://app.kubus.site',
  );
  
  /// Mock data endpoint (when useBackendMockData is true)
  static final String mockDataApiUrl = '$baseApiUrl/api/mock';
  
  /// IPFS configuration (future integration)
  static String get ipfsApiUrl => ApiKeys.ipfsApiUrl;
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
      case 'backendMockData': return useBackendMockData;
      case 'liking': return enableLiking;
      case 'commenting': return enableCommenting;
      case 'sharing': return enableSharing;
      case 'messaging': return enableMessaging;
      case 'web3': return enableWeb3;
      case 'daoOnchainTreasury': return enableDaoOnchainTreasury;
      case 'daoReviewDecisions': return enableDaoReviewDecisions;
      case 'walletConnect': return enableWalletConnect;
      case 'emailAuth': return enableEmailAuth;
      case 'googleAuth': return enableGoogleAuth;
      case 'multiAuth': return enableMultiAuthEntry;
      case 'marketplace': return enableMarketplace;
      case 'events': return enableEvents;
      case 'exhibitions': return enableExhibitions;
      case 'collections': return enableCollections;
      case 'institutions': return enableInstitutions;
      case 'ar': return enableARViewer;
      case 'analytics': return enableAnalytics;
      case 'supportTickets': return enableSupportTickets;
      case 'debug': return enableDebugPrints;
      case 'debugIssueToken': return enableDebugIssueToken;
      case 'sounds': return enableSoundEffects;
      case 'haptics': return enableHapticFeedback;
      case 'animations': return enableAnimations;
      case 'ipfs': return enableIPFS;
      case 'collabInvites': return enableCollabInvites;
      case 'collabInviteNotifications': return enableCollabInviteNotifications;
      case 'season0': return enableSeason0;
      case 'labs': return enableLabs;
      case 'presence': return enablePresence;
      case 'presenceLastVisitedLocation': return enablePresenceLastVisitedLocation;
      case 'externalImageProxy': return enableExternalImageProxy;
      case 'rePromptLoginOnExpiry': return enableRePromptLoginOnExpiry;
      default: return false;
    }
  }
  
  /// Get current environment string
  static String get environmentName {
    // Structure as a simple chain to avoid patterns that sometimes produce
    // "unreachable code after return" warnings in generated debug JS.
    if (isProduction) {
      return 'production';
    }
    if (isProfile) {
      return 'profile';
    }
    return 'development';
  }
  
  /// Debug print helper
  static void debugPrint(String message) {
    if (enableDebugPrints && foundation.kDebugMode) {
      foundation.debugPrint('[art.kubus Debug] $message');
    }
  }
  
  /// Verbose logging helper
  static void verboseLog(String category, String message) {
    if (!enableVerboseLogging) return;
    debugPrint('[$category] $message');
  }
  
  /// Network logging helper
  static void networkLog(String method, String url, {Map<String, dynamic>? data}) {
    if (!enableNetworkLogging) return;
    debugPrint('[$method] $url ${data != null ? '- Data: $data' : ''}');
  }
}

/// App version and build information
class AppInfo {
  static const String appName = 'art.kubus';
  static const String version = '0.2.4';
  static const int buildNumber = 11;
  static const String buildDate = '2026-01-04';
  
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
  /// User persona UX preference (stored per-wallet by ProfileProvider).
  static const String userPersona = 'user_persona';
  /// Marks that persona onboarding has been completed (stored per-wallet).
  static const String userPersonaOnboardedV1 = 'user_persona_onboarded_v1';
  static const String selectedNetwork = 'selected_network';
  static const String soundEnabled = 'sound_enabled';
  static const String hapticsEnabled = 'haptics_enabled';
  static const String animationsEnabled = 'animations_enabled';
  static const String isDarkMode = 'is_dark_mode';
  static const String selectedLanguage = 'selected_language';
  static const String lastSync = 'last_sync';
  static const String userProfile = 'user_profile';
}
