import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;
import '../../../providers/profile_provider.dart';
import '../../../providers/dao_provider.dart';
import '../../../services/backend_api_service.dart';
import '../../../models/user.dart';
import '../../../models/dao.dart';
import '../../../services/event_bus.dart';
import '../../../providers/themeprovider.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/media_url_resolver.dart';
import '../components/desktop_widgets.dart';

/// Desktop profile edit screen - form layout with card sections
/// Clean organized layout for editing profile information
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late TextEditingController _usernameController;
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _twitterController;
  late TextEditingController _instagramController;
  late TextEditingController _websiteController;
  late TextEditingController _specialtyController;
  late TextEditingController _yearsActiveController;
  
  String? _avatarUrl;
  String? _coverImageUrl;
  bool _isLoading = false;
  bool _isSaving = false;
  Uint8List? _localAvatarBytes;
  Uint8List? _localCoverBytes;
  final ImagePicker _picker = ImagePicker();
  VoidCallback? _profileListener;
  
  bool _privateProfile = false;
  bool _showActivityStatus = true;
  bool _showCollection = true;
  bool _allowMessages = true;
  bool _isArtist = false;
  bool _isInstitution = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final daoProvider = Provider.of<DAOProvider>(context, listen: false);
    final profile = profileProvider.currentUser;
    
    final initialUsername = (profile?.username ?? '').toString().replaceFirst(RegExp(r'^@+'), '');
    _usernameController = TextEditingController(text: initialUsername);
    _displayNameController = TextEditingController(text: profile?.displayName ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
    
    final social = profile?.social ?? <String, String>{};
    _twitterController = TextEditingController(text: social['twitter'] ?? '');
    _instagramController = TextEditingController(text: social['instagram'] ?? '');
    _websiteController = TextEditingController(text: social['website'] ?? '');
    _avatarUrl = profile?.avatar;
    _coverImageUrl = _normalizeMediaUrl(profile?.coverImage);
    
    final artistInfo = profile?.artistInfo;
    _specialtyController = TextEditingController(
      text: artistInfo?.specialty.join(', ') ?? '',
    );
    _yearsActiveController = TextEditingController(
      text: artistInfo?.yearsActive.toString() ?? '0',
    );
    
    final prefs = profile?.preferences ?? profileProvider.preferences;
    _privateProfile = prefs.privacy.toLowerCase() == 'private';
    _showActivityStatus = prefs.showActivityStatus;
    _showCollection = prefs.showCollection;
    _allowMessages = prefs.allowMessages;
    
    _isArtist = profile?.isArtist ?? false;
    _isInstitution = profile?.isInstitution ?? false;
    
    final walletAddress = profile?.walletAddress ?? '';
    if (walletAddress.isNotEmpty) {
      final daoReview = daoProvider.findReviewForWallet(walletAddress);
      if (daoReview != null && daoReview.isApproved) {
        if (daoReview.isArtistApplication) _isArtist = true;
        if (daoReview.isInstitutionApplication) _isInstitution = true;
      }
    }

    _profileListener = () {
      final p = profileProvider.currentUser;
      if (!mounted) return;
      setState(() {
        _avatarUrl = p?.avatar;
        _coverImageUrl = _normalizeMediaUrl(p?.coverImage);
      });
    };
    profileProvider.addListener(_profileListener!);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    _twitterController.dispose();
    _instagramController.dispose();
    _websiteController.dispose();
    _specialtyController.dispose();
    _yearsActiveController.dispose();
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    if (_profileListener != null) {
      profileProvider.removeListener(_profileListener!);
      _profileListener = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth >= 1200;

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF8F9FA),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: _animationController,
              curve: animationTheme.fadeCurve,
            ),
            child: Column(
              children: [
                _buildHeader(themeProvider),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLarge ? 32 : 24,
                      vertical: 24,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCoverImageSection(themeProvider),
                              const SizedBox(height: 24),
                              _buildAvatarSection(themeProvider),
                              const SizedBox(height: 32),
                              _buildBasicInfoSection(themeProvider),
                              const SizedBox(height: 24),
                              _buildSocialLinksSection(themeProvider),
                              const SizedBox(height: 24),
                              if (_isArtist || _isInstitution) ...[
                                _buildArtistInfoSection(themeProvider),
                                const SizedBox(height: 24),
                              ],
                              _buildPrivacySection(themeProvider),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: 'Back',
          ),
          const SizedBox(width: 16),
          Text(
            'Edit Profile',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          if (_isLoading || _isSaving)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else ...[
            DesktopActionButton(
              label: 'Cancel',
              icon: Icons.close,
              onPressed: () => Navigator.of(context).pop(),
              isPrimary: false,
            ),
            const SizedBox(width: 12),
            DesktopActionButton(
              label: 'Save Changes',
              icon: Icons.check,
              onPressed: _saveProfile,
              isPrimary: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoverImageSection(ThemeProvider themeProvider) {
    return DesktopCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: DesktopSectionHeader(
              title: 'Cover Image',
              subtitle: 'Recommended size: 1920x1080px',
              icon: Icons.panorama,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: GestureDetector(
              onTap: _pickCoverImage,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: themeProvider.accentColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    image: _localCoverBytes != null
                        ? DecorationImage(
                            image: MemoryImage(_localCoverBytes!),
                            fit: BoxFit.cover,
                          )
                        : _coverImageUrl != null && _coverImageUrl!.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(_coverImageUrl!),
                                fit: BoxFit.cover,
                                onError: (error, stackTrace) {
                                  // Ignore cover image load errors (e.g., 404) to avoid
                                  // bubbling into unhandled zone exceptions on web.
                                },
                              )
                            : null,
                  ),
                  child: (_localCoverBytes == null && (_coverImageUrl == null || _coverImageUrl!.isEmpty))
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 48,
                              color: themeProvider.accentColor.withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Click to upload cover image',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          alignment: Alignment.bottomRight,
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Change Cover',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection(ThemeProvider themeProvider) {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesktopSectionHeader(
            title: 'Profile Picture',
            subtitle: 'Recommended size: 512x512px',
            icon: Icons.account_circle,
          ),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Stack(
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: themeProvider.accentColor,
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                            ? _buildAvatarWidget(_avatarUrl!, themeProvider)
                            : Icon(
                                Icons.person,
                                size: 70,
                                color: themeProvider.accentColor,
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: themeProvider.accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Click to change avatar',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection(ThemeProvider themeProvider) {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesktopSectionHeader(
            title: 'Basic Information',
            subtitle: 'Your public profile details',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            label: 'Username',
            controller: _usernameController,
            hint: 'Enter username',
            icon: Icons.alternate_email,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Username is required';
              }
              if (value.trim().length < 3) {
                return 'Username must be at least 3 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'Display Name',
            controller: _displayNameController,
            hint: 'Enter display name',
            icon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Display name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'Bio',
            controller: _bioController,
            hint: 'Tell us about yourself',
            icon: Icons.info_outline,
            maxLines: 4,
            maxLength: 500,
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLinksSection(ThemeProvider themeProvider) {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesktopSectionHeader(
            title: 'Social Links',
            subtitle: 'Connect your social profiles',
            icon: Icons.link,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            label: 'Twitter',
            controller: _twitterController,
            hint: 'username',
            icon: Icons.alternate_email,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'Instagram',
            controller: _instagramController,
            hint: 'username',
            icon: Icons.camera_alt_outlined,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'Website',
            controller: _websiteController,
            hint: 'https://example.com',
            icon: Icons.language,
          ),
        ],
      ),
    );
  }

  Widget _buildArtistInfoSection(ThemeProvider themeProvider) {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesktopSectionHeader(
            title: _isInstitution ? 'Institution Details' : 'Artist Information',
            subtitle: _isInstitution
                ? 'Information about your institution'
                : 'Additional details about your artistic practice',
            icon: _isInstitution ? Icons.business : Icons.palette,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            label: _isInstitution ? 'Focus Areas' : 'Specialties',
            controller: _specialtyController,
            hint: _isInstitution
                ? 'Contemporary Art, Digital Media'
                : 'Painting, Sculpture, Digital Art',
            icon: Icons.interests_outlined,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: _isInstitution ? 'Established Year' : 'Years Active',
            controller: _yearsActiveController,
            hint: '2020',
            icon: Icons.calendar_today_outlined,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySection(ThemeProvider themeProvider) {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesktopSectionHeader(
            title: 'Privacy & Visibility',
            subtitle: 'Control who can see your content',
            icon: Icons.privacy_tip_outlined,
          ),
          const SizedBox(height: 24),
          _buildSwitchTile(
            title: 'Private Profile',
            subtitle: 'Only approved followers can see your posts',
            value: _privateProfile,
            onChanged: (value) => setState(() => _privateProfile = value),
          ),
          const Divider(height: 32),
          _buildSwitchTile(
            title: 'Show Activity Status',
            subtitle: 'Let others see when you\'re online',
            value: _showActivityStatus,
            onChanged: (value) => setState(() => _showActivityStatus = value),
          ),
          const Divider(height: 32),
          _buildSwitchTile(
            title: 'Show Collection',
            subtitle: 'Display your collected artworks on your profile',
            value: _showCollection,
            onChanged: (value) => setState(() => _showCollection = value),
          ),
          const Divider(height: 32),
          _buildSwitchTile(
            title: 'Allow Messages',
            subtitle: 'Let other users send you direct messages',
            value: _allowMessages,
            onChanged: (value) => setState(() => _allowMessages = value),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: GoogleFonts.inter(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: themeProvider.accentColor,
        ),
      ],
    );
  }

  // Helper methods for avatar and cover image
  Widget _buildAvatarWidget(String url, ThemeProvider themeProvider) {
    if (_localAvatarBytes != null) {
      return Image.memory(
        _localAvatarBytes!,
        fit: BoxFit.cover,
        width: 140,
        height: 140,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.person,
            size: 70,
            color: themeProvider.accentColor,
          );
        },
      );
    }
    
    String displayUrl = url;
    try {
      final lower = url.toLowerCase();
      if (lower.contains('dicebear')) {
        String seed = '';
        String style = 'identicon';
        try {
          final u = Uri.parse(url);
          if (u.queryParameters.containsKey('seed')) {
            seed = u.queryParameters['seed']!;
            final segs = u.pathSegments;
            if (segs.isNotEmpty) style = segs.lastWhere((s) => s.isNotEmpty, orElse: () => 'identicon');
          } else {
            final last = u.pathSegments.isNotEmpty ? u.pathSegments.last : '';
            seed = last.replaceAll('.svg', '');
            if (u.pathSegments.length >= 2) style = u.pathSegments[u.pathSegments.length - 2];
          }
        } catch (_) {
          final p = url.split('/').last;
          seed = p.split('?').first.replaceAll('.svg', '');
        }
        final base = BackendApiService().baseUrl.replaceAll(RegExp(r'/$'), '');
        displayUrl = '$base/api/avatar/${Uri.encodeComponent(seed)}?style=$style&format=png&raw=true';
      } else if (lower.endsWith('.svg') || lower.contains('.svg?')) {
        displayUrl = url.replaceAll(RegExp(r'\.svg', caseSensitive: false), '.png');
      }
    } catch (_) {
      displayUrl = url;
    }

    return Image.network(
      displayUrl,
      fit: BoxFit.cover,
      width: 140,
      height: 140,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.person,
          size: 70,
          color: themeProvider.accentColor,
        );
      },
    );
  }

  Future<void> _pickAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        setState(() {
          _localAvatarBytes = bytes;
          _isLoading = true;
        });

        try {
          final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
          final wallet = profileProvider.currentUser?.walletAddress ?? '';

          if (wallet.isEmpty) {
            setState(() => _isLoading = false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('No wallet connected. Connect your wallet to upload avatar.'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
            return;
          }

          await profileProvider.saveProfile(walletAddress: wallet);

          final fileName = (image.name.isNotEmpty) ? image.name : path.basename(image.path);
          final uploadedUrl = await profileProvider.uploadAvatarBytes(
            fileBytes: bytes,
            fileName: fileName,
            walletAddress: wallet,
            mimeType: image.mimeType,
          );

          final saved = await profileProvider.saveProfile(
            walletAddress: wallet,
            avatar: uploadedUrl,
          );

          setState(() {
            _avatarUrl = uploadedUrl;
            _localAvatarBytes = null;
            _isLoading = false;
          });

          if (!mounted) return;
          final uri = Uri.tryParse(uploadedUrl);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 6),
              content: Row(
                children: [
                  Expanded(
                    child: Text(
                      uploadedUrl,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20, color: Colors.white),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: uploadedUrl));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied avatar URL to clipboard'), duration: Duration(seconds: 1)),
                      );
                    },
                  ),
                ],
              ),
              action: uri != null
                  ? SnackBarAction(
                      label: 'Open',
                      onPressed: () async {
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (_) {}
                      },
                    )
                  : null,
            ),
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(saved ? 'Avatar uploaded and saved!' : 'Avatar uploaded locally (save failed)'),
              backgroundColor: saved
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondary,
              duration: const Duration(seconds: 2),
            ),
          );
        } catch (e) {
          setState(() => _isLoading = false);
          if (!mounted) return;
          final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );

          final debug = profileProvider.lastUploadDebug;
          if (debug != null) {
            final pretty = const JsonEncoder.withIndent('  ').convert(debug);
            showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Upload Debug Info'),
                content: SingleChildScrollView(
                  child: SelectableText(pretty),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(ClipboardData(text: pretty));
                      if (!mounted) return;
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Debug info copied to clipboard')),
                      );
                    },
                    child: const Text('Copy'),
                  ),
                ],
              ),
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 90,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        setState(() {
          _localCoverBytes = bytes;
          _isLoading = true;
        });

        try {
          final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
          final wallet = profileProvider.currentUser?.walletAddress ?? '';

          if (wallet.isEmpty) {
            if (mounted) setState(() => _isLoading = false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('No wallet connected. Connect your wallet to upload cover image.'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
            return;
          }

          final fileName = (image.name.isNotEmpty) ? image.name : path.basename(image.path);
          final api = BackendApiService();
          final result = await api.uploadFile(
            fileBytes: bytes,
            fileName: fileName,
            fileType: 'cover',
            metadata: {'uploadFolder': 'profiles/cover'},
            walletAddress: wallet,
          );

          final rawUploadedUrl = result['uploadedUrl']?.toString() ?? 
                                 result['url']?.toString() ?? 
                                 result['data']?['url']?.toString() ?? '';
          final uploadedUrl = _normalizeMediaUrl(rawUploadedUrl);

          if (uploadedUrl == null || uploadedUrl.isEmpty) {
            throw Exception('Failed to get upload URL');
          }

          final saved = await profileProvider.saveProfile(
            walletAddress: wallet,
            coverImage: uploadedUrl,
          );

          if (mounted) {
            setState(() {
              _coverImageUrl = uploadedUrl;
              _localCoverBytes = null;
              _isLoading = false;
            });
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(saved ? 'Cover image uploaded!' : 'Cover image uploaded locally'),
              backgroundColor: saved
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondary,
              duration: const Duration(seconds: 2),
            ),
          );
        } catch (e) {
          if (mounted) setState(() => _isLoading = false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cover upload failed: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking cover image: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  String? _normalizeMediaUrl(String? url) {
    return MediaUrlResolver.resolve(url);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final wallet = profileProvider.currentUser?.walletAddress;

      if (wallet == null) {
        throw Exception('No wallet connected');
      }

      await profileProvider.updatePreferences(
        privateProfile: _privateProfile,
        showActivityStatus: _showActivityStatus,
        showCollection: _showCollection,
        allowMessages: _allowMessages,
      );

      final success = await profileProvider.saveProfile(
        walletAddress: wallet,
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
        avatar: _avatarUrl,
        coverImage: _coverImageUrl,
        social: {
          'twitter': _twitterController.text.trim(),
          'instagram': _instagramController.text.trim(),
          'website': _websiteController.text.trim(),
          if (_isArtist || _isInstitution) 'specialty': _specialtyController.text.trim(),
          if (_isArtist || _isInstitution) 'yearsActive': _yearsActiveController.text.trim(),
        },
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        
        try {
          final uprof = profileProvider.currentUser;
          if (uprof != null) {
            final User updatedUser = User(
              id: uprof.walletAddress,
              name: uprof.displayName,
              username: uprof.username,
              bio: uprof.bio,
              profileImageUrl: uprof.avatar,
              followersCount: uprof.stats?.followersCount ?? 0,
              followingCount: uprof.stats?.followingCount ?? 0,
              postsCount: uprof.stats?.artworksCreated ?? 0,
              isFollowing: false,
              isVerified: false,
              joinedDate: uprof.createdAt.toIso8601String(),
              achievementProgress: [],
            );
            try { EventBus().emitProfileUpdated(updatedUser); } catch (_) {}
          }
        } catch (_) {}
        
        Navigator.pop(context, true);
      } else {
        throw Exception(profileProvider.error ?? 'Failed to save profile');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
