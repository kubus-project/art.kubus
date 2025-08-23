import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import '../models/achievements.dart';
import '../providers/themeprovider.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? username;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.username,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with TickerProviderStateMixin {
  User? user;
  bool isLoading = true;
  late AnimationController _followButtonController;
  late Animation<double> _followButtonAnimation;

  @override
  void initState() {
    super.initState();
    _followButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _followButtonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _followButtonController, curve: Curves.easeInOut),
    );
    _loadUser();
  }

  @override
  void dispose() {
    _followButtonController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    setState(() {
      isLoading = true;
    });

    User? loadedUser;
    if (widget.username != null) {
      loadedUser = await UserService.getUserByUsername(widget.username!);
    } else {
      loadedUser = await UserService.getUserById(widget.userId);
    }

    setState(() {
      user = loadedUser;
      isLoading = false;
    });
  }

  Future<void> _toggleFollow() async {
    if (user == null) return;

    _followButtonController.forward().then((_) {
      _followButtonController.reverse();
    });

    final newFollowState = await UserService.toggleFollow(user!.id);
    
    setState(() {
      user = user!.copyWith(
        isFollowing: newFollowState,
        followersCount: newFollowState 
            ? user!.followersCount + 1 
            : user!.followersCount - 1,
      );
    });

    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newFollowState 
                ? 'Following ${user!.name}' 
                : 'Unfollowed ${user!.name}',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Profile',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Profile',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(
          child: Text('User not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          user!.name,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Share profile functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile shared!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showMoreOptions();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(themeProvider),
            _buildStatsRow(),
            _buildActionButtons(themeProvider),
            _buildAchievements(themeProvider),
            _buildPostsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Profile Image
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  themeProvider.accentColor,
                  themeProvider.accentColor.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: themeProvider.accentColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 50,
            ),
          ),
          const SizedBox(height: 16),
          
          // Name and Username
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user!.name,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (user!.isVerified) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.verified,
                  color: themeProvider.accentColor,
                  size: 20,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            user!.username,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          
          // Bio
          Text(
            user!.bio,
            style: GoogleFonts.inter(
              fontSize: 16,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          
          // Join Date
          Text(
            user!.joinedDate,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Posts', user!.postsCount.toString()),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
          ),
          _buildStatItem('Followers', _formatCount(user!.followersCount)),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
          ),
          _buildStatItem('Following', _formatCount(user!.followingCount)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String count) {
    return Column(
      children: [
        Text(
          count,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: ScaleTransition(
              scale: _followButtonAnimation,
              child: ElevatedButton(
                onPressed: _toggleFollow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: user!.isFollowing 
                      ? Theme.of(context).colorScheme.surface
                      : themeProvider.accentColor,
                  foregroundColor: user!.isFollowing 
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.white,
                  side: user!.isFollowing 
                      ? BorderSide(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                        )
                      : null,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  user!.isFollowing ? 'Following' : 'Follow',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              // Message functionality - to be implemented later
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Messaging feature coming soon!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: BorderSide(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Icon(Icons.message),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievements(ThemeProvider themeProvider) {
    if (user!.achievementProgress.isEmpty) return const SizedBox.shrink();
    
    // Get only completed achievements
    final completedAchievements = user!.achievementProgress
        .where((progress) => progress.isCompleted)
        .map((progress) => AchievementService.getAchievementById(progress.achievementId))
        .where((achievement) => achievement != null)
        .cast<Achievement>()
        .toList();
        
    if (completedAchievements.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Achievements',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                '${completedAchievements.length}/${AchievementService.allAchievements.length}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: themeProvider.accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: completedAchievements.map((achievement) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      achievement.color.withOpacity(0.2),
                      achievement.color.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: achievement.color.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      achievement.icon,
                      size: 16,
                      color: achievement.color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      achievement.title,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${achievement.points}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Posts',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          // Placeholder for user's posts
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'User posts will appear here',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionItem(Icons.block, 'Block User', () {
              Navigator.pop(context);
              _showBlockConfirmation();
            }),
            _buildOptionItem(Icons.report, 'Report User', () {
              Navigator.pop(context);
              _showReportDialog();
            }),
            _buildOptionItem(Icons.copy, 'Copy Profile Link', () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile link copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        title,
        style: GoogleFonts.inter(fontSize: 16),
      ),
      onTap: onTap,
    );
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Block ${user!.name}?',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'They won\'t be able to see your profile or posts.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${user!.name} has been blocked'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Report ${user!.name}',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Why are you reporting this user?',
              style: GoogleFonts.inter(),
            ),
            const SizedBox(height: 16),
            _buildReportOption('Spam'),
            _buildReportOption('Inappropriate content'),
            _buildReportOption('Harassment'),
            _buildReportOption('Other'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportOption(String reason) {
    return ListTile(
      title: Text(reason),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted. Thank you for your feedback.'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
}
