import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;
import '../providers/profile_provider.dart';
import '../providers/themeprovider.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _twitterController;
  late TextEditingController _instagramController;
  late TextEditingController _websiteController;
  
  String? _avatarUrl;
  bool _isLoading = false;
  Uint8List? _localAvatarBytes;
  final ImagePicker _picker = ImagePicker();
  VoidCallback? _profileListener;

  @override
  void initState() {
    super.initState();
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final profile = profileProvider.currentUser;
    
    // Show username without any leading '@' in the edit field for a cleaner UX.
    final initialUsername = (profile?.username ?? '').toString().replaceFirst(RegExp(r'^@+'), '');
    _usernameController = TextEditingController(text: initialUsername);
    _displayNameController = TextEditingController(text: profile?.displayName ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
    // Avoid null map index when social is null
    final social = profile?.social ?? <String, String>{};
    _twitterController = TextEditingController(text: social['twitter'] ?? '');
    _instagramController = TextEditingController(text: social['instagram'] ?? '');
    _websiteController = TextEditingController(text: social['website'] ?? '');
    _avatarUrl = profile?.avatar;

    // Listen to profile provider changes so avatar updates immediately when provider updates
    _profileListener = () {
      final p = profileProvider.currentUser;
      if (!mounted) return;
      setState(() {
        _avatarUrl = p?.avatar;
      });
    };
    profileProvider.addListener(_profileListener!);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    _twitterController.dispose();
    _instagramController.dispose();
    _websiteController.dispose();
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    if (_profileListener != null) {
      profileProvider.removeListener(_profileListener!);
      _profileListener = null;
    }
    super.dispose();
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
        // Read bytes and show local preview immediately (works for gallery and PC)
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
              const SnackBar(
                content: Text('No wallet connected. Connect your wallet to upload avatar.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // Ensure profile exists and obtain JWT for authenticated upload
          await profileProvider.saveProfile(walletAddress: wallet);

          // Upload avatar to backend using bytes (handles content:// URIs on Android)
          final fileName = (image.name.isNotEmpty) ? image.name : path.basename(image.path);
          final uploadedUrl = await profileProvider.uploadAvatarBytes(
            fileBytes: bytes,
            fileName: fileName,
            walletAddress: wallet,
            mimeType: image.mimeType,
          );

          // Immediately save the avatar URL to the profile on the backend so it persists
          final saved = await profileProvider.saveProfile(
            walletAddress: wallet,
            avatar: uploadedUrl,
          );

          setState(() {
            _avatarUrl = uploadedUrl;
            // Keep local preview cleared since backend URL is now available
            _localAvatarBytes = null;
            _isLoading = false;
          });

          // Show resolved URL with actions: copy and open in browser
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
              backgroundColor: saved ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        } catch (e) {
          setState(() => _isLoading = false);
          if (!mounted) return;
          final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
          // Show snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: $e'),
              backgroundColor: Colors.red,
            ),
          );

          // If debug info is available, show detailed dialog with raw server response
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
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final wallet = profileProvider.currentUser?.walletAddress;

      if (wallet == null) {
        throw Exception('No wallet connected');
      }

      final success = await profileProvider.saveProfile(
        walletAddress: wallet,
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
        avatar: _avatarUrl,
        social: {
          'twitter': _twitterController.text.trim(),
          'instagram': _instagramController.text.trim(),
          'website': _websiteController.text.trim(),
        },
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        throw Exception(profileProvider.error ?? 'Failed to save profile');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildAvatarWidget(String url, ThemeProvider themeProvider) {
    // If we have a local picked image, show it immediately
    if (_localAvatarBytes != null) {
      return Image.memory(
        _localAvatarBytes!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.person,
            size: 60,
            color: themeProvider.accentColor,
          );
        },
      );
    }
    // Ensure we use raster images; convert known SVG avatar URLs (DiceBear) to PNG.
    String displayUrl = url;
    try {
      final lower = url.toLowerCase();
      if (lower.contains('dicebear') && (lower.contains('/svg') || lower.contains('format=svg') || lower.contains('type=svg') || lower.endsWith('.svg'))) {
        displayUrl = url.replaceAll(RegExp(r'/svg(?=/|\?|$)', caseSensitive: false), '/png')
            .replaceAll(RegExp(r'\.svg(\?|$)', caseSensitive: false), '.png')
            .replaceAll(RegExp(r'format=svg', caseSensitive: false), 'format=png')
            .replaceAll(RegExp(r'type=svg', caseSensitive: false), 'type=png');
      } else if (lower.endsWith('.svg') || lower.contains('.svg?')) {
        displayUrl = url.replaceAll(RegExp(r'\.svg', caseSensitive: false), '.png');
      }
    } catch (_) {
      displayUrl = url;
    }

    return Image.network(
      displayUrl,
      fit: BoxFit.cover,
      width: 120,
      height: 120,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.person,
          size: 60,
          color: themeProvider.accentColor,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: Text(
                'Save',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.accentColor,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar section
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
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
                                        size: 60,
                                        color: themeProvider.accentColor,
                                      ),
                              ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: themeProvider.accentColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  width: 2,
                                ),
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
                    const SizedBox(height: 12),
                    Text(
                      'Tap to change avatar',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Username
              Text(
                'Username',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  hintText: 'Enter username',
                  prefixIcon: const Icon(Icons.alternate_email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.primaryContainer,
                ),
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
              const SizedBox(height: 24),

              // Display Name
              Text(
                'Display Name',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  hintText: 'Enter display name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.primaryContainer,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Display name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Bio
              Text(
                'Bio',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bioController,
                maxLines: 4,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Tell us about yourself...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.primaryContainer,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),

              // Social Links Section
              Text(
                'Social Links',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),

              // Twitter
              TextFormField(
                controller: _twitterController,
                decoration: InputDecoration(
                  hintText: '@username',
                  labelText: 'Twitter',
                  prefixIcon: const Icon(Icons.alternate_email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.primaryContainer,
                ),
              ),
              const SizedBox(height: 16),

              // Instagram
              TextFormField(
                controller: _instagramController,
                decoration: InputDecoration(
                  hintText: '@username',
                  labelText: 'Instagram',
                  prefixIcon: const Icon(Icons.camera_alt),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.primaryContainer,
                ),
              ),
              const SizedBox(height: 16),

              // Website
              TextFormField(
                controller: _websiteController,
                decoration: InputDecoration(
                  hintText: 'https://...',
                  labelText: 'Website',
                  prefixIcon: const Icon(Icons.language),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.primaryContainer,
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (!value.startsWith('http://') && !value.startsWith('https://')) {
                      return 'URL must start with http:// or https://';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
