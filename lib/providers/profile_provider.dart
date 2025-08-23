import 'package:flutter/material.dart';
import '../models/user_profile.dart';

class ProfileProvider extends ChangeNotifier {
  UserProfile? _currentUser;
  List<UserProfile> _followingUsers = [];
  final List<UserProfile> _followers = [];
  bool _isSignedIn = false;
  
  UserProfile? get currentUser => _currentUser;
  UserProfile? get profile => _currentUser; // Alias for compatibility
  List<UserProfile> get followingUsers => _followingUsers;
  List<UserProfile> get followers => _followers;
  bool get isSignedIn => _isSignedIn;
  
  void setCurrentUser(UserProfile user) {
    _currentUser = user;
    _isSignedIn = true;
    notifyListeners();
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
      isFollowing: false,
      isVerified: true,
      joinDate: DateTime.now().subtract(const Duration(days: 365)),
      badges: ['Creator', 'Early Adopter'],
    );
    _isSignedIn = true;
    
    notifyListeners();
  }
}