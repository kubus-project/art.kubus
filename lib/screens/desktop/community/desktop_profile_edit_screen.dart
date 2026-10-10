import 'package:flutter/material.dart';
import '../../../widgets/inline_loading.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../providers/app_mode_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/dao_provider.dart';
import '../../../services/backend_api_service.dart';
import '../../../models/user.dart';
import '../../../models/user_profile.dart';
import '../../../models/dao.dart';
import '../../../services/event_bus.dart';
import '../../../providers/themeprovider.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/media_url_resolver.dart';
import '../../../utils/profile_edit_form_utils.dart';
import '../../../utils/profile_media_ref_utils.dart';
import '../../../widgets/common/kubus_screen_header.dart';
import '../../../widgets/avatar_widget.dart';
import '../desktop_shell_scope.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/app_mode_unavailable_state.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/forms/kubus_form.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:art_kubus/widgets/profile/profile_edit_form_body.dart';
import '../../../utils/kubus_color_roles.dart';

/// Desktop profile edit screen - form layout with card sections
/// Clean organized layout for editing profile information
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({
    super.key,
    this.isOnboarding = false,
    this.onSaved,
  });

  final bool isOnboarding;
  final Future<void> Function()? onSaved;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final KubusFormSubmitState _submit = KubusFormSubmitState();
  final ScrollController _scrollController = ScrollController();

  /// Form-level message: validation summary or save failure.
  String? _formNotice;
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
  bool _isSavingProfile = false;
  bool _isUploadingAvatar = false;
  bool _isUploadingCover = false;
  bool _avatarChanged = false;
  bool _coverChanged = false;
  Uint8List? _localAvatarBytes;
  Uint8List? _localCoverBytes;
  final ImagePicker _picker = ImagePicker();
  VoidCallback? _profileListener;
  ProfileProvider? _profileProvider;

  bool _privateProfile = false;
  bool _showActivityStatus = true;
  bool _shareLastVisitedLocation = false;
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

    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    _profileProvider = profileProvider;
    DAOProvider? daoProvider;
    try {
      daoProvider = Provider.of<DAOProvider>(context, listen: false);
    } catch (_) {
      daoProvider = null;
    }
    final profile = profileProvider.currentUser;

    final initialUsername =
        (profile?.username ?? '').toString().replaceFirst(RegExp(r'^@+'), '');
    _usernameController = TextEditingController(text: initialUsername);
    _displayNameController =
        TextEditingController(text: profile?.displayName ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');

    final social = profile?.social ?? <String, String>{};
    _twitterController = TextEditingController(text: social['twitter'] ?? '');
    _instagramController =
        TextEditingController(text: social['instagram'] ?? '');
    _websiteController = TextEditingController(text: social['website'] ?? '');
    _avatarUrl = _editableAvatarRef(profile?.avatar);
    _coverImageUrl = MediaUrlResolver.resolve(profile?.coverImage);

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
    _shareLastVisitedLocation = prefs.shareLastVisitedLocation;
    _showCollection = prefs.showCollection;
    _allowMessages = prefs.allowMessages;

    _isArtist = profile?.isArtist ?? false;
    _isInstitution = profile?.isInstitution ?? false;

    final walletAddress = profile?.walletAddress ?? '';
    if (walletAddress.isNotEmpty && daoProvider != null) {
      final daoReview = daoProvider.findReviewForWallet(walletAddress);
      if (daoReview != null && daoReview.isApproved) {
        if (daoReview.isArtistApplication) _isArtist = true;
        if (daoReview.isInstitutionApplication) _isInstitution = true;
      }
    }

    _profileListener = () {
      if (!mounted) return;
      _syncMediaFromProvider(profileProvider.currentUser);
    };
    profileProvider.addListener(_profileListener!);
    _animationController.forward();
  }

  String? _editableAvatarRef(String? value) {
    final avatar = value?.trim();
    if (avatar == null ||
        avatar.isEmpty ||
        ProfileMediaRefUtils.isGeneratedAvatarRef(avatar)) {
      return null;
    }
    return avatar;
  }

  void _syncMediaFromProvider(UserProfile? profile) {
    final nextAvatar = _editableAvatarRef(profile?.avatar);
    final nextCoverDisplay = MediaUrlResolver.resolve(profile?.coverImage);

    setState(() {
      if (!_isUploadingAvatar && !_avatarChanged) {
        _avatarUrl = nextAvatar;
      }

      if (!_isUploadingCover && !_coverChanged) {
        _coverImageUrl = nextCoverDisplay;
      }
    });
  }

  @visibleForTesting
  String? get debugAvatarUrl => _avatarUrl;

  @visibleForTesting
  String? get debugCoverImageUrl => _coverImageUrl;

  @visibleForTesting
  bool get debugIsUploadingAvatar => _isUploadingAvatar;

  @visibleForTesting
  bool get debugIsUploadingCover => _isUploadingCover;

  @visibleForTesting
  bool get debugIsSavingProfile => _isSavingProfile;

  @visibleForTesting
  bool get debugAvatarChanged => _avatarChanged;

  @visibleForTesting
  bool get debugCoverChanged => _coverChanged;

  @visibleForTesting
  bool get debugHasLocalAvatarBytes => _localAvatarBytes != null;

  @visibleForTesting
  bool get debugHasLocalCoverBytes => _localCoverBytes != null;

  @visibleForTesting
  void debugSetMediaSyncState({
    bool? isUploadingAvatar,
    bool? isUploadingCover,
    bool? avatarChanged,
    bool? coverChanged,
  }) {
    setState(() {
      _isUploadingAvatar = isUploadingAvatar ?? _isUploadingAvatar;
      _isUploadingCover = isUploadingCover ?? _isUploadingCover;
      _avatarChanged = avatarChanged ?? _avatarChanged;
      _coverChanged = coverChanged ?? _coverChanged;
    });
  }

  @visibleForTesting
  Future<void> debugUploadAvatarBytesForTesting({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) {
    return _uploadAvatarBytes(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  @visibleForTesting
  Future<void> debugUploadCoverBytesForTesting({
    required Uint8List bytes,
    required String fileName,
  }) {
    return _uploadCoverBytes(bytes: bytes, fileName: fileName);
  }

  @visibleForTesting
  Future<void> debugSaveProfileForTesting() => _saveProfile();

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    _twitterController.dispose();
    _instagramController.dispose();
    _websiteController.dispose();
    _specialtyController.dispose();
    _yearsActiveController.dispose();
    if (_profileListener != null) {
      _profileProvider?.removeListener(_profileListener!);
      _profileListener = null;
    }
    _profileProvider = null;
    super.dispose();
  }

  void _onPrivacyChanged(ProfilePrivacyField field, bool value) {
    setState(() {
      switch (field) {
        case ProfilePrivacyField.privateProfile:
          _privateProfile = value;
        case ProfilePrivacyField.showActivityStatus:
          _showActivityStatus = value;
          if (!value) _shareLastVisitedLocation = false;
        case ProfilePrivacyField.shareLastVisitedLocation:
          _shareLastVisitedLocation = value;
        case ProfilePrivacyField.showCollection:
          _showCollection = value;
        case ProfilePrivacyField.allowMessages:
          _allowMessages = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final appModeProvider = context.watch<AppModeProvider?>();
    final isIpfsFallbackMode = appModeProvider?.isIpfsFallbackMode ?? false;
    final animationTheme = context.animationTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    // Two-column sections need room for a 240 px title column plus a
    // readable field measure; narrower desktop panes stack like mobile.
    final wide = screenWidth >= 1100;
    const avatarDiameter = 112.0;
    final avatarFrameRadius = AvatarWidget.shapeRadiusFor(
      radius: avatarDiameter / 2,
      cornerRadiusFactor: AvatarWidget.defaultCornerRadiusFactor,
    );
    final hasCover = _localCoverBytes != null ||
        (_coverImageUrl != null && _coverImageUrl!.isNotEmpty);
    final hasAvatar = _localAvatarBytes != null ||
        (_avatarUrl != null && _avatarUrl!.isNotEmpty);
    final ImageProvider? coverImage = _localCoverBytes != null
        ? MemoryImage(_localCoverBytes!)
        : (hasCover ? NetworkImage(_coverImageUrl!) : null);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: isIpfsFallbackMode
          ? Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: AppModeUnavailableState(
                    featureLabel: l10n.profileEditTitle,
                    title: l10n.stateUnsupportedTitle,
                    icon: Icons.person_outline,
                  ),
                ),
              ],
            )
          : AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _animationController,
                    curve: animationTheme.fadeCurve,
                  ),
                  child: Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: KubusSpacing.lg,
                            vertical: KubusSpacing.lg,
                          ),
                          child: KubusFormMeasure(
                            maxWidth: wide ? 960 : 640,
                            child: Form(
                              key: _formKey,
                              autovalidateMode: _submit.autovalidateMode,
                              child: ProfileEditFormBody(
                                wide: wide,
                                switchKeyPrefix:
                                    'desktop_profile_edit_privacy_',
                                formNotice: _formNotice,
                                controllers: ProfileEditControllers(
                                  username: _usernameController,
                                  displayName: _displayNameController,
                                  bio: _bioController,
                                  twitter: _twitterController,
                                  instagram: _instagramController,
                                  website: _websiteController,
                                  specialty: _specialtyController,
                                  yearsActive: _yearsActiveController,
                                ),
                                isArtist: _isArtist,
                                isInstitution: _isInstitution,
                                privacy: ProfilePrivacyDraft(
                                  privateProfile: _privateProfile,
                                  showActivityStatus: _showActivityStatus,
                                  shareLastVisitedLocation:
                                      _shareLastVisitedLocation,
                                  showCollection: _showCollection,
                                  allowMessages: _allowMessages,
                                ),
                                onPrivacyChanged: _onPrivacyChanged,
                                coverPreview: ProfileEditCoverPreview(
                                  height: 180,
                                  isBusy: _isUploadingCover,
                                  image: coverImage,
                                ),
                                hasCover: hasCover,
                                onPickCover: _pickCoverImage,
                                isUploadingCover: _isUploadingCover,
                                avatarPreview: ExcludeSemantics(
                                  child: Container(
                                    width: avatarDiameter,
                                    height: avatarDiameter,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      color: roles.surfaceRaised,
                                      borderRadius: BorderRadius.circular(
                                          avatarFrameRadius),
                                      border: Border.all(color: roles.rule),
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        hasAvatar
                                            ? _buildAvatarWidget(
                                                _avatarUrl ?? '',
                                                themeProvider,
                                              )
                                            : Icon(
                                                Icons.person_outline,
                                                size: 44,
                                                color: roles.foregroundSubtle,
                                              ),
                                        if (_isUploadingAvatar)
                                          ColoredBox(
                                            color: roles.ground
                                                .withValues(alpha: 0.6),
                                            child: const Center(
                                              child: SizedBox(
                                                width: 28,
                                                height: 28,
                                                child:
                                                    InlineLoading(tileSize: 4),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                hasAvatar: hasAvatar,
                                onPickAvatar: _pickAvatar,
                                isUploadingAvatar: _isUploadingAvatar,
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

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: roles.ground,
        border: Border(bottom: BorderSide(color: roles.rule)),
      ),
      child: KubusScreenHeaderBar(
        title: l10n.profileEditTitle,
        leading: IconButton(
          onPressed: () => popDesktopShellAware(context),
          icon: Icon(
            Icons.arrow_back,
            size: KubusHeaderMetrics.actionIcon,
            color: roles.foreground,
          ),
          tooltip: l10n.commonBack,
        ),
        actions: <Widget>[
          KubusButton(
            onPressed:
                _isSavingProfile ? null : () => popDesktopShellAware(context),
            label: l10n.commonCancel,
            variant: KubusButtonVariant.quiet,
          ),
          const SizedBox(width: KubusSpacing.sm),
          KubusButton(
            onPressed: _saveProfile,
            isLoading: _isSavingProfile,
            label: l10n.profileEditSaveChanges,
            icon: Icons.check,
          ),
        ],
      ),
    );
  }

  Future<void> _handleSaveSuccess() async {
    if (widget.isOnboarding) {
      Navigator.of(context).pushReplacementNamed('/main');
      return;
    }

    final onSaved = widget.onSaved;
    if (onSaved != null) {
      try {
        await onSaved();
      } catch (e) {
        debugPrint(
            'DesktopProfileEditScreen._handleSaveSuccess onSaved failed: $e');
      }
      if (!mounted) return;
      popDesktopShellAware(context);
      return;
    }

    Navigator.pop(context, true);
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
            if (segs.isNotEmpty) {
              style = segs.lastWhere((s) => s.isNotEmpty,
                  orElse: () => 'identicon');
            }
          } else {
            final last = u.pathSegments.isNotEmpty ? u.pathSegments.last : '';
            seed = last.replaceAll('.svg', '');
            if (u.pathSegments.length >= 2) {
              style = u.pathSegments[u.pathSegments.length - 2];
            }
          }
        } catch (_) {
          final p = url.split('/').last;
          seed = p.split('?').first.replaceAll('.svg', '');
        }
        final base = BackendApiService().baseUrl.replaceAll(RegExp(r'/$'), '');
        displayUrl =
            '$base/api/avatar/${Uri.encodeComponent(seed)}?style=$style&format=png&raw=true';
      } else {
        displayUrl = MediaUrlResolver.svgAsPngReference(url);
      }
    } catch (_) {
      displayUrl = url;
    }
    // Fail closed: an unresolvable avatar shows the placeholder icon, never the
    // raw string.
    final safeUrl = MediaUrlResolver.resolve(displayUrl);
    if (safeUrl == null) {
      return Icon(
        Icons.person,
        size: 70,
        color: themeProvider.accentColor,
      );
    }
    displayUrl = safeUrl;

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
    final l10n = AppLocalizations.of(context)!;
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
        final fileName =
            (image.name.isNotEmpty) ? image.name : path.basename(image.path);
        await _uploadAvatarBytes(
          bytes: bytes,
          fileName: fileName,
          mimeType: image.mimeType,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.profileEditPickImageFailedToast),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _uploadAvatarBytes({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    setState(() {
      _localAvatarBytes = bytes;
      _isUploadingAvatar = true;
    });

    var succeeded = false;
    try {
      final wallet = profileProvider.currentUser?.walletAddress ?? '';

      if (wallet.isEmpty) {
        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(l10n.profileEditNoWalletUploadAvatarToast),
            backgroundColor: colorScheme.error,
          ),
        );
        return;
      }

      final uploadedRef = await profileProvider.uploadAvatarBytes(
        fileBytes: bytes,
        fileName: fileName,
        walletAddress: wallet,
        mimeType: mimeType,
      );

      final persistableAvatar = _toPersistableAvatarRef(uploadedRef);
      if (persistableAvatar == null || persistableAvatar.isEmpty) {
        throw Exception('Failed to get uploaded avatar ref');
      }

      _avatarChanged = true;

      final saved = await profileProvider.saveProfile(
        walletAddress: wallet,
        avatar: persistableAvatar,
        reloadStats: false,
      );
      if (!saved) {
        throw Exception(profileProvider.error ?? 'Avatar save failed');
      }

      succeeded = true;
      if (!mounted) return;
      setState(() {
        _avatarUrl = persistableAvatar;
        _localAvatarBytes = null;
        _avatarChanged = false;
      });

      unawaited(profileProvider.loadProfile(wallet));
      if (kDebugMode) {
        final displayAvatarUrl =
            MediaUrlResolver.resolve(persistableAvatar) ?? persistableAvatar;
        final uri = Uri.tryParse(displayAvatarUrl);
        messenger.showKubusSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Row(
              children: [
                Expanded(
                  child: Text(
                    displayAvatarUrl,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20, color: Colors.white),
                  onPressed: () async {
                    final activeMessenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(
                        ClipboardData(text: displayAvatarUrl));
                    if (!mounted) return;
                    activeMessenger.showKubusSnackBar(
                      SnackBar(
                        content:
                            Text(l10n.profileEditAvatarCopiedToClipboardToast),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
            action: uri != null
                ? SnackBarAction(
                    label: l10n.commonOpen,
                    onPressed: () async {
                      try {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      } catch (_) {}
                    },
                  )
                : null,
          ),
        );
      }

      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.profileEditAvatarUploadedSavedToast),
          backgroundColor: colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } on TimeoutException catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('DesktopProfileEditScreen: avatar upload timed out: $e');
        debugPrint('$stackTrace');
      }
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.profileEditAvatarUploadTimeoutToast),
          backgroundColor: colorScheme.error,
        ),
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('DesktopProfileEditScreen: avatar upload failed: $e');
        debugPrint('$stackTrace');
      }
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.profileEditAvatarUploadFailedToast),
          backgroundColor: colorScheme.error,
        ),
      );

      final debug = profileProvider.lastUploadDebug;
      if (kDebugMode && debug != null) {
        final pretty = const JsonEncoder.withIndent('  ').convert(debug);
        showKubusDialog<void>(
          context: context,
          builder: (context) => KubusAlertDialog(
            title: Text(l10n.profileEditUploadDebugInfoTitle),
            content: SingleChildScrollView(
              child: SelectableText(pretty),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.commonClose),
              ),
              TextButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final activeMessenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: pretty));
                  if (!mounted) return;
                  navigator.pop();
                  activeMessenger.showKubusSnackBar(
                    SnackBar(
                      content: Text(l10n.profileEditUploadDebugInfoCopiedToast),
                    ),
                  );
                },
                child: Text(l10n.commonCopy),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
          if (!succeeded) {
            _avatarChanged = false;
            _localAvatarBytes = null;
          }
        });
      }
    }
  }

  Future<void> _pickCoverImage() async {
    final l10n = AppLocalizations.of(context)!;
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
        final fileName =
            (image.name.isNotEmpty) ? image.name : path.basename(image.path);
        await _uploadCoverBytes(bytes: bytes, fileName: fileName);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.profileEditPickImageFailedToast),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _uploadCoverBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    setState(() {
      _localCoverBytes = bytes;
      _isUploadingCover = true;
    });

    var succeeded = false;
    try {
      final wallet = profileProvider.currentUser?.walletAddress ?? '';

      if (wallet.isEmpty) {
        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(l10n.profileEditNoWalletUploadCoverToast),
            backgroundColor: colorScheme.error,
          ),
        );
        return;
      }

      final result = await profileProvider.uploadProfileCoverBytes(
        fileBytes: bytes,
        fileName: fileName,
        walletAddress: wallet,
      );
      final uploadedRef = (result['uploadedUrl']?.toString() ??
              result['data']?['relativeUrl']?.toString() ??
              result['data']?['relative_url']?.toString() ??
              result['data']?['url']?.toString() ??
              result['url']?.toString() ??
              '')
          .trim();

      if (uploadedRef.isEmpty) {
        throw Exception('Failed to get uploaded cover ref');
      }

      final persistableCover = _toPersistableCoverRef(uploadedRef);
      if (persistableCover == null || persistableCover.isEmpty) {
        throw Exception('Failed to normalize uploaded cover ref');
      }

      _coverChanged = true;

      final saved = await profileProvider.saveProfile(
        walletAddress: wallet,
        coverImage: persistableCover,
        reloadStats: false,
      );
      if (!saved) {
        throw Exception(profileProvider.error ?? 'Cover save failed');
      }

      if (!mounted) return;
      succeeded = true;
      setState(() {
        _coverImageUrl = persistableCover;
        _localCoverBytes = null;
        _coverChanged = false;
      });
      unawaited(profileProvider.loadProfile(wallet));
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.profileEditCoverUploadedSavedToast),
          backgroundColor: colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } on TimeoutException catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('DesktopProfileEditScreen: cover upload timed out: $e');
        debugPrint('$stackTrace');
      }
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.profileEditCoverUploadTimeoutToast),
          backgroundColor: colorScheme.error,
        ),
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('DesktopProfileEditScreen: cover upload failed: $e');
        debugPrint('$stackTrace');
      }
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.profileEditCoverUploadFailedToast),
          backgroundColor: colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingCover = false;
          if (!succeeded) {
            _coverChanged = false;
            _localCoverBytes = null;
          }
        });
      }
    }
  }

  void _showFormNotice(String? message) {
    setState(() => _formNotice = message);
    if (message != null && _scrollController.hasClients) {
      unawaited(_scrollController.animateTo(
        0,
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ));
    }
  }

  Future<void> _saveProfile() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_submit.validate(_formKey)) {
      _showFormNotice(l10n.formFixHighlightedFields);
      return;
    }

    setState(() {
      _isSavingProfile = true;
      _formNotice = null;
    });

    try {
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      final wallet = profileProvider.currentUser?.walletAddress;

      if (wallet == null) {
        throw Exception('No wallet connected');
      }

      await profileProvider.updatePreferences(
        privateProfile: _privateProfile,
        showActivityStatus: _showActivityStatus,
        shareLastVisitedLocation: _shareLastVisitedLocation,
        showCollection: _showCollection,
        allowMessages: _allowMessages,
      );

      final success = await profileProvider.saveProfile(
        walletAddress: wallet,
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
        avatar: _avatarChanged ? _toPersistableAvatarRef(_avatarUrl) : null,
        coverImage:
            _coverChanged ? _toPersistableCoverRef(_coverImageUrl) : null,
        social: {
          'twitter': _twitterController.text.trim(),
          'instagram': _instagramController.text.trim(),
          'website': ProfileEditFormUtils.normalizeWebsiteForSave(
            _websiteController.text,
          ),
        },
        fieldOfWork: _specialtyController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(growable: false),
        yearsActive: int.tryParse(_yearsActiveController.text.trim()) ?? 0,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: Text(l10n.profileEditProfileUpdatedToast),
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
              coverImageUrl: MediaUrlResolver.resolve(uprof.coverImage),
              followersCount: uprof.stats?.followersCount ?? 0,
              followingCount: uprof.stats?.followingCount ?? 0,
              postsCount: uprof.stats?.artworksCreated ?? 0,
              isFollowing: false,
              isVerified: false,
              joinedDate: uprof.createdAt.toIso8601String(),
              achievementProgress: [],
            );
            try {
              EventBus().emitProfileUpdated(updatedUser);
            } catch (_) {}
          }
        } catch (_) {}

        await _handleSaveSuccess();
      } else {
        throw Exception(profileProvider.error ?? l10n.commonActionFailedToast);
      }
    } catch (e) {
      if (!mounted) return;
      final errorText = e.toString().contains('Profile save timed out')
          ? l10n.profileEditSaveTimeoutToast
          : l10n.profileEditErrorToast;
      if (kDebugMode) {
        debugPrint('DesktopProfileEditScreen: profile save failed: $e');
      }
      // Save failures stay on the form (inline, announced).
      _showFormNotice(errorText);
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  // Local helper wrappers to keep the older private helper API used in this
  // screen. These delegate to the shared ProfileMediaRefUtils implementation.
  String? _toPersistableAvatarRef(String? value) =>
      ProfileMediaRefUtils.toPersistableAvatarRef(value);

  String? _toPersistableCoverRef(String? value) =>
      ProfileMediaRefUtils.toPersistableCoverRef(value);
}
