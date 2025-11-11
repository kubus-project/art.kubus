import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import 'dart:math';

class ProfileProvider extends ChangeNotifier {
  UserProfile? _currentUser;
  List<UserProfile> _followingUsers = [];
  final List<UserProfile> _followers = [];
  bool _isSignedIn = false;
  bool _useMockData = false;
  
  // Mock data storage for collections
  int _mockCollectionsCount = 8;
  late SharedPreferences _prefs;
  final Random _random = Random();
  
  UserProfile? get currentUser => _currentUser;
  UserProfile? get profile => _currentUser; // Alias for compatibility
  List<UserProfile> get followingUsers => _followingUsers;
  List<UserProfile> get followers => _followers;
  bool get isSignedIn => _isSignedIn;
  bool get useMockData => _useMockData;
  
  // Dynamic getters for profile stats
  int get artworksCount => _useMockData ? 
    (_currentUser?.artworksCount ?? _random.nextInt(50) + 5) : 
    (_currentUser?.artworksCount ?? 0);
    
  int get collectionsCount => _useMockData ? 
    _mockCollectionsCount : 
    (_currentUser?.collectionsCount ?? 0);
    
  int get followersCount => _useMockData ?
    (_currentUser?.followersCount ?? _random.nextInt(5000) + 100) :
    (_followers.length);
    
  int get followingCount => _useMockData ?
    (_currentUser?.followingCount ?? _random.nextInt(500) + 50) :
    (_followingUsers.length);
    
  String get formattedFollowersCount => _formatCount(followersCount);
  String get formattedFollowingCount => _formatCount(followingCount);
  String get formattedArtworksCount => _formatCount(artworksCount);
  String get formattedCollectionsCount => _formatCount(collectionsCount);
  
  void setCurrentUser(UserProfile user) {
    _currentUser = user;
    _isSignedIn = true;
    notifyListeners();
  }
  
  // Initialize SharedPreferences and settings
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _useMockData = _prefs.getBool('use_mock_data') ?? false;
    _mockCollectionsCount = _prefs.getInt('mock_collections_count') ?? 8;
    notifyListeners();
  }
  
  // Mock data management
  void setUseMockData(bool useMock) {
    _useMockData = useMock;
    _prefs.setBool('use_mock_data', useMock);
    
    // Generate new random values when enabling mock data
    if (useMock) {
      _mockCollectionsCount = _random.nextInt(20) + 2;
      _prefs.setInt('mock_collections_count', _mockCollectionsCount);
    }
    
    notifyListeners();
  }
  
  // Sync with ConfigProvider
  void syncWithConfigProvider(bool useMockData) {
    if (_useMockData != useMockData) {
      setUseMockData(useMockData);
    }
  }
  
  // Helper method to format large numbers
  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
  
  void signOut() {
    _currentUser = null;
    _followingUsers.clear();
    _followers.clear();
    _isSignedIn = false;
    notifyListeners();
  }
  
  void followUser(UserProfile user) {
    if (!_followingUsers.any((u) => u.id == user.id)) {
      _followingUsers.add(user);
      notifyListeners();
    }
  }
  
  void unfollowUser(String userId) {
    _followingUsers.removeWhere((user) => user.id == userId);
    notifyListeners();
  }
  
  bool isFollowing(String userId) {
    return _followingUsers.any((user) => user.id == userId);
  }
  
  void addFollower(UserProfile user) {
    if (!_followers.any((u) => u.id == user.id)) {
      _followers.add(user);
      notifyListeners();
    }
  }
  
  void removeFollower(String userId) {
    _followers.removeWhere((user) => user.id == userId);
    notifyListeners();
  }
  
  // Initialize with sample data
  void initializeSampleData() {
    _followingUsers = UserProfile.getSampleUsers().where((user) => user.isFollowing).toList();
    
    // Set a default current user
    _currentUser = UserProfile(
      id: 'current_user',
      name: 'Current User',
      username: '@current_user',
      bio: 'Digital artist exploring the intersection of AR, blockchain, and creativity.',
      profileImageUrl: '',
      followersCount: 1250,
      followingCount: _followingUsers.length,
      artworksCount: 45,
      collectionsCount: 8,
      isFollowing: false,
      isVerified: true,
      joinDate: DateTime.now().subtract(const Duration(days: 365)),
      badges: ['Creator', 'Early Adopter'],
    );
    _isSignedIn = true;
    
    notifyListeners();
  }
}