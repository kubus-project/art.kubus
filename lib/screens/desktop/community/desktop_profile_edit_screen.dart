import 'package:flutter/material.dart';
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
import '../components/desktop_widgets.dart';
import '../desktop_shell_scope.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/app_mode_unavailable_state.dart';
import 'package:art_kubus/widgets/glass_components.dart';

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
    final nextCoverDisplay = _normalizeMediaUrl(profile?.coverImage);

    setState(() {
      if (!_isUploadingAvatar &&
          !_avatarChanged &&
          nextAvatar != null &&
          nextAvatar.isNotEmpty) {
        _avatarUrl = nextAvatar;
      }

      if (!_isUploadingCover &&
          !_coverChanged &&
          nextCoverDisplay != null &&
          nextCoverDisplay.isNotEmpty) {
        _coverImageUrl = nextCoverDisplay;
      }
    });
  }

  @visibleForTesting
  String? get debugAvatarUrl => _avatarUrl;

  @visibleForTesting
  String? get debugCoverImageUrl => _coverImageUrl;

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
    if (_profileListener != null) {
      _profileProvider?.removeListener(_profileListener!);
      _profileListener = null;
    }
    _profileProvider = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final appModeProvider = context.watch<AppModeProvider?>();
    final isIpfsFallbackMode = appModeProvider?.isIpfsFallbackMode ?? false;
    final animationTheme = context.animationTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth >= 1200;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: isIpfsFallbackMode
          ? Column(
              children: [
                _buildHeader(themeProvider),
                const Expanded(
                  child: AppModeUnavailableState(
                    featureLabel: 'Profile editing',
                    title: 'Profile editing unavailable',
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
                                constraints:
                                    const BoxConstraints(maxWidth: 900),
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
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final headerStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.header,
      tintBase: scheme.surface,
    );
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: LiquidGlassPanel(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        borderRadius: BorderRadius.zero,
        blurSigma: headerStyle.blurSigma,
        fallbackMinOpacity: headerStyle.fallbackMinOpacity,
        showBorder: false,
        backgroundColor: headerStyle.tintColor,
        child: KubusScreenHeaderBar(
          title: l10n.profileEditTitle,
          leading: IconButton(
            onPressed: () => popDesktopShellAware(context),
            icon: Icon(
              Icons.arrow_back,
              size: KubusHeaderMetrics.actionIcon,
              color: scheme.onSurface,
            ),
            tooltip: l10n.commonBack,
          ),
          actions: _isSavingProfile
              ? <Widget>[
                  const SizedBox(
                    width: KubusHeaderMetrics.actionIcon,
                    height: KubusHeaderMetrics.actionIcon,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ]
              : <Widget>[
                  DesktopActionButton(
                    label: l10n.commonCancel,
                    icon: Icons.close,
                    onPressed: () => popDesktopShellAware(context),
                    isPrimary: false,
                  ),
                  const SizedBox(width: KubusSpacing.sm),
                  DesktopActionButton(
                    label: l10n.profileEditSaveChanges,
                    icon: Icons.check,
                    onPressed: _saveProfile,
                    isPrimary: true,
                  ),
                ],
        ),
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

  Widget _buildCoverImageSection(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    return DesktopCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(KubusSpacing.lg),
            child: DesktopSectionHeader(
              title: l10n.commonCoverImage,
              subtitle:
                  l10n.profileEditCoverImageRecommendedSize('1920x1080px'),
              icon: Icons.panorama,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KubusSpacing.xl,
              0,
              KubusSpacing.xl,
              KubusSpacing.xl,
            ),
            child: GestureDetector(
              onTap: _isUploadingCover ? null : _pickCoverImage,
              child: MouseRegion(
                cursor: _isUploadingCover
                    ? SystemMouseCursors.basic
                    : SystemMouseCursors.click,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(KubusRadius.lg),
                        border: Border.all(
                          color:
                              themeProvider.accentColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        image: _localCoverBytes != null
                            ? DecorationImage(
                                image: MemoryImage(_localCoverBytes!),
                                fit: BoxFit.cover,
                              )
                            : _coverImageUrl != null &&
                                    _coverImageUrl!.isNotEmpty
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
                      child: (_localCoverBytes == null &&
                              (_coverImageUrl == null ||
                                  _coverImageUrl!.isEmpty))
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 48,
                                  color: themeProvider.accentColor
                                      .withValues(alpha: 0.6),
                                ),
                                const SizedBox(height: KubusSpacing.md),
                                Text(
                                  l10n.profileEditCoverImageClickToUpload,
                                  style: KubusTextStyles.detailBody.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              alignment: Alignment.bottomRight,
                              padding: const EdgeInsets.all(KubusSpacing.md),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: KubusSpacing.md,
                                  vertical: KubusSpacing.sm +
                                      KubusSpacing.xs +
                                      KubusSpacing.xxs,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius:
                                      BorderRadius.circular(KubusRadius.sm),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: KubusHeaderMetrics.actionIcon,
                                    ),
                                    const SizedBox(width: KubusSpacing.sm),
                                    Text(
                                      l10n.commonChangeCover,
                                      style:
                                          KubusTextStyles.detailLabel.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                    if (_isUploadingCover)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(KubusRadius.lg),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 50,
                              height: 50,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    const avatarDiameter = 140.0;
    const avatarRadius = avatarDiameter / 2;
    final avatarFrameRadius = AvatarWidget.shapeRadiusFor(
      radius: avatarRadius,
      cornerRadiusFactor: AvatarWidget.defaultCornerRadiusFactor,
    );
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesktopSectionHeader(
            title: l10n.profileEditProfilePictureTitle,
            subtitle: l10n.profileEditCoverImageRecommendedSize('512x512px'),
            icon: Icons.account_circle,
          ),
          const SizedBox(height: KubusSpacing.lg),
          Center(
            child: GestureDetector(
              onTap: _isUploadingAvatar ? null : _pickAvatar,
              child: MouseRegion(
                cursor: _isUploadingAvatar
                    ? SystemMouseCursors.basic
                    : SystemMouseCursors.click,
                child: Stack(
                  children: [
                    Container(
                      width: avatarDiameter,
                      height: avatarDiameter,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(avatarFrameRadius),
                        border: Border.all(
                          color: themeProvider.accentColor,
                          width: 3,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(avatarFrameRadius),
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
                        padding: const EdgeInsets.all(KubusSpacing.md),
                        decoration: BoxDecoration(
                          color: themeProvider.accentColor,
                          borderRadius: BorderRadius.circular(KubusRadius.sm),
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
                          size: KubusHeaderMetrics.actionIcon,
                        ),
                      ),
                    ),
                    if (_isUploadingAvatar)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(avatarFrameRadius),
                          child: Container(
                            color: Colors.black26,
                            child: const Center(
                              child: SizedBox(
                                width: 45,
                                height: 45,
                                child:
                                    CircularProgressIndicator(strokeWidth: 3),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          Center(
            child: Text(
              l10n.profileEditAvatarClickToChange,
              style: KubusTextStyles.detailCaption.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesktopSectionHeader(
            title: l10n.profileEditBasicInformationTitle,
            subtitle: l10n.profileEditPublicProfileDetailsSubtitle,
            icon: Icons.person_outline,
          ),
          const SizedBox(height: KubusSpacing.lg),
          _buildTextField(
            label: l10n.profileEditUsernameLabel,
            controller: _usernameController,
            hint: l10n.profileEditUsernameHint,
            icon: Icons.alternate_email,
            validator: (value) {
              return ProfileEditFormUtils.validateUsername(l10n, value);
            },
          ),
          const SizedBox(height: KubusSpacing.lg - KubusSpacing.xs),
          _buildTextField(
            label: l10n.profileEditDisplayNameLabel,
            controller: _displayNameController,
            hint: l10n.profileEditDisplayNameHint,
            icon: Icons.person_outline,
            validator: (value) {
              return ProfileEditFormUtils.validateDisplayName(l10n, value);
            },
          ),
          const SizedBox(height: KubusSpacing.lg - KubusSpacing.xs),
          _buildTextField(
            label: l10n.profileEditBioLabel,
            controller: _bioController,
            hint: l10n.profileEditBioHint,
            icon: Icons.info_outline,
            maxLines: 4,
            maxLength: ProfileEditFormUtils.bioMaxLength,
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLinksSection(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesktopSectionHeader(
            title: l10n.profileEditSocialLinksTitle,
            subtitle: l10n.profileEditSocialLinksSubtitle,
            icon: Icons.link,
          ),
          const SizedBox(height: KubusSpacing.lg),
          _buildTextField(
            label: l10n.profileEditSocialTwitterLabel,
            controller: _twitterController,
            hint: l10n.profileEditSocialHandleHint,
            icon: Icons.alternate_email,
          ),
          const SizedBox(height: KubusSpacing.lg - KubusSpacing.xs),
          _buildTextField(
            label: l10n.profileEditSocialInstagramLabel,
            controller: _instagramController,
            hint: l10n.profileEditSocialHandleHint,
            icon: Icons.camera_alt_outlined,
          ),
          const SizedBox(height: KubusSpacing.lg - KubusSpacing.xs),
          _buildTextField(
            label: l10n.profileEditSocialWebsiteLabel,
            controller: _websiteController,
            hint: l10n.profileEditSocialWebsiteHint,
            icon: Icons.language,
            validator: (value) =>
                ProfileEditFormUtils.validateWebsite(l10n, value),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistInfoSection(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesktopSectionHeader(
            title: _isInstitution
                ? l10n.profileEditInstitutionInformationTitle
                : l10n.profileEditArtistInformationTitle,
            subtitle: _isInstitution
                ? l10n.profileEditInstitutionDetailsSubtitle
                : l10n.profileEditArtistDetailsSubtitle,
            icon: _isInstitution ? Icons.business : Icons.palette,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            label: _isInstitution
                ? l10n.profileEditInstitutionFocusAreasLabel
                : l10n.profileEditArtistSpecialtiesLabel,
            controller: _specialtyController,
            hint: _isInstitution
                ? 'Contemporary Art, Digital Media'
                : 'Painting, Sculpture, Digital Art',
            icon: Icons.interests_outlined,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: _isInstitution
                ? l10n.profileEditInstitutionEstablishedYearLabel
                : l10n.profileEditArtistYearsActiveLabel,
            controller: _yearsActiveController,
            hint: '2020',
            icon: Icons.calendar_today_outlined,
            keyboardType: TextInputType.number,
            validator: (value) =>
                ProfileEditFormUtils.validateYearsActive(l10n, value),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySection(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesktopSectionHeader(
            title: l10n.profileEditPrivacyVisibilityTitle,
            subtitle: l10n.profileEditPrivacyVisibilitySubtitle,
            icon: Icons.privacy_tip_outlined,
          ),
          const SizedBox(height: 24),
          _buildSwitchTile(
            title: l10n.settingsPrivateProfileTitle,
            subtitle: l10n.settingsPrivateProfileSubtitle,
            value: _privateProfile,
            onChanged: (value) => setState(() => _privateProfile = value),
            switchKey:
                const Key('desktop_profile_edit_privacy_private_profile'),
          ),
          const Divider(height: 32),
          _buildSwitchTile(
            title: l10n.settingsShowActivityStatusTitle,
            subtitle: l10n.settingsShowActivityStatusSubtitle,
            value: _showActivityStatus,
            onChanged: (value) => setState(() {
              _showActivityStatus = value;
              if (!value) _shareLastVisitedLocation = false;
            }),
            switchKey:
                const Key('desktop_profile_edit_privacy_show_activity_status'),
          ),
          const Divider(height: 32),
          _buildSwitchTile(
            title: l10n.settingsShareLastVisitedLocationTitle,
            subtitle: l10n.settingsShareLastVisitedLocationSubtitle,
            value: _shareLastVisitedLocation,
            enabled: _showActivityStatus,
            onChanged: (value) =>
                setState(() => _shareLastVisitedLocation = value),
            switchKey: const Key(
                'desktop_profile_edit_privacy_share_last_visited_location'),
          ),
          const Divider(height: 32),
          _buildSwitchTile(
            title: l10n.settingsShowCollectionTitle,
            subtitle: l10n.settingsShowCollectionSubtitle,
            value: _showCollection,
            onChanged: (value) => setState(() => _showCollection = value),
            switchKey:
                const Key('desktop_profile_edit_privacy_show_collection'),
          ),
          const Divider(height: 32),
          _buildSwitchTile(
            title: l10n.settingsAllowMessagesTitle,
            subtitle: l10n.settingsAllowMessagesSubtitle,
            value: _allowMessages,
            onChanged: (value) => setState(() => _allowMessages = value),
            switchKey: const Key('desktop_profile_edit_privacy_allow_messages'),
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
          style: KubusTextStyles.detailCardTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: KubusSpacing.sm),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: KubusHeaderMetrics.actionIcon),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KubusRadius.md),
            ),
            filled: true,
            fillColor: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: KubusSpacing.md,
              vertical: KubusSpacing.sm + KubusSpacing.xs + KubusSpacing.xxs,
            ),
          ),
          style: KubusTextStyles.detailBody.copyWith(
            fontSize: KubusHeaderMetrics.screenSubtitle,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
    Key? switchKey,
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
                style: KubusTextStyles.detailCardTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: KubusSpacing.xs),
              Text(
                subtitle,
                style: KubusTextStyles.detailCaption.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Switch(
          key: switchKey,
          value: value,
          onChanged: enabled ? onChanged : null,
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
      } else if (lower.endsWith('.svg') || lower.contains('.svg?')) {
        displayUrl =
            url.replaceAll(RegExp(r'\.svg', caseSensitive: false), '.png');
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
        setState(() {
          _localAvatarBytes = bytes;
          _isUploadingAvatar = true;
        });

        var succeeded = false;
        try {
          final profileProvider =
              Provider.of<ProfileProvider>(context, listen: false);
          final wallet = profileProvider.currentUser?.walletAddress ?? '';

          if (wallet.isEmpty) {
            ScaffoldMessenger.of(context).showKubusSnackBar(
              SnackBar(
                content: Text(l10n.profileEditNoWalletUploadAvatarToast),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
            return;
          }

          final fileName =
              (image.name.isNotEmpty) ? image.name : path.basename(image.path);
          final uploadedRef = await profileProvider.uploadAvatarBytes(
            fileBytes: bytes,
            fileName: fileName,
            walletAddress: wallet,
            mimeType: image.mimeType,
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
          final displayAvatarUrl =
              _normalizeMediaUrl(persistableAvatar) ?? persistableAvatar;
          final uri = Uri.tryParse(displayAvatarUrl);
          ScaffoldMessenger.of(context).showKubusSnackBar(
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
                      await Clipboard.setData(
                          ClipboardData(text: displayAvatarUrl));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showKubusSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.profileEditAvatarCopiedToClipboardToast,
                          ),
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

          if (!mounted) return;
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(
              content: Text(l10n.profileEditAvatarUploadedSavedToast),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          final profileProvider =
              Provider.of<ProfileProvider>(context, listen: false);
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(
              content: Text(
                l10n.profileEditAvatarUploadFailedToast,
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );

          final debug = profileProvider.lastUploadDebug;
          if (debug != null) {
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
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(ClipboardData(text: pretty));
                      if (!mounted) return;
                      navigator.pop();
                      messenger.showKubusSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.profileEditUploadDebugInfoCopiedToast,
                          ),
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
              if (!succeeded) _avatarChanged = false;
            });
          }
        }
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
        setState(() {
          _localCoverBytes = bytes;
          _isUploadingCover = true;
        });

        var succeeded = false;
        try {
          final profileProvider =
              Provider.of<ProfileProvider>(context, listen: false);
          final wallet = profileProvider.currentUser?.walletAddress ?? '';

          if (wallet.isEmpty) {
            ScaffoldMessenger.of(context).showKubusSnackBar(
              SnackBar(
                content: Text(l10n.profileEditNoWalletUploadCoverToast),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
            return;
          }

          final fileName =
              (image.name.isNotEmpty) ? image.name : path.basename(image.path);
          final api = BackendApiService();
          final result = await api.uploadFile(
            fileBytes: bytes,
            fileName: fileName,
            fileType: 'cover',
            metadata: {'uploadFolder': 'profiles/cover'},
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
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(
              content: Text(l10n.profileEditCoverUploadedSavedToast),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(
              content: Text(
                l10n.profileEditCoverUploadFailedToast,
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        } finally {
          if (mounted) {
            setState(() {
              _isUploadingCover = false;
              if (!succeeded) _coverChanged = false;
            });
          }
        }
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

  String? _normalizeMediaUrl(String? url) {
    return MediaUrlResolver.resolve(url);
  }

  Future<void> _saveProfile() async {
    final formState = _formKey.currentState;
    if (!(formState?.validate() ?? false)) return;

    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSavingProfile = true);

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
              coverImageUrl: _normalizeMediaUrl(uprof.coverImage),
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
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.profileEditErrorToast),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
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
