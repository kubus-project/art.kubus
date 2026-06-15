// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTagline => 'kubus - your art companion.';

  @override
  String get appTaglineSupport => 'Discover public art, artists, institutions and community stories on an open cultural map.';

  @override
  String get exploreOnlyAppTitle => 'art.kubus - Explore';

  @override
  String get exploreOnlyConnectWalletAction => 'Connect wallet';

  @override
  String get exploreOnlyModeBanner => 'You are exploring the public map. Profiles, community and discovery work without a wallet. Connect one later for archive records, digital editions and governance.';

  @override
  String get exploreOnlyDiscoverTitle => 'Discover art';

  @override
  String get exploreOnlyCollectionsTitle => 'Browse collections';

  @override
  String get exploreOnlyCollectionsDescription => 'Explore artworks, public-space stories and cultural archive records.';

  @override
  String get exploreOnlyArTitle => 'AR layers';

  @override
  String get exploreOnlyArDescription => 'View AR layers when artists or institutions enable them.';

  @override
  String get exploreOnlyCommunityTitle => 'Community';

  @override
  String get exploreOnlyCommunityDescription => 'Follow artists, institutions and discussions around public art.';

  @override
  String get exploreOnlyArtifactsTitle => 'Digital editions';

  @override
  String get exploreOnlyArtifactsDescription => 'Discover archive records and digital editions connected to artworks.';

  @override
  String get walletPromptTitle => 'Connect wallet';

  @override
  String get walletPromptBody => 'A wallet connects your profile to attribution, archive records, digital editions and governance tools. Discovery and community remain open without it.';

  @override
  String get walletPromptIntro => 'Connect a wallet for:';

  @override
  String get walletPromptFeatureArchiveObjects => 'Archive records and digital editions';

  @override
  String get walletPromptFeatureCreateArtworks => 'Create and document artworks';

  @override
  String get walletPromptFeatureCommunity => 'Participation and governance records';

  @override
  String get walletPromptMaybeLater => 'Maybe later';

  @override
  String get walletPromptSetUpAction => 'Set up wallet';

  @override
  String get walletHomeArchiveObjectFallbackTitle => 'Archive record';

  @override
  String get walletHomeCollectibleFallbackTitle => 'Digital edition';

  @override
  String get walletHomeConnectWalletToFetchCollectibles => 'Connect your wallet to load digital editions.';

  @override
  String get artworkDraftCoverRequired => 'Cover image is required.';

  @override
  String get artworkDraftCoverUploadFailed => 'Failed to upload cover image.';

  @override
  String get artworkDraftGalleryUploadFailed => 'Failed to upload a gallery image. Please try again.';

  @override
  String get artworkDraftTitleDescriptionRequired => 'Title and description are required.';

  @override
  String get artworkDraftAttendanceUnavailable => 'Attendance records are currently unavailable.';

  @override
  String get artworkDraftAttendanceIdOrUrlRequired => 'Please provide an attendance event ID or record URL.';

  @override
  String get artworkDraftCoordinatesRequired => 'Please provide both latitude and longitude (or leave both empty).';

  @override
  String get artworkDraftCoordinatesInvalid => 'Location coordinates are invalid.';

  @override
  String get artworkDraftAttendanceImageUploadFailed => 'Failed to upload attendance record image. Please try again.';

  @override
  String get artworkDraftPublishFailed => 'Failed to publish artwork. Please try again.';

  @override
  String get archiveObjectCreatedToast => 'Archive record created.';

  @override
  String get archiveObjectCreateFailed => 'Failed to create archive record.';

  @override
  String get archiveObjectCreationPleaseWait => 'This may take a few moments.';

  @override
  String archiveObjectSeriesDefaultDescription(Object artworkTitle, Object artistName) {
    return 'Archive records for $artworkTitle by $artistName';
  }

  @override
  String get archiveObjectSeriesCreateFailed => 'Failed to create archive record series';

  @override
  String get archiveObjectSeriesNotFound => 'Archive record series not found';

  @override
  String get archiveObjectSeriesSoldOut => 'Series is sold out';

  @override
  String archiveObjectCreatedReason(Object artworkTitle, Object tokenId) {
    return 'Created archive record for \"$artworkTitle\" (edition #$tokenId)';
  }

  @override
  String get artworkCreatorAttendanceRecordUrlOptionalLabel => 'Attendance record URL';

  @override
  String archiveObjectCreateFailedWithError(Object error) {
    return 'Failed to create archive record: $error';
  }

  @override
  String archiveObjectCreateError(Object error) {
    return 'Error creating archive record: $error';
  }

  @override
  String communityAchievementUnlockedToast(Object title, Object extra, Object amount, Object currency) {
    return 'Achievement unlocked\n$title$extra\n+$amount $currency recognition';
  }

  @override
  String get communityViewAchievementsAction => 'View achievements';

  @override
  String get markerBadgePromoted => 'Promoted';

  @override
  String get markerBadgeAttendanceRecord => 'Attendance record';

  @override
  String get markerDescriptionSemanticLabel => 'marker description';

  @override
  String get recentActivityRecognitionRecordedTitle => 'Recognition recorded';

  @override
  String get recentActivityArchiveObjectUpdateTitle => 'Archive record update';

  @override
  String recentActivityRecognitionAmountDescription(Object amount) {
    return '+$amount KUB8 recognition';
  }

  @override
  String get recentActivityNewRecognitionDescription => 'You have new recognition';

  @override
  String recentActivityArchiveObjectStatusDescription(Object status, Object title) {
    return 'Archive record $status for $title';
  }

  @override
  String get recentActivityFallbackArtworkTitle => 'an artwork';

  @override
  String get notificationSomeoneFallback => 'Someone';

  @override
  String get notificationAchievementFallback => 'Achievement';

  @override
  String get notificationRecognitionRecordedTitle => 'Recognition recorded';

  @override
  String get pushArchiveObjectCreatingTitle => 'Creating archive record...';

  @override
  String pushArchiveObjectCreatingBody(Object artworkTitle) {
    return 'Creating archive record for \"$artworkTitle\"';
  }

  @override
  String get pushArchiveObjectCreatedTitle => 'Archive record created';

  @override
  String pushArchiveObjectCreatedBody(Object artworkTitle) {
    return '\"$artworkTitle\" now has an archive record';
  }

  @override
  String get pushArchiveObjectCreationFailedTitle => 'Creation failed';

  @override
  String pushArchiveObjectCreationFailedBody(Object artworkTitle) {
    return 'Could not create an archive record for \"$artworkTitle\". Please try again.';
  }

  @override
  String get pushArchiveObjectCreationChannelName => 'Archive record creation';

  @override
  String get pushArchiveObjectCreationChannelDescription => 'Notifications for archive record creation';

  @override
  String get pushRecognitionChannelName => 'Recognition';

  @override
  String get pushRecognitionChannelDescription => 'Notifications for contribution recognition';

  @override
  String get analyticsMetricArchiveObjectsCreatedLabel => 'Archive records created';

  @override
  String get analyticsMetricArchiveObjectsCreatedDescription => 'Archive records connected to artworks.';

  @override
  String get analyticsMetricKub8RecognitionLabel => 'KUB8 recognition';

  @override
  String get analyticsMetricKub8RecognitionDescription => 'KUB8 recorded through contribution recognition.';

  @override
  String get analyticsPresetArtistSubtitle => 'Artwork reach, community response, AR activity, and recognition.';

  @override
  String get analyticsPresetInstitutionSubtitle => 'Visitor reach, hosted programs, exhibitions, and recognition.';

  @override
  String get analyticsExportNoDataToast => 'No analytics data available to export.';

  @override
  String get analyticsExportFailedToast => 'Unable to export analytics.';

  @override
  String collectiblesLoadFailed(Object error) {
    return 'Failed to load digital editions: $error';
  }

  @override
  String get collectiblesItemNotFound => 'Digital edition not found';

  @override
  String get collectiblesInvalidListingPrice => 'Invalid listing price';

  @override
  String get collectiblesArtworkProviderUnavailable => 'Artwork provider is unavailable';

  @override
  String get collectiblesListingUpdateFailed => 'Failed to update listing on canonical artwork record';

  @override
  String collectiblesListFailed(Object error) {
    return 'Failed to list digital edition: $error';
  }

  @override
  String collectiblesRemoveListingFailed(Object error) {
    return 'Failed to remove digital edition from sale: $error';
  }

  @override
  String get collectiblesMockDataDisabled => 'Mock digital edition data is disabled in canonical mode. Use indexed artwork mint records.';

  @override
  String get appTitle => 'art.kubus';

  @override
  String get appExitConfirmBackHint => 'Swipe or press back again to exit the app.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSignIn => 'Sign in';

  @override
  String get commonReconnect => 'Reconnect';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonClose => 'Close';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonOr => 'or';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonSkipForNow => 'Skip for now';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSavedToast => 'Saved';

  @override
  String get supportTicketSubmittedToast => 'Support request sent.';

  @override
  String get supportTicketReceiptEmailToast => 'Support request sent. We\'ll email a receipt to the address you provided.';

  @override
  String get commonActionFailedToast => 'Something went wrong. Please try again.';

  @override
  String get commonNetworkErrorToast => 'Network error. Please try again.';

  @override
  String get commonTitle => 'Title';

  @override
  String get commonDescription => 'Description';

  @override
  String get commonPrice => 'Price';

  @override
  String get commonForSale => 'For sale';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonDone => 'Done';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonMore => 'More';

  @override
  String get commonEditedTag => '(edited)';

  @override
  String get commonLink => 'Link';

  @override
  String get commonPublish => 'Publish';

  @override
  String get commonUnpublish => 'Unpublish';

  @override
  String get commonDraft => 'Draft';

  @override
  String get commonPublished => 'Published';

  @override
  String get commonStatus => 'Status';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonGotIt => 'Got it';

  @override
  String get commonInstall => 'Install';

  @override
  String get commonNavigate => 'Navigate';

  @override
  String get commonFree => 'Free';

  @override
  String get commonOpenOnMap => 'Open on map';

  @override
  String get commonReplace => 'Replace';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonNotifications => 'Notifications';

  @override
  String get commonLabLabel => 'Lab';

  @override
  String get commonShare => 'Share';

  @override
  String get shareOptionCreatePost => 'Create community post';

  @override
  String get shareOptionSendMessage => 'Send in message';

  @override
  String get shareOptionShareExternal => 'Share outside app';

  @override
  String get shareLinkCopiedToast => 'Link copied to clipboard';

  @override
  String get shareMessageTitle => 'Send in message';

  @override
  String get shareMessageSearchHint => 'Search profiles…';

  @override
  String get shareMessageNoteHint => 'Add a message (optional)';

  @override
  String get shareDmDefaultMessage => 'Check this out on art.kubus';

  @override
  String shareMessageSentToast(String recipient) {
    return 'Sent to $recipient';
  }

  @override
  String get shareMessageFailedToast => 'Failed to send message.';

  @override
  String get commonFeed => 'Feed';

  @override
  String get commonGroup => 'Group';

  @override
  String get commonImage => 'Image';

  @override
  String get commonCoverImage => 'Cover image';

  @override
  String get commonChangeCover => 'Change cover';

  @override
  String get commonVideo => 'Video';

  @override
  String get commonMembers => 'Members';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonUpload => 'Upload';

  @override
  String get uploadCompressionProcessing => 'Preparing media…';

  @override
  String get uploadCompressionImageProcessing => 'Optimizing image…';

  @override
  String get uploadCompressionVideoProcessing => 'Optimizing video…';

  @override
  String get uploadCompressionModelProcessing => 'Optimizing 3D asset…';

  @override
  String get uploadCompressionDone => 'Media ready';

  @override
  String get uploadCompressionSkipped => 'Using original file';

  @override
  String get commonViewInAr => 'View in AR';

  @override
  String get commonViewAll => 'View all';

  @override
  String get commonProceed => 'Proceed';

  @override
  String get commonGetStarted => 'Get started';

  @override
  String get commonCreateAccount => 'Create an account';

  @override
  String get commonDiscoverArt => 'Discover art';

  @override
  String get commonWorking => 'Working…';

  @override
  String get commentHistoryTitle => 'Edit history';

  @override
  String get commentHistoryCurrentLabel => 'Current';

  @override
  String get commentHistoryOriginalLabel => 'Original';

  @override
  String get commentEditTitle => 'Edit comment';

  @override
  String get commentUpdatedToast => 'Comment updated';

  @override
  String get commentEditFailedToast => 'Failed to update comment. Please try again.';

  @override
  String get commentDeleteConfirmTitle => 'Delete comment?';

  @override
  String get commentDeleteConfirmMessage => 'This will delete the comment and all replies.';

  @override
  String get commentDeletedToast => 'Comment deleted';

  @override
  String get commentDeleteFailedToast => 'Failed to delete comment. Please try again.';

  @override
  String get commonEmail => 'Email';

  @override
  String get commonPassword => 'Password';

  @override
  String get commonConfirmPassword => 'Confirm password';

  @override
  String get commonUsernameOptional => 'Username (optional)';

  @override
  String get commonUnlock => 'Unlock';

  @override
  String get commonPinLabel => 'PIN';

  @override
  String get personaOnboardingTitle => 'How should kubus guide you?';

  @override
  String get personaOnboardingSubtitle => 'Choose what you are here for. This only changes what we highlight, not what you can access.';

  @override
  String get personaOptionLoverTitle => 'Art lover';

  @override
  String get personaOptionLoverSubtitle => 'Discover nearby artworks, exhibitions, public works, and community updates.';

  @override
  String get personaOptionCreatorTitle => 'Artist / collective';

  @override
  String get personaOptionCreatorSubtitle => 'Share your practice, add context, publish works, and build community.';

  @override
  String get personaOptionInstitutionTitle => 'Institution / gallery';

  @override
  String get personaOptionInstitutionSubtitle => 'Connect programmes, exhibitions, artists, and public archive context.';

  @override
  String get exhibitionCreatorAppBarTitle => 'Create exhibition';

  @override
  String get exhibitionCreatorDisabledAppBarTitle => 'Exhibition';

  @override
  String get exhibitionCreatorDisabledMessage => 'Exhibitions are currently disabled.';

  @override
  String get exhibitionCreatorBasicsTitle => 'Basics';

  @override
  String get exhibitionCreatorTitleLabel => 'Title';

  @override
  String get exhibitionCreatorTitleValidation => 'Please enter a title.';

  @override
  String get exhibitionCreatorDescriptionLabel => 'Description (optional)';

  @override
  String get exhibitionCreatorLocationLabel => 'Location name (optional)';

  @override
  String get exhibitionCreatorScheduleTitle => 'Schedule';

  @override
  String get exhibitionCreatorStartsLabel => 'Starts';

  @override
  String get exhibitionCreatorEndsLabel => 'Ends';

  @override
  String get exhibitionCreatorNotSetLabel => 'Not set';

  @override
  String get exhibitionCreatorPublishTitle => 'Publish';

  @override
  String get exhibitionCreatorPublishVisible => 'Visible to everyone';

  @override
  String get exhibitionCreatorPublishDraft => 'Save as draft';

  @override
  String get exhibitionCreatorCollabHint => 'After creating, you can invite collaborators from the exhibition detail screen.';

  @override
  String get exhibitionDetailInvitesTooltip => 'Invites';

  @override
  String get exhibitionDetailRefreshTooltip => 'Refresh';

  @override
  String get exhibitionDetailOverviewTitle => 'Overview';

  @override
  String get exhibitionDetailArtworksTitle => 'Artworks';

  @override
  String get exhibitionDetailArtworksManageHint => 'Link artworks so visitors can discover them from this exhibition.';

  @override
  String get exhibitionDetailArtworksViewHint => 'Artworks linked to this exhibition will appear here.';

  @override
  String get exhibitionDetailNoArtworksLinkedYet => 'No artworks linked yet.';

  @override
  String get exhibitionDetailNoArtworksAvailableToLinkToast => 'No artworks available to link.';

  @override
  String get exhibitionDetailAddArtworksDialogTitle => 'Add artworks';

  @override
  String get exhibitionDetailArtworksLinkedToast => 'Artworks linked to exhibition.';

  @override
  String get exhibitionDetailLinkArtworksFailedToast => 'Failed to link artworks. Please try again.';

  @override
  String get exhibitionDetailDeleteDialogTitle => 'Delete exhibition?';

  @override
  String exhibitionDetailDeleteDialogContent(Object title) {
    return 'Exhibition \"$title\" will be deleted. This action cannot be undone.';
  }

  @override
  String get exhibitionDetailDeletedToast => 'Exhibition deleted.';

  @override
  String exhibitionDetailStatusRowLabel(Object status) {
    return 'Status: $status';
  }

  @override
  String get exhibitionDetailBadgeTitle => 'Badge';

  @override
  String get exhibitionDetailBadgeClaimed => 'Claimed';

  @override
  String get exhibitionDetailBadgeNotClaimed => 'Not recorded';

  @override
  String get exhibitionCreatorEndDateAfterStartError => 'End date must be after start date.';

  @override
  String get exhibitionCreatorCreateFailed => 'Failed to create exhibition.';

  @override
  String get exhibitionCreatorCreateFailedWithError => 'Failed to create exhibition. Please try again.';

  @override
  String get exhibitionCreatorSavedInfoBox => 'Exhibition saved. Collaboration is available from the sidebar, and you can keep refining the details below.';

  @override
  String get exhibitionCreatorShellDraftSubtitle => 'Curate the exhibition, then save it to unlock collaboration.';

  @override
  String get exhibitionCreatorShellSavedSubtitle => 'Exhibition saved. Keep refining or open the detail view from the sidebar.';

  @override
  String get exhibitionCreatorReadyBasicsLabel => 'Basics complete';

  @override
  String get exhibitionCreatorReadyBasicsDescription => 'Title, description, and location are filled in.';

  @override
  String get exhibitionCreatorReadyDatesLabel => 'Date range set';

  @override
  String get exhibitionCreatorReadyDatesComplete => 'The exhibition has a start and end date.';

  @override
  String get exhibitionCreatorReadyDatesPending => 'Set both dates before saving.';

  @override
  String get exhibitionCreatorReadyCoverLabel => 'Cover image added';

  @override
  String get exhibitionCreatorReadyCoverComplete => 'Cover image is ready.';

  @override
  String get exhibitionCreatorReadyCoverPending => 'Optional, but it improves the showcase.';

  @override
  String get exhibitionCreatorReadyVisibilityLabel => 'Visibility chosen';

  @override
  String get exhibitionCreatorReadyVisibilityPublic => 'Public exhibition will be discoverable.';

  @override
  String get exhibitionCreatorReadyVisibilityPrivate => 'Private exhibitions stay restricted.';

  @override
  String get exhibitionCreatorStatusDraftSubtitle => 'Draft in progress';

  @override
  String get exhibitionCreatorStatusSavedSubtitle => 'Saved exhibition';

  @override
  String get exhibitionCreatorSummaryIdLabel => 'Exhibition ID';

  @override
  String get exhibitionCreatorSummaryNotCreatedYet => 'Not created yet';

  @override
  String get exhibitionCreatorSummaryScheduleLabel => 'Schedule';

  @override
  String get exhibitionCreatorSummaryScheduleReady => 'Ready';

  @override
  String get exhibitionCreatorSummaryScheduleIncomplete => 'Incomplete';

  @override
  String get exhibitionCreatorSummaryVisibilityLabel => 'Visibility';

  @override
  String get exhibitionCreatorReadinessTitle => 'Readiness';

  @override
  String get exhibitionCreatorReadinessSubtitle => 'A quick sanity check before saving.';

  @override
  String get exhibitionCreatorQuickActionsTitle => 'Quick actions';

  @override
  String get exhibitionCreatorQuickActionsSubtitle => 'Stay inside the creator while you work.';

  @override
  String get exhibitionCreatorQuickActionSave => 'Save exhibition';

  @override
  String get exhibitionCreatorQuickActionUpdate => 'Update exhibition';

  @override
  String get exhibitionCreatorQuickActionOpen => 'Open exhibition';

  @override
  String get exhibitionCreatorCollaborationTitle => 'Collaboration';

  @override
  String get exhibitionCreatorCollaborationReadySubtitle => 'Invite co-curators without leaving the workspace.';

  @override
  String get exhibitionCreatorCollaborationLockedSubtitle => 'Save once to unlock collaboration.';

  @override
  String get exhibitionCreatorCollaborationLockedMessage => 'Once saved, collaborators can be invited here so curation stays in context.';

  @override
  String get lockAppLockedTitle => 'App locked';

  @override
  String get lockAppLockedDescription => 'Authenticate to unlock wallet access.';

  @override
  String get lockEnterPinTitle => 'Enter PIN to unlock';

  @override
  String get lockAppUnlockedToast => 'App unlocked';

  @override
  String get lockAuthenticationFailedToast => 'Authentication failed';

  @override
  String get authSignInTitle => 'Sign in to art.kubus';

  @override
  String get authSignInSubtitle => 'Start with art discovery, artists, institutions, and community. Add Wallet when you need archive records, editions, or governance.';

  @override
  String get authRegisterTitle => 'Create your account';

  @override
  String get authRegisterSubtitle => 'Create a profile first. Discovery, community, and local art access work without a wallet.';

  @override
  String get authHighlightSignInMethods => 'Email, Google, or wallet sign-in';

  @override
  String get authHighlightNoFees => 'No fee is required to sign in';

  @override
  String get authHighlightControl => 'Explore art and community without a wallet';

  @override
  String get authHighlightOnboardingOptions => 'Choose email, Google, or wallet sign-in';

  @override
  String get authHighlightKeysLocal => 'Private keys stay with you';

  @override
  String get authHighlightOptionalWeb3 => 'Wallet, editions, and governance when needed';

  @override
  String get authSignedInProfileRefreshSoon => 'Signed in. Your profile will refresh shortly.';

  @override
  String get postAuthPreparingSession => 'Preparing session';

  @override
  String get postAuthSecuringWallet => 'Securing wallet';

  @override
  String get postAuthLoadingProfile => 'Loading profile';

  @override
  String get postAuthSyncingSavedItems => 'Syncing saved items';

  @override
  String get postAuthCheckingOnboarding => 'Checking onboarding';

  @override
  String get postAuthOpeningWorkspace => 'Opening workspace';

  @override
  String get postAuthPreparingSessionBody => 'Finalizing your sign-in and preparing the workspace.';

  @override
  String get postAuthSecuringWalletBody => 'Verifying wallet access and device security.';

  @override
  String get postAuthLoadingProfileBody => 'Loading your account profile and preferences.';

  @override
  String get postAuthSyncingSavedItemsBody => 'Refreshing bookmarks and saved state from the backend.';

  @override
  String get postAuthCheckingOnboardingBody => 'Checking whether anything still needs your attention.';

  @override
  String get postAuthOpeningWorkspaceBody => 'Bringing your workspace online.';

  @override
  String get postAuthFailedTitle => 'We couldn\'t finish signing you in';

  @override
  String get postAuthFailedBody => 'Something interrupted the post-auth flow. You can retry or return to sign-in.';

  @override
  String get postAuthRetry => 'Retry';

  @override
  String get postAuthBackToSignIn => 'Back to sign-in';

  @override
  String get authReauthDialogTitle => 'Sign in again';

  @override
  String get authReauthDialogMessage => 'Your session has expired. Sign in again to continue.';

  @override
  String get authAccountCreatedProfileLoading => 'Account created. Loading your profile in the background.';

  @override
  String get authEmailSignInDisabled => 'Email sign-in is disabled.';

  @override
  String get authEmailRegistrationDisabled => 'Email registration is disabled.';

  @override
  String get authGoogleSignInDisabled => 'Google sign-in is disabled.';

  @override
  String get authGoogleUnavailableError => 'Google sign-in was cancelled or is unavailable right now.';

  @override
  String get authGoogleConnectingLabel => 'Connecting…';

  @override
  String get authContinueWithGoogleLabel => 'Continue with Google';

  @override
  String get authWalletConnectionDisabled => 'Wallet connection is disabled right now.';

  @override
  String get authEnterValidEmailPassword => 'Enter a valid email and an 8+ character password.';

  @override
  String get authEnterValidEmailInline => 'Enter a valid email address.';

  @override
  String get authPasswordPolicyError => 'Password must be at least 8 characters and include a letter and a number.';

  @override
  String get authPasswordMismatchInline => 'Passwords do not match.';

  @override
  String get authAccountAlreadyExistsToast => 'An account with this email already exists. Sign in instead.';

  @override
  String get authEmailSignInFailed => 'Email sign-in failed. Please try again.';

  @override
  String get authWalletSignInFailed => 'Wallet sign-in failed. Please try again.';

  @override
  String get authWalletOnlyAccountSignInHint => 'This account uses wallet sign-in. Connect the original wallet to continue.';

  @override
  String get authRegistrationFailed => 'Registration failed. Please try again.';

  @override
  String get authVerifyEmailRegistrationToast => 'Registration successful. Check your email to verify your account.';

  @override
  String get authEmailNotVerifiedToast => 'Email not verified. Check your inbox to continue.';

  @override
  String get authEmailNotVerifiedBadge => 'Email not verified';

  @override
  String get authForgotPasswordLink => 'Forgot password?';

  @override
  String get authVerifyEmailTitle => 'Verify your email';

  @override
  String get authVerifyEmailSubtitle => 'We sent a verification link. Tap it to finish setting up your account.';

  @override
  String get authVerifyEmailHighlightInbox => 'Open your email app and find our message';

  @override
  String get authVerifyEmailHighlightSpam => 'Check spam/junk if you don\'t see it';

  @override
  String get authVerifyEmailHighlightSecure => 'Links expire for security';

  @override
  String get authVerifyEmailStatusVerifying => 'Verifying…';

  @override
  String get authVerifyEmailStatusVerified => 'Email verified';

  @override
  String get authVerifyEmailStatusPending => 'Waiting for verification';

  @override
  String get authVerifyEmailResendButton => 'Resend verification email';

  @override
  String get authVerifyEmailEnterEmailInline => 'Enter your email to resend verification.';

  @override
  String get authVerifyEmailResendToast => 'If an account exists for this email, a verification email will be sent shortly.';

  @override
  String get authVerifyEmailResendFailedInline => 'Could not resend verification email. Please try again.';

  @override
  String get authVerifyEmailFailedInline => 'This verification link is invalid or expired.';

  @override
  String get authVerifyEmailSuccessToast => 'Email verified. You can now sign in.';

  @override
  String get authVerifyEmailSignInHint => 'After verifying, return here to sign in.';

  @override
  String get authForgotPasswordTitle => 'Reset your password';

  @override
  String get authForgotPasswordSubtitle => 'Enter your email and we\'ll send a reset link.';

  @override
  String get authForgotPasswordHighlightOne => 'We never reveal whether an email exists';

  @override
  String get authForgotPasswordHighlightTwo => 'Reset links expire quickly';

  @override
  String get authForgotPasswordEnterEmailInline => 'Enter your email.';

  @override
  String get authForgotPasswordSendButton => 'Send reset link';

  @override
  String get authForgotPasswordSentToast => 'If an account exists for this email, a reset link will be sent shortly.';

  @override
  String get authForgotPasswordFailedInline => 'Could not request a reset link. Please try again.';

  @override
  String get authResetPasswordTitle => 'Choose a new password';

  @override
  String get authResetPasswordSubtitle => 'Create a new password for your account.';

  @override
  String get authResetPasswordHighlightOne => 'Use a strong password';

  @override
  String get authResetPasswordHighlightTwo => 'Reset links are single-use';

  @override
  String get authResetPasswordMissingTokenInline => 'This reset link is missing a token.';

  @override
  String get authResetPasswordSubmitButton => 'Reset password';

  @override
  String get authResetPasswordSuccessToast => 'Password updated. You can now sign in.';

  @override
  String get authResetPasswordFailedInline => 'Could not reset your password. The link may be invalid or expired.';

  @override
  String get authGoogleSignInFailed => 'Google sign-in failed. Please try again.';

  @override
  String get authSignerProvisioningFailed => 'Unable to prepare wallet access on this device.';

  @override
  String authGoogleRateLimitedRetryIn(Object duration) {
    return 'Google sign-in is temporarily rate limited. Retry in ~$duration.';
  }

  @override
  String get authConnectWalletButton => 'Connect wallet';

  @override
  String get authUseWalletInstead => 'Use wallet';

  @override
  String get authSelfCustodyWalletHint => 'Already using a self-custody wallet? Connect it to continue with your existing art.kubus identity.';

  @override
  String get authConnectWalletModalTitle => 'Connect wallet';

  @override
  String get authConnectWalletModalDescriptionSignIn => 'Approve a signature to use Wallet on this device. Sign-in itself has no fee.';

  @override
  String get authConnectWalletModalDescriptionRegister => 'Approve a signature to use Wallet after creating your profile. No fee is required.';

  @override
  String get authWalletOptionWalletConnect => 'WalletConnect';

  @override
  String get authWalletOptionOtherWallets => 'Other wallets';

  @override
  String get authOrLogInWithEmailOrUsername => 'Or sign in with your email or username';

  @override
  String get authOrUseEmail => 'Or use email';

  @override
  String get authNeedAccountRegister => 'Need an account? Register';

  @override
  String get authHaveAccountSignIn => 'Have an account? Sign in';

  @override
  String get authSignInWithEmail => 'Sign in with email';

  @override
  String get authContinueWithEmail => 'Continue with email';

  @override
  String get authContinueWithPasskey => 'Continue with passkey';

  @override
  String get authPasskeySignInFailed => 'Passkey sign-in failed';

  @override
  String get accountPasskeySectionTitle => 'Account sign-in passkeys';

  @override
  String get accountPasskeySectionBody => 'Sign in without a password using a passkey on this device or browser.';

  @override
  String get accountPasskeyCreateAction => 'Create a passkey';

  @override
  String get accountPasskeyAddedToast => 'Passkey added';

  @override
  String get accountPasskeyRemovedToast => 'Passkey removed';

  @override
  String get accountPasskeyAddFailedToast => 'Could not add passkey';

  @override
  String get accountPasskeyRemoveFailedToast => 'Could not remove passkey';

  @override
  String get accountPasskeyRemoveAction => 'Remove passkey';

  @override
  String get accountPasskeySignInReadyStatus => 'Passkey sign-in ready';

  @override
  String get accountPasskeyNotConfiguredStatus => 'No passkey sign-in yet';

  @override
  String get passkeyProtectionEnableAction => 'Enable passkey protection';

  @override
  String get passkeyProtectionWalletRecoveryReady => 'Wallet recovery with passkey ready';

  @override
  String get passkeyProtectionSignInOnlyMessage => 'Passkey sign-in ready. Wallet recovery still needs your recovery password or recovery phrase on this device.';

  @override
  String get passkeyProtectionPrfUnsupportedMessage => 'This device supports passkey sign-in, but not passkey wallet recovery.';

  @override
  String get passkeyProtectionWalletRecoveryUnavailable => 'Passkey wallet recovery is unavailable';

  @override
  String get authShowOtherOptions => 'Show other options';

  @override
  String get authHideOtherOptions => 'Hide other options';

  @override
  String get authOtherOptionsLabel => 'Other ways to continue';

  @override
  String get authRestoreWalletTitle => 'Restore wallet from encrypted backup';

  @override
  String get authRestoreWalletBeforeSignInDescription => 'Enter the recovery password to restore wallet access on this device before sign-in completes.';

  @override
  String get authRestoreWalletForAccountDescription => 'Enter the recovery password to restore wallet access for this account on this device.';

  @override
  String get authRestoreWalletAction => 'Restore wallet';

  @override
  String get authSecureAccountTitle => 'Secure your account';

  @override
  String get authSecureAccountButton => 'Secure account';

  @override
  String get authSecureAccountAddPasswordTitle => 'Add a password';

  @override
  String get authSecureAccountAddPasswordButton => 'Add password';

  @override
  String get authSecureAccountPasswordAddedToast => 'Password added to your account.';

  @override
  String get authSecureAccountVerificationSentTitle => 'Verification email sent';

  @override
  String get authSecureAccountVerificationSentSubtitle => 'You\'re still signed in. Verify when you can.';

  @override
  String get authSecureAccountSecuredTitle => 'Account secured';

  @override
  String get authSecureAccountSecuredVerifiedSubtitle => 'Your email and password are ready for recovery sign-in.';

  @override
  String get authSecureAccountSecuredUnverifiedSubtitle => 'Your password is set. Verify your email to finish securing this account.';

  @override
  String get authSecureAccountFormAddPasswordSubtitle => 'Your signed-in email is already attached. Add a password for recovery without changing the Google sign-in.';

  @override
  String get authSecureAccountFormDefaultSubtitle => 'Add email + password so you can recover this account if you lose your device. You can verify email later.';

  @override
  String get authSecureAccountPromptAddPasswordBody => 'Your Google account is ready. Add a password now so you can recover this account even without Google.';

  @override
  String get authSecureAccountBannerAddPasswordSubtitle => 'Your email is already attached. Add a password for recovery.';

  @override
  String get authSecureAccountSettingsAddPasswordSubtitle => 'Add a password for recovery';

  @override
  String get authSecureAccountSettingsAddEmailPasswordSubtitle => 'Add email + password for recovery';

  @override
  String get commonEnable => 'Enable';

  @override
  String get commonFollow => 'Follow';

  @override
  String get commonFollowing => 'Following';

  @override
  String get onboardingFlowTitle => 'Your quick setup';

  @override
  String get onboardingFlowWelcomeTitle => 'art.kubus is an open art platform.';

  @override
  String get onboardingFlowWelcomeBody => 'Start with art, places, and community. Account setup and wallet tools can wait.';

  @override
  String get onboardingFlowWelcomeInfoAccount => 'Create a profile when you want a personal feed, follows, and community participation.';

  @override
  String get onboardingFlowWelcomeInfoCreate => 'Share artworks, add cultural context, or keep exploring the open art map.';

  @override
  String get onboardingFlowWelcomeInfoFollow => 'Follow artists, institutions, exhibitions, and public-space art.';

  @override
  String get onboardingFlowWelcomeInfoTime => 'Most people finish this in about 2 minutes.';

  @override
  String get onboardingFlowAccountTitle => 'Create your profile first';

  @override
  String get onboardingFlowAccountBody => 'Use email, Google, or wallet sign-in. Discovery, map browsing, and community access work without a wallet.';

  @override
  String get onboardingFlowAccountVerifyHint => 'If you registered with email, verify your email before signing in.';

  @override
  String get onboardingFlowCreateAccount => 'Create account';

  @override
  String get onboardingFlowOpenVerification => 'Open email verification';

  @override
  String get onboardingFlowVerifyLastTitle => 'One last step: verify your email';

  @override
  String get onboardingFlowVerifyLastBody => 'Check your inbox and verify your email to finish creating your account.';

  @override
  String get onboardingFlowProfileTitle => 'Create your profile';

  @override
  String get onboardingFlowProfileBody => 'Add a name and a photo so people can recognize you.';

  @override
  String get onboardingStepWalletSetupTitle => 'Set up your wallet';

  @override
  String get onboardingStepWalletSecurityTitle => 'Secure your wallet';

  @override
  String get onboardingFlowWalletBackupIntroTitle => 'Wallet backup';

  @override
  String get onboardingFlowWalletBackupIntroBody => 'Some account paths create a wallet for attribution, archive records, digital editions, and future participation. Public discovery and community access remain available without Wallet.';

  @override
  String get onboardingFlowWalletBackupIntroWeb3Warning => 'Discovery, profiles, and community do not require connecting a wallet.';

  @override
  String get onboardingFlowWalletBackupIntroSecretWarning => 'If you use encrypted backup, store the two secrets separately: the recovery phrase restores the wallet, and the recovery password unlocks the encrypted backup.';

  @override
  String get onboardingFlowWalletBackupIntroRecoveryPhraseLabel => 'Recovery phrase';

  @override
  String get onboardingFlowWalletBackupIntroRecoveryPhraseBody => 'Copy the recovery phrase and store it safely offline. It is the only way to restore this wallet if you lose the device.';

  @override
  String get onboardingFlowWalletBackupIntroEncryptedBackupLabel => 'Encrypted server backup';

  @override
  String get onboardingFlowWalletBackupIntroEncryptedBackupBody => 'Create an encrypted server backup as a second recovery path, then store the recovery password separately and just as carefully.';

  @override
  String get onboardingFlowWalletBackupIntroPasskeyLabel => 'Passkey protection';

  @override
  String get onboardingFlowWalletBackupIntroPasskeyBody => 'On supported browsers, add a passkey after creating the encrypted backup for stronger protection.';

  @override
  String get onboardingFlowWalletBackupIntroRevealAction => 'Reveal & copy phrase';

  @override
  String get onboardingFlowWalletBackupIntroEncryptedAction => 'Create encrypted backup';

  @override
  String get onboardingFlowWalletBackupIntroEncryptedDone => 'Encrypted backup ready';

  @override
  String get onboardingFlowWalletBackupIntroPasskeyAction => 'Add passkey';

  @override
  String get onboardingFlowWalletBackupIntroPasskeyDone => 'Passkey added';

  @override
  String get onboardingFlowWalletBackupTitle => 'Back up your recovery phrase';

  @override
  String get onboardingFlowWalletBackupBody => 'This phrase restores wallet access for digital ownership, archive records and future participation on a new device.';

  @override
  String get onboardingFlowWalletBackupPrivacyWarning => 'Keep it private. Anyone with this phrase can fully control your wallet.';

  @override
  String get onboardingFlowWalletBackupLossWarning => 'If you lose it, we cannot restore wallet-linked access for you. Public discovery and community browsing still work.';

  @override
  String get onboardingFlowWalletBackupAction => 'Reveal and confirm backup';

  @override
  String get onboardingFlowWalletBackupCompleted => 'Recovery phrase backup confirmed.';

  @override
  String get onboardingFlowWalletBackupNoWallet => 'No wallet is available for backup yet.';

  @override
  String get onboardingFlowWalletBackupContinueHint => 'Reveal your phrase and confirm the backup to continue.';

  @override
  String get onboardingFlowRoleTitle => 'Pick your role';

  @override
  String get onboardingFlowRoleBody => 'Choose the highlights you want. You can change this later in Settings.';

  @override
  String get onboardingFlowRoleRequiredHint => 'Choose how you want to use art.kubus before continuing.';

  @override
  String get onboardingFlowRoleSaving => 'Saving your role...';

  @override
  String get onboardingFlowRoleSaveFailed => 'We could not save your role. Please try again.';

  @override
  String get onboardingFlowPermissionsTitle => 'Choose what to enable';

  @override
  String get onboardingFlowPermissionsBody => 'Enable location for nearby public art, camera for AR layers in development, and notifications for artists, institutions, exhibitions, and community updates.';

  @override
  String get onboardingFlowContinueWithoutPermissions => 'Continue';

  @override
  String get onboardingFlowArtworkTitle => 'Create your first artwork';

  @override
  String get onboardingFlowArtworkBody => 'Start with one piece. Drafts are fine, and you can refine it anytime.';

  @override
  String get onboardingFlowFollowTitle => 'Follow a few artists';

  @override
  String get onboardingFlowFollowBody => 'Pick a few creators to personalize your feed.';

  @override
  String get onboardingFlowDoneTitle => 'You\'re all set';

  @override
  String get onboardingFlowDoneBody => 'Your space is ready. Start discovering public art, artists, institutions, and community activity.';

  @override
  String get onboardingFlowOpenProfile => 'Open profile setup';

  @override
  String get onboardingFlowPermissionLocation => 'Location';

  @override
  String get onboardingFlowPermissionNotifications => 'Notifications';

  @override
  String get onboardingFlowPermissionCamera => 'Camera';

  @override
  String get onboardingFlowCreateArtwork => 'Create artwork';

  @override
  String get onboardingFlowNoSuggestions => 'No suggestions yet. You can follow artists from Community anytime.';

  @override
  String get onboardingFlowUnknownArtist => 'Artist';

  @override
  String get onboardingFlowFollowFailed => 'Couldn\'t update follow status. Please try again.';

  @override
  String get onboardingFlowVerifyContinue => 'I verified / Continue';

  @override
  String get onboardingFlowWelcomeDecisionHint => 'Choose one path to get started.';

  @override
  String get onboardingFlowVerifySignInPrompt => 'Verified - please enter password to finish signing in';

  @override
  String get onboardingFlowVerifySigningIn => 'Verified - signing you in...';

  @override
  String get onboardingFlowVerifySignedInSuccess => 'Verified account signed in successfully.';

  @override
  String get onboardingFlowVerifySessionMismatch => 'Sign-in session mismatch. Please sign in with your verified email.';

  @override
  String onboardingFlowVerificationDifferentAccountWarning(Object email) {
    return 'Sign-in used a different account. Use $email to finish verification.';
  }

  @override
  String get onboardingFlowProfileRefreshPending => 'Signed in, but profile refresh is still syncing. Please continue.';

  @override
  String get onboardingFlowSignedInFinishing => 'Signed in. Finishing onboarding...';

  @override
  String get onboardingFlowVerifyEmailConfirmedHint => 'Email confirmed. Continue to finish onboarding.';

  @override
  String get onboardingFlowVerifySignInTitle => 'Sign in to finish';

  @override
  String get onboardingFlowVerifySignInDescription => 'Use your verified email and password to finish onboarding.';

  @override
  String get onboardingFlowProfileAvatarPickFailed => 'Unable to select avatar right now.';

  @override
  String get onboardingFlowProfileInstitutionIntro => 'Add the organization details people should see first. Community governance review comes right after this.';

  @override
  String get onboardingFlowProfileCreatorIntro => 'Set up your public creator profile now so your review submission has the right context.';

  @override
  String get onboardingFlowProfileOrganizationNameLabel => 'Organization name';

  @override
  String get onboardingFlowProfileInstitutionBioLabel => 'About your institution';

  @override
  String get onboardingFlowProfileSelectingAvatar => 'Selecting...';

  @override
  String get onboardingFlowWalletBackupCreateEncryptedTitle => 'Create encrypted server backup';

  @override
  String get onboardingFlowWalletBackupCreateEncryptedDescription => 'Choose a recovery password and store it separately from your recovery phrase.';

  @override
  String get onboardingFlowWalletBackupCreateEncryptedAction => 'Create backup';

  @override
  String get onboardingFlowWalletBackupEncryptedSaved => 'Encrypted server backup saved.';

  @override
  String get onboardingFlowWalletBackupPasskeyDialogTitle => 'Add a passkey';

  @override
  String get onboardingFlowWalletBackupPasskeyDialogLabel => 'Passkey name';

  @override
  String get onboardingFlowWalletBackupPasskeyDialogDescription => 'Add a passkey to protect the encrypted server backup on this browser or device.';

  @override
  String get onboardingFlowWalletBackupPasskeyDialogDefaultName => 'This device';

  @override
  String get onboardingFlowWalletBackupPasskeyDialogAction => 'Add passkey';

  @override
  String onboardingFlowWalletBackupPasskeyAdded(Object passkeyName) {
    return 'Passkey \"$passkeyName\" added.';
  }

  @override
  String get onboardingFlowDaoReviewTitle => 'Governance review';

  @override
  String get onboardingFlowDaoReviewInstitutionBody => 'Submit your institution details for community governance review before account setup is completed.';

  @override
  String get onboardingFlowDaoReviewArtistBody => 'Submit your practice for community governance review before account setup is completed.';

  @override
  String get onboardingFlowDaoReviewCompleteFormError => 'Complete the review form before continuing.';

  @override
  String get onboardingFlowDaoReviewSubmitFailed => 'Unable to submit the governance review right now.';

  @override
  String onboardingFlowDaoReviewStatus(Object status) {
    return 'Current status: $status';
  }

  @override
  String get onboardingFlowDaoReviewOrganizationLabel => 'Organization';

  @override
  String get onboardingFlowDaoReviewContactLabel => 'Contact URL or email';

  @override
  String get onboardingFlowDaoReviewPortfolioLabel => 'Portfolio URL';

  @override
  String get onboardingFlowDaoReviewInstitutionFocusLabel => 'Institution focus';

  @override
  String get onboardingFlowDaoReviewPrimaryMediumLabel => 'Primary medium';

  @override
  String get onboardingFlowDaoReviewMissionLabel => 'Mission';

  @override
  String get onboardingFlowDaoReviewArtistStatementLabel => 'Artist statement';

  @override
  String get onboardingFlowDaoReviewReviewerNotes => 'Reviewer notes';

  @override
  String get onboardingFlowDaoReviewSubmitAction => 'Submit for governance review';

  @override
  String get onboardingWelcomeTitle => 'art.kubus is an open art platform.';

  @override
  String get onboardingWelcomeSubtitle => 'Community-first cultural discovery';

  @override
  String get onboardingWelcomeDescription => 'Discover local art, creators, institutions, exhibitions and works in public space. art.kubus connects the map, community, AR, wallet, archive records and governance into one open cultural infrastructure.';

  @override
  String get onboardingExploreTitle => 'Explore the open art map';

  @override
  String get onboardingExploreSubtitle => 'Discover local and public-space art';

  @override
  String get onboardingExploreDescription => 'Use the community-generated cultural map to find artworks, exhibitions, institutions, artists, and public-space stories nearby.';

  @override
  String get onboardingCreateTitle => 'Share art and context';

  @override
  String get onboardingCreateSubtitle => 'Contribute to the cultural archive';

  @override
  String get onboardingCreateDescription => 'Publish artworks, document practice, add context, and prepare AR layers when they support the work.';

  @override
  String get onboardingCommunityTitle => 'Join the art community';

  @override
  String get onboardingCommunitySubtitle => 'Community, collaboration and governance';

  @override
  String get onboardingCommunityDescription => 'Follow artists and institutions, discuss works, collaborate and take part in shaping the platform.';

  @override
  String get onboardingCollectiblesTitle => 'Archive records and digital editions';

  @override
  String get onboardingCollectiblesSubtitle => 'Cultural memory, visits and ownership';

  @override
  String get onboardingCollectiblesDescription => 'When you visit or contribute to public art, kubus can record that context as an archive record or digital edition. Discovery and community remain open without a wallet.';

  @override
  String get onboardingGrantPermissions => 'Grant permissions';

  @override
  String get onboardingSkipPermissions => 'Skip permissions';

  @override
  String get permissionsChecking => 'Checking permissions…';

  @override
  String get permissionsSkipAll => 'Skip all';

  @override
  String get permissionsBenefitsTitle => 'What you can do:';

  @override
  String get permissionsPrivacyNote => 'Your privacy matters. Permissions are used only for the features you enable, and you can change them anytime.';

  @override
  String get permissionsGrantedLabel => 'Permission granted';

  @override
  String get permissionsGetStarted => 'Get started';

  @override
  String get permissionsNextPermission => 'Next permission';

  @override
  String get permissionsGrantPermission => 'Grant permission';

  @override
  String get permissionsSkipThisPermission => 'Skip this permission';

  @override
  String permissionsPermissionGrantedToast(Object permission) {
    return 'Permission granted: $permission';
  }

  @override
  String get permissionsPermissionRequiredTitle => 'Permission required';

  @override
  String permissionsOpenSettingsDialogContent(Object permission) {
    return 'To enable $permission, open Settings and grant the permission.';
  }

  @override
  String get permissionsOpenSettings => 'Open settings';

  @override
  String get permissionsLocationTitle => 'Find art near you';

  @override
  String get permissionsLocationSubtitle => 'Nearby artworks and places';

  @override
  String get permissionsLocationDescription => 'We use your location to show nearby artworks, markers, and exhibitions. You can still browse without it.';

  @override
  String get permissionsLocationBenefit1 => 'Find artworks near you';

  @override
  String get permissionsLocationBenefit2 => 'Discover local galleries and exhibitions';

  @override
  String get permissionsLocationBenefit3 => 'Get updates about nearby events';

  @override
  String get permissionsLocationBenefit4 => 'Track your exploration journey';

  @override
  String get permissionsCameraTitle => 'Camera for AR layers';

  @override
  String get permissionsCameraSubtitle => 'AR pilots in development';

  @override
  String get permissionsCameraDescription => 'Camera access supports AR layers in development, including previews, placement, and capture when pilots are available.';

  @override
  String get permissionsCameraBenefit1 => 'Preview AR layers when pilots are available';

  @override
  String get permissionsCameraBenefit2 => 'Prepare virtual placements';

  @override
  String get permissionsCameraBenefit3 => 'Take photos to share';

  @override
  String get permissionsCameraBenefit4 => 'Scan QR codes to unlock content';

  @override
  String get permissionsNotificationsTitle => 'Notifications';

  @override
  String get permissionsNotificationsSubtitle => 'Stay connected';

  @override
  String get permissionsNotificationsDescription => 'Get updates about new artworks, exhibitions, events, community activity and participation records.';

  @override
  String get permissionsNotificationsBenefit1 => 'New artwork updates';

  @override
  String get permissionsNotificationsBenefit2 => 'Progress and recognition';

  @override
  String get permissionsNotificationsBenefit3 => 'Participation records and exhibition updates';

  @override
  String get permissionsNotificationsBenefit4 => 'Community event reminders';

  @override
  String get permissionsPhotosTitle => 'Photo library access';

  @override
  String get permissionsPhotosSubtitle => 'Save your creations';

  @override
  String get permissionsPhotosDescription => 'Save AR pilot screenshots and downloads to your photo library when those features are available.';

  @override
  String get permissionsPhotosBenefit1 => 'Save AR pilot screenshots to your photos';

  @override
  String get permissionsPhotosBenefit2 => 'Download artwork images';

  @override
  String get permissionsPhotosBenefit3 => 'Export creations to share';

  @override
  String get permissionsPhotosBenefit4 => 'Keep your collection accessible';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageDescription => 'Choose the app language';

  @override
  String get languageSlovenian => 'Slovene';

  @override
  String get languageEnglish => 'English';

  @override
  String get commonOn => 'On';

  @override
  String get commonOff => 'Off';

  @override
  String get commonEnabled => 'Enabled';

  @override
  String get commonDisabled => 'Disabled';

  @override
  String get commonAvailable => 'Available';

  @override
  String get commonNotAvailable => 'Not available';

  @override
  String get settingsGuestUserName => 'Guest user';

  @override
  String get desktopSettingsProfileSectionSubtitle => 'Update your profile information visible to other users';

  @override
  String get desktopSettingsDisplayNameLabel => 'Display name';

  @override
  String get desktopSettingsDisplayNameHint => 'Enter your name';

  @override
  String get desktopSettingsUsernameLabel => 'Username';

  @override
  String get desktopSettingsUsernameHint => '@username';

  @override
  String get desktopSettingsBioLabel => 'Bio';

  @override
  String get desktopSettingsBioHint => 'Tell us about yourself';

  @override
  String get desktopSettingsWebsiteLabel => 'Website';

  @override
  String get desktopSettingsWebsiteHint => 'https://';

  @override
  String get desktopSettingsLocationLabel => 'Location';

  @override
  String get desktopSettingsLocationHint => 'City, Country';

  @override
  String get desktopSettingsWalletSectionSubtitle => 'Manage wallet access, recovery and ownership tools.';

  @override
  String get desktopSettingsViewWalletButton => 'View wallet';

  @override
  String get desktopSettingsSecuritySectionTitle => 'Security';

  @override
  String get desktopSettingsDisconnectWalletTileTitle => 'Disconnect wallet';

  @override
  String get desktopSettingsDisconnectWalletTileSubtitle => 'Disconnect this device from your account wallet';

  @override
  String get desktopSettingsDisconnectWalletDialogTitle => 'Disconnect wallet';

  @override
  String get desktopSettingsDisconnectWalletDialogBody => 'Disconnect your wallet from this device? You can reconnect anytime.';

  @override
  String get desktopSettingsWalletDisconnectedToast => 'Wallet disconnected';

  @override
  String get desktopSettingsDisconnectButton => 'Disconnect';

  @override
  String get desktopSettingsExportingDataToast => 'Exporting data…';

  @override
  String get desktopSettingsPlatformSubtitle => 'Check which capabilities are available on this device';

  @override
  String get desktopSettingsAppearanceSubtitle => 'Customize the look and feel';

  @override
  String get desktopSettingsShowFriendsTitle => 'Show friends';

  @override
  String get desktopSettingsShowFriendsSubtitle => 'Display your friends list on your profile';

  @override
  String get desktopSettingsShowAchievementsTitle => 'Show achievements';

  @override
  String get desktopSettingsShowAchievementsSubtitle => 'Display your achievements on your profile';

  @override
  String get desktopSettingsAllowMessagesTitle => 'Allow messages';

  @override
  String get desktopSettingsAllowMessagesSubtitle => 'Allow others to message you';

  @override
  String get desktopSettingsDangerZoneSubtitle => 'Irreversible actions that require caution';

  @override
  String get desktopSettingsAchievementsTitle => 'Achievements & recognition';

  @override
  String get desktopSettingsAchievementsSubtitle => 'Track milestones and signals of participation without presenting them as financial incentives';

  @override
  String get desktopSettingsAchievementsStatArtworksDiscovered => 'Artworks discovered';

  @override
  String get desktopSettingsAchievementsStatArViews => 'AR views';

  @override
  String get desktopSettingsAchievementsStatEventsAttended => 'Events attended';

  @override
  String get desktopSettingsAchievementsStatKub8PointsEarned => 'Contribution recognition';

  @override
  String get desktopSettingsAchievementFirstDiscoveryTitle => 'First discovery';

  @override
  String get desktopSettingsAchievementFirstDiscoveryDescription => 'Discover your first public artwork';

  @override
  String get desktopSettingsAchievementArtCollectorTitle => 'Art explorer';

  @override
  String get desktopSettingsAchievementArtCollectorDescription => 'Discover 10 artworks or AR layers.';

  @override
  String get desktopSettingsAchievementCommunityMemberTitle => 'Community member';

  @override
  String get desktopSettingsAchievementCommunityMemberDescription => 'Join 3 community groups';

  @override
  String get desktopSettingsAchievementEventExplorerTitle => 'Event explorer';

  @override
  String get desktopSettingsAchievementEventExplorerDescription => 'Attend 5 art events';

  @override
  String get desktopSettingsAchievementNftCreatorTitle => 'First digital edition';

  @override
  String get desktopSettingsAchievementNftCreatorDescription => 'Create your first digital edition';

  @override
  String get desktopSettingsHelpSupportTitle => 'Help & support';

  @override
  String get desktopSettingsHelpSupportSubtitle => 'Get help and find answers to common questions';

  @override
  String get desktopSettingsFaqTileTitle => 'FAQ';

  @override
  String get desktopSettingsFaqTileSubtitle => 'Frequently asked questions';

  @override
  String get desktopSettingsContactSupportTileSubtitle => 'Get help from our team';

  @override
  String get desktopSettingsReportBugTileTitle => 'Report a bug';

  @override
  String get desktopSettingsReportBugTileSubtitle => 'Help us improve the app';

  @override
  String get desktopSettingsOpeningBugReportToast => 'Opening bug report form…';

  @override
  String get desktopSettingsAboutSubtitle => 'Open art platform connecting artists, institutions, and public space';

  @override
  String get desktopSettingsFeaturesSectionTitle => 'Features';

  @override
  String get desktopSettingsFeatureArDiscoveryTitle => 'AR layers in development';

  @override
  String get desktopSettingsFeatureArDiscoveryDescription => 'Prepare AR previews as pilots become available.';

  @override
  String get desktopSettingsFeatureWeb3IntegrationTitle => 'Wallet and Web3 access';

  @override
  String get desktopSettingsFeatureWeb3IntegrationDescription => 'Connect Wallet for attribution, archive records, digital editions, or future participation tools. Basic discovery and community do not require it.';

  @override
  String get desktopSettingsFeatureNftMintingTitle => 'Digital editions';

  @override
  String get desktopSettingsFeatureNftMintingDescription => 'Create and manage digital records connected to artworks, visits or contributions.';

  @override
  String get desktopSettingsFeatureCommunityTitle => 'Community';

  @override
  String get desktopSettingsFeatureCommunityDescription => 'Connect with artists, institutions, and art lovers';

  @override
  String get desktopSettingsFeatureInstitutionsTitle => 'Institutions';

  @override
  String get desktopSettingsFeatureInstitutionsDescription => 'Partner with galleries and museums';

  @override
  String get desktopSettingsLegalSectionTitle => 'Legal';

  @override
  String get settingsNoWalletConnected => 'No wallet connected';

  @override
  String get settingsAppearanceSectionTitle => 'Appearance';

  @override
  String get settingsThemeModeTitle => 'Theme mode';

  @override
  String get settingsThemeModeLight => 'Light';

  @override
  String get settingsThemeModeDark => 'Dark';

  @override
  String get settingsThemeModeSystem => 'System';

  @override
  String get settingsAccentColorTitle => 'Accent color';

  @override
  String get settingsPlatformFeaturesSectionTitle => 'Platform features';

  @override
  String settingsRunningOnPlatform(Object platform) {
    return 'Running on $platform';
  }

  @override
  String get settingsAvailableFeaturesLabel => 'Available features:';

  @override
  String get settingsDeveloperToolsSectionTitle => 'Developer tools';

  @override
  String get settingsDeveloperClearQuickActionsTitle => 'Clear quick actions';

  @override
  String get settingsDeveloperClearQuickActionsSubtitle => 'Reset recently visited screens';

  @override
  String get settingsDeveloperQuickActionsClearedToast => 'Quick actions cleared';

  @override
  String get settingsCapabilityCamera => 'Camera access (QR scanner, AR)';

  @override
  String get settingsCapabilityAr => 'Augmented reality features';

  @override
  String get settingsCapabilityNfc => 'NFC communication';

  @override
  String get settingsCapabilityGps => 'Location services';

  @override
  String get settingsCapabilityBiometrics => 'Biometric authentication';

  @override
  String get settingsCapabilityNotifications => 'Push notifications';

  @override
  String get settingsCapabilityFileSystem => 'File system access';

  @override
  String get settingsCapabilityBluetooth => 'Bluetooth connectivity';

  @override
  String get settingsCapabilityVibration => 'Haptic feedback';

  @override
  String get settingsCapabilityOrientation => 'Device orientation';

  @override
  String get settingsCapabilityBackground => 'Background processing';

  @override
  String get settingsProfileSectionTitle => 'Profile settings';

  @override
  String get settingsProfileVisibilityPublicLabel => 'Public';

  @override
  String get settingsProfileVisibilityPublicDescription => 'Anyone can see your profile';

  @override
  String get settingsProfileVisibilityPrivateLabel => 'Private';

  @override
  String get settingsProfileVisibilityPrivateDescription => 'Only you can see your profile';

  @override
  String get settingsProfileVisibilityFriendsOnlyLabel => 'Friends only';

  @override
  String get settingsProfileVisibilityFriendsOnlyDescription => 'Only friends can see your profile';

  @override
  String get settingsProfileVisibilityTileTitle => 'Profile visibility';

  @override
  String settingsCurrentlyValue(Object value) {
    return 'Currently: $value';
  }

  @override
  String get settingsPrivacySettingsTileTitle => 'Privacy settings';

  @override
  String settingsPrivacySummary(Object dataState, Object adsState) {
    return 'Data: $dataState, Ads: $adsState';
  }

  @override
  String get settingsSecuritySettingsTileTitle => 'Security settings';

  @override
  String settingsSecuritySummary(Object twoFactorStatus, Object autoLockTime) {
    return '2FA: $twoFactorStatus, Auto-lock: $autoLockTime';
  }

  @override
  String get settingsEditProfileTileTitle => 'Edit profile';

  @override
  String get settingsEditProfileTileSubtitle => 'Update your username, bio, and avatar';

  @override
  String get settingsAccountManagementTileTitle => 'Account management';

  @override
  String settingsAccountSummary(Object accountType, Object notificationsState) {
    return 'Type: $accountType, Notifications: $notificationsState';
  }

  @override
  String get settingsRoleSimulationTileTitle => 'Role simulation';

  @override
  String settingsRoleSummary(Object artistStatus, Object institutionStatus) {
    return 'Artist: $artistStatus, Institution: $institutionStatus';
  }

  @override
  String get settingsRoleSimulationSheetTitle => 'Role simulation';

  @override
  String get settingsRoleSimulationSheetSubtitle => 'Toggle roles to preview profile layouts locally. Changes are local to this device.';

  @override
  String get settingsRoleArtistTitle => 'Artist profile';

  @override
  String get settingsRoleArtistSubtitle => 'Show artist sections (artworks, collections)';

  @override
  String get settingsRoleInstitutionTitle => 'Institution profile';

  @override
  String get settingsRoleInstitutionSubtitle => 'Show institution sections (events, collections)';

  @override
  String get settingsWalletSectionTitle => 'Wallet';

  @override
  String get settingsWalletConnectionTileTitle => 'Wallet connection';

  @override
  String get settingsWalletConnectionConnected => 'Connected';

  @override
  String get settingsWalletConnectionNotConnected => 'Not connected';

  @override
  String get walletSessionAccountSignedIn => 'Signed in';

  @override
  String get walletSessionAccountSignedOut => 'Signed out';

  @override
  String get walletSessionSignerReady => 'Signing available';

  @override
  String get walletSessionSignerMissing => 'Signing unavailable on this device';

  @override
  String walletSessionStatusSummary(Object accountStatus, Object walletStatus, Object signerStatus) {
    return 'Account: $accountStatus · Wallet: $walletStatus · Access: $signerStatus';
  }

  @override
  String get walletActionSignInRequiredToast => 'Sign in to continue.';

  @override
  String get walletActionConnectWalletRequiredToast => 'Connect a wallet to continue with this wallet-linked action.';

  @override
  String get walletActionAccountShellNeedsWalletToast => 'Your account is signed in, but this device still needs the wallet restored or connected before this action can continue.';

  @override
  String get walletActionEncryptedBackupRestoreToast => 'An encrypted backup is available. Restore wallet access on this device before continuing.';

  @override
  String get walletActionRecoveryNeededToast => 'Restore wallet access on this device before continuing.';

  @override
  String get walletActionReadOnlyReconnectToast => 'Reconnect with your wallet provider or restore wallet access on this device before continuing.';

  @override
  String get settingsNetworkTileTitle => 'Network';

  @override
  String settingsCurrentNetworkValue(Object network) {
    return 'Current: $network';
  }

  @override
  String get settingsTransactionHistoryTileTitle => 'Transaction history';

  @override
  String get settingsTransactionHistoryTileSubtitle => 'View all transactions';

  @override
  String get settingsBackupSettingsTileTitle => 'Backup protection';

  @override
  String settingsAutoBackupSummary(Object status) {
    return 'Auto-backup: $status';
  }

  @override
  String get settingsBackupStatusNoWallet => 'No wallet connected yet';

  @override
  String get settingsBackupStatusAccountShellOnly => 'Account wallet has not been restored on this device yet';

  @override
  String get settingsBackupStatusNoBackup => 'No backup protection configured yet';

  @override
  String get settingsBackupStatusRecoveryPhraseRequired => 'Recovery phrase backup still required';

  @override
  String get settingsBackupStatusEncryptedServerBackup => 'Encrypted server backup configured';

  @override
  String get settingsBackupStatusPasskeyProtection => 'Passkey-protected server backup configured';

  @override
  String get settingsBackupStatusReadOnly => 'Read-only wallet session on this device';

  @override
  String get settingsBackupStatusEncryptedBackupRestoreAvailable => 'Encrypted backup available to restore signing on this device';

  @override
  String get settingsExportRecoveryPhraseTileTitle => 'Export recovery phrase';

  @override
  String get settingsExportRecoveryPhraseTileSubtitle => 'Back up your wallet (sensitive)';

  @override
  String get settingsImportWalletTileTitle => 'Import existing wallet (advanced)';

  @override
  String get settingsImportWalletTileSubtitle => 'Use a recovery phrase you already have';

  @override
  String get settingsSecurityPrivacySectionTitle => 'Security & privacy';

  @override
  String get settingsBiometricTileTitle => 'Biometric authentication';

  @override
  String get settingsBiometricTileSubtitle => 'Use fingerprint or face unlock';

  @override
  String get settingsUseBiometricsOnUnlockTitle => 'Use biometrics on unlock';

  @override
  String get settingsUseBiometricsOnUnlockSubtitle => 'Prefer biometrics when unlocking the app';

  @override
  String get settingsRequirePinTileTitle => 'Require PIN';

  @override
  String get settingsRequirePinTileSubtitle => 'Require PIN to unlock the app';

  @override
  String get settingsSetPinTileTitle => 'Set app PIN';

  @override
  String get settingsSetPinTileSubtitle => 'Protect the app with a numeric PIN';

  @override
  String get settingsAutoLockTileTitle => 'Auto-lock';

  @override
  String get settingsAutoLockTileSubtitle => 'Lock app after inactivity';

  @override
  String get settingsPrivacyModeTileTitle => 'Privacy mode';

  @override
  String get settingsPrivacyModeTileSubtitle => 'Hide sensitive information';

  @override
  String get settingsClearCacheTileTitle => 'Clear cache';

  @override
  String get settingsClearCacheTileSubtitle => 'Remove temporary files';

  @override
  String get settingsDataAnalyticsSectionTitle => 'Data & analytics';

  @override
  String get settingsAnalyticsTileTitle => 'Analytics';

  @override
  String get settingsAnalyticsTileSubtitle => 'Help improve the app';

  @override
  String get settingsCrashReportingTileTitle => 'Crash reporting';

  @override
  String get settingsCrashReportingTileSubtitle => 'Send crash reports automatically';

  @override
  String get settingsSkipOnboardingTileTitle => 'Skip onboarding';

  @override
  String get settingsSkipOnboardingTileSubtitle => 'Skip welcome screens for returning users';

  @override
  String get settingsDataExportTileTitle => 'Data export';

  @override
  String get settingsDataExportTileSubtitle => 'Download your data';

  @override
  String get settingsResetPermissionFlagsTileTitle => 'Reset permission flags';

  @override
  String get settingsResetPermissionFlagsTileSubtitle => 'Clear saved permission/service prompts';

  @override
  String get settingsAboutSectionTitle => 'About';

  @override
  String get settingsAboutVersionTileTitle => 'Version';

  @override
  String get settingsAboutTermsTileTitle => 'Terms of service';

  @override
  String get settingsAboutTermsTileSubtitle => 'Read our terms';

  @override
  String get settingsAboutPrivacyTileTitle => 'Privacy policy';

  @override
  String get settingsAboutPrivacyTileSubtitle => 'Read our privacy policy';

  @override
  String get settingsAboutSupportTileTitle => 'Support';

  @override
  String get settingsAboutSupportTileSubtitle => 'Get help or report issues';

  @override
  String get settingsAboutLicensesTileTitle => 'Open source licenses';

  @override
  String get settingsAboutLicensesTileSubtitle => 'View third-party licenses';

  @override
  String get settingsAboutRateTileTitle => 'Rate app';

  @override
  String get settingsAboutRateTileSubtitle => 'Rate us on the app store';

  @override
  String get settingsDangerZoneSectionTitle => 'Danger zone';

  @override
  String get settingsLogoutTileTitle => 'Log out';

  @override
  String get settingsLogoutTileSubtitle => 'Sign out and clear this device session';

  @override
  String get settingsResetAppTileTitle => 'Reset app';

  @override
  String get settingsResetAppTileSubtitle => 'Clear all data and settings';

  @override
  String get settingsDeleteAccountTileTitle => 'Delete account';

  @override
  String get settingsDeleteAccountTileSubtitle => 'Permanently delete your account';

  @override
  String get settingsSelectNetworkDialogTitle => 'Select network';

  @override
  String get settingsNetworkMainnetDescription => 'Live Solana network';

  @override
  String get settingsNetworkDevnetDescription => 'Development network for testing';

  @override
  String get settingsNetworkTestnetDescription => 'Test network for development';

  @override
  String settingsSwitchedToNetworkToast(Object network) {
    return 'Switched to $network';
  }

  @override
  String get settingsConnectWalletFirstToast => 'Please connect your wallet first';

  @override
  String get settingsBackupWalletDialogTitle => 'Back up recovery phrase';

  @override
  String get settingsBackupWalletDialogIntro => 'This will reveal your recovery phrase. Anyone who sees it can control this wallet.';

  @override
  String get settingsSecurityWarningTitle => 'Security warning';

  @override
  String get settingsSecurityWarningBullets => '• Make sure you are in a private place\n• Never share your recovery phrase or recovery password\n• Store them separately and safely offline';

  @override
  String get settingsConnectOrCreateWalletFirstToast => 'Connect or create a wallet first.';

  @override
  String get settingsAutoLockImmediately => 'Immediately';

  @override
  String get settingsAutoLock10Seconds => '10 seconds';

  @override
  String get settingsAutoLock30Seconds => '30 seconds';

  @override
  String get settingsAutoLock1Minute => '1 minute';

  @override
  String get settingsAutoLock5Minutes => '5 minutes';

  @override
  String get settingsAutoLock15Minutes => '15 minutes';

  @override
  String get settingsAutoLock30Minutes => '30 minutes';

  @override
  String get settingsAutoLock1Hour => '1 hour';

  @override
  String get settingsAutoLock3Hours => '3 hours';

  @override
  String get settingsAutoLock6Hours => '6 hours';

  @override
  String get settingsAutoLock12Hours => '12 hours';

  @override
  String get settingsAutoLock1Day => '1 day';

  @override
  String get settingsAutoLockNever => 'Never';

  @override
  String get settingsAutoLockTimerDialogTitle => 'Auto-lock timer';

  @override
  String settingsAutoLockSetToToast(Object value) {
    return 'Auto-lock set to $value';
  }

  @override
  String get settingsBiometricUnavailableToast => 'Biometric unlock not available on this device.';

  @override
  String get settingsBiometricFailedToast => 'Biometric authentication failed.';

  @override
  String get settingsExportRecoveryPhraseDialogTitle => 'Export recovery phrase';

  @override
  String get settingsExportRecoveryPhraseDialogBody => 'Only view your phrase in private. We never store it, and anyone with it can move your assets.';

  @override
  String get settingsExportRecoveryPhraseDialogConfirm => 'Confirm you are ready before revealing the words.';

  @override
  String get settingsShowPhraseButton => 'Show phrase';

  @override
  String get settingsImportWalletDialogTitle => 'Import existing wallet';

  @override
  String get settingsImportWalletDialogBody => 'Only paste a recovery phrase from a trusted source. Avoid public Wi-Fi, shared screens, and anyone looking over your shoulder while importing.';

  @override
  String get settingsImportWalletDialogConfirm => 'We never store your recovery phrase. The wallet and its recovery stay in your hands.';

  @override
  String get settingsSetPinDialogTitle => 'Set app PIN';

  @override
  String get settingsConfirmPinLabel => 'Confirm PIN';

  @override
  String get settingsPinClearedToast => 'PIN cleared';

  @override
  String get settingsClearPinButton => 'Clear PIN';

  @override
  String get settingsPinMinLengthError => 'PIN must be at least 4 digits';

  @override
  String get settingsPinMismatchError => 'PINs do not match';

  @override
  String get settingsPinSetSuccessToast => 'PIN set successfully';

  @override
  String get settingsPinSetFailedToast => 'Failed to set PIN';

  @override
  String get settingsClearCacheDialogTitle => 'Clear cache';

  @override
  String get settingsClearCacheDialogBody => 'This will clear temporary files and may improve performance.';

  @override
  String get settingsCacheClearedToast => 'Cache cleared successfully';

  @override
  String get settingsClearButton => 'Clear';

  @override
  String get settingsResetPermissionFlagsDialogTitle => 'Reset permission flags';

  @override
  String get settingsResetPermissionFlagsDialogBody => 'This will clear the app\'s stored permission and service request flags. Use this to re-trigger permission prompts if needed.';

  @override
  String get settingsPermissionFlagsResetToast => 'Permission flags reset';

  @override
  String get settingsResetButton => 'Reset';

  @override
  String get settingsExportDataDialogTitle => 'Export data';

  @override
  String get settingsExportDataDialogBody => 'This will create a file with your app data (excluding private keys).';

  @override
  String settingsDataExportedToast(Object count) {
    return 'Data exported: $count categories';
  }

  @override
  String get settingsExportButton => 'Export';

  @override
  String get settingsResetAppDialogTitle => 'Reset app';

  @override
  String get settingsResetAppDialogBody => 'This will clear app data and settings on this device. It disconnects the wallet session here, but it does not delete the wallet itself.';

  @override
  String get settingsAppResetSuccessToast => 'App reset successfully. Please restart the app.';

  @override
  String get settingsDeleteAccountDialogTitle => 'Delete account';

  @override
  String get settingsDeleteAccountDialogBody => 'We will remove your profile and community data from our servers. Your wallet remains yours, and you can still restore access with your recovery phrase.';

  @override
  String get settingsFinalConfirmationTitle => 'Final confirmation';

  @override
  String get settingsDeleteAccountFinalConfirmationBody => 'Are you absolutely sure you want to delete your account? This action cannot be undone.';

  @override
  String get settingsConfirmButton => 'Confirm';

  @override
  String get settingsDeleteAccountBackendFailedToast => 'Backend deletion failed. Please try again.';

  @override
  String get settingsAccountDeletedToast => 'Account deleted. All data has been removed.';

  @override
  String get settingsDeleteForeverButton => 'Delete forever';

  @override
  String get settingsEnableNotificationsInSystemToast => 'Enable notifications in system settings to receive alerts.';

  @override
  String get settingsLogoutDialogTitle => 'Log out';

  @override
  String get settingsLogoutDialogBody => 'Disconnect your wallet and clear your session on this device?';

  @override
  String get settingsLogoutButton => 'Log out';

  @override
  String get settingsTransactionHistoryDialogTitle => 'Transaction history';

  @override
  String get settingsRecentTransactionsTitle => 'Recent transactions';

  @override
  String get settingsNoTransactionsTitle => 'No transactions found';

  @override
  String get settingsNoTransactionsDescription => 'Your transaction history will appear here when you start making transactions.';

  @override
  String get settingsTxReceivedLabel => 'Received';

  @override
  String get settingsTxSentLabel => 'Sent';

  @override
  String get settingsTxFromLabel => 'From';

  @override
  String get settingsTxToLabel => 'To';

  @override
  String settingsTxFromToLabel(Object directionLabel, Object addressPrefix) {
    return '$directionLabel: $addressPrefix...';
  }

  @override
  String get settingsAppVersionDialogTitle => 'App version';

  @override
  String settingsVersionValue(Object version) {
    return 'Version: $version';
  }

  @override
  String settingsBuildValue(Object build) {
    return 'Build: $build';
  }

  @override
  String get settingsAllRightsReserved => 'All rights reserved.';

  @override
  String settingsCopyright(Object year) {
    return '© $year kubus';
  }

  @override
  String get settingsTermsDialogTitle => 'Terms of service';

  @override
  String get settingsTermsDialogBody => 'By using art.kubus, you agree to these terms:\n\n1. art.kubus is an open art platform and research-development prototype.\n2. You are responsible for protecting any wallet, recovery phrase, and recovery passwords you choose to use.\n3. Wallet-based actions can be final and irreversible.\n4. Discovery, community participation, and public cultural access should be used responsibly.\n5. We may update these terms over time.\n\nFor the complete terms, visit our website.';

  @override
  String get settingsPrivacyPolicyDialogTitle => 'Privacy policy';

  @override
  String get settingsPrivacyPolicyDialogBody => 'Your privacy matters to us:\n\n• We only collect personal data when it is needed and you have consented\n• Your wallet keys and recovery phrase stay under your control\n• We may collect anonymous usage statistics to improve the app\n• We do not share your data with third parties\n• You can disable analytics in Privacy settings\n\nFor our complete privacy policy, visit our website.';

  @override
  String get settingsSupportDialogTitle => 'Support';

  @override
  String get settingsSupportDialogBody => 'Need help? Choose an option:';

  @override
  String get settingsOpeningFaqToast => 'Opening FAQ…';

  @override
  String get settingsViewFaqButton => 'View FAQ';

  @override
  String get settingsOpeningEmailClientToast => 'Opening email client…';

  @override
  String get settingsContactSupportButton => 'Contact support';

  @override
  String get settingsLicensesDialogTitle => 'Open source licenses';

  @override
  String get settingsLicensesDialogBody => 'This app uses the following open source libraries:\n\n• Flutter SDK (BSD License)\n• Material Design Icons (Apache 2.0)\n• SharedPreferences (BSD License)\n• HTTP (BSD License)\n• Path Provider (BSD License)\n\nFull license texts are available in the app repository.';

  @override
  String get settingsRateAppDialogTitle => 'Rate art.kubus';

  @override
  String get settingsRateAppDialogBodyTitle => 'Enjoying the app?';

  @override
  String get settingsRateAppDialogBodySubtitle => 'Please consider rating us on the app store!';

  @override
  String get settingsMaybeLaterButton => 'Maybe later';

  @override
  String get settingsOpeningAppStoreToast => 'Opening app store…';

  @override
  String get settingsRateNowButton => 'Rate now';

  @override
  String get settingsChangePasswordDialogTitle => 'Change password';

  @override
  String get settingsCurrentPasswordLabel => 'Current password';

  @override
  String get settingsNewPasswordLabel => 'New password';

  @override
  String get settingsConfirmNewPasswordLabel => 'Confirm new password';

  @override
  String get settingsPasswordUpdatedToast => 'Password updated successfully';

  @override
  String get settingsUpdateButton => 'Update';

  @override
  String get settingsDeactivateAccountDialogTitle => 'Deactivate account';

  @override
  String get settingsDeactivateAccountDialogBodyTitle => 'Are you sure you want to deactivate your account?';

  @override
  String get settingsDeactivateAccountDialogBodySubtitle => 'You can reactivate it later by logging in.';

  @override
  String get settingsAccountDeactivatedToast => 'Account deactivated';

  @override
  String get settingsDeactivateButton => 'Deactivate';

  @override
  String get settingsProfileVisibilityDialogTitle => 'Profile visibility';

  @override
  String settingsProfileVisibilitySetToast(Object value) {
    return 'Profile visibility set to $value';
  }

  @override
  String get settingsPrivacySettingsDialogTitle => 'Privacy settings';

  @override
  String get settingsPrivacyDataCollectionTitle => 'Data collection';

  @override
  String get settingsPrivacyDataCollectionSubtitle => 'Allow app to collect usage data';

  @override
  String get settingsPrivacyPersonalizedAdsTitle => 'Personalized ads';

  @override
  String get settingsPrivacyPersonalizedAdsSubtitle => 'Show ads based on your interests';

  @override
  String get settingsPrivacyLocationTrackingTitle => 'Location tracking';

  @override
  String get settingsPrivacyLocationTrackingSubtitle => 'Allow location-based features';

  @override
  String get settingsPrivacyDataRetentionTitle => 'Data retention';

  @override
  String get settingsPrivacyDataRetentionSubtitle => 'How long to keep your data';

  @override
  String get settingsRetention3Months => '3 months';

  @override
  String get settingsRetention6Months => '6 months';

  @override
  String get settingsRetention1Year => '1 year';

  @override
  String get settingsRetention2Years => '2 years';

  @override
  String get settingsRetentionIndefinite => 'Indefinite';

  @override
  String get settingsPrivacySettingsUpdatedToast => 'Privacy settings updated';

  @override
  String get settingsSecuritySettingsDialogTitle => 'Security settings';

  @override
  String get settingsChangePasswordTileTitle => 'Change password';

  @override
  String get settingsChangePasswordTileSubtitle => 'Update your account password';

  @override
  String get settingsTwoFactorTitle => 'Two-factor authentication';

  @override
  String get settingsTwoFactorSubtitle => 'Add extra security to your account';

  @override
  String get settingsSessionTimeoutTitle => 'Session timeout';

  @override
  String get settingsSessionTimeoutSubtitle => 'Automatically sign out when idle';

  @override
  String get settingsAutoLockTimeTitle => 'Auto-lock time';

  @override
  String get settingsAutoLockTimeSubtitle => 'Lock app after inactivity';

  @override
  String get settingsLoginNotificationsTitle => 'Login notifications';

  @override
  String get settingsLoginNotificationsSubtitle => 'Get notified of new sign-ins';

  @override
  String get settingsSecuritySettingsUpdatedToast => 'Security settings updated';

  @override
  String get settingsAccountManagementDialogTitle => 'Account management';

  @override
  String get settingsEmailNotificationsTitle => 'Email notifications';

  @override
  String get settingsEmailNotificationsSubtitle => 'Receive updates via email';

  @override
  String get settingsPushNotificationsTitle => 'Push notifications';

  @override
  String get settingsPushNotificationsSubtitle => 'Get notifications on your device';

  @override
  String get settingsMarketingEmailsTitle => 'Marketing emails';

  @override
  String get settingsMarketingEmailsSubtitle => 'Receive promotional content';

  @override
  String get settingsEmailPreferencesSectionTitle => 'Email preferences';

  @override
  String get settingsEmailPreferencesTransactionalNote => 'Critical account and wallet security emails are always enabled.';

  @override
  String get settingsEmailPreferencesProductUpdatesTitle => 'Product updates';

  @override
  String get settingsEmailPreferencesProductUpdatesSubtitle => 'Occasional announcements about new features';

  @override
  String get settingsEmailPreferencesNewsletterTitle => 'Newsletter';

  @override
  String get settingsEmailPreferencesNewsletterSubtitle => 'News and highlights from art.kubus';

  @override
  String get settingsEmailPreferencesCommunityDigestTitle => 'Community digest';

  @override
  String get settingsEmailPreferencesCommunityDigestSubtitle => 'Periodic summary of community activity';

  @override
  String get settingsEmailPreferencesActivityArtTitle => 'Artwork activity';

  @override
  String get settingsEmailPreferencesActivityArtSubtitle => 'Updates about your artworks, collections, and related activity';

  @override
  String get settingsEmailPreferencesActivityCommunityTitle => 'Community activity';

  @override
  String get settingsEmailPreferencesActivityCommunitySubtitle => 'Replies, mentions, and updates from community spaces';

  @override
  String get settingsEmailPreferencesActivityDaoTitle => 'Governance activity';

  @override
  String get settingsEmailPreferencesActivityDaoSubtitle => 'Updates about governance review, proposals, and community participation';

  @override
  String get settingsEmailPreferencesActivityArtistHubTitle => 'Artist Hub activity';

  @override
  String get settingsEmailPreferencesActivityArtistHubSubtitle => 'Updates from Artist Hub features and workflows';

  @override
  String get settingsEmailPreferencesActivityInstitutionHubTitle => 'Institution Hub activity';

  @override
  String get settingsEmailPreferencesActivityInstitutionHubSubtitle => 'Updates from Institution Hub features and collaborations';

  @override
  String get settingsEmailPreferencesActivityPromotionTitle => 'Promotion activity';

  @override
  String get settingsEmailPreferencesActivityPromotionSubtitle => 'Status changes and lifecycle updates for your promotions';

  @override
  String get settingsEmailPreferencesSecurityAlertsTitle => 'Security alerts';

  @override
  String get settingsEmailPreferencesSecurityAlertsSubtitle => 'Important account security notifications';

  @override
  String get settingsEmailPreferencesCriticalAccountSecurityTitle => 'Critical account security';

  @override
  String get settingsEmailPreferencesCriticalAccountSecuritySubtitle => 'Account security alerts and suspicious activity notices (always on)';

  @override
  String get settingsEmailPreferencesCriticalWalletSecurityTitle => 'Critical wallet security';

  @override
  String get settingsEmailPreferencesCriticalWalletSecuritySubtitle => 'Wallet and custody security alerts (always on)';

  @override
  String get settingsEmailPreferencesTransactionalTitle => 'Account emails';

  @override
  String get settingsEmailPreferencesTransactionalSubtitle => 'Transactional emails (verification, reset, and recovery) are always enabled';

  @override
  String get settingsEmailPreferencesUpdateFailedToast => 'Could not update email preferences. Please try again.';

  @override
  String get settingsInAppNotificationsMasterTitle => 'All app notifications';

  @override
  String get settingsInAppNotificationsMasterSubtitle => 'Master switch for in-app and push notification categories.';

  @override
  String get settingsInAppNotificationsArtTitle => 'Art notifications';

  @override
  String get settingsInAppNotificationsArtSubtitle => 'In-app notifications for artwork activity and achievements.';

  @override
  String get settingsInAppNotificationsCommunityTitle => 'Community notifications';

  @override
  String get settingsInAppNotificationsCommunitySubtitle => 'In-app notifications for comments, likes, follows, and shares.';

  @override
  String get settingsInAppNotificationsDaoTitle => 'Governance notifications';

  @override
  String get settingsInAppNotificationsDaoSubtitle => 'In-app notifications for governance review and platform decisions.';

  @override
  String get settingsInAppNotificationsArtistHubTitle => 'Artist hub notifications';

  @override
  String get settingsInAppNotificationsArtistHubSubtitle => 'In-app notifications for artist workflow and studio updates.';

  @override
  String get settingsInAppNotificationsInstitutionHubTitle => 'Institution hub notifications';

  @override
  String get settingsInAppNotificationsInstitutionHubSubtitle => 'In-app notifications for institution workflow and review updates.';

  @override
  String get settingsInAppNotificationsAccountTitle => 'Account notifications';

  @override
  String get settingsInAppNotificationsAccountSubtitle => 'In-app notifications for security, access, and account updates.';

  @override
  String get settingsInAppNotificationsPromotionTitle => 'Promotion notifications';

  @override
  String get settingsInAppNotificationsPromotionSubtitle => 'In-app notifications for promotion outcomes and upcoming campaign milestones.';

  @override
  String get settingsAccountTypeTitle => 'Account type';

  @override
  String get settingsAccountTypeSubtitle => 'Your current membership level';

  @override
  String get settingsAccountTypeStandard => 'Standard';

  @override
  String get settingsAccountTypePremium => 'Premium';

  @override
  String get settingsAccountTypeEnterprise => 'Enterprise';

  @override
  String get settingsPublicProfileTitle => 'Public profile';

  @override
  String get settingsPublicProfileSubtitle => 'Allow others to find your profile';

  @override
  String get settingsProfilePrivacySectionTitle => 'Profile privacy';

  @override
  String get settingsPrivateProfileTitle => 'Private profile';

  @override
  String get settingsPrivateProfileSubtitle => 'Only approved followers can see your posts';

  @override
  String get settingsShowActivityStatusTitle => 'Show activity status';

  @override
  String get settingsShowActivityStatusSubtitle => 'Let others see when you\'re online';

  @override
  String get settingsShareLastVisitedLocationTitle => 'Share last visited location';

  @override
  String get settingsShareLastVisitedLocationSubtitle => 'Let others see what you last visited';

  @override
  String get settingsShowCollectionTitle => 'Show cultural artifacts';

  @override
  String get settingsShowCollectionSubtitle => 'Show your digital cultural artifacts publicly on your profile';

  @override
  String get settingsAllowMessagesTitle => 'Allow messages';

  @override
  String get settingsAllowMessagesSubtitle => 'Receive direct messages from others';

  @override
  String get settingsDeactivateAccountTileTitle => 'Deactivate account';

  @override
  String get settingsDeactivateAccountTileSubtitle => 'Temporarily disable your account';

  @override
  String get settingsAccountSettingsUpdatedToast => 'Account settings updated';

  @override
  String commonStepOfTotal(Object current, Object total) {
    return '$current of $total';
  }

  @override
  String get web3OnboardingKeyFeaturesTitle => 'Platform tools:';

  @override
  String get web3FeatureWeb3Title => 'Wallet and archive tools';

  @override
  String get web3FeatureMarketplaceTitle => 'Digital editions';

  @override
  String get web3FeatureArtistStudioTitle => 'Artist studio';

  @override
  String get web3FeatureInstitutionHubTitle => 'Institution hub';

  @override
  String get web3FeatureGovernanceTitle => 'Community governance';

  @override
  String get web3DaoP1Title => 'Community governance';

  @override
  String get web3DaoP1Description => 'Take part in experimental community decision-making that helps shape art.kubus. It is participation infrastructure, not a financial product.';

  @override
  String get web3DaoP1Feature1 => 'Review community proposals';

  @override
  String get web3DaoP1Feature2 => 'Submit ideas with context';

  @override
  String get web3DaoP1Feature3 => 'Receive recognition for participation';

  @override
  String get web3DaoP1Feature4 => 'Discuss and collaborate with others';

  @override
  String get web3DaoP2Title => 'Participation signals';

  @override
  String get web3DaoP2Description => 'Participation signals can reflect Season 0 recognition. They acknowledge contribution and visibility, not financial value.';

  @override
  String get web3DaoP2Feature1 => 'Signals can follow KUB8 recognition';

  @override
  String get web3DaoP2Feature2 => 'Participate in active proposals';

  @override
  String get web3DaoP2Feature3 => 'See results as they update';

  @override
  String get web3DaoP2Feature4 => 'Track your participation history';

  @override
  String get web3DaoP3Title => 'Submit community proposals';

  @override
  String get web3DaoP3Description => 'Have an idea for the platform or community? Submit a proposal with clear context, goals, and impact.';

  @override
  String get web3DaoP3Feature1 => 'Write clear proposals with context';

  @override
  String get web3DaoP3Feature2 => 'Choose voting duration and requirements';

  @override
  String get web3DaoP3Feature3 => 'Gather community support';

  @override
  String get web3DaoP3Feature4 => 'Follow status and discussion';

  @override
  String get web3DaoP4Title => 'Ready to contribute';

  @override
  String get web3DaoP4Description => 'Review proposals, follow the discussion, and participate when you are ready.';

  @override
  String get web3DaoP4Feature1 => 'Browse and vote on proposals';

  @override
  String get web3DaoP4Feature2 => 'Review your voting history';

  @override
  String get web3DaoP4Feature3 => 'See governance activity';

  @override
  String get web3DaoP4Feature4 => 'Collaborate with the community';

  @override
  String get web3ArtistStudioP1Title => 'Welcome to artist studio';

  @override
  String get web3ArtistStudioP1Description => 'Your workspace for managing artworks, creating AR markers, and tracking your progress.';

  @override
  String get web3ArtistStudioP1Feature1 => 'Manage your artwork collection';

  @override
  String get web3ArtistStudioP1Feature2 => 'Create interactive AR markers';

  @override
  String get web3ArtistStudioP1Feature3 => 'Track performance insights';

  @override
  String get web3ArtistStudioP1Feature4 => 'Showcase and share with the community';

  @override
  String get web3ArtistStudioP2Title => 'Artwork gallery';

  @override
  String get web3ArtistStudioP2Description => 'Present artworks and digital cultural artifacts. Upload, organize, and describe your practice.';

  @override
  String get web3ArtistStudioP2Feature1 => 'Upload and organize artworks';

  @override
  String get web3ArtistStudioP2Feature2 => 'Add titles and descriptions';

  @override
  String get web3ArtistStudioP2Feature3 => 'Choose visibility and availability';

  @override
  String get web3ArtistStudioP2Feature4 => 'Track views and engagement';

  @override
  String get web3ArtistStudioP3Title => 'AR marker creator';

  @override
  String get web3ArtistStudioP3Description => 'Turn artworks into AR experiences. Place markers in real-world locations for others to discover.';

  @override
  String get web3ArtistStudioP3Feature1 => 'Create geo-located markers';

  @override
  String get web3ArtistStudioP3Feature2 => 'Attach artworks to places';

  @override
  String get web3ArtistStudioP3Feature3 => 'Add recognition for discoveries';

  @override
  String get web3ArtistStudioP3Feature4 => 'Monitor marker interactions';

  @override
  String get web3ArtistStudioP4Title => 'Insights dashboard';

  @override
  String get web3ArtistStudioP4Description => 'Track performance with insights on views, discoveries, and community engagement.';

  @override
  String get web3ArtistStudioP4Feature1 => 'Monitor artwork performance';

  @override
  String get web3ArtistStudioP4Feature2 => 'Track contribution recognition';

  @override
  String get web3ArtistStudioP4Feature3 => 'See discovery patterns';

  @override
  String get web3ArtistStudioP4Feature4 => 'Export reports';

  @override
  String get web3ArtistStudioP5Title => 'Start creating';

  @override
  String get web3ArtistStudioP5Description => 'Your studio is ready. Upload your first artwork or create an AR marker to share with the community.';

  @override
  String get web3ArtistStudioP5Feature1 => 'Upload your first artwork';

  @override
  String get web3ArtistStudioP5Feature2 => 'Create your first AR marker';

  @override
  String get web3ArtistStudioP5Feature3 => 'Explore community creations';

  @override
  String get web3ArtistStudioP5Feature4 => 'Build contribution recognition';

  @override
  String get web3InstitutionHubP1Title => 'Welcome to institution hub';

  @override
  String get web3InstitutionHubP1Description => 'Manage events, exhibitions, and educational programs. Connect your institution with the art community.';

  @override
  String get web3InstitutionHubP1Feature1 => 'Create and manage events';

  @override
  String get web3InstitutionHubP1Feature2 => 'Host exhibitions';

  @override
  String get web3InstitutionHubP1Feature3 => 'Engage with the community';

  @override
  String get web3InstitutionHubP1Feature4 => 'Track reach and engagement';

  @override
  String get web3InstitutionHubP2Title => 'Event management';

  @override
  String get web3InstitutionHubP2Description => 'Organize exhibitions, workshops, and events. Manage scheduling, registrations, and updates.';

  @override
  String get web3InstitutionHubP2Feature1 => 'Schedule exhibitions and workshops';

  @override
  String get web3InstitutionHubP2Feature2 => 'Manage registrations';

  @override
  String get web3InstitutionHubP2Feature3 => 'Send updates to attendees';

  @override
  String get web3InstitutionHubP2Feature4 => 'Track attendance and engagement';

  @override
  String get web3InstitutionHubP3Title => 'Event creation tools';

  @override
  String get web3InstitutionHubP3Description => 'Create event pages with rich descriptions and media to help people join.';

  @override
  String get web3InstitutionHubP3Feature1 => 'Design event pages with media';

  @override
  String get web3InstitutionHubP3Feature2 => 'Set capacity and registration';

  @override
  String get web3InstitutionHubP3Feature3 => 'Create promotional materials';

  @override
  String get web3InstitutionHubP3Feature4 => 'Integrate with calendars';

  @override
  String get web3InstitutionHubP4Title => 'Analytics & insights';

  @override
  String get web3InstitutionHubP4Description => 'Measure success with insights on attendance, engagement, and community impact.';

  @override
  String get web3InstitutionHubP4Feature1 => 'Track attendance and engagement';

  @override
  String get web3InstitutionHubP4Feature2 => 'Monitor community interest';

  @override
  String get web3InstitutionHubP4Feature3 => 'Analyze participant feedback';

  @override
  String get web3InstitutionHubP4Feature4 => 'Export reports';

  @override
  String get web3InstitutionHubP5Title => 'Launch your events';

  @override
  String get web3InstitutionHubP5Description => 'Ready to connect with the art community? Create your first event or explore ongoing exhibitions.';

  @override
  String get web3InstitutionHubP5Feature1 => 'Create your first event';

  @override
  String get web3InstitutionHubP5Feature2 => 'Explore community events';

  @override
  String get web3InstitutionHubP5Feature3 => 'Connect with other institutions';

  @override
  String get web3InstitutionHubP5Feature4 => 'Build your cultural network';

  @override
  String get institutionHubHelpTooltip => 'Help';

  @override
  String get institutionHubInvitesTooltip => 'Invites';

  @override
  String get institutionHubTabExhibitions => 'Exhibitions';

  @override
  String get institutionHubTabCreate => 'Create';

  @override
  String get institutionHubTabAnalytics => 'Analytics';

  @override
  String get institutionHubSeparateWalletsTip => 'Tip: Use separate wallets for artist and institution roles to keep governance review contexts clear.';

  @override
  String get institutionHubApplyForReviewAction => 'Apply for review';

  @override
  String get institutionHubArtistBadgeActiveTitle => 'Artist badge active';

  @override
  String get institutionHubArtistBadgeActiveDescription => 'Artist wallets unlock creation tooling. Institution flows need a dedicated wallet without creator approvals.';

  @override
  String get institutionHubArtistReviewInProgressTitle => 'Artist review in progress';

  @override
  String get institutionHubArtistReviewInProgressDescription => 'You have an active artist application. Wait for that decision or reset it before continuing as an institution.';

  @override
  String get institutionHubApplicationTitle => 'Institution application';

  @override
  String get institutionHubApplicationSubtitle => 'Share your mission, programming focus, and how you plan to collaborate with the community.';

  @override
  String get institutionHubApplicationOrganizationLabel => 'Organization name';

  @override
  String get institutionHubApplicationContactLabel => 'Website or contact email';

  @override
  String get institutionHubApplicationFocusLabel => 'Curation focus';

  @override
  String get institutionHubApplicationMissionLabel => 'Mission and goals';

  @override
  String get institutionHubApplicationOrganizationRequired => 'Please provide your organization name.';

  @override
  String get institutionHubApplicationContactRequired => 'Share a website or contact email.';

  @override
  String get institutionHubApplicationFocusRequired => 'Let us know your programming focus.';

  @override
  String get institutionHubApplicationMissionRequired => 'Describe your mission in at least 20 characters.';

  @override
  String get institutionHubApplicationWalletRequired => 'Connect a wallet before submitting.';

  @override
  String get institutionHubApplicationSubmittedToast => 'Application submitted for governance review.';

  @override
  String get institutionHubApplicationSubmitUnavailableToast => 'Unable to submit application right now.';

  @override
  String institutionHubApplicationSubmitFailedToast(Object error) {
    return 'Submission failed: $error';
  }

  @override
  String get institutionHubApplicationSubmitButton => 'Submit application';

  @override
  String get institutionHubCrossRoleConflictTitle => 'Role conflict detected';

  @override
  String get institutionHubArtistWalletSwitchDescription => 'Artist wallets are optimized for creation tooling. Switch to a dedicated institutional wallet before applying for curation tools.';

  @override
  String get institutionHubArtistReviewPendingResetDescription => 'You currently have an artist application pending. Finish that review or request a reset prior to submitting an institution application.';

  @override
  String get institutionHubArtistSubmissionConflictDescription => 'We detected an artist submission for this wallet. Clear it from settings before continuing as an institution.';

  @override
  String get institutionHubApplicationCardSubtitle => 'Submit your organization for governance review and unlock institutional tooling.';

  @override
  String get institutionHubDaoStatusApproved => 'APPROVED';

  @override
  String get institutionHubDaoStatusPending => 'PENDING';

  @override
  String get institutionHubDaoStatusRejected => 'REJECTED';

  @override
  String get institutionHubDaoStatusInReview => 'IN REVIEW';

  @override
  String get institutionHubDaoStatusNotApplied => 'NOT APPLIED';

  @override
  String get institutionHubCtaApprovedByDao => 'Approved by governance review';

  @override
  String get institutionHubCtaPendingDaoReview => 'Pending governance review';

  @override
  String get institutionHubCtaConnectWalletToApply => 'Connect wallet to apply';

  @override
  String get institutionHubDaoStatusSyncedLabel => 'Status synced from governance review';

  @override
  String get institutionHubDaoReviewQueueMessage => 'Your submission is in the governance review queue.';

  @override
  String get institutionHubApprovedToolsMessage => 'Congratulations! Approved for institution tools.';

  @override
  String get institutionHubRejectedResubmitMessage => 'Your last submission was rejected. You can resubmit with updates.';

  @override
  String get web3MarketplaceP1Title => 'Digital cultural artifacts';

  @override
  String get web3MarketplaceP1Description => 'Archive records and digital editions connect artworks with provenance, visits and cultural memory.';

  @override
  String get web3MarketplaceP1Feature1 => 'Browse cultural artifacts';

  @override
  String get web3MarketplaceP1Feature2 => 'See artist and artwork context';

  @override
  String get web3MarketplaceP1Feature3 => 'Understand provenance';

  @override
  String get web3MarketplaceP1Feature4 => 'Keep ownership tools clear';

  @override
  String get web3MarketplaceP2Title => 'Discover with context';

  @override
  String get web3MarketplaceP2Description => 'Explore artifacts through artists, institutions, exhibitions, and public-space stories instead of trading hype.';

  @override
  String get web3MarketplaceP2Feature1 => 'Filter by category and rarity';

  @override
  String get web3MarketplaceP2Feature2 => 'View detailed artwork info';

  @override
  String get web3MarketplaceP2Feature3 => 'Check provenance and authenticity';

  @override
  String get web3MarketplaceP2Feature4 => 'Save favorites to a wishlist';

  @override
  String get web3MarketplaceP3Title => 'Support artists carefully';

  @override
  String get web3MarketplaceP3Description => 'When enabled, offers and listings support artist projects and cultural archiving. They are not the core app experience.';

  @override
  String get web3MarketplaceP3Feature1 => 'Upload your digital artwork';

  @override
  String get web3MarketplaceP3Feature2 => 'Add descriptions and tags';

  @override
  String get web3MarketplaceP3Feature3 => 'Set price and availability';

  @override
  String get web3MarketplaceP3Feature4 => 'Track interest and activity';

  @override
  String get web3MarketplaceP4Title => 'Digital editions';

  @override
  String get web3MarketplaceP4Description => 'Collecting is a supporting layer. You can use art.kubus for discovery, community, and cultural access without collecting.';

  @override
  String get web3MarketplaceP4Feature1 => 'Explore featured collections';

  @override
  String get web3MarketplaceP4Feature2 => 'Make your first purchase';

  @override
  String get web3MarketplaceP4Feature3 => 'List an item for sale';

  @override
  String get web3MarketplaceP4Feature4 => 'Join the art community';

  @override
  String get web3FeaturesP1Title => 'Wallet account';

  @override
  String get web3FeaturesP1Description => 'A wallet can support long-term access, attribution, digital ownership, and future participation. Basic discovery and community do not start with Wallet.';

  @override
  String get web3FeaturesP1Feature1 => 'Long-term account continuity';

  @override
  String get web3FeaturesP1Feature2 => 'Digital editions, visit proofs, and future rights research';

  @override
  String get web3FeaturesP1Feature3 => 'Keys stay with you';

  @override
  String get web3FeaturesP1Feature4 => 'Access you can restore and move';

  @override
  String get web3FeaturesP2Title => 'Digital edition catalog';

  @override
  String get web3FeaturesP2Description => 'Browse digital cultural artifacts connected to artists, artworks, institutions, and provenance.';

  @override
  String get web3FeaturesP2Feature1 => 'Browse featured cultural artifacts';

  @override
  String get web3FeaturesP2Feature2 => 'Search by artist, artwork, or context';

  @override
  String get web3FeaturesP2Feature3 => 'View details and provenance';

  @override
  String get web3FeaturesP2Feature4 => 'Support artists when enabled';

  @override
  String get web3FeaturesP2Feature5 => 'Save favorites for later';

  @override
  String get web3FeaturesP3Title => 'Artist studio';

  @override
  String get web3FeaturesP3Description => 'Create and manage artworks, build your portfolio, and publish digital editions when a project calls for them.';

  @override
  String get web3FeaturesP3Feature1 => 'Upload and organize artworks';

  @override
  String get web3FeaturesP3Feature2 => 'Create AR markers';

  @override
  String get web3FeaturesP3Feature3 => 'Publish digital editions';

  @override
  String get web3FeaturesP3Feature4 => 'Track discovery and response';

  @override
  String get web3FeaturesP3Feature5 => 'Collaborate with other creators';

  @override
  String get web3FeaturesP4Title => 'Future community governance';

  @override
  String get web3FeaturesP4Description => 'Governance is developing as a transparent way for the community to help shape platform priorities. It is not required for discovery.';

  @override
  String get web3FeaturesP4Feature1 => 'Review proposals';

  @override
  String get web3FeaturesP4Feature2 => 'Submit suggestions with context';

  @override
  String get web3FeaturesP4Feature3 => 'Receive recognition for participation';

  @override
  String get web3FeaturesP4Feature4 => 'Follow discussions and outcomes';

  @override
  String get web3FeaturesP4Feature5 => 'Help shape community guidelines';

  @override
  String get web3FeaturesP5Title => 'Institution hub';

  @override
  String get web3FeaturesP5Description => 'Work with galleries and cultural institutions on events, exhibitions, and longer-term programs.';

  @override
  String get web3FeaturesP5Feature1 => 'Partner with verified institutions';

  @override
  String get web3FeaturesP5Feature2 => 'Host events and exhibitions';

  @override
  String get web3FeaturesP5Feature3 => 'Curate collections together';

  @override
  String get web3FeaturesP5Feature4 => 'Professional networking tools';

  @override
  String get web3FeaturesP5Feature5 => 'Tools built for institutions';

  @override
  String get web3FeaturesP6Title => 'Contribution recognition';

  @override
  String get web3FeaturesP6Description => 'KUB8 records Season 0 participation and recognition. They are not money, not a tradable asset, and not a live payment promise.';

  @override
  String get web3FeaturesP6Feature1 => 'Record participation and discoveries';

  @override
  String get web3FeaturesP6Feature2 => 'Track contribution progress over the season';

  @override
  String get web3FeaturesP6Feature3 => 'Unlock badges and community recognition';

  @override
  String get web3FeaturesP6Feature4 => 'Recognition comes through access and visibility';

  @override
  String get web3FeaturesP6Feature5 => 'Non-transferable participation records';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonView => 'View';

  @override
  String get commonViewDetails => 'View details';

  @override
  String get commonContinueExploring => 'Continue exploring';

  @override
  String commonByArtist(Object artist) {
    return 'by $artist';
  }

  @override
  String commonKub8PointsReward(Object points) {
    return '+$points KUB8 recognition';
  }

  @override
  String commonDistanceKm(Object value) {
    return '$value km';
  }

  @override
  String commonDistanceM(Object value) {
    return '$value m';
  }

  @override
  String commonPercentComplete(Object percent) {
    return '$percent% complete';
  }

  @override
  String get commonCollapse => 'Collapse';

  @override
  String get commonExpand => 'Expand';

  @override
  String get detailShowMore => 'Show more';

  @override
  String get detailShowLess => 'Show less';

  @override
  String get mapNearbyRadiusTitle => 'Nearby radius';

  @override
  String mapNearbyRadiusTooltip(Object radiusKm) {
    return 'Nearby radius ($radiusKm km)';
  }

  @override
  String get mapNearbyRadiusTooltipWorld => 'Nearby radius (World)';

  @override
  String get mapNearbyRadiusWorldShort => 'Radius: World';

  @override
  String get mapTravelModeStatusTravelling => 'You are travelling';

  @override
  String get mapTravelModeStatusTravellingTooltip => 'Travel mode is on - showing markers in view';

  @override
  String get mapArArtworkNearbyTitle => 'Artwork nearby';

  @override
  String mapArArtworkNearbySubtitle(Object name, Object distanceMeters) {
    return '$name · ${distanceMeters}m away';
  }

  @override
  String get mapFailedToLaunchAr => 'Failed to launch AR.';

  @override
  String get mapMarkerCreatedToast => 'Marker created successfully!';

  @override
  String get mapMarkerCreateFailedToast => 'Failed to create marker. Please try again.';

  @override
  String get mapLocationUnavailableToast => 'Unable to determine your location.';

  @override
  String get mapMarkerCreateWalletRequired => 'Create a profile and Wallet access before placing a marker tied to your own artwork.';

  @override
  String get mapMarkerCreateNoArArtworks => 'No map-ready artworks are linked to this account yet. Create an artwork first, then place it on the open art map.';

  @override
  String get mapMarkerDialogTitle => 'Add to open art map';

  @override
  String get mapMarkerDialogRefreshSubjectsTooltip => 'Refresh subjects';

  @override
  String get mapMarkerDialogAttachHint => 'Attach an existing artwork, institution, exhibition, or AR asset to this location.';

  @override
  String get mapMarkerDialogSubjectTypeLabel => 'Subject type';

  @override
  String mapMarkerDialogSubjectRequiredLabel(Object subject) {
    return '$subject *';
  }

  @override
  String mapMarkerDialogMarkerForTitle(Object title) {
    return 'Marker for $title';
  }

  @override
  String mapMarkerDialogNoSubjectsAvailable(Object subjectType) {
    return 'No $subjectType available. Create one first.';
  }

  @override
  String get mapMarkerDialogMiscHint => 'Misc markers do not need a linked subject. Provide a custom title and description below.';

  @override
  String get mapMarkerDialogLinkedArAssetTitle => 'Linked AR asset';

  @override
  String get mapMarkerDialogNoArEnabledArtworksHint => 'No AR-enabled artworks available. Create one first.';

  @override
  String get mapMarkerDialogMarkerTitleLabel => 'Marker title *';

  @override
  String get mapMarkerDialogDescriptionLabel => 'Description *';

  @override
  String get mapMarkerDialogCategoryLabel => 'Category';

  @override
  String get mapMarkerDialogMarkerLayerLabel => 'Marker layer';

  @override
  String get mapMarkerDialogPublicMarkerTitle => 'Public cultural marker';

  @override
  String get mapMarkerDialogPublicMarkerSubtitle => 'Visible to all explorers on the map';

  @override
  String get mapMarkerDialogLatitudeLabel => 'Latitude *';

  @override
  String get mapMarkerDialogLongitudeLabel => 'Longitude *';

  @override
  String get mapMarkerDialogUseMapCenterButton => 'Use map center';

  @override
  String get mapMarkerDialogCreateButton => 'Create marker';

  @override
  String get mapMarkerDialogSelectSubjectToast => 'Select a subject to continue';

  @override
  String get mapMarkerDialogSelectArArtworkToast => 'Select an AR-enabled artwork to link';

  @override
  String get mapMarkerDialogEnterTitleError => 'Please enter a title';

  @override
  String mapMarkerDialogTitleMinLengthError(Object min) {
    return 'Title must be at least $min characters';
  }

  @override
  String get mapMarkerDialogEnterDescriptionError => 'Please enter a description';

  @override
  String mapMarkerDialogDescriptionMinLengthError(Object min) {
    return 'Description must be at least $min characters';
  }

  @override
  String get mapMarkerDialogValidLatitudeError => 'Enter a valid latitude';

  @override
  String get mapMarkerDialogValidLongitudeError => 'Enter a valid longitude';

  @override
  String get mapMarkerDialogStreetArtHint => 'Street art markers do not need a linked subject. Add a title and description for the public artwork you found.';

  @override
  String get mapMarkerDialogCoverImageTitle => 'Cover image *';

  @override
  String get mapMarkerDialogUploadCover => 'Upload cover';

  @override
  String get mapMarkerDialogChangeCover => 'Change cover';

  @override
  String get mapMarkerDialogRemoveCoverTooltip => 'Remove cover';

  @override
  String get mapMarkerDialogStreetArtCoverRequiredHint => 'Street art markers require a cover image.';

  @override
  String get mapMarkerDialogStreetArtCoverRequiredError => 'Add a cover image for this street art marker.';

  @override
  String get mapMarkerCommunityLabel => 'Community';

  @override
  String get mapMarkerClaimButton => 'Claim';

  @override
  String get mapMarkerClaimsDialogTitle => 'Public art ownership requests';

  @override
  String get mapMarkerClaimSubmitTitle => 'Submit request';

  @override
  String get mapMarkerClaimReasonLabel => 'Reason *';

  @override
  String get mapMarkerClaimEvidenceUrlLabel => 'Evidence URL (optional)';

  @override
  String get mapMarkerClaimProfileNameLabel => 'Profile name (optional)';

  @override
  String get mapMarkerClaimSubmitButton => 'Submit request';

  @override
  String get mapMarkerClaimLoading => 'Loading requests...';

  @override
  String get mapMarkerClaimNoClaims => 'No requests yet.';

  @override
  String get mapMarkerClaimOwnerReviewActionsTitle => 'Owner review';

  @override
  String get mapMarkerClaimDaoReviewActionsTitle => 'Governance review';

  @override
  String get mapMarkerClaimActionApprove => 'Approve';

  @override
  String get mapMarkerClaimActionReject => 'Reject';

  @override
  String get mapMarkerClaimActionEscalate => 'Escalate to governance review';

  @override
  String get mapMarkerClaimActionApproveDao => 'Approve (community)';

  @override
  String get mapMarkerClaimActionRejectDao => 'Reject (community)';

  @override
  String get mapMarkerClaimNoteLabel => 'Note (optional)';

  @override
  String get mapMarkerClaimSubmittedToast => 'Street art ownership request submitted.';

  @override
  String get mapMarkerClaimActionSuccessToast => 'Claim updated.';

  @override
  String get mapMarkerClaimNotEligibleToast => 'Only verified artists can submit ownership requests.';

  @override
  String get mapMarkerClaimAlreadyActiveToast => 'You already have an active request for this marker.';

  @override
  String mapMarkerClaimReasonMinError(Object min) {
    return 'Reason must be at least $min characters';
  }

  @override
  String get mapMarkerClaimStatusPendingOwnerReview => 'Pending owner review';

  @override
  String get mapMarkerClaimStatusPendingDaoReview => 'Pending governance review';

  @override
  String get mapMarkerClaimStatusApproved => 'Approved';

  @override
  String get mapMarkerClaimStatusRejectedOwner => 'Rejected by owner';

  @override
  String get mapMarkerClaimStatusRejectedDao => 'Rejected by governance review';

  @override
  String get mapMarkerClaimStageOwnerReview => 'Owner review';

  @override
  String get mapMarkerClaimStageDaoReview => 'Governance review';

  @override
  String get mapMarkerClaimStageResolved => 'Resolved';

  @override
  String get mapMarkerSubjectTypeArtwork => 'Artwork';

  @override
  String get mapMarkerSubjectTypeStreetArt => 'Street Art';

  @override
  String get mapMarkerSubjectTypeExhibition => 'Exhibition';

  @override
  String get mapMarkerSubjectTypeInstitution => 'Institution';

  @override
  String get mapMarkerSubjectTypeEvent => 'Event';

  @override
  String get mapMarkerSubjectTypeGroup => 'Group';

  @override
  String get mapMarkerSubjectTypeMisc => 'Misc';

  @override
  String get mapMarkerLayerArtwork => 'Artwork';

  @override
  String get mapMarkerLayerStreetArt => 'Street Art';

  @override
  String get mapMarkerLayerInstitution => 'Institution';

  @override
  String get mapMarkerLayerEvent => 'Event';

  @override
  String get mapMarkerLayerResidency => 'Residency';

  @override
  String get mapMarkerLayerDropReward => 'Drop/Reward';

  @override
  String get mapMarkerLayerArExperience => 'AR experience';

  @override
  String get mapMarkerLayerOther => 'Other';

  @override
  String get mapArtDiscoveredTitle => 'Artwork discovered';

  @override
  String get desktopMapTitleDiscover => 'Discover';

  @override
  String get mapSearchHint => 'Search artworks, artists, institutions…';

  @override
  String get mapClearSearchTooltip => 'Clear search';

  @override
  String get mapHideFiltersTooltip => 'Hide filters';

  @override
  String get mapShowFiltersTooltip => 'Show filters';

  @override
  String get mapSearchMinCharsHint => 'Type at least 2 characters to search';

  @override
  String get mapNoSuggestions => 'No suggestions';

  @override
  String get commonNoResultsFound => 'No results found';

  @override
  String get mapFiltersTitle => 'Filters';

  @override
  String get mapFilterAll => 'All';

  @override
  String get mapFilterNearby => 'Nearby';

  @override
  String get mapFilterAllNearby => 'All nearby';

  @override
  String get mapFilterWithin1Km => 'Within 1 km';

  @override
  String get mapFilterDiscovered => 'Discovered';

  @override
  String get mapFilterUndiscovered => 'Undiscovered';

  @override
  String get mapFilterArEnabled => 'AR ready';

  @override
  String get mapFilterFavorites => 'Favorites';

  @override
  String get mapLayersTitle => 'Map layers';

  @override
  String get mapDiscoveryPathTitle => 'Discovery path';

  @override
  String get mapDiscoveryPathIdleSubtitle => 'Explore nearby art';

  @override
  String get mapDiscoveryPathIdleHint => 'Start a route from the map';

  @override
  String get mapShowListViewTooltip => 'Show list view';

  @override
  String get mapShowGridViewTooltip => 'Show grid view';

  @override
  String get mapSortResultsTooltip => 'Sort results';

  @override
  String get mapCenterOnMeTooltip => 'Center on me';

  @override
  String get mapAddMapMarkerTooltip => 'Add map marker';

  @override
  String get mapTravelModeTooltip => 'Travel mode';

  @override
  String get mapTravelModeEnableTooltip => 'Enable travel mode';

  @override
  String get mapTravelModeDisableTooltip => 'Disable travel mode';

  @override
  String get mapIsometricViewEnableTooltip => 'Enable isometric view';

  @override
  String get mapIsometricViewDisableTooltip => 'Disable isometric view';

  @override
  String get mapResetBearingTooltip => 'Point north';

  @override
  String get mapExhibitionsUnavailableToast => 'Exhibitions are currently unavailable.';

  @override
  String get mapTutorialStepMapTitle => 'Open art map';

  @override
  String get mapTutorialStepMapBody => 'Discover public-space art, exhibitions, institutions, and artist stories on a community-generated cultural map.';

  @override
  String get mapTutorialStepMarkersTitle => 'Cultural markers';

  @override
  String get mapTutorialStepMarkersBody => 'Markers can represent artworks, exhibitions, events, institutions, and more. Colors/icons help you spot what\'s what.';

  @override
  String get mapTutorialStepCreateMarkerTitle => 'Add a marker';

  @override
  String get mapTutorialStepCreateMarkerBody => 'Tap this to add a marker at the current location (or the last long-press point).';

  @override
  String get mapTutorialStepNearbyTitle => 'Nearby art and places';

  @override
  String get mapTutorialStepNearbyBody => 'Browse artworks near you. The list updates as you move and as filters change.';

  @override
  String get mapTutorialStepNearbyDesktopBody => 'Open the Nearby panel to browse results near your current area and see details faster.';

  @override
  String get mapTutorialStepTypesTitle => 'Marker types';

  @override
  String get mapTutorialStepTypesDesktopBody => 'Use these chips to quickly focus on a category (artworks, events, institutions…).';

  @override
  String get mapTutorialStepFiltersTitle => 'Filters';

  @override
  String get mapTutorialStepFiltersBody => 'Use filters to narrow down what you see on the map and in the list.';

  @override
  String get mapTutorialStepFiltersDesktopBody => 'Open the Filters panel to refine results (type, distance, discovery status, and more).';

  @override
  String get mapTutorialStepTravelTitle => 'Travel mode';

  @override
  String get mapTutorialStepTravelBody => 'Travel mode loads markers for the visible map area so you can explore anywhere.';

  @override
  String get mapTutorialStepRecenterTitle => 'Recenter';

  @override
  String get mapTutorialStepRecenterBody => 'Tap to jump back to your location and keep following you.';

  @override
  String get mapTutorialStepSearchTitle => 'Search';

  @override
  String get mapTutorialStepSearchBody => 'Search for artworks, artists, institutions, or places to jump to them quickly.';

  @override
  String get mapTravelModeTutorialTitle => 'Explore beyond nearby';

  @override
  String get mapTravelModeTutorialBody => 'Travel mode lets you browse markers anywhere. The map loads what\'s currently in view.';

  @override
  String get mapTravelModeTutorialHint => 'Tip: Pan and zoom - markers refresh to match the viewport.';

  @override
  String get mapTravelModeTutorialGotIt => 'Got it';

  @override
  String get mapTravelModeTutorialEnable => 'Enable travel mode';

  @override
  String get mapNearbyArtTitle => 'Nearby art and places';

  @override
  String mapResultsDiscoveredLabel(Object count, Object percent) {
    return '$count results · $percent% discovered';
  }

  @override
  String get mapEmptyNoArtworksTitle => 'No nearby cultural markers';

  @override
  String get mapEmptyNoArtworksDescription => 'Explore different areas or adjust your filters to discover art around you.';

  @override
  String get mapEmptyZoomOutAction => 'Zoom out';

  @override
  String get mapEmptyAdjustFiltersAction => 'Adjust filters';

  @override
  String get mapNoLinkedArtworkForMarker => 'No linked artwork found for this marker yet.';

  @override
  String get mapCreateMarkerHereTooltip => 'Create marker here';

  @override
  String get mapMarkerDuplicateToast => 'A marker already exists here.';

  @override
  String get mapDistanceHere => 'Here';

  @override
  String get mapDistanceAwaySuffix => ' away';

  @override
  String get commonGetDirections => 'Get directions';

  @override
  String get desktopMapNoArAssetToast => 'No AR asset available for this artwork.';

  @override
  String get desktopMapArtworkTypeTitle => 'Artwork type';

  @override
  String get desktopMapArtworkTypeArArt => 'AR art';

  @override
  String get desktopMapArtworkTypeNfts => 'Archive records';

  @override
  String get desktopMapArtworkTypeModels3d => '3D models';

  @override
  String get desktopMapArtworkTypeSculptures => 'Sculptures';

  @override
  String get desktopMapSortByTitle => 'Sort by';

  @override
  String get desktopMapSortDistance => 'Distance';

  @override
  String get desktopMapSortPopularity => 'Popularity';

  @override
  String get desktopMapSortNewest => 'Newest';

  @override
  String get desktopMapSortRating => 'Rating';

  @override
  String desktopMapDiscoveriesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# discoveries',
      one: '# discovery',
    );
    return '$_temp0';
  }

  @override
  String get mapMarkerTypeArtworks => 'Artworks';

  @override
  String get mapMarkerTypeInstitutions => 'Institutions';

  @override
  String get mapMarkerTypeEvents => 'Events';

  @override
  String get mapMarkerTypeResidencies => 'Residencies';

  @override
  String get mapMarkerTypeDrops => 'Drops';

  @override
  String get mapMarkerTypeExperiences => 'Experiences';

  @override
  String get mapMarkerTypeMisc => 'Misc';

  @override
  String get mapMarkerTypeStreetArt => 'Street Art';

  @override
  String get mapSortNearest => 'Nearest';

  @override
  String get mapSortNewest => 'Newest';

  @override
  String get mapSortRarity => 'Rarity';

  @override
  String get mapSortHighestRewards => 'Most recognition';

  @override
  String get mapSortMostViewed => 'Most viewed';

  @override
  String get mapArReadyChipLabel => 'AR ready';

  @override
  String get mapAlreadyDiscoveredTooltip => 'Already discovered';

  @override
  String get mapMarkAsDiscoveredTooltip => 'Mark as discovered';

  @override
  String get arWebFallbackFeature => 'AR experience';

  @override
  String get arWebFallbackDescription => 'Augmented Reality (AR) features require native device capabilities. Download the art.kubus app to view digital artworks in your physical space using your phone\'s camera.';

  @override
  String get arModeScanName => 'Scan';

  @override
  String get arModePlaceName => 'Place';

  @override
  String get arModeViewName => 'View';

  @override
  String get arModeCreateName => 'Create';

  @override
  String get arModeScanDescription => 'Scan AR markers to discover artworks around you.';

  @override
  String get arModePlaceDescription => 'Place digital artworks into your space.';

  @override
  String get arModeViewDescription => 'View your placed artworks and revisit them.';

  @override
  String get arModeCreateDescription => 'Create and experiment with AR placements.';

  @override
  String arMarkerNearbyToast(Object name) {
    return 'Marker nearby: $name';
  }

  @override
  String get arInitializingTitle => 'Initializing AR…';

  @override
  String get arReadyStatus => 'AR is ready';

  @override
  String get arSettingUpStatus => 'Setting things up…';

  @override
  String get arNoArtworksYetTitle => 'No artworks yet';

  @override
  String get arNoArtworksYetDescription => 'Scan a marker or place an artwork to start building your AR view.';

  @override
  String get arModelLoadedToast => 'AR model loaded';

  @override
  String get arModelLoadFailedToast => 'Failed to load AR model. Please try again.';

  @override
  String arPlacingTitle(Object title) {
    return 'Placing: $title';
  }

  @override
  String get arPlacingInstruction => 'Move your device to find a flat surface.';

  @override
  String arModePreviewTitle(Object mode) {
    return '$mode mode';
  }

  @override
  String get arPlaceArtworkFailedToast => 'Failed to place artwork. Please try again.';

  @override
  String get arActionScan => 'Scan for artwork';

  @override
  String get arActionPlace => 'Place artwork here';

  @override
  String get arActionView => 'View details';

  @override
  String get arActionCreate => 'Create AR artwork';

  @override
  String get arArtworkPlacedToast => 'Artwork placed successfully!';

  @override
  String get arNearbyArtworksTitle => 'Nearby artworks';

  @override
  String arSelectedArtworkToast(Object title) {
    return 'Selected: $title';
  }

  @override
  String get arSelectArtworkBeforePlacingToast => 'Select or create an artwork before placing it.';

  @override
  String get arNoPlacedArtworksToast => 'No artworks placed yet. Try placing some first!';

  @override
  String arPlacedArtworksTitle(Object count) {
    return 'Placed artworks ($count)';
  }

  @override
  String get arArtworkRemovedToast => 'Artwork removed';

  @override
  String get arLocationUnavailableToast => 'Current location unavailable. Move your device to calibrate AR tracking.';

  @override
  String get arUnableToReadFileError => 'Unable to read file data. Please try another file.';

  @override
  String get arFileSelectionFailedError => 'File selection failed. Please try again.';

  @override
  String get arSelectSubjectBeforeMarkerToast => 'Select a subject before creating the marker.';

  @override
  String get arAttach3dModelError => 'Attach a 3D model before continuing.';

  @override
  String get arSelectedArtworkUnavailableToast => 'Selected artwork is no longer available. Refresh data and try again.';

  @override
  String get arUploadFailedToast => 'Upload failed. Please try again.';

  @override
  String get arMarkerCreatedSwitchToPlaceToast => 'AR asset uploaded and marker created. Switching to Place mode.';

  @override
  String get arCreateMarkerFailedToast => 'Failed to create AR marker. Please try again.';

  @override
  String arShareText(Object title, Object artist) {
    return 'Check out this artwork on art.kubus!\n\n\"$title\"\nby $artist\n\nAR layers are in development.';
  }

  @override
  String get arShareSuccessToast => 'Artwork shared successfully!';

  @override
  String get arShareFailedToast => 'Share failed. Please try again.';

  @override
  String get commonActions => 'Actions';

  @override
  String get commonCurrentlyOn => 'Currently ON';

  @override
  String get commonCurrentlyOff => 'Currently OFF';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonJustNow => 'Just now';

  @override
  String commonMinutesAgo(num minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '${minutes}m ago',
      one: '1m ago',
    );
    return '$_temp0';
  }

  @override
  String commonHoursAgo(num hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '${hours}h ago',
      one: '1h ago',
    );
    return '$_temp0';
  }

  @override
  String commonDaysAgo(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '${days}d ago',
      one: '1d ago',
    );
    return '$_temp0';
  }

  @override
  String commonWeeksAgo(num weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '${weeks}w ago',
      one: '1w ago',
    );
    return '$_temp0';
  }

  @override
  String get commonTba => 'TBA';

  @override
  String get commonUntitled => 'Untitled';

  @override
  String get commonDigital => 'Digital';

  @override
  String get commonArtwork => 'Artwork';

  @override
  String get commonEvent => 'Event';

  @override
  String get commonUndo => 'Undo';

  @override
  String get savedItemsArtworkLabel => 'artworks';

  @override
  String get savedItemsEventLabel => 'events';

  @override
  String get savedItemsCollectionLabel => 'collections';

  @override
  String get savedItemsExhibitionLabel => 'exhibitions';

  @override
  String get savedItemsPostLabel => 'posts';

  @override
  String get savedItemsArtistLabel => 'artists';

  @override
  String get savedItemsInstitutionLabel => 'institutions';

  @override
  String get savedItemsGroupLabel => 'groups';

  @override
  String get savedItemsMarkerLabel => 'markers';

  @override
  String get savedItemsLoadMoreButton => 'Load more';

  @override
  String get messagesTitle => 'Messages';

  @override
  String get messagesEmptyNoConversationsTitle => 'No conversations';

  @override
  String get messagesEmptyNoConversationsDescription => 'Start a conversation using the chat button below.';

  @override
  String get messagesEmptyStartChatAction => 'Start a chat';

  @override
  String get messagesListHeaderTitle => 'Conversations';

  @override
  String get messagesListHeaderDescription => 'Pick up direct chats and group threads with artists, collectors, and institutions.';

  @override
  String get messagesFallbackGroupTitle => 'Group';

  @override
  String get messagesFallbackConversationTitle => 'Conversation';

  @override
  String get messagesFallbackConversationInitial => 'C';

  @override
  String get messagesCreateConversationTitle => 'Create conversation';

  @override
  String get messagesCreateConversationTitleOptionalLabel => 'Title (optional)';

  @override
  String get messagesCreateConversationMembersLabel => 'Members (username or wallet)';

  @override
  String get messagesCreateConversationGroupAvatarOptionalLabel => 'Group avatar (optional)';

  @override
  String get messagesCreateConversationIsGroupLabel => 'Group';

  @override
  String messagesReplyingToLabel(Object name) {
    return 'Replying to $name';
  }

  @override
  String get messagesCreatedNewGroupChatToast => 'Created a new group chat.';

  @override
  String get messagesUploadingAvatarToast => 'Uploading avatar…';

  @override
  String get messagesAvatarUpdatedToast => 'Avatar updated.';

  @override
  String get messagesUpdateAvatarFailedToast => 'Unable to update avatar right now.';

  @override
  String get messagesMenuAddMember => 'Add member';

  @override
  String get messagesMenuRenameConversation => 'Rename conversation';

  @override
  String get messagesMenuChangeGroupAvatar => 'Change group avatar';

  @override
  String get messagesMenuDeleteConversation => 'Delete conversation';

  @override
  String get messagesMessageCopiedToClipboardToast => 'Message copied to clipboard';

  @override
  String get messagesDeleteConversationTitle => 'Delete conversation';

  @override
  String get messagesDeleteConversationBody => 'Are you sure you want to delete this conversation? This removes it from your conversations list.';

  @override
  String get messagesDeleteConversationSuccessToast => 'Conversation deleted.';

  @override
  String get messagesDeleteConversationFailedToast => 'Unable to delete conversation right now.';

  @override
  String get messagesAttachmentDefaultFilename => 'attachment';

  @override
  String get messagesAttachmentFailedToLoadImage => 'Failed to load image';

  @override
  String get messagesAttachmentVideoLabel => 'Video';

  @override
  String get messagesAttachmentPlayVideoButton => 'Play Video';

  @override
  String get messagesAttachmentDownloadButton => 'Download';

  @override
  String get messagesTypeMessageHint => 'Type a message…';

  @override
  String get messagesAddMemberDialogTitle => 'Add member';

  @override
  String get messagesAddMemberIdentifierLabel => 'Username or wallet';

  @override
  String get messagesAddMemberDialogLoadFailedTitle => 'Unable to load member';

  @override
  String get messagesAddMemberDialogLoadFailedBody => 'We couldn\'t load this user right now. Please try again.';

  @override
  String get messagesConversationMembersTitle => 'Conversation members';

  @override
  String get messagesMemberLabel => 'Member';

  @override
  String get messagesMemberOptionsTitle => 'Member options';

  @override
  String messagesMemberOptionsBody(Object displayName) {
    return 'What would you like to do with $displayName?';
  }

  @override
  String get messagesTransferOwnershipAction => 'Transfer ownership';

  @override
  String get messagesRemoveMemberAction => 'Remove member';

  @override
  String get messagesTransferOwnershipTitle => 'Transfer ownership';

  @override
  String messagesTransferOwnershipBody(Object displayName, Object wallet) {
    return 'Transfer ownership to $displayName ($wallet)?';
  }

  @override
  String get messagesOwnershipTransferredToast => 'Ownership transferred.';

  @override
  String get messagesTransferFailedToast => 'Transfer failed.';

  @override
  String get messagesManageMemberAction => 'Manage';

  @override
  String get messagesRenameConversationTitle => 'Rename conversation';

  @override
  String get messagesRenameConversationHint => 'Enter a new name';

  @override
  String get messagesRenameConversationFieldLabel => 'Conversation name';

  @override
  String get userProfileTitle => 'Profile';

  @override
  String get userProfileNotFound => 'User not found';

  @override
  String get userProfileNotFoundDescription => 'This profile may have been deleted or doesn\'t exist.';

  @override
  String get userProfileShareTooltip => 'Share';

  @override
  String get userProfileMoreTooltip => 'More';

  @override
  String get userProfileSharedToast => 'Profile shared!';

  @override
  String userProfileJoinedLabel(Object date) {
    return 'Joined $date';
  }

  @override
  String get userProfileMessageButtonLabel => 'Message';

  @override
  String get userProfileArtistPortfolioTitle => 'Artist portfolio';

  @override
  String get userProfileInstitutionHighlightsDesktopSubtitle => 'Featured exhibitions and programs';

  @override
  String get userProfileArtistPortfolioDesktopSubtitle => 'Latest artworks and collections';

  @override
  String get userProfileNoCreatorContentTitle => 'No content available';

  @override
  String get userProfileNoInstitutionContentDescription => 'No exhibitions or programs to display yet';

  @override
  String get userProfileNoArtistContentDescription => 'No artworks or collections to display yet';

  @override
  String get userProfileFollowButton => 'Follow';

  @override
  String get userProfileFollowingButton => 'Following';

  @override
  String get userProfileSignInToFollowToast => 'Please sign in to follow creators.';

  @override
  String get userProfileFollowUpdateFailedToast => 'Could not update follow status. Please try again.';

  @override
  String userProfileNowFollowingToast(Object name) {
    return 'Following $name';
  }

  @override
  String userProfileUnfollowedToast(Object name) {
    return 'Unfollowed $name';
  }

  @override
  String get userProfilePostsStatLabel => 'Posts';

  @override
  String get userProfileFollowersStatLabel => 'Followers';

  @override
  String get userProfileFollowingStatLabel => 'Following';

  @override
  String get userProfileNoFollowersTitle => 'No followers yet';

  @override
  String get userProfileNoFollowersDescription => 'Share your profile to gain followers';

  @override
  String get userProfileFollowersLoadFailedMessage => 'Failed to load followers.';

  @override
  String get userProfileNoFollowingTitle => 'Not following anyone';

  @override
  String get userProfileNoFollowingDescription => 'Discover artists in the Community tab';

  @override
  String get userProfileFollowingLoadFailedMessage => 'Failed to load following.';

  @override
  String get userProfileMessageLoginRequiredToast => 'Please log in to message this user.';

  @override
  String get userProfileConversationOpenFailedToast => 'Could not open conversation.';

  @override
  String get userProfileConversationOpenGenericErrorToast => 'Failed to open conversation. Please try again.';

  @override
  String get userProfileAchievementsTitle => 'Achievements';

  @override
  String get profileBadgesVerificationTitle => 'Profile badges';

  @override
  String get profileBadgesVerificationSubtitle => 'Role, verification and participation signals for this profile.';

  @override
  String get walletBadgesVerificationTitle => 'Wallet badges';

  @override
  String get walletBadgesVerificationSubtitle => 'Badges linked to this wallet and its activity on art.kubus.';

  @override
  String get profileAchievementsPreviewTitle => 'Achievements';

  @override
  String get profileAchievementsPreviewSubtitle => 'Milestones recognized through activity across art.kubus.';

  @override
  String userProfileAchievementsProgressLabel(Object completed, Object total) {
    return '$completed of $total unlocked';
  }

  @override
  String userProfileAchievementsEmptyTitle(Object name) {
    return '$name hasn\'t unlocked any achievements yet.';
  }

  @override
  String get userProfileAchievementsEmptyDescription => 'Start exploring to unlock achievements';

  @override
  String get userProfileAchievementCompletedLabel => 'Completed';

  @override
  String get userProfilePostsTitle => 'Posts';

  @override
  String userProfileRecentActivitySubtitle(Object name) {
    return 'Recent activity from $name';
  }

  @override
  String get userProfilePostsLoadFailedTitle => 'Could not load posts';

  @override
  String get userProfilePostsLoadFailedDescription => 'Failed to load posts.';

  @override
  String get userProfilePostsLoadMoreFailedDescription => 'Failed to load more posts.';

  @override
  String get userProfileNoPostsTitle => 'No posts yet';

  @override
  String userProfileNoPostsDescription(Object name) {
    return '$name hasn\'t shared any posts so far.';
  }

  @override
  String get userProfileNoMorePostsLabel => 'No more posts';

  @override
  String get userProfileArtistHighlightsTitle => 'Artist highlights';

  @override
  String userProfileArtistHighlightsSubtitle(Object name) {
    return 'Latest drops from $name.';
  }

  @override
  String get userProfileInstitutionHighlightsTitle => 'Institution highlights';

  @override
  String userProfileInstitutionHighlightsSubtitle(Object name) {
    return 'Programs and collections curated by $name.';
  }

  @override
  String get userProfileArtworksTitle => 'Artworks';

  @override
  String get userProfileCollectionsTitle => 'Collections';

  @override
  String get userProfileEventsTitle => 'Events';

  @override
  String userProfileEventsSubtitleFeaturing(Object name) {
    return 'Upcoming experiences featuring $name.';
  }

  @override
  String userProfileNoUpcomingEventsYetLabel(Object name) {
    return 'No upcoming events from $name just yet.';
  }

  @override
  String userProfileNoArtworksYetLabel(Object name) {
    return '$name hasn\'t published any artworks yet.';
  }

  @override
  String userProfileNoCollectionsYetLabel(Object name) {
    return '$name hasn\'t curated collections yet.';
  }

  @override
  String userProfileNoItemsTitle(Object title) {
    return 'No $title';
  }

  @override
  String userProfileLikesLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count likes',
      one: '1 like',
    );
    return '$_temp0';
  }

  @override
  String userProfileArtworksCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artworks',
      one: '1 artwork',
    );
    return '$_temp0';
  }

  @override
  String userProfileCuratedByLabel(Object name) {
    return 'Curated by $name';
  }

  @override
  String get userProfileCollectionFallbackTitle => 'Collection';

  @override
  String get userProfileEventFallbackTitle => 'Event';

  @override
  String get collectionSettingsTitle => 'Collection Settings';

  @override
  String get artistStudioCreatePrompt => 'What would you like to create?';

  @override
  String get artistStudioCreateOptionArtworkTitle => 'Create artwork';

  @override
  String get artistStudioCreateOptionArtworkSubtitle => 'Upload media, set details, and publish.';

  @override
  String get artworkCreatorInviteSentSingular => 'Artwork created. 1 invite sent.';

  @override
  String artworkCreatorInviteSentPlural(int count) {
    return 'Artwork created. $count invites sent.';
  }

  @override
  String get artworkCreatorInviteFailedSingular => 'Artwork created. 1 invite could not be sent.';

  @override
  String artworkCreatorInviteFailedPlural(int count) {
    return 'Artwork created. $count invites could not be sent.';
  }

  @override
  String artworkCreatorInvitePartialResult(int sent, int failed) {
    return 'Artwork created. $sent invite(s) sent, $failed failed.';
  }

  @override
  String get artworkCreatorCollaborationQueuedSubtitle => 'Queue invites before publishing.';

  @override
  String get artworkCreatorCollaborationManageSubtitle => 'Manage collaborators without leaving the creator.';

  @override
  String get artworkCreatorCollaborationUnavailableSubtitle => 'Collaboration is unavailable.';

  @override
  String get artworkCreatorCollaborationLockedMessage => 'Once the artwork is saved, collaborators can be invited here without leaving the creator.';

  @override
  String get artworkCreatorOpenArSetup => 'Open AR setup';

  @override
  String get artworkCreatorSaveFirstToUnlockAr => 'Save first to unlock AR';

  @override
  String get artworkCreatorDraftSavedBadge => 'Draft saved';

  @override
  String get artworkCreatorSavedWorkspaceSubtitle => 'Draft saved. Collaboration and AR are available in-context.';

  @override
  String get artworkCreatorArSetupAction => 'AR setup';

  @override
  String get artworkCreatorShellDraftSubtitle => 'Compose the artwork, then unlock collaboration and AR from the sidebar.';

  @override
  String get artworkCreatorLiveWorkspaceSubtitle => 'The artwork is live and can still be refined from this workspace.';

  @override
  String get artistStudioCreateOptionCollectionTitle => 'Create collection';

  @override
  String get artistStudioCreateOptionCollectionSubtitle => 'Curate a set of artworks into a collection.';

  @override
  String get collectionCreatorTitle => 'Create collection';

  @override
  String get collectionCreatorNameRequiredError => 'Collection name is required';

  @override
  String get collectionCreatorCreateFailed => 'Failed to create collection.';

  @override
  String get collectionCreatorCreateFailedWithError => 'Failed to create collection. Please try again.';

  @override
  String get collectionCreatorShellDraftSubtitle => 'Shape the collection, then save it to unlock collaboration.';

  @override
  String get collectionCreatorShellSavedSubtitle => 'Collection saved. Keep curating or invite collaborators in-context.';

  @override
  String get collectionCreatorReadyBasicsLabel => 'Basics complete';

  @override
  String get collectionCreatorReadyBasicsDescription => 'Name and description are filled in.';

  @override
  String get collectionCreatorReadyCoverLabel => 'Cover image added';

  @override
  String get collectionCreatorReadyCoverComplete => 'Collection cover is ready.';

  @override
  String get collectionCreatorReadyCoverPending => 'Optional, but strongly recommended on desktop.';

  @override
  String get collectionCreatorReadySelectionLabel => 'Artwork selection ready';

  @override
  String collectionCreatorReadySelectionComplete(int count) {
    return '$count artwork(s) selected.';
  }

  @override
  String get collectionCreatorReadySelectionPending => 'Choose artworks to anchor the collection.';

  @override
  String get collectionCreatorReadyVisibilityLabel => 'Visibility chosen';

  @override
  String get collectionCreatorReadyVisibilityPublic => 'Public collection visible to everyone.';

  @override
  String get collectionCreatorReadyVisibilityPrivate => 'Private collection is still available to collaborators.';

  @override
  String get collectionCreatorStatusSavedSubtitle => 'Saved collection';

  @override
  String get collectionCreatorStatusDraftSubtitle => 'Draft in progress';

  @override
  String get collectionCreatorSummaryIdLabel => 'Collection ID';

  @override
  String get collectionCreatorSummaryNotCreatedYet => 'Not created yet';

  @override
  String get collectionCreatorSummarySelectedArtworksLabel => 'Selected artworks';

  @override
  String get collectionCreatorSummaryVisibilityLabel => 'Visibility';

  @override
  String get collectionCreatorReadinessTitle => 'Readiness';

  @override
  String get collectionCreatorReadinessSubtitle => 'A quick sanity check before saving.';

  @override
  String get collectionCreatorQuickActionsTitle => 'Quick actions';

  @override
  String get collectionCreatorQuickActionsSubtitle => 'Keep the workflow in this creator.';

  @override
  String get collectionCreatorQuickActionUpdate => 'Update collection';

  @override
  String get collectionCreatorQuickActionSave => 'Save collection';

  @override
  String get collectionCreatorQuickActionOpen => 'Open collection';

  @override
  String get collectionCreatorCollaborationReadySubtitle => 'Invite co-curators without leaving the workspace.';

  @override
  String get collectionCreatorCollaborationLockedSubtitle => 'Save once to unlock collaboration.';

  @override
  String get collectionCreatorCollaborationLockedMessage => 'Once saved, collaborators can be invited here so curation stays in context.';

  @override
  String get collectionCreatorSavedInfoBox => 'Collection saved. Collaboration is available from the sidebar, and you can keep refining the selection below.';

  @override
  String get collectionCreatorPartialSuccessToast => 'The collection may have been created, but it could not be resolved locally yet. Refresh your collections before adding artworks.';

  @override
  String get collectionCreatorPartialSuccessInfoBox => 'The server accepted the collection, but no collection ID was returned. Check your collections or refresh before attaching artworks.';

  @override
  String get collectionCreatorPartialSuccessArtworkAttachmentInfo => 'Selected artworks were not attached because the collection ID is not available yet.';

  @override
  String get collectionCreatorPartialSuccessArtworkAttachmentFailedToast => 'Collection saved, but selected artworks could not be attached. Open the collection and try adding them again.';

  @override
  String get collectionCreatorConnectWalletLabel => 'Connect a wallet to load and curate your artwork library inside this collection creator.';

  @override
  String get collectionCreatorArtworkLibraryLoadingLabel => 'Your artwork library is still loading. If the backend is slow, you can keep editing the collection basics and come back here.';

  @override
  String get collectionCreatorArtworkLibraryPlaceholderLabel => 'Load your artwork library to select pieces for this collection. This keeps the first open lighter and avoids unnecessary API calls.';

  @override
  String get collectionCreatorLoadingLibraryLabel => 'Loading library…';

  @override
  String get collectionCreatorLoadArtworkLibraryLabel => 'Load artwork library';

  @override
  String get collectionCreatorArtworkSelectedLabel => 'Selected';

  @override
  String get collectionCreatorArtworkAddLabel => 'Add';

  @override
  String get collectionCreatorNoArtworksAvailable => 'No artworks available matching your search.';

  @override
  String get collectionCreatorSearchArtworksLabel => 'Search';

  @override
  String get collectionCreatorSearchArtworksHint => 'Find artworks by title or description...';

  @override
  String get collectionCreatorAddArtworksTitle => 'Add artworks to your collection';

  @override
  String get collectionDetailLoadFailedMessage => 'Failed to load collection details. Please try again.';

  @override
  String get collectionDetailNoArtworksYet => 'No artworks yet.';

  @override
  String get collectionDetailAddArtwork => 'Add Artwork';

  @override
  String get collectionDetailManage => 'Manage';

  @override
  String get collectionDetailArtworks => 'Artworks';

  @override
  String get collectionDetailDescription => 'Description';

  @override
  String get collectionDetailByYou => 'by You';

  @override
  String get collectionDetailSharingToast => 'Sharing collection...';

  @override
  String get collectionDetailOpeningEditorToast => 'Opening collection editor...';

  @override
  String get collectionDetailAddArtworkFailedToast => 'Failed to add artwork to collection. Please try again.';

  @override
  String get collectionDetailRemoveArtworkFailedToast => 'Failed to remove artwork from collection. Please try again.';

  @override
  String get collectionSettingsBasicInfo => 'Basic Information';

  @override
  String get collectionSettingsName => 'Collection Name';

  @override
  String get collectionSettingsNameHint => 'Enter collection name';

  @override
  String get collectionSettingsDescriptionLabel => 'Description';

  @override
  String get collectionSettingsDescriptionHint => 'Describe your collection...';

  @override
  String get collectionSettingsCategory => 'Category';

  @override
  String get collectionSettingsPrivacy => 'Privacy Settings';

  @override
  String get collectionSettingsPublic => 'Public Collection';

  @override
  String get collectionSettingsPublicSubtitle => 'Make this collection visible to everyone';

  @override
  String get collectionSettingsCollaboration => 'Collaboration';

  @override
  String get collectionSettingsAllowContributions => 'Allow Contributions';

  @override
  String get collectionSettingsAllowContributionsSubtitle => 'Let other artists contribute to this collection';

  @override
  String get collectionSettingsNotifications => 'Notifications';

  @override
  String get collectionSettingsUpdates => 'Collection Updates';

  @override
  String get collectionSettingsUpdatesSubtitle => 'Get notified when artworks are added or removed';

  @override
  String get collectionSettingsDangerZone => 'Danger Zone';

  @override
  String get collectionSettingsDeleteTitle => 'Delete Collection';

  @override
  String get collectionSettingsDeleteWarning => 'Once you delete a collection, there is no going back. This action cannot be undone.';

  @override
  String get collectionSettingsDeleteButton => 'Delete Collection';

  @override
  String collectionSettingsSavedToast(Object name) {
    return 'Collection settings saved for \"$name\"';
  }

  @override
  String get collectionSettingsSaveFailedToast => 'Failed to save collection settings. Please try again.';

  @override
  String get collectionSettingsDeleteDialogTitle => 'Delete Collection';

  @override
  String collectionSettingsDeleteDialogContent(Object name) {
    return 'Are you sure you want to delete \"$name\"? This action cannot be undone.';
  }

  @override
  String get collectionSettingsDeletedToast => 'Collection deleted';

  @override
  String get userProfileMoreOptionsBlockUser => 'Block user';

  @override
  String get userProfileMoreOptionsReportUser => 'Report user';

  @override
  String get userProfileMoreOptionsCopyLink => 'Copy profile link';

  @override
  String get userProfileLinkCopiedToast => 'Profile link copied to clipboard';

  @override
  String userProfileBlockDialogTitle(Object name) {
    return 'Block $name?';
  }

  @override
  String get userProfileBlockDialogDescription => 'They won\'t be able to see your profile or posts.';

  @override
  String get userProfileUnableToBlockToast => 'Unable to block user.';

  @override
  String get userProfileBlockFailedToast => 'Failed to block user. Please try again.';

  @override
  String userProfileBlockedToast(Object name) {
    return 'Blocked $name';
  }

  @override
  String get userProfileBlockButtonLabel => 'Block';

  @override
  String userProfileReportDialogTitle(Object name) {
    return 'Report $name';
  }

  @override
  String get userProfileReportDialogQuestion => 'Why are you reporting this user?';

  @override
  String get userProfileReportReasonSpam => 'Spam';

  @override
  String get userProfileReportReasonInappropriate => 'Inappropriate content';

  @override
  String get userProfileReportReasonHarassment => 'Harassment';

  @override
  String get userProfileReportReasonOther => 'Other';

  @override
  String get userProfileReportSubmittedToast => 'Report submitted. Thank you for your feedback.';

  @override
  String get arDetailModelLabel => 'Model';

  @override
  String get arDetailScaleLabel => 'Scale';

  @override
  String get arDetailPlacedLabel => 'Placed';

  @override
  String get arShareButtonLabel => 'Share';

  @override
  String get arLikeButtonLabel => 'Like';

  @override
  String get arLikedButtonLabel => 'Liked';

  @override
  String get arSaveButtonLabel => 'Save';

  @override
  String get arSavedButtonLabel => 'Saved';

  @override
  String get arLikeAddedToast => 'Added to your likes!';

  @override
  String get arLikeRemovedToast => 'Removed from likes';

  @override
  String get arSaveAddedToast => 'Saved to your collection!';

  @override
  String get arSaveRemovedToast => 'Removed from saved items';

  @override
  String get arNotSupportedTitle => 'AR not supported';

  @override
  String get arNotSupportedMessage => 'Your device does not support AR features. AR requires ARCore (Android) or ARKit (iOS).';

  @override
  String get arInitializationFailedTitle => 'AR initialization failed';

  @override
  String get arInitializationFailedMessage => 'Could not initialize AR. Please check camera permissions and try again.';

  @override
  String get commonRequired => 'required';

  @override
  String commonFileSizeKb(String value) {
    return '$value KB';
  }

  @override
  String commonFileSizeMb(String value) {
    return '$value MB';
  }

  @override
  String get arCreateUploadTitle => 'Upload AR asset';

  @override
  String get arCreateUploadSubtitle => 'Link an existing artwork, upload a 3D model (GLB/GLTF/USDZ), and we\'ll enrich its AR marker.';

  @override
  String get arCreateSubjectTypeLabel => 'Subject type';

  @override
  String arCreateSubjectLabel(String subjectType) {
    return '$subjectType *';
  }

  @override
  String arCreateDefaultDescription(String title) {
    return 'Marker for $title';
  }

  @override
  String arCreateNoSubjectsAvailable(String subjectTypeLower) {
    return 'No ${subjectTypeLower}s available. Use the respective module to create one first.';
  }

  @override
  String get arCreateMarkerTitleLabel => 'Marker title *';

  @override
  String get arCreateTitleRequiredError => 'Title is required';

  @override
  String get arCreateTitleMinLengthError => 'Title must be at least 3 characters';

  @override
  String get arCreateDescriptionLabel => 'Description *';

  @override
  String get arCreateDescriptionRequiredError => 'Description is required';

  @override
  String get arCreateDescriptionMinLengthError => 'Describe the experience in at least 10 characters';

  @override
  String get arCreateCategoryLabel => 'Category';

  @override
  String get arCreateAttach3dAssetTitle => 'Attach 3D asset';

  @override
  String get arCreateSelectModelButton => 'Select GLB / GLTF / USDZ';

  @override
  String get arCreateReplaceModelButton => 'Replace model';

  @override
  String get arCreatePublicMarkerTitle => 'Public marker';

  @override
  String get arCreatePublicMarkerSubtitle => 'Visible to nearby explorers';

  @override
  String get arCreateUploadingLabel => 'Uploading…';

  @override
  String get arCreateUploadAndCreateButton => 'Upload & create marker';

  @override
  String get arSettingsTitle => 'AR settings';

  @override
  String get arScannerSettingsTitle => 'Scanner settings';

  @override
  String get arFlashControlTitle => 'Flash control';

  @override
  String get arFlashNotAvailableToast => 'Flash is not available on this device.';

  @override
  String get arScannerOverlayTitle => 'Scanner overlay';

  @override
  String get arScannerOverlaySubtitle => 'Show/hide scanner guide';

  @override
  String get arScannerOverlayResetToast => 'Scanner overlay resets automatically after 3 seconds.';

  @override
  String get arDisplayTitle => 'AR display';

  @override
  String get arShowFeaturePointsTitle => 'Show feature points';

  @override
  String get arShowFeaturePointsSubtitle => 'Display tracking points on surfaces';

  @override
  String get arShowPlanesTitle => 'Show planes';

  @override
  String get arShowPlanesSubtitle => 'Display detected plane surfaces';

  @override
  String get arAutoDetectSurfacesTitle => 'Auto-detect surfaces';

  @override
  String get arAutoDetectSurfacesSubtitle => 'Automatically detect flat surfaces';

  @override
  String get arDebugInfoTitle => 'Debug info';

  @override
  String get arDebugInfoSubtitle => 'Show technical information';

  @override
  String arModelScaleLabel(Object percent) {
    return 'Model scale: $percent%';
  }

  @override
  String get arClearAllArtworksTitle => 'Clear all artworks';

  @override
  String get arClearAllArtworksSubtitle => 'Remove all placed AR objects';

  @override
  String get arAllArtworksClearedToast => 'All artworks cleared';

  @override
  String get arResetSessionTitle => 'Reset AR session';

  @override
  String get arResetSessionSubtitle => 'Restart AR tracking';

  @override
  String get arSessionResetToast => 'AR session reset';

  @override
  String get connectWalletSecureAccessTitle => 'Secure your wallet';

  @override
  String get connectWalletChooseTitle => 'Connect wallet';

  @override
  String get connectWalletChooseDescription => 'Choose how to set up your account wallet. Create or import a local recovery phrase, or connect an external wallet for signing.';

  @override
  String get connectWalletOptionWalletConnectTitle => 'Connect external wallet';

  @override
  String get connectWalletOptionWalletConnectDescription => 'Use Phantom, Solflare, Backpack, or another compatible Solana wallet without importing a recovery phrase';

  @override
  String get connectWalletOptionSignInTitle => 'Sign in';

  @override
  String get connectWalletOptionSignInDescription => 'Sign in with your e-mail and password';

  @override
  String get connectWalletOptionRegisterTitle => 'Register account';

  @override
  String get connectWalletOptionRegisterDescription => 'Register with your e-mail or Google account';

  @override
  String get connectWalletHybridHelpLink => 'What\'s WalletConnect?';

  @override
  String get connectWalletLinkExistingTitle => 'Link existing wallet';

  @override
  String get connectWalletAdvancedBadge => 'Advanced';

  @override
  String get connectWalletImportTitle => 'Import wallet';

  @override
  String get connectWalletImportDescription => 'Enter the 12-word recovery phrase to restore a wallet from another device and reconnect your art.kubus account.';

  @override
  String get connectWalletImportHint => 'Enter 12 words separated by spaces';

  @override
  String get connectWalletImportWarning => 'Never share your recovery phrase. Anyone with it can take control of your wallet and the access tied to it.';

  @override
  String get connectWalletImportButton => 'Import wallet';

  @override
  String get connectWalletImportEmptyMnemonicError => 'Please enter your recovery phrase';

  @override
  String connectWalletImportInvalidMnemonicWordCountError(Object count) {
    return 'Expected 12 words, got $count.';
  }

  @override
  String connectWalletImportSuccessToast(Object prefix) {
    return 'Wallet imported: $prefix…';
  }

  @override
  String get connectWalletImportFailedToast => 'Wallet import failed. Please try again.';

  @override
  String get connectWalletCreateTitle => 'Create a new wallet';

  @override
  String get connectWalletCreateDescription => 'We will create a new wallet you control on this device for your art.kubus account. Back up the recovery phrase right away to protect long-term access.';

  @override
  String get connectWalletCreateMissingBackupError => 'Created wallet is missing backup details.';

  @override
  String get connectWalletCreateInfoTitle => 'Important';

  @override
  String get connectWalletCreateInfoBody => 'Write down the recovery phrase and store it safely offline. It is essential for restoring this wallet, and we cannot recover it for you.';

  @override
  String get connectWalletCreateWarning => 'By continuing, you confirm that you understand how important the recovery phrase is.';

  @override
  String get connectWalletCreateGenerateButton => 'Generate wallet';

  @override
  String get connectWalletCreateAlreadyHaveWalletPrefix => 'Already have a wallet?';

  @override
  String get connectWalletCreateAlreadyHaveWalletLink => 'Import it';

  @override
  String get connectWalletCreateSuccessToast => 'Wallet created and profile set up.';

  @override
  String get connectWalletCreateFailedToast => 'Failed to create wallet. Please try again.';

  @override
  String get connectWalletMnemonicDialogTitle => 'Save your recovery phrase';

  @override
  String get connectWalletMnemonicDialogWarning => 'Write this down and keep it safe!';

  @override
  String get connectWalletMnemonicDialogConfirmPrompt => 'Confirm by typing your recovery phrase:';

  @override
  String get connectWalletMnemonicDialogConfirmHint => 'Paste or type your recovery phrase';

  @override
  String connectWalletMnemonicDialogAddressLabel(Object address) {
    return 'Your wallet address: $address';
  }

  @override
  String get connectWalletMnemonicDialogConfirmButton => 'I\'ve saved it';

  @override
  String get connectWalletConnectedTitle => 'Wallet connected';

  @override
  String get connectWalletConnectedDescription => 'Your account wallet is now connected to art.kubus. It supports long-term access, digital ownership, and upcoming features for artists, institutions, and community participation.';

  @override
  String get connectWalletConnectedStartExploringButton => 'Start exploring';

  @override
  String get connectWalletConnectedDisconnectButton => 'Disconnect wallet';

  @override
  String get connectWalletWeb3GuideTitle => 'What\'s a wallet?';

  @override
  String get connectWalletWeb3GuideDescription => 'Your account wallet keeps access and ownership in your hands. It also enables features that need proof of ownership, without giving your keys to us:';

  @override
  String get connectWalletWeb3GuideFeatureSecureTitle => 'You stay in control';

  @override
  String get connectWalletWeb3GuideFeatureSecureDescription => 'You control the keys, not us';

  @override
  String get connectWalletWeb3GuideFeatureNftsTitle => 'Digital editions';

  @override
  String get connectWalletWeb3GuideFeatureNftsDescription => 'Collect and keep digital works connected to artists and places';

  @override
  String get connectWalletWeb3GuideFeatureGovernanceTitle => 'Community';

  @override
  String get connectWalletWeb3GuideFeatureGovernanceDescription => 'Take part in community decisions and future platform rights';

  @override
  String get connectWalletWeb3GuideFeatureDefiTitle => 'Portable access';

  @override
  String get connectWalletWeb3GuideFeatureDefiDescription => 'Use the same wallet across future art.kubus and compatible ecosystem features';

  @override
  String get connectWalletWeb3GuideGotItButton => 'Got it!';

  @override
  String get connectWalletWalletConnectTitle => 'Connect external wallet';

  @override
  String get connectWalletWalletConnectDescription => 'Connect a Solana wallet for signing. On web, compatible browser wallets are preferred automatically before falling back to the full Reown wallet list.';

  @override
  String get connectWalletWalletConnectSupportedTitle => 'Supported wallets';

  @override
  String get connectWalletWalletConnectSupportedList => 'Phantom, Solflare, Backpack, and other compatible Solana wallets';

  @override
  String get connectWalletWalletConnectHowToTitle => 'How it works';

  @override
  String get connectWalletWalletConnectStep1 => 'Choose your wallet';

  @override
  String get connectWalletWalletConnectStep2 => 'Approve the Solana connection';

  @override
  String get connectWalletWalletConnectStep3 => 'Return to art.kubus to finish';

  @override
  String get connectWalletBrowserWalletChooserTitle => 'Choose a browser wallet';

  @override
  String get connectWalletBrowserWalletChooserDescription => 'Compatible Solana extensions are preferred automatically on web. If none are available, continue with the all-wallets flow.';

  @override
  String connectWalletBrowserWalletAutoPrompt(Object walletName) {
    return 'Opening $walletName in your browser. Approve the connection in the extension, or continue with the all-wallets flow instead.';
  }

  @override
  String get connectWalletBrowserWalletNoWalletTitle => 'No compatible browser wallet detected';

  @override
  String get connectWalletBrowserWalletNoWalletDescription => 'Install Phantom or another compatible Solana browser wallet, or continue with the all-wallets flow.';

  @override
  String get connectWalletBrowserWalletFallbackButton => 'Open all wallets';

  @override
  String get connectWalletBrowserWalletRescanButton => 'Rescan browser wallets';

  @override
  String get connectWalletWalletConnectConnectingLabel => 'Connecting…';

  @override
  String get connectWalletWalletConnectQuickConnectLabel => 'Open wallet picker';

  @override
  String get connectWalletWalletConnectUriHint => 'External wallet session';

  @override
  String get connectWalletWalletConnectSecurityNote => 'External wallets sign in their own app. The encrypted backup supports recovery; it is not custody.';

  @override
  String get connectWalletWalletConnectScanQrButton => 'Scan QR code';

  @override
  String get connectWalletWalletConnectConnectButton => 'Connect';

  @override
  String get connectWalletWalletConnectNoWalletPrefix => 'Don\'t have a wallet yet?';

  @override
  String get connectWalletWalletConnectNoWalletLink => 'Create one';

  @override
  String get connectWalletWalletConnectScanQrTitle => 'Scan WalletConnect QR code';

  @override
  String get connectWalletWalletConnectScanQrHint => 'Position the QR code within the frame';

  @override
  String get connectWalletWalletConnectUriRequiredToast => 'Please enter a WalletConnect URI';

  @override
  String get connectWalletWalletConnectInvalidUriToast => 'Invalid WalletConnect URI';

  @override
  String get connectWalletWalletConnectNeedsLocalWalletToast => 'Choose an external wallet to continue';

  @override
  String connectWalletWalletConnectConnectedToast(Object address) {
    return 'Connected to $address';
  }

  @override
  String get connectWalletWalletConnectConnectionErrorToast => 'Connection error. Please try again.';

  @override
  String get connectWalletWalletConnectWaitingApprovalToast => 'Waiting for external wallet approval…';

  @override
  String get connectWalletWalletConnectFailedToast => 'Failed to connect external wallet';

  @override
  String get walletHomeTitle => 'Wallet';

  @override
  String get walletHomeLoadingLabel => 'Loading your wallet…';

  @override
  String get walletHomeNoWalletDescription => 'Connect or restore a wallet when you need digital ownership, attribution, or participation tools.';

  @override
  String get walletHomeSignedOutTitle => 'Wallet not connected';

  @override
  String get walletHomeSignedOutDescription => 'Sign in to use your profile. Connect or restore a wallet when you want balances, digital editions, or wallet-protected actions.';

  @override
  String get walletHomeAccountShellTitle => 'Profile active, wallet not restored';

  @override
  String get walletHomeAccountShellDescription => 'Your account session is available. This device needs Wallet only for ownership and participation actions.';

  @override
  String get walletHomeRestoreWalletAction => 'Restore wallet';

  @override
  String get walletHomeCreateWalletAction => 'Create wallet';

  @override
  String get walletHomeImportWalletAction => 'Import wallet';

  @override
  String get walletHomeAlreadyConnectedToast => 'Wallet is already connected.';

  @override
  String get walletHomeTotalBalanceLabel => 'Wallet balance';

  @override
  String get walletHomeDesktopSurfaceLabel => 'Desktop wallet';

  @override
  String walletHomeAddressLabel(Object address) {
    return 'Address: $address';
  }

  @override
  String get walletHomeAddressCopiedToast => 'Address copied to clipboard!';

  @override
  String get walletHomeActionSend => 'Send';

  @override
  String get walletHomeActionReceive => 'Receive';

  @override
  String get walletHomeActionSwap => 'Swap';

  @override
  String get walletHomeActionNfts => 'Artifacts';

  @override
  String get walletHomeQuickActionsTitle => 'Wallet actions';

  @override
  String get walletHomeQuickActionsSubtitle => 'Send, receive, swap, or open digital editions from one place when wallet tools are enabled.';

  @override
  String get walletHomeSendAction => 'Send';

  @override
  String get walletHomeReceiveAction => 'Receive';

  @override
  String get walletHomeSwapAction => 'Swap';

  @override
  String get walletHomeDesktopSendSubtitle => 'Transfer tokens';

  @override
  String get walletHomeDesktopReceiveSubtitle => 'Get your address';

  @override
  String get walletHomeDesktopSwapSubtitle => 'Exchange tokens';

  @override
  String get walletHomeDesktopNftsSubtitle => 'Open digital editions and account-linked pieces';

  @override
  String get walletHomeDesktopRailSubtitle => 'Wallet status, activity, and balances stay visible while you work.';

  @override
  String get walletHomeSecureWalletAction => 'Secure wallet';

  @override
  String get availabilityNodeTitle => 'Availability Node';

  @override
  String get availabilityNodeNavTitle => 'Availability Node';

  @override
  String get availabilityNodeNavSubtitle => 'Create and manage scoped node operator tokens.';

  @override
  String get availabilityNodeSubtitle => 'Create and manage scoped node operator tokens.';

  @override
  String get availabilityNodeWhatIsTitle => 'What this does';

  @override
  String get availabilityNodeIntro => 'This token lets your node register, send heartbeats, commit to CIDs, and read recognition status. It does not control your wallet or spend funds.';

  @override
  String get availabilityNodeDescription => 'Availability nodes let trusted operators report backend availability from their own infrastructure.';

  @override
  String get availabilityNodeWalletLabel => 'Operator wallet';

  @override
  String get availabilityNodeSecurityNote => 'Store it like a password. You can revoke it at any time.';

  @override
  String get availabilityNodeCreateTitle => 'Create operator token';

  @override
  String get availabilityNodeDefaultLabel => 'Home server node';

  @override
  String get availabilityNodeLabel => 'Token label';

  @override
  String get availabilityNodeExpiry => 'Expiry';

  @override
  String availabilityNodeExpiryDaysOption(Object days) {
    return '$days days';
  }

  @override
  String get availabilityNodeExistingTokensTitle => 'Existing tokens';

  @override
  String get availabilityNodeEmptyState => 'No operator tokens yet.';

  @override
  String get availabilityNodeExpiresLabel => 'expires';

  @override
  String get availabilityNodeLastUsedLabel => 'last used';

  @override
  String get availabilityNodeCreatedTitle => 'Operator token created';

  @override
  String get availabilityNodeCreatedBody => 'Copy the token now. You will not be able to see it again.';

  @override
  String get availabilityNodeEnvSnippetLabel => '.env snippet';

  @override
  String get availabilityNodeCopyTokenButton => 'Copy token';

  @override
  String get availabilityNodeCopySnippetButton => 'Copy .env snippet';

  @override
  String get availabilityNodeTokenCopiedToast => 'Operator token copied';

  @override
  String get availabilityNodeSnippetCopiedToast => '.env snippet copied';

  @override
  String get availabilityNodeCreateFailedToast => 'Failed to create operator token';

  @override
  String get availabilityNodeConnectWalletToast => 'Connect a wallet first';

  @override
  String get availabilityNodeSigningRequiredToast => 'A wallet-signed session is required to create an operator token.';

  @override
  String get availabilityNodeRevokeTitle => 'Revoke token?';

  @override
  String availabilityNodeRevokeBody(Object label) {
    return 'Revoke \"$label\"? This token will stop working immediately.';
  }

  @override
  String get availabilityNodeStatusTitle => 'My node status';

  @override
  String get availabilityNodeNoNodeTitle => 'No node is registered yet.';

  @override
  String get availabilityNodeRunNodeCta => 'Run a node to start contributing to the public art archive.';

  @override
  String get availabilityNodeUptimeTodayLabel => 'Uptime today';

  @override
  String get availabilityNodePublicCoverageLabel => 'Public archive coverage';

  @override
  String get availabilityNodeContributionScoreLabel => 'Contribution score';

  @override
  String get availabilityNodePendingKub8Label => 'Pending KUB8';

  @override
  String get availabilityNodePublicCidsPinnedLabel => 'Public archive records pinned';

  @override
  String get availabilityNodeRewardableCidsPinnedLabel => 'Priority archive records pinned';

  @override
  String get availabilityNodeFormulaExplanation => 'Public archive replication is the base contribution. Priority archive records add bonus weight. Rewards are pending records until settlement exists.';

  @override
  String get availabilityNodeCopyGuiUrlButton => 'Copy node GUI URL';

  @override
  String get walletHomeSecurityTitle => 'Secure your wallet';

  @override
  String get walletHomeSecuritySubtitle => 'Backup, wallet access, and recovery status stay together here.';

  @override
  String get walletHomeYourTokensTitle => 'Wallet tokens';

  @override
  String get walletHomeYourTokensSubtitle => 'Balances currently associated with this wallet.';

  @override
  String get walletHomeNoTokensTitle => 'No tokens yet';

  @override
  String get walletHomeNoTokensDescription => 'Token balances will appear if this wallet receives assets.';

  @override
  String get walletHomeRecentTransactionsTitle => 'Wallet activity';

  @override
  String get walletHomeRecentTransactionsSubtitle => 'Latest wallet activity and confirmations.';

  @override
  String get walletHomeDesktopRecentActivityTitle => 'Recent activity';

  @override
  String get walletHomeDesktopTabAssets => 'Assets';

  @override
  String get walletHomeDesktopTabActivity => 'Activity';

  @override
  String get walletHomeDesktopTabNfts => 'Artifacts';

  @override
  String get walletHomeDesktopTabStaking => 'Staking';

  @override
  String get walletHomeNftLoadFailedTitle => 'Could not load digital editions';

  @override
  String get walletHomeNoCollectiblesDescription => 'Digital editions will appear here when they are linked to this wallet.';

  @override
  String walletHomeCollectibleByline(Object creator) {
    return 'by $creator';
  }

  @override
  String get walletHomeRewardsTitle => 'KUB8 recognition';

  @override
  String walletHomeRewardsDescription(Object balance) {
    return '$balance KUB8 recorded from achievements';
  }

  @override
  String get walletHomeStakeTitle => 'Fee support setup';

  @override
  String get walletHomeStakeDescription => 'Prepare SOL for future transaction fees when publishing or artifact actions require it.';

  @override
  String get walletHomeStakeAction => 'Set up support';

  @override
  String get walletHomeRefreshRatesAction => 'Refresh rates';

  @override
  String walletHomeApproxTotalValue(Object value) {
    return 'Approx. $value';
  }

  @override
  String walletHomeTimeAgoDays(Object count) {
    return '${count}d ago';
  }

  @override
  String walletHomeTimeAgoHours(Object count) {
    return '${count}h ago';
  }

  @override
  String walletHomeTimeAgoMinutes(Object count) {
    return '${count}m ago';
  }

  @override
  String get walletHomeTxSwapLabel => 'Swapped';

  @override
  String get walletHomeTxStakeLabel => 'Staked';

  @override
  String get walletHomeTxUnstakeLabel => 'Unstaked';

  @override
  String get walletHomeTxGovernanceVoteLabel => 'Governance vote';

  @override
  String get receiveTokenTitle => 'Receive tokens';

  @override
  String get receiveTokenSelectTokenTitle => 'Select token to receive';

  @override
  String receiveTokenBalanceLabel(Object amount) {
    return 'Bal. $amount';
  }

  @override
  String get receiveTokenQrError => 'QR error\nGeneration failed';

  @override
  String get receiveTokenQrRequiresWallet => 'Create or import a wallet\nto generate a QR code';

  @override
  String receiveTokenScanToSend(Object token) {
    return 'Scan to send $token';
  }

  @override
  String receiveTokenAnyoneCanSend(Object token) {
    return 'Anyone can send $token to this address';
  }

  @override
  String get receiveTokenFinishSetupToShare => 'Finish wallet setup to share your address';

  @override
  String receiveTokenYourAddressTitle(Object token) {
    return 'Your $token address';
  }

  @override
  String get receiveTokenShareAddressTooltip => 'Share address';

  @override
  String get receiveTokenCopyAddressTooltip => 'Copy address';

  @override
  String get receiveTokenRequiresWalletToReceive => 'Create or import a wallet to receive tokens';

  @override
  String get receiveTokenCopyAddressButton => 'Copy address';

  @override
  String receiveTokenHowToReceiveTitle(Object token) {
    return 'How to receive $token';
  }

  @override
  String get receiveTokenStep1Title => 'Share your address';

  @override
  String receiveTokenStep1Description(Object token) {
    return 'Send your wallet address to the person who wants to send you $token';
  }

  @override
  String get receiveTokenStep2Title => 'Or show QR code';

  @override
  String get receiveTokenStep2Description => 'Let them scan the QR code above with their wallet app';

  @override
  String get receiveTokenStep3Title => 'Receive tokens';

  @override
  String get receiveTokenStep3Description => 'Tokens will appear in your wallet once the transaction is confirmed';

  @override
  String receiveTokenWarningOnlySend(Object token) {
    return 'Only send $token and compatible tokens to this address';
  }

  @override
  String get receiveTokenNoWalletAddressToast => 'No wallet address available yet';

  @override
  String receiveTokenShareText(Object token, Object address, Object payload) {
    return 'Send $token to $address\n$payload';
  }

  @override
  String get receiveTokenNoTokensMessage => 'Connect or import a wallet to display available tokens.';

  @override
  String get receiveTokenSidebarShareTitle => 'Share your receive details';

  @override
  String get receiveTokenSidebarShareSubtitle => 'Copy the address or share the QR-ready payload.';

  @override
  String get receiveTokenSidebarShareAction => 'Share';

  @override
  String get receiveTokenSidebarActivityTitle => 'Recent inbound';

  @override
  String get receiveTokenSidebarActivitySubtitle => 'Recent counterparties can be reused or verified here.';

  @override
  String get receiveTokenSidebarNoActivityTitle => 'No inbound activity';

  @override
  String get receiveTokenSidebarNoActivityDescription => 'Incoming transfers will appear here once this wallet receives funds.';

  @override
  String receiveTokenSidebarTransferSubtitle(Object token, Object amount, Object date) {
    return '$token · $amount · $date';
  }

  @override
  String get sendTokenTitle => 'Send token';

  @override
  String get sendTokenScanQrTooltip => 'Scan QR code';

  @override
  String get sendTokenQrScannerUnavailableTooltip => 'QR scanner not available';

  @override
  String get sendTokenSelectTokenTitle => 'Select token';

  @override
  String get sendTokenRecipientAddressTitle => 'Recipient address';

  @override
  String get sendTokenRecipientAddressHint => 'Enter recipient address';

  @override
  String get sendTokenAmountTitle => 'Amount';

  @override
  String get sendTokenAmountPlaceholder => '0.0';

  @override
  String get sendTokenMaxButton => 'MAX';

  @override
  String sendTokenAvailableLabel(Object amount, Object token) {
    return 'Available: $amount $token';
  }

  @override
  String get sendTokenTransactionSummaryTitle => 'Transaction summary';

  @override
  String get sendTokenSidebarRecipientsTitle => 'Recent recipients';

  @override
  String get sendTokenSidebarRecipientsSubtitle => 'Reuse recent destinations without leaving this flow.';

  @override
  String get sendTokenSidebarNoRecipientsTitle => 'No recent recipients';

  @override
  String get sendTokenSidebarNoRecipientsDescription => 'Recent send destinations will appear here after you transfer tokens.';

  @override
  String sendTokenSidebarRecipientSubtitle(Object token, Object amount, Object date) {
    return '$token · $amount · $date';
  }

  @override
  String get sendTokenSidebarSummaryTitle => 'Send context';

  @override
  String get sendTokenSidebarSummarySubtitle => 'Review available balance, fee estimate, and destination at a glance.';

  @override
  String get sendTokenSidebarSecuritySubtitle => 'Wallet access and recovery status for this transfer.';

  @override
  String get sendTokenSummaryAmountLabel => 'Amount';

  @override
  String sendTokenSummaryFeesLabel(Object percent) {
    return 'kubus fees (~$percent%)';
  }

  @override
  String get sendTokenSummaryEstimatedDebitLabel => 'Estimated token debit';

  @override
  String get sendTokenSummaryUsdValueLabel => 'USD value';

  @override
  String get sendTokenSummaryNetworkFeeLabel => 'Network fee';

  @override
  String get sendTokenNetworkFeeNote => 'Network fees are paid in SOL. Keep a small SOL balance for gas.';

  @override
  String get sendTokenNoTokensMessage => 'Connect or create a wallet to select tokens for sending.';

  @override
  String sendTokenButtonLabel(Object token) {
    return 'Send $token';
  }

  @override
  String get sendTokenAddressRequiredError => 'Address is required';

  @override
  String get sendTokenAddressInvalidError => 'Enter a valid Solana address';

  @override
  String get sendTokenAmountRequiredError => 'Amount is required';

  @override
  String get sendTokenAmountGreaterThanZeroError => 'Amount must be greater than 0';

  @override
  String get sendTokenInsufficientBalanceError => 'Insufficient balance';

  @override
  String get sendTokenNoBalanceToast => 'No balance available for this token';

  @override
  String get sendTokenMaxAmountComputeFailedToast => 'Unable to compute max amount. Keep some balance for fees.';

  @override
  String get sendTokenQrScannerUnsupportedWeb => 'QR code scanning is not available on web browsers. Please use the mobile or desktop app for this feature.';

  @override
  String get sendTokenQrScannerUnsupportedDesktop => 'QR code scanning is not available on desktop platforms. Please use the mobile app for this feature.';

  @override
  String get sendTokenQrScannerUnsupportedPlatform => 'QR code scanning is not supported on this platform.';

  @override
  String get sendTokenQrUnreadableToast => 'Unable to read QR code payload.';

  @override
  String get sendTokenQrInvalidAddressToast => 'QR code did not include a valid address.';

  @override
  String get sendTokenQrScannedAddressLabel => 'Address scanned';

  @override
  String sendTokenQrScannedTokenLabel(Object token) {
    return 'Token: $token';
  }

  @override
  String sendTokenQrScannedAmountLabel(Object amount) {
    return 'Amount: $amount';
  }

  @override
  String get sendTokenQrScanErrorToast => 'Error scanning QR code. Please try again.';

  @override
  String sendTokenSendSuccessToast(Object amount, Object token) {
    return 'Sent $amount $token successfully';
  }

  @override
  String sendTokenSendSuccessWithSignatureToast(Object amount, Object token, Object signature) {
    return '$amount $token submitted. Tx: $signature';
  }

  @override
  String get sendTokenSendFailedToast => 'Failed to send tokens. Please try again.';

  @override
  String get sendTokenInsufficientAfterFeesToast => 'Insufficient balance after protocol fees. Reduce the amount or top up your wallet.';

  @override
  String get sendTokenNoKeypairToast => 'No wallet keypair available. Reconnect or re-import your wallet.';

  @override
  String get sendTokenInvalidAddressBeforeSendToast => 'Enter a valid Solana address before sending.';

  @override
  String get sendTokenConnectWalletBeforeSendToast => 'Connect your wallet before sending tokens.';

  @override
  String get qrScannerTitle => 'Scan QR code';

  @override
  String get qrScannerWebUnavailableTitle => 'QR scanner not available';

  @override
  String get qrScannerWebUnavailableDescription => 'Camera-based QR scanning is not supported on web browsers. Please paste or type the address manually instead.';

  @override
  String get qrScannerGoBackButton => 'Go back';

  @override
  String get qrScannerPreparingCameraLabel => 'Preparing camera…';

  @override
  String get qrScannerPermissionNeededTitle => 'Camera permission needed';

  @override
  String get qrScannerPermissionNeededDescription => 'Enable camera access to scan wallet QR codes securely.';

  @override
  String get qrScannerOpenSettingsButton => 'Open settings';

  @override
  String get qrScannerGrantCameraAccessButton => 'Grant camera access';

  @override
  String get qrScannerCameraErrorTitle => 'Camera error';

  @override
  String get qrScannerCameraErrorDescription => 'Unable to start camera. Please check permissions and try again.';

  @override
  String get qrScannerStatusAddressCapturedTitle => 'Address captured';

  @override
  String get qrScannerStatusUnsupportedQrTitle => 'Unsupported QR code';

  @override
  String get qrScannerStatusUnsupportedQrDescription => 'This QR code does not include a valid Solana address.';

  @override
  String get qrScannerStatusReadyTitle => 'Ready to scan';

  @override
  String get qrScannerStatusReadyDescription => 'Align the QR code inside the frame to capture a Solana address.';

  @override
  String get qrScannerMetaAmountLabel => 'Amount';

  @override
  String get qrScannerMetaMintLabel => 'Mint';

  @override
  String get qrScannerInvalidQrToast => 'Please scan a Solana wallet QR code.';

  @override
  String get qrScannerTorchNotSupportedToast => 'Torch toggle not supported on this device.';

  @override
  String get qrScannerSwitchCameraFailedToast => 'Unable to switch camera.';

  @override
  String get artworkNotFound => 'Artwork not found';

  @override
  String get web3DashboardComingSoon => 'Web3 dashboard - coming soon';

  @override
  String get artDetailLoadingTitle => 'Loading artwork';

  @override
  String get artDetailTitle => 'Artwork';

  @override
  String get artDetailLoadFailedMessage => 'Failed to load artwork details. Please try again.';

  @override
  String get artDetailArStatusReady => 'AR: Ready';

  @override
  String get artDetailArStatusDraft => 'AR: Draft';

  @override
  String get artDetailArStatusNeedsAttention => 'AR: Needs attention';

  @override
  String get artDetailArStatusNotSet => 'AR: Not set';

  @override
  String get artDetailScanArAction => 'Scan AR';

  @override
  String get artDetailFinishArSetupAction => 'Finish AR setup';

  @override
  String artDetailNavigateToTitle(Object title) {
    return 'Navigate to $title';
  }

  @override
  String get artDetailNavigationGoogleMaps => 'Google Maps';

  @override
  String get artDetailNavigationAppleMaps => 'Apple Maps';

  @override
  String get artDetailNavigationOtherMaps => 'Other Maps';

  @override
  String get artDetailNavigationCopyCoordinates => 'Copy coordinates';

  @override
  String get artDetailNavigationCouldNotOpenGoogleMaps => 'Could not open Google Maps';

  @override
  String get artDetailNavigationCouldNotOpenAppleMaps => 'Could not open Apple Maps';

  @override
  String get artDetailNavigationCouldNotOpenMaps => 'Could not open maps application';

  @override
  String artDetailNavigationErrorOpeningGoogleMaps(Object error) {
    return 'Error opening Google Maps: $error';
  }

  @override
  String artDetailNavigationErrorOpeningAppleMaps(Object error) {
    return 'Error opening Apple Maps: $error';
  }

  @override
  String artDetailNavigationErrorOpeningMaps(Object error) {
    return 'Error opening maps: $error';
  }

  @override
  String artDetailCoordinatesCopiedToast(Object coordinates) {
    return 'Coordinates copied to clipboard: $coordinates';
  }

  @override
  String get artDetailNavigationErrorTitle => 'Navigation error';

  @override
  String get artworkDetailLike => 'Like';

  @override
  String get artworkDetailLiked => 'Liked';

  @override
  String get artworkDetailHideComments => 'Hide comments';

  @override
  String get artworkDetailMintNft => 'Create archive record';

  @override
  String get eventCreatorNoInstitutionAvailableMessage => 'No institution is available for this event yet.';

  @override
  String get eventCreatorInstitutionLabel => 'Institution';

  @override
  String get eventCreatorSelectDateLabel => 'Select date';

  @override
  String get eventCreatorSelectTimeLabel => 'Select time';

  @override
  String get eventCreatorNotSelectedLabel => 'Not selected';

  @override
  String get eventCreatorEventTypeWorkshop => 'Workshop';

  @override
  String get eventCreatorEventTypeTalk => 'Talk';

  @override
  String get eventCreatorEventTypePerformance => 'Performance';

  @override
  String get eventCreatorEventTypeConference => 'Conference';

  @override
  String get eventCreatorEventTypeGalleryOpening => 'Gallery opening';

  @override
  String get eventCreatorEventTypeAuction => 'Auction';

  @override
  String get eventCreatorEventTypeExhibition => 'Exhibition';

  @override
  String get eventCreatorCategoryDigitalArt => 'Digital art';

  @override
  String get eventCreatorCategoryPhotography => 'Photography';

  @override
  String get eventCreatorCategorySculpture => 'Sculpture';

  @override
  String get eventCreatorCategoryMixedMedia => 'Mixed media';

  @override
  String get eventCreatorCategoryInstallation => 'Installation';

  @override
  String get eventCreatorCategoryArt => 'Art';

  @override
  String get eventCreatorHelpTitle => 'Event creator help';

  @override
  String get eventCreatorHelpBody => 'Fill in the basics, choose the date and time, then review everything before saving. Collaboration unlocks after the event is created.';

  @override
  String get eventCreatorCapacityLabel => 'Capacity';

  @override
  String get eventCreatorCapacityHint => 'Enter capacity';

  @override
  String get eventCreatorCapacityRequiredError => 'Event capacity is required';

  @override
  String get eventCreatorPriceLabel => 'Price';

  @override
  String get eventCreatorPriceHint => 'Optional ticket price';

  @override
  String get eventCreatorPublicEventTitle => 'Public event';

  @override
  String get eventCreatorPublicEventSubtitle => 'Make this event visible to everyone';

  @override
  String get eventCreatorAllowRegistrationTitle => 'Allow registration';

  @override
  String get eventCreatorAllowRegistrationSubtitle => 'Let attendees register for this event';

  @override
  String get eventCreatorReviewTitle => 'Review';

  @override
  String get eventCreatorSavedCollaborationHint => 'Event saved. You can now manage collaboration from the sidebar.';

  @override
  String get eventCreatorReviewNotice => 'Please review all details before saving.';

  @override
  String get eventCreatorBasicsTitle => 'Basics';

  @override
  String get eventCreatorTitleHint => 'Enter event title';

  @override
  String get eventCreatorTitleRequiredError => 'Event title is required';

  @override
  String get eventCreatorDescriptionHint => 'Describe the event...';

  @override
  String get eventCreatorDescriptionRequiredError => 'Event description is required';

  @override
  String get eventCreatorTitleLabel => 'Title';

  @override
  String get eventCreatorDescriptionPlaceholder => 'Describe the event...';

  @override
  String get eventCreatorEventTypeLabel => 'Event type';

  @override
  String get eventCreatorCategoryLabel => 'Category';

  @override
  String get eventCreatorDateTimeTitle => 'Date & time';

  @override
  String get eventCreatorStartDateLabel => 'Start date';

  @override
  String get eventCreatorStartTimeLabel => 'Start time';

  @override
  String get eventCreatorEndDateLabel => 'End date';

  @override
  String get eventCreatorEndTimeLabel => 'End time';

  @override
  String get eventCreatorLocationHint => 'Enter event location';

  @override
  String get eventCreatorLocationRequiredError => 'Event location is required';

  @override
  String get eventCreatorDetailsTitle => 'Details';

  @override
  String get eventCreatorReviewTypeLabel => 'Type';

  @override
  String get eventCreatorReviewCategoryLabel => 'Category';

  @override
  String get eventCreatorReviewLocationLabel => 'Location';

  @override
  String get eventCreatorLocationLabel => 'Location';

  @override
  String get eventCreatorReviewDateLabel => 'Date';

  @override
  String get eventCreatorReviewTimeLabel => 'Time';

  @override
  String get eventCreatorReviewCapacityLabel => 'Capacity';

  @override
  String get eventCreatorReviewPriceLabel => 'Price';

  @override
  String get eventCreatorReviewPublicLabel => 'Public';

  @override
  String get eventCreatorReviewRegistrationLabel => 'Registration';

  @override
  String get eventCreatorSelectStartEndDatesToast => 'Please select start and end dates';

  @override
  String get eventCreatorEnterCapacityToast => 'Please enter event capacity';

  @override
  String get eventCreatorNoInstitutionAvailableToast => 'No institution available for this event';

  @override
  String get eventCreatorSelectedInstitutionNotFoundToast => 'Selected institution not found';

  @override
  String get eventCreatorEndTimeAfterStartToast => 'End time must be after start time';

  @override
  String get eventCreatorEventUpdatedTitle => 'Event updated';

  @override
  String get eventCreatorEventCreatedTitle => 'Event created';

  @override
  String get eventCreatorEventUpdatedBody => 'Your event has been updated successfully.';

  @override
  String get eventCreatorEventCreatedBody => 'Your event has been created successfully.';

  @override
  String get eventCreatorCreateAnotherButton => 'Create another';

  @override
  String get eventCreatorSaveFailedToast => 'Failed to save event. Please try again.';

  @override
  String get eventCreatorShellEditTitle => 'Edit Event';

  @override
  String get eventCreatorShellCreateTitle => 'Create New Event';

  @override
  String get eventCreatorShellDraftSubtitle => 'Complete the wizard here, then save to unlock collaboration.';

  @override
  String get eventCreatorShellSavedSubtitle => 'Event saved. Keep refining or open collaboration from the sidebar.';

  @override
  String eventCreatorStepBadge(int step) {
    return 'Step $step of 4';
  }

  @override
  String get eventCreatorHelpTooltip => 'Help';

  @override
  String get eventCreatorReadyInstitutionLabel => 'Institution selected';

  @override
  String eventCreatorReadyInstitutionComplete(Object institutionName) {
    return 'The event will belong to $institutionName.';
  }

  @override
  String get eventCreatorReadyInstitutionPending => 'Choose the institution first.';

  @override
  String get eventCreatorReadyBasicsLabel => 'Basics complete';

  @override
  String get eventCreatorReadyBasicsDescription => 'Title, description, and event type are in place.';

  @override
  String get eventCreatorReadyDatesLabel => 'Dates selected';

  @override
  String get eventCreatorReadyDatesComplete => 'Start and end dates are set.';

  @override
  String get eventCreatorReadyDatesPending => 'Pick both dates before saving.';

  @override
  String get eventCreatorReadyCapacityLabel => 'Capacity set';

  @override
  String get eventCreatorReadyCapacityComplete => 'Registration limit is ready.';

  @override
  String get eventCreatorReadyCapacityPending => 'Add a capacity to complete the setup.';

  @override
  String get eventCreatorStatusDraftSubtitle => 'Draft in progress';

  @override
  String get eventCreatorStatusSavedSubtitle => 'Saved event';

  @override
  String get eventCreatorSummaryEventId => 'Event ID';

  @override
  String get eventCreatorSummaryNotCreatedYet => 'Not created yet';

  @override
  String get eventCreatorSummaryEventType => 'Event type';

  @override
  String get eventCreatorSummaryRegistration => 'Registration';

  @override
  String get eventCreatorReadinessTitle => 'Readiness';

  @override
  String get eventCreatorReadinessSubtitle => 'A quick sanity check before saving.';

  @override
  String get eventCreatorQuickActionsTitle => 'Quick actions';

  @override
  String get eventCreatorQuickActionsSubtitle => 'Keep the whole workflow in one workspace.';

  @override
  String get eventCreatorQuickActionNextStep => 'Next step';

  @override
  String get eventCreatorQuickActionCreateEvent => 'Create event';

  @override
  String get eventCreatorQuickActionUpdateEvent => 'Update event';

  @override
  String get eventCreatorQuickActionOpenEvent => 'Open event';

  @override
  String get eventCreatorCollaborationReadySubtitle => 'Invite collaborators without leaving the creator.';

  @override
  String get eventCreatorCollaborationLockedSubtitle => 'Save once to unlock collaboration.';

  @override
  String get eventCreatorCollaborationLockedMessage => 'Once saved, collaborators can be invited here so event planning stays in context.';

  @override
  String eventCreatorStepLabel(int step) {
    return 'Step $step of 4';
  }

  @override
  String get activityNavigationUnableToOpenToast => 'Unable to open this activity right now.';

  @override
  String navigationUnableToNavigateToScreen(Object screenName) {
    return 'Unable to navigate to $screenName';
  }

  @override
  String get arMarkerScannerDefaultArtworkTitle => 'AR artwork';

  @override
  String get arMarkerScannerInvalidQrFormatToast => 'Invalid QR code format';

  @override
  String get arMarkerScannerMissingModelUrlToast => 'QR code missing model URL';

  @override
  String arMarkerScannerByArtist(Object artist) {
    return 'By $artist';
  }

  @override
  String get arMarkerScannerLaunchViewerPrompt => 'Launch AR viewer?';

  @override
  String get arMarkerScannerLaunchFailedInstallPrompt => 'Failed to launch AR viewer. Install Google ARCore?';

  @override
  String get arMarkerScannerProcessingFailedToast => 'Failed to process QR code. Please try again.';

  @override
  String get arMarkerScannerProcessingQrLabel => 'Processing QR code…';

  @override
  String get arMarkerScannerPointCameraLabel => 'Point camera at QR code to discover AR artwork';

  @override
  String get arMarkerScannerLaunchingViewerLabel => 'Launching AR viewer…';

  @override
  String get artistGalleryTitle => 'Your gallery';

  @override
  String artistGalleryArtworkCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artworks',
      one: '1 artwork',
    );
    return '$_temp0';
  }

  @override
  String get artistGalleryStatActiveLabel => 'Active';

  @override
  String get artistGalleryStatViewsLabel => 'Views';

  @override
  String get artistGalleryStatLikesLabel => 'Likes';

  @override
  String get artistGalleryFilterAll => 'All';

  @override
  String get artistGalleryFilterActive => 'Active';

  @override
  String get artistGalleryFilterDraft => 'Draft';

  @override
  String get artistGalleryFilterSold => 'Sold';

  @override
  String get artistGallerySortByTitle => 'Sort by';

  @override
  String get artistGallerySortNewest => 'Newest';

  @override
  String get artistGallerySortOldest => 'Oldest';

  @override
  String get artistGallerySortMostViews => 'Most views';

  @override
  String get artistGallerySortMostLikes => 'Most likes';

  @override
  String get artistGallerySearchTitle => 'Search artworks';

  @override
  String get artistGallerySearchHint => 'Enter artwork title…';

  @override
  String get artistGalleryCreateNewTitle => 'Create new artwork';

  @override
  String get artistGalleryCreateNewDescription => 'Navigate to the Create tab to upload and create your new artwork.';

  @override
  String get artistGalleryGoToCreateButton => 'Go to Create';

  @override
  String get artistGalleryEmptyTitle => 'No artworks yet';

  @override
  String get artistGalleryEmptyDescription => 'Create your first artwork to get started.';

  @override
  String get artistGalleryCreateArtworkButton => 'Create artwork';

  @override
  String artistGalleryEditingToast(Object title) {
    return 'Editing $title';
  }

  @override
  String artistGallerySharingToast(Object title) {
    return 'Sharing $title';
  }

  @override
  String artistGalleryPublishSuccessToast(Object title) {
    return '\"$title\" published';
  }

  @override
  String artistGalleryUnpublishSuccessToast(Object title) {
    return '\"$title\" moved to draft';
  }

  @override
  String artistGalleryPublishFailedToast(Object title) {
    return 'Failed to publish \"$title\". Please try again.';
  }

  @override
  String artistGalleryUnpublishFailedToast(Object title) {
    return 'Failed to unpublish \"$title\". Please try again.';
  }

  @override
  String artistGalleryDeletedToast(Object title) {
    return '$title deleted';
  }

  @override
  String get artistGalleryDeleteArtworkTitle => 'Delete artwork';

  @override
  String get artistGalleryPromoteUnavailableToast => 'Only active public artworks can be promoted.';

  @override
  String artistGalleryDeleteConfirmBody(Object title) {
    return 'Are you sure you want to delete \"$title\"? This action cannot be undone.';
  }

  @override
  String get artistCreatorCreateArtworkButton => 'Create artwork';

  @override
  String get artistCreatorCoverSelectedToast => 'Cover selected';

  @override
  String get artistCreatorPickImageFailedToast => 'Failed to pick an image. Please try again.';

  @override
  String get artistCreatorModelSelectedToast => '3D model selected';

  @override
  String get artistCreatorPickModelFailedToast => 'Failed to pick a 3D model. Please try again.';

  @override
  String get artistCreatorSelectImageToast => 'Please select an image';

  @override
  String get artistCreatorConnectWalletToPublishToast => 'Connect a wallet to publish wallet-linked artwork.';

  @override
  String get artistCreatorSelectCoverImageToast => 'Please select a cover image.';

  @override
  String get artistCreatorUploadModelToEnableArToast => 'Upload a 3D model to enable AR.';

  @override
  String get artistCreatorEnterLatLngOrDisableToast => 'Enter both latitude and longitude or disable coordinates.';

  @override
  String get artistCreatorInvalidCoordinatesToast => 'Coordinates must be valid latitude/longitude values.';

  @override
  String get artistCreatorCoverUrlMissingToast => 'Upload succeeded but cover URL is missing.';

  @override
  String get artistCreatorSubmittedPendingToast => 'Artwork submitted. Backend response pending.';

  @override
  String get artistCreatorSuccessTitle => 'Success!';

  @override
  String get artistCreatorSuccessBody => 'Your artwork has been created successfully!';

  @override
  String get artistCreatorViewGalleryButton => 'View gallery';

  @override
  String get artistCreatorCreateFailedToast => 'Failed to create artwork. Please try again.';

  @override
  String get artistCreatorHelpTitle => 'AR marker creation';

  @override
  String get artistCreatorHelpBody => 'Follow the 4-step process to create your AR artwork:\n\n1. Upload: Select your artwork image\n2. Details: Enter title, description, and pricing\n3. Settings: Configure location and features\n4. Review: Confirm and publish your artwork';

  @override
  String get artistStudioTitle => 'Artist Studio';

  @override
  String get artistStudioHeaderWelcome => 'Welcome to your Studio';

  @override
  String get artistStudioHeaderSubtitle => 'Create AR markers for your artwork and share them with the world';

  @override
  String get artistStudioInstitutionRoleActiveTitle => 'Institution role active';

  @override
  String get artistStudioInstitutionReviewInProgressTitle => 'Institution review in progress';

  @override
  String get artistStudioInstitutionRoleActiveDescription => 'Institution accounts can view exhibitions and events but cannot maintain artist applications. Use a dedicated artist wallet to create artworks.';

  @override
  String get artistStudioInstitutionReviewInProgressDescription => 'You have an institution application pending. Complete or withdraw it before switching to an artist review.';

  @override
  String get artistStudioCrossRoleInstitutionBadgeActiveTitle => 'Institution badge active';

  @override
  String get artistStudioCrossRoleInstitutionBadgeActiveDescription => 'Institution accounts unlock curation & event tooling. Use a dedicated artist wallet if you need creator utilities.';

  @override
  String get artistStudioCrossRoleInstitutionReviewInProgressTitle => 'Institution review in progress';

  @override
  String get artistStudioCrossRoleInstitutionReviewInProgressDescription => 'You currently have an institution application pending. Complete that process or request a review reset before applying as an artist.';

  @override
  String get artistStudioCrossRoleConflictTitle => 'Role conflict detected';

  @override
  String get artistStudioCrossRoleConflictDescription => 'We detected an existing institution record for this wallet. Clear it from settings before applying as an artist.';

  @override
  String get artistStudioDaoCardTitle => 'Artist application (governance review)';

  @override
  String get artistStudioDaoCardSubtitle => 'Submit your practice for governance review. This is how art.kubus opens artist tools while keeping the platform community-led.';

  @override
  String get artistStudioDaoStatusApproved => 'APPROVED';

  @override
  String get artistStudioDaoStatusPending => 'PENDING';

  @override
  String get artistStudioDaoStatusRejected => 'REJECTED';

  @override
  String get artistStudioDaoStatusNotApplied => 'NOT APPLIED';

  @override
  String get artistStudioStatusSyncedFromDao => 'Status synced from governance review';

  @override
  String get artistStudioReviewPendingInfo => 'Your submission is in the governance review queue. We will let you know when the review is complete.';

  @override
  String get artistStudioReviewApprovedInfo => 'Your practice has been approved through governance review. Studio tools are ready.';

  @override
  String get artistStudioReviewRejectedInfo => 'Your last submission was rejected. You can resubmit with updates.';

  @override
  String get artistStudioConnectWalletToSubmitForDaoReview => 'Connect a wallet before submitting for governance review.';

  @override
  String get artistStudioCtaConnectWalletToApply => 'Connect a wallet to apply';

  @override
  String get artistStudioCtaApprovedByDao => 'Approved by governance review';

  @override
  String get artistStudioCtaPendingDaoReview => 'Pending governance review';

  @override
  String get artistStudioCtaResubmitForReview => 'Resubmit for review';

  @override
  String get artistStudioCtaApplyForDaoReview => 'Apply for governance review';

  @override
  String get artistPromotionRequiresWalletReason => 'Connect an approved artist wallet to request profile promotion.';

  @override
  String get artistPromotionConflictWithInstitutionReason => 'Institution wallets cannot self-serve artist promotion. Use a dedicated artist wallet.';

  @override
  String get artistPromotionRequiresApprovalReason => 'Profile promotion is available only for approved artist wallets.';

  @override
  String get artistStudioPromoteAction => 'Promote';

  @override
  String get artistStudioPromoteTooltip => 'Promote artist profile';

  @override
  String get artistStudioPromoteArtwork => 'Promote artwork';

  @override
  String get artistStudioPromoteProfile => 'Promote profile';

  @override
  String get artistStudioPromoteCollection => 'Promote collection';

  @override
  String get artistStudioPromoteComingSoon => 'Promotion tools are coming soon.';

  @override
  String get artistStudioTabGallery => 'Gallery';

  @override
  String get artistStudioTabCreate => 'Create';

  @override
  String get artistStudioTabExhibitions => 'Exhibitions';

  @override
  String get artistStudioTabAnalytics => 'Analytics';

  @override
  String get artistStudioUnlocksAfterDaoApprovalToast => 'Artist Studio unlocks after governance review approval.';

  @override
  String get artistStudioSeparateWalletsTip => 'Use separate wallets for artist and institution roles if you want to keep access and review paths clearly separated.';

  @override
  String get artistStudioLockedTitle => 'Artist Studio is locked';

  @override
  String get artistStudioLockedDescription => 'Apply for governance review to unlock studio tools for publishing, showcasing, and tracking your work.';

  @override
  String get artistStudioSettingsTitle => 'Studio Settings';

  @override
  String get artistStudioApplicationModalTitle => 'Artist application';

  @override
  String get artistStudioApplicationModalSubtitle => 'Share a snapshot of your practice. Submissions are routed to the governance review queue.';

  @override
  String get artistStudioApplicationFieldPortfolioLabel => 'Portfolio or website';

  @override
  String get artistStudioApplicationFieldMediumLabel => 'Primary medium or focus';

  @override
  String get artistStudioApplicationFieldStatementLabel => 'Artist statement';

  @override
  String get artistStudioApplicationValidationPortfolio => 'Please provide a link to your work';

  @override
  String get artistStudioApplicationValidationMedium => 'Let reviewers know what you create';

  @override
  String artistStudioApplicationValidationStatementMinChars(Object min) {
    return 'Share at least $min characters about your work';
  }

  @override
  String get artistStudioApplicationWalletRequiredToast => 'Connect a wallet before submitting for review.';

  @override
  String get artistStudioApplicationReviewTitle => 'Artist application';

  @override
  String get artistStudioApplicationSubmittedToast => 'Application submitted to governance reviewers.';

  @override
  String get artistStudioApplicationUnableToSubmitToast => 'Unable to submit application right now.';

  @override
  String get artistStudioApplicationSubmissionFailedToast => 'Submission failed. Please try again.';

  @override
  String get artistStudioApplicationSubmitButton => 'Submit application';

  @override
  String get desktopArtistStudioOverviewTitle => 'Studio Overview';

  @override
  String get desktopArtistStudioQuickActionsTitle => 'Quick Actions';

  @override
  String get desktopArtistStudioQuickActionInvitesTitle => 'Invites';

  @override
  String get desktopArtistStudioQuickActionInvitesSubtitle => 'View collaboration invites';

  @override
  String get desktopArtistStudioQuickActionInvitesPendingSubtitle => 'You have pending collaboration invites';

  @override
  String get desktopArtistStudioQuickActionCollaborationInvitesTitle => 'Collaboration Invites';

  @override
  String get desktopArtistStudioQuickActionExhibitionsTitle => 'My Exhibitions';

  @override
  String get desktopArtistStudioQuickActionExhibitionsSubtitle => 'View exhibitions you collaborate on';

  @override
  String get desktopArtistStudioQuickActionCreateArtworkTitle => 'Create Artwork';

  @override
  String get desktopArtistStudioQuickActionCreateArtworkSubtitle => 'Upload and publish new work';

  @override
  String get desktopArtistStudioQuickActionMyGalleryTitle => 'My Gallery';

  @override
  String get desktopArtistStudioQuickActionMyGallerySubtitle => 'View all artworks';

  @override
  String get desktopArtistStudioQuickActionAnalyticsTitle => 'Analytics';

  @override
  String get desktopArtistStudioQuickActionAnalyticsSubtitle => 'View performance stats';

  @override
  String get desktopArtistStudioStatisticsTitle => 'Studio Statistics';

  @override
  String get desktopArtistStudioRecentActivityTitle => 'Recent Activity';

  @override
  String get desktopArtistStudioNoRecentActivityLabel => 'No recent activity';

  @override
  String get desktopArtistStudioPromoteProfileTitle => 'Promote Profile';

  @override
  String get desktopArtistStudioPromoteProfileSubtitle => 'Boost profile visibility with priority placement';

  @override
  String get desktopArtistStudioCreatorWorkspaceSubtitle => 'Open a dedicated creator workspace and stay in flow.';

  @override
  String get desktopArtistStudioMyProfile => 'my profile';

  @override
  String get desktopArtistStudioVerificationNotAppliedTitle => 'Not Applied';

  @override
  String get desktopArtistStudioVerificationNotAppliedDescription => 'Apply for artist verification';

  @override
  String get desktopArtistStudioVerificationLoadingTitle => 'Loading…';

  @override
  String get desktopArtistStudioVerificationLoadingDescription => 'Checking verification status';

  @override
  String get desktopArtistStudioVerificationApprovedTitle => 'Verified Artist';

  @override
  String get desktopArtistStudioVerificationApprovedDescription => 'Your studio is verified';

  @override
  String get desktopArtistStudioVerificationPendingTitle => 'Pending Review';

  @override
  String get desktopArtistStudioVerificationPendingDescription => 'Application under review';

  @override
  String get desktopArtistStudioVerificationRejectedTitle => 'Application Rejected';

  @override
  String get desktopArtistStudioVerificationRejectedDescription => 'Please resubmit with improvements';

  @override
  String get desktopArtistStudioApplyForVerificationButton => 'Apply for Verification';

  @override
  String get desktopArtistStudioStatArtworks => 'Artworks';

  @override
  String get desktopArtistStudioStatViews => 'Views';

  @override
  String get desktopArtistStudioStatLikes => 'Likes';

  @override
  String get desktopArtistStudioStatSales => 'Sales';

  @override
  String get desktopInstitutionPromotionWalletRequiredReason => 'Connect a wallet to create promotions.';

  @override
  String get desktopInstitutionPromotionArtistConflictReason => 'This wallet is verified as an artist. Use an institution wallet to promote institution content.';

  @override
  String get desktopInstitutionPromotionRequiresApprovalReason => 'Institution approval is required before creating promotions.';

  @override
  String get desktopInstitutionPromoteProfileTitle => 'Promote Institution';

  @override
  String get desktopInstitutionPromoteProfileSubtitle => 'Boost institution visibility with priority placement';

  @override
  String get desktopInstitutionCreatorWorkspaceSubtitle => 'Launch institution creator workspaces as dedicated desktop flows.';

  @override
  String get desktopInstitutionCreateEventTitle => 'Create Event';

  @override
  String get desktopInstitutionCreateEventSubtitle => 'Schedule and publish institution events';

  @override
  String get desktopInstitutionCreateExhibitionSubtitle => 'Create a curated exhibition experience';

  @override
  String get desktopInstitutionManageEventsTitle => 'Manage Events';

  @override
  String get desktopInstitutionManageEventsSubtitle => 'Edit upcoming events and attendance details';

  @override
  String get desktopInstitutionMyExhibitionsTitle => 'My Exhibitions';

  @override
  String get desktopInstitutionMyExhibitionsSubtitle => 'Review and update institution exhibitions';

  @override
  String get desktopInstitutionStatsTitle => 'Institution Stats';

  @override
  String get desktopInstitutionVerificationNotAppliedTitle => 'Not Applied';

  @override
  String get desktopInstitutionVerificationNotAppliedDescription => 'Apply for institution verification';

  @override
  String get desktopInstitutionVerificationApprovedDescription => 'Your institution is verified';

  @override
  String get desktopInstitutionVerificationPendingDescription => 'Application under review';

  @override
  String get desktopInstitutionVerificationApplyHint => 'Verification unlocks institution publishing tools and promotions.';

  @override
  String get desktopInstitutionStatVisitors => 'Visitors';

  @override
  String get desktopInstitutionStatRevenue => 'Revenue';

  @override
  String get desktopInstitutionNoUpcomingEventsLabel => 'No upcoming events';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonNow => 'Now';

  @override
  String get commonNotAvailableShort => 'N/A';

  @override
  String get eventManagerTitle => 'Event Manager';

  @override
  String get eventManagerSubtitle => 'Manage your institution\'s events';

  @override
  String get eventManagerStatTotalEvents => 'Total events';

  @override
  String get eventManagerStatActiveNow => 'Active now';

  @override
  String get eventManagerStatRegistrations => 'Registrations';

  @override
  String get eventManagerEmptyTitle => 'No events found';

  @override
  String get eventManagerEmptyDescription => 'Create your first event to get started';

  @override
  String eventManagerOccupancyLabel(Object current, Object capacity) {
    return 'Occupancy: $current/$capacity';
  }

  @override
  String eventManagerAttendeesLabel(Object count) {
    return 'Attendees: $count';
  }

  @override
  String get eventManagerStatusUpcoming => 'UPCOMING';

  @override
  String get eventManagerStatusActive => 'ACTIVE';

  @override
  String get eventManagerStatusCompleted => 'COMPLETED';

  @override
  String get eventManagerFilterAll => 'All';

  @override
  String get eventManagerFilterUpcoming => 'Upcoming';

  @override
  String get eventManagerFilterActive => 'Active';

  @override
  String get eventManagerFilterCompleted => 'Completed';

  @override
  String get eventManagerOptionsSubtitle => 'Choose what to do with this event';

  @override
  String eventManagerCapacityAlert(Object title, Object percent) {
    return '\"$title\" capacity at $percent%';
  }

  @override
  String eventManagerStartsSoonAlert(Object title, int hours) {
    return '\"$title\" starts in ${hours}h';
  }

  @override
  String get eventManagerSoonLabel => 'Soon';

  @override
  String get eventManagerNoAlerts => 'No alerts right now.';

  @override
  String get eventManagerSearchTitle => 'Search Events';

  @override
  String get eventManagerSearchHint => 'Enter event name or keyword...';

  @override
  String get eventManagerDeleteTitle => 'Delete Event';

  @override
  String eventManagerDeleteBody(Object title) {
    return 'Are you sure you want to delete \"$title\"? This action cannot be undone.';
  }

  @override
  String eventManagerDeletedToast(Object title) {
    return '$title deleted';
  }

  @override
  String get collabRoleLabel => 'Role';

  @override
  String get collabRoleViewer => 'Viewer';

  @override
  String get collabRoleCurator => 'Curator';

  @override
  String get collabRoleEditor => 'Editor';

  @override
  String get collabRolePublisher => 'Publisher';

  @override
  String get collabRoleAdmin => 'Admin';

  @override
  String get exhibitionListDisabledTitle => 'Exhibitions are not enabled';

  @override
  String get exhibitionListDisabledSubtitle => 'This feature is currently disabled.';

  @override
  String get exhibitionListMyExhibitionsTab => 'My Exhibitions';

  @override
  String get exhibitionListCollaboratingTab => 'Collaborating';

  @override
  String get exhibitionListCreateTitle => 'Create Exhibition';

  @override
  String get exhibitionListCreateSubtitle => 'Curate artworks and invite collaborators';

  @override
  String get exhibitionListCreateNewButton => 'New';

  @override
  String get exhibitionListEmptyMineTitle => 'No exhibitions yet';

  @override
  String get exhibitionListEmptyMineDescriptionCanCreate => 'Create your first exhibition to showcase artworks and invite collaborators.';

  @override
  String get exhibitionListEmptyMineDescriptionReadonly => 'Your hosted exhibitions will appear here.';

  @override
  String get exhibitionListRoleHost => 'Host';

  @override
  String get exhibitionListEmptyCollaboratingTitle => 'No collaborations yet';

  @override
  String get exhibitionListEmptyCollaboratingDescription => 'When someone invites you to collaborate on an exhibition, it will appear here.';

  @override
  String get exhibitionListRoleCollaborator => 'Collaborator';

  @override
  String get collabPanelNoInvitePermission => 'You do not have permission to invite collaborators.';

  @override
  String get collabPanelEnterUsernameOrEmail => 'Enter a username or email.';

  @override
  String get collabPanelUseUsernameOrEmail => 'Use a username or email to invite someone.';

  @override
  String get collabPanelInviteSent => 'Invite sent.';

  @override
  String get collabPanelInviteFailed => 'Could not send invite. Try again.';

  @override
  String get collabPanelRoleUpdated => 'Role updated.';

  @override
  String get collabPanelRoleUpdateFailed => 'Could not update role.';

  @override
  String get collabPanelRemoveConfirmTitle => 'Remove collaborator?';

  @override
  String collabPanelRemoveConfirmBody(Object name) {
    return 'This will revoke access for $name.';
  }

  @override
  String get collabPanelGenericUser => 'this person';

  @override
  String get collabPanelRemoved => 'Removed.';

  @override
  String get collabPanelRemoveFailed => 'Could not remove collaborator.';

  @override
  String get collabPanelLoadFailed => 'Could not load collaborators.';

  @override
  String get collabPanelNoCollaborators => 'No collaborators yet.';

  @override
  String get collabPanelInviteTitle => 'Invite someone';

  @override
  String get collabPanelUsernameOrEmailHint => 'Username or email';

  @override
  String get collabPanelInviteHint => 'Invite collaborators by username or email.';

  @override
  String marketplaceNetworkLabel(Object network) {
    return 'Network: $network';
  }

  @override
  String marketplaceWalletLabel(Object wallet) {
    return 'Wallet: $wallet';
  }

  @override
  String get marketplaceConnectWalletTitle => 'Wallet connection';

  @override
  String get marketplaceConnectWalletDescription => 'Connect a Solana wallet to view digital editions linked to your account.';

  @override
  String get marketplaceSettingsShowArOnlyTitle => 'Show AR-only collections';

  @override
  String get marketplaceSettingsShowArOnlyDescription => 'Filter collections that require AR interaction.';

  @override
  String get marketplaceFeaturedTab => 'Featured';

  @override
  String get marketplaceTrendingTab => 'Trending';

  @override
  String get marketplaceMyListingsTab => 'My listings';

  @override
  String get marketplaceFeaturedCollectionsTitle => 'Featured collections';

  @override
  String get marketplaceFeaturedCollectionsSubtitle => 'Curated digital editions and AR-ready series from the community.';

  @override
  String get marketplaceNoMintedNftsTitle => 'No digital editions available yet';

  @override
  String get marketplaceNoMintedNftsDescription => 'Listings appear once an artwork is issued as a digital cultural object.';

  @override
  String get marketplaceTrendingThisWeekTitle => 'Active this week';

  @override
  String get marketplaceTrendingThisWeekSubtitle => 'Artifacts with recent community attention.';

  @override
  String get marketplaceNoTrendingNftsTitle => 'No active artifacts yet';

  @override
  String get marketplaceNoTrendingNftsDescription => 'Check back later as cultural artifact activity grows.';

  @override
  String get marketplaceMyCollectionTitle => 'My digital editions';

  @override
  String marketplaceMyCollectionCount(Object count) {
    return '$count artifacts';
  }

  @override
  String get marketplaceListedForSaleTitle => 'Available listing';

  @override
  String get marketplaceListNftForSaleTitle => 'List digital edition';

  @override
  String get marketplacePriceKub8Label => 'Price (KUB8)';

  @override
  String get marketplaceDetailCollectionLabel => 'Collection';

  @override
  String get marketplaceDetailArtworkLabel => 'Artwork';

  @override
  String get marketplaceTokenIdLabel => 'Token ID';

  @override
  String get marketplaceMintedLabel => 'Issued as digital edition';

  @override
  String get marketplaceTotalSupplyLabel => 'Total supply';

  @override
  String get marketplaceRarityLabel => 'Rarity';

  @override
  String get marketplaceOwnedNftStatus => 'Owned artifact';

  @override
  String get marketplaceOwnedNftListedStatus => 'Owned artifact - Listed';

  @override
  String get marketplaceEmptyCollectionTitle => 'No digital editions yet';

  @override
  String get marketplaceEmptyCollectionDescription => 'Create digital editions from artworks and keep them here.';

  @override
  String get marketplaceExploreArArtButton => 'Explore art map';

  @override
  String get marketplaceListForSaleButton => 'List artifact';

  @override
  String get marketplaceListForSaleSuccessToast => 'Listed for sale.';

  @override
  String get marketplaceListForSaleFailedToast => 'Unable to list artifact right now.';

  @override
  String get marketplaceRemoveFromSaleTitle => 'Remove from sale';

  @override
  String get marketplaceRemoveFromSaleConfirmBody => 'Remove this digital edition from listings?';

  @override
  String get marketplaceRemoveFromSaleSuccessToast => 'Artifact removed from listing.';

  @override
  String get marketplaceMintConnectWalletTitle => 'Wallet required for digital editions';

  @override
  String get marketplaceMintConnectWalletDescription => 'Connect a wallet only if you want to create digital cultural artifacts from artworks.';

  @override
  String get marketplaceMintSuccessTitle => 'Digital artifact created';

  @override
  String get marketplaceMintSuccessDescription => 'Your digital edition is ready. You can view it in your wallet.';

  @override
  String get marketplaceViewInWalletButton => 'View in wallet';

  @override
  String get marketplaceMintFailedTitle => 'Creation failed';

  @override
  String get marketplaceMintFailedDescription => 'The digital edition could not be created right now. Please try again.';

  @override
  String get marketplaceArBadgeLabel => 'AR';

  @override
  String get marketplaceListedForLabel => 'Listed for';

  @override
  String get marketplaceOwnedLabel => 'Owned';

  @override
  String get marketplacePropertiesTitle => 'Properties';

  @override
  String get marketplaceSoldOutBadgeLabel => 'SOLD OUT';

  @override
  String get marketplaceCardActionListed => 'Listed';

  @override
  String get marketplaceCardActionMint => 'Mint';

  @override
  String get marketplaceCardActionView => 'View';

  @override
  String get marketplaceNftArtworkStatus => 'Digital edition artwork';

  @override
  String get marketplaceNftArtworkStatusArEnabled => 'Digital edition artwork - AR enabled';

  @override
  String get marketplaceMintUnavailableLabel => 'Mint unavailable';

  @override
  String get marketplaceSoldOutLabel => 'Sold out';

  @override
  String get marketplaceMintNftButtonLabel => 'Create artifact';

  @override
  String get marketplaceArRequiredTitle => 'Location visit required';

  @override
  String get marketplaceArRequiredDescription => 'This artifact requires interaction with the physical artwork location. Visit the artwork and use the AR scanner if the artist enabled it.';

  @override
  String get marketplaceGoToArButton => 'Go to AR';

  @override
  String get marketplaceMintDialogTitle => 'Create digital edition';

  @override
  String marketplaceMintConfirmCollectionDescription(Object collection) {
    return 'You are creating a digital edition from the \"$collection\" collection.';
  }

  @override
  String get marketplaceMintPriceLabel => 'Mint price:';

  @override
  String get marketplaceConfirmMintButton => 'Confirm Mint';

  @override
  String marketplaceTokenNumberLabel(String tokenId) {
    return 'Token #$tokenId';
  }

  @override
  String get marketplaceHelpTooltip => 'Marketplace help';

  @override
  String get marketplaceSettingsTooltip => 'Marketplace settings';

  @override
  String marketplaceOpenSeriesDetailsSemantic(Object title) {
    return 'Open details for $title';
  }

  @override
  String marketplaceOpenCollectibleDetailsSemantic(Object title, Object tokenId) {
    return 'Open details for $title, token $tokenId';
  }

  @override
  String get marketplaceShareTooltip => 'Share collection';

  @override
  String get marketplaceListForSaleTooltip => 'List for sale';

  @override
  String get marketplaceRemoveFromSaleTooltip => 'Remove from sale';

  @override
  String get marketplaceRemoveFromSaleFailedToast => 'Unable to remove this digital edition from listing right now.';

  @override
  String get marketplaceValueNotListedLabel => 'Not listed';

  @override
  String get marketplaceValueLastSaleLabel => 'Last sale';

  @override
  String get marketplaceValueMintPriceLabel => 'Mint price';

  @override
  String get marketplaceOwnedCollectionTitle => 'Owned collection';

  @override
  String get marketplaceOwnedCollectionSubtitle => 'Digital editions currently held by this wallet.';

  @override
  String get marketplaceListedForSaleSubtitle => 'Digital editions currently visible to marketplace buyers.';

  @override
  String get marketplaceArOnlyFilterActiveLabel => 'AR only';

  @override
  String get marketplaceArOnlyFilterInactiveLabel => 'All mints';

  @override
  String marketplaceListingDialogDescription(Object title) {
    return 'Set a KUB8 sale price for $title.';
  }

  @override
  String get marketplacePriceRequiredError => 'Enter a price.';

  @override
  String get marketplacePriceInvalidError => 'Enter a price greater than 0.';

  @override
  String get marketplacePropertyMintTimestampLabel => 'Issued at';

  @override
  String get marketplacePropertyMintedByLabel => 'Issued by';

  @override
  String get marketplaceNftCollectibleLabel => 'Digital edition';

  @override
  String get collectibleRarityCommon => 'Common';

  @override
  String get collectibleRarityUncommon => 'Uncommon';

  @override
  String get collectibleRarityRare => 'Rare';

  @override
  String get collectibleRarityEpic => 'Epic';

  @override
  String get collectibleRarityLegendary => 'Legendary';

  @override
  String get collectibleRarityMythic => 'Mythic';

  @override
  String get collectibleStatusMinted => 'Issued as archive record';

  @override
  String get collectibleStatusListed => 'Listed';

  @override
  String get collectibleStatusSold => 'Sold';

  @override
  String get collectibleStatusTransferred => 'Transferred';

  @override
  String get collectibleStatusBurned => 'Burned';

  @override
  String get communityPostingFeatureLabel => 'Posting';

  @override
  String get daoModerationApproveLabel => 'Approve';

  @override
  String get daoModerationRejectLabel => 'Reject';

  @override
  String get daoModerationSetPendingLabel => 'Set pending';

  @override
  String daoModerationDecisionDialogTitle(Object decision) {
    return '$decision submission?';
  }

  @override
  String get daoModerationDecisionDialogDescription => 'Provide optional reviewer notes for the applicant.';

  @override
  String get daoModerationReviewerNotesLabel => 'Reviewer notes (optional)';

  @override
  String get daoReviewStatusApproved => 'Approved';

  @override
  String get daoReviewStatusRejected => 'Rejected';

  @override
  String get daoReviewStatusPending => 'Pending';

  @override
  String get daoReviewStatusInReview => 'In review';

  @override
  String get daoModerationDisabledToast => 'Review moderation is disabled.';

  @override
  String get daoModerationWalletRequiredToast => 'Connect a wallet to moderate submissions.';

  @override
  String get daoModerationSelfNotAllowedToast => 'You cannot moderate your own submission.';

  @override
  String get daoModerationSubmissionApprovedToast => 'Submission approved';

  @override
  String get daoModerationSubmissionUpdatedToast => 'Submission updated';

  @override
  String get daoModerationNoChangesSavedToast => 'No changes saved';

  @override
  String get daoModerationUpdateFailedToast => 'Unable to update review right now.';

  @override
  String get daoReviewDetailsVotingDisabledForApplicant => 'Voting disabled for the applicant profile.';

  @override
  String get daoReviewDetailsVotingDisabledForSubmission => 'Voting is disabled for this submission.';

  @override
  String get daoReviewDetailsVotingManagedByDao => 'Review decisions are managed by the DAO review process.';

  @override
  String get daoReviewQueueTitle => 'Governance review queue';

  @override
  String get daoReviewVotingHandledByDaoHelper => 'Voting is handled directly by the DAO; use proposals to decide.';

  @override
  String get daoReviewCannotVoteOwnSubmissionHelper => 'You cannot vote on your own submission';

  @override
  String get daoReviewVotingDisabledSubmissionHelper => 'Voting is disabled for this submission';

  @override
  String get daoReviewVotingOpensAfterReviewHelper => 'Voting opens after review';

  @override
  String daoReviewDecisionRecordedHelper(Object status) {
    return 'Decision recorded: $status';
  }

  @override
  String get daoReviewMediumNotProvided => 'Medium not provided';

  @override
  String get daoReviewViewDetailsButton => 'View details';

  @override
  String get daoReviewDetailsDialogTitle => 'Review submission';

  @override
  String daoReviewDetailsPortfolioLabel(Object url) {
    return 'Portfolio: $url';
  }

  @override
  String daoReviewDetailsMediumLabel(Object medium) {
    return 'Medium: $medium';
  }

  @override
  String daoReviewDetailsStatusLabel(Object status) {
    return 'Status: $status';
  }

  @override
  String get daoReviewDetailsReviewerNotesLabel => 'Reviewer notes:';

  @override
  String get daoProposalCategoryLabel => 'Category';

  @override
  String get daoCategoryPlatformUpdate => 'Platform update';

  @override
  String get daoCategoryNewFeature => 'New feature';

  @override
  String get daoCategoryPolicyChange => 'Policy change';

  @override
  String get daoCategoryTreasuryAllocation => 'Treasury allocation';

  @override
  String get daoCategoryCommunityInitiative => 'Community initiative';

  @override
  String get daoCategoryTechnicalImprovement => 'Technical improvement';

  @override
  String get daoProposalTypePlatformUpdate => 'Platform update';

  @override
  String get daoProposalTypeRewards => 'Rewards';

  @override
  String get daoProposalTypeFeatureRequest => 'Feature request';

  @override
  String get daoProposalTypeGovernance => 'Governance';

  @override
  String get daoProposalTypeCommunity => 'Community';

  @override
  String get daoProposalRequirementsTitle => 'Proposal Requirements';

  @override
  String get daoProposalRequirementWalletConnected => 'Wallet connection required to submit';

  @override
  String get daoProposalRequirementClearlyDefined => 'Proposal must be clearly defined';

  @override
  String get daoProposalRequirementVotingPeriod => 'Voting period: 3-14 days';

  @override
  String get daoProposalRequirementQuorumTargets => 'Quorum targets are enforced by DAO config';

  @override
  String get daoProposalFillRequiredFieldsToast => 'Please fill in all required fields';

  @override
  String get daoProposalWalletRequiredToast => 'Connect a wallet to submit proposals.';

  @override
  String get daoProposalSubmittedToast => 'Proposal submitted to DAO';

  @override
  String get daoProposalSubmitFailedToast => 'Unable to submit proposal right now.';

  @override
  String get daoQuorumReached => 'Quorum reached';

  @override
  String get daoQuorumPending => 'Quorum pending';

  @override
  String get daoVoteWalletRequiredToast => 'Connect a wallet before voting.';

  @override
  String get daoVoteSubmittedYesToast => 'Vote Yes submitted';

  @override
  String get daoVoteSubmittedNoToast => 'Vote No submitted';

  @override
  String get daoVoteSubmitFailedToast => 'Unable to submit vote right now.';

  @override
  String get daoVoteYesButton => 'Vote Yes';

  @override
  String get daoVoteNoButton => 'Vote No';

  @override
  String daoProposalVotesYesLabel(Object count) {
    return 'Yes: $count';
  }

  @override
  String daoProposalVotesNoLabel(Object count) {
    return 'No: $count';
  }

  @override
  String daoProposalVotesAbstainLabel(Object count) {
    return 'Abstain: $count';
  }

  @override
  String get daoVotingHistoryUnknownProposal => 'Unknown Proposal';

  @override
  String get daoVoteChoiceYes => 'Yes';

  @override
  String get daoVoteChoiceNo => 'No';

  @override
  String get daoVoteChoiceAbstain => 'Abstain';

  @override
  String get daoVotingResultPassing => 'Passing';

  @override
  String get daoVotingResultNotPassing => 'Not Passing';

  @override
  String daoVotingHistoryYourPowerLabel(Object power) {
    return 'Your power: $power';
  }

  @override
  String get daoVotingHistoryEmptyTitle => 'No voting history yet';

  @override
  String get daoVotingHistoryEmptyDescription => 'Cast your first vote on an active proposal';

  @override
  String get daoActiveProposalsEmptyTitle => 'No active proposals';

  @override
  String get daoActiveProposalsEmptyDescription => 'Submit a proposal or review to get governance moving.';

  @override
  String get daoTreasuryTitle => 'DAO Treasury';

  @override
  String get daoTreasurySubtitle => 'Community-controlled funds for platform development';

  @override
  String get daoTreasuryInflowLabel => 'Inflow';

  @override
  String get daoTreasuryOutflowLabel => 'Outflow';

  @override
  String get daoTreasuryProposalsLabel => 'Proposals';

  @override
  String get daoRecentTransactionsTitle => 'Recent Transactions';

  @override
  String get daoRecentTransactionsEmptyTitle => 'No recent transactions';

  @override
  String get daoRecentTransactionsEmptyDescription => '';

  @override
  String commonTimeAgoDays(Object count) {
    return '${count}d ago';
  }

  @override
  String commonTimeAgoHours(Object count) {
    return '${count}h ago';
  }

  @override
  String commonTimeAgoMinutes(Object count) {
    return '${count}m ago';
  }

  @override
  String get daoTreasuryProposalsEmptyTitle => 'No treasury proposals yet';

  @override
  String get daoTreasuryProposalsEmptyDescription => 'Create a treasury request to allocate KUB8 to initiatives.';

  @override
  String get daoTreasuryProposalsTitle => 'Treasury Proposals';

  @override
  String get daoCreateProposalButton => 'Create proposal';

  @override
  String get daoVoteDelegationTitle => 'Vote Delegation';

  @override
  String get daoVoteDelegationSubtitle => 'Delegate your voting power to trusted community members';

  @override
  String get daoTopDelegatesTitle => 'Top Delegates';

  @override
  String get daoTopDelegatesEmptyTitle => 'No delegates yet';

  @override
  String get daoTopDelegatesEmptyDescription => 'No delegates have been registered yet.';

  @override
  String get daoDelegateActiveLabel => 'Active';

  @override
  String get daoTapToDelegateHint => 'Tap to delegate';

  @override
  String get daoDelegationActionsTitle => 'Delegation Actions';

  @override
  String get daoDelegationActionsSubtitle => 'Choose how to use your voting power';

  @override
  String get daoDelegateToTrustedMembersButton => 'Delegate to Trusted Members';

  @override
  String get daoSelfDelegateButton => 'Self Delegate';

  @override
  String get daoRevokeButton => 'Revoke';

  @override
  String get daoDelegateVotingPowerDialogTitle => 'Delegate Voting Power';

  @override
  String daoDelegateVotingPowerDialogBody(Object votingPower, Object delegateName) {
    return 'Are you sure you want to delegate your $votingPower voting power to $delegateName?';
  }

  @override
  String get daoDelegationBenefitsTitle => 'Delegation Benefits';

  @override
  String get daoDelegationBenefitsBody => '• Your delegate will vote on your behalf\n• You can revoke delegation anytime\n• Your voting power remains yours';

  @override
  String get daoConfirmDelegationButton => 'Confirm Delegation';

  @override
  String daoDelegationSuccessToast(Object delegateName) {
    return 'Voting power successfully delegated to $delegateName';
  }

  @override
  String get daoViewDelegationDetailsAction => 'View Details';

  @override
  String get daoDelegationActiveTitle => 'Delegation Active';

  @override
  String get daoDelegationDetailDelegateLabel => 'Delegate';

  @override
  String get daoDelegationDetailVotingPowerLabel => 'Voting Power';

  @override
  String get daoDelegationDetailStatusLabel => 'Status';

  @override
  String get daoDelegationDetailStartedLabel => 'Started';

  @override
  String get daoDelegationStatusActive => 'Active';

  @override
  String get daoDelegationStartedJustNow => 'Just now';

  @override
  String get daoRevokeDelegationButton => 'Revoke Delegation';

  @override
  String get daoDelegationRevokedToast => 'Delegation revoked successfully';

  @override
  String get daoSelfDelegationEnabledToast => 'Self-delegation enabled';

  @override
  String get commonPost => 'Post';

  @override
  String get commonComments => 'Comments';

  @override
  String get commonLikes => 'Likes';

  @override
  String get commonReply => 'Reply';

  @override
  String get commonSend => 'Send';

  @override
  String get commonYou => 'You';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonUnnamed => 'Unnamed';

  @override
  String get commonOwner => 'Owner';

  @override
  String get commonJoined => 'Joined';

  @override
  String get commonJoin => 'Join';

  @override
  String get commonPublic => 'Public';

  @override
  String get commonPrivate => 'Private';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String commonMembersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String commonCommentsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
    );
    return '$_temp0';
  }

  @override
  String commonDistanceKmAway(Object value) {
    return '$value km away';
  }

  @override
  String commonTimeAgoWeeks(Object count) {
    return '${count}w ago';
  }

  @override
  String get commonTimeAgoJustNow => 'Just now';

  @override
  String get presenceOnlineLabel => 'Online';

  @override
  String presenceLastSeenLabel(Object timeAgo) {
    return 'Last seen $timeAgo';
  }

  @override
  String presenceLastSeenAtLabel(Object location) {
    return 'Last seen at $location';
  }

  @override
  String get postDetailLoadPostFailedMessage => 'Failed to load post.';

  @override
  String get postDetailMoreOptionsReportAction => 'Report';

  @override
  String get postDetailReportPostDialogTitle => 'Report post';

  @override
  String get postDetailReportPostDialogQuestion => 'Why are you reporting this post?';

  @override
  String get postDetailEditPostTitle => 'Edit post';

  @override
  String get postDetailPostUpdatedToast => 'Post updated';

  @override
  String get postDetailUpdatePostFailedToast => 'Failed to update post.';

  @override
  String get postDetailDeletePostTitle => 'Delete post';

  @override
  String get postDetailDeletePostBody => 'Are you sure you want to delete this post? This action cannot be undone.';

  @override
  String get postDetailPostDeletedToast => 'Post deleted';

  @override
  String get postDetailDeletePostFailedToast => 'Failed to delete post.';

  @override
  String get postDetailPostLikedToast => 'Post liked';

  @override
  String get postDetailLikeRemovedToast => 'Like removed';

  @override
  String get postDetailUndoLikeFailedToast => 'Failed to undo like.';

  @override
  String get postDetailUpdateLikeFailedToast => 'Failed to update like.';

  @override
  String get postDetailRetryLikeFailedToast => 'Retry failed.';

  @override
  String get postDetailCommentAddedToast => 'Comment added';

  @override
  String get postDetailAddCommentFailedToast => 'Failed to add comment.';

  @override
  String get postDetailUpdateCommentLikeFailedToast => 'Failed to update like.';

  @override
  String get postDetailLoadLikesFailedMessage => 'Failed to load likes.';

  @override
  String get postDetailNoLikesTitle => 'No likes yet';

  @override
  String get postDetailNoLikesDescription => 'Be the first to like this';

  @override
  String get postDetailSharePostTitle => 'Share post';

  @override
  String get postDetailSearchProfilesHint => 'Search for profiles…';

  @override
  String get postDetailCopyLink => 'Copy link';

  @override
  String get postDetailLinkCopiedToast => 'Link copied to clipboard';

  @override
  String get postDetailShareViaEllipsis => 'Share via…';

  @override
  String get postDetailNoProfilesFoundTitle => 'No profiles found';

  @override
  String get postDetailNoProfilesFoundDescription => 'Try a different search term';

  @override
  String get postDetailShareDmDefaultMessage => 'Check out this post!';

  @override
  String postDetailShareSuccessToast(Object username) {
    return 'Shared post with @$username';
  }

  @override
  String get postDetailShareFailedToast => 'Failed to share.';

  @override
  String get postDetailRepostTitle => 'Repost';

  @override
  String get postDetailRepostButton => 'Repost';

  @override
  String get postDetailRepostSuccessToast => 'Reposted!';

  @override
  String get postDetailRepostWithCommentSuccessToast => 'Reposted with comment!';

  @override
  String get postDetailRepostFailedToast => 'Failed to repost.';

  @override
  String get postDetailRepostThoughtsHint => 'Add your thoughts (optional)…';

  @override
  String get postDetailRepostingLabel => 'Reposting:';

  @override
  String get postDetailNoCommentsTitle => 'No comments yet';

  @override
  String get postDetailNoCommentsDescription => 'Be the first to start the conversation';

  @override
  String postDetailReplyingToLabel(Object author) {
    return 'Replying to $author';
  }

  @override
  String get postDetailWriteCommentHint => 'Write a comment…';

  @override
  String get postDetailLinkedArtworkLabel => 'Linked artwork';

  @override
  String get postDetailOriginalUnavailableMessage => 'Original post is no longer available';

  @override
  String get communityGroupsRefreshFailedToast => 'Could not refresh groups.';

  @override
  String get communityGroupMembershipUpdateFailedToast => 'Could not update group membership.';

  @override
  String get communityGroupNoDescription => 'No description provided.';

  @override
  String get communityGroupLatestPostLabel => 'Latest post';

  @override
  String get communityOpenGroupFeedButton => 'Open group feed';

  @override
  String get communityLocationEnableServicesToast => 'Enable location services to attach your location.';

  @override
  String get communityLocationPermissionRequiredToast => 'Location permission is required.';

  @override
  String get communityLocationUnableToDetermineToast => 'Unable to determine your location.';

  @override
  String get communityLocationUnableToAccessToast => 'Unable to access your location.';

  @override
  String get communityArtFeedLocationPermissionRequiredError => 'Location permission is required for the art feed.';

  @override
  String get communityArtFeedLoadFailedError => 'Unable to load the art feed.';

  @override
  String get communityArtFeedLoadFailedToast => 'Unable to load the art feed right now.';

  @override
  String get communityFollowingFeedUnavailableToast => 'Following feed is unavailable. Please try again later.';

  @override
  String get communityDiscoverFeedUnavailableToast => 'Discover feed is unavailable. Please try again later.';

  @override
  String get communityScreenTitle => 'Community';

  @override
  String get communityFollowingTab => 'Following';

  @override
  String get communityDiscoverTab => 'Discover';

  @override
  String get communityGroupsTab => 'Groups';

  @override
  String get communityArtTab => 'Art';

  @override
  String get communityFeedEmptyTitle => 'No posts yet';

  @override
  String get communityFeedEmptyDescription => 'Follow artists, institutions, and groups to see updates here.';

  @override
  String get communityDiscoverEmptyTitle => 'Nothing to discover yet';

  @override
  String get communityDiscoverEmptyDescription => 'New discussions, artworks, and cultural updates will appear here.';

  @override
  String communityNewPostsBanner(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new posts',
      one: '1 new post',
    );
    return 'Show $_temp0';
  }

  @override
  String get communityGroupsEmptyTitle => 'No groups yet';

  @override
  String get communityGroupsEmptyDescription => 'Create a group or join one to start collaborating.';

  @override
  String communityGroupsEmptySearchDescription(Object query) {
    return 'No groups found for \"$query\".';
  }

  @override
  String get communityGroupsEndOfDirectory => 'End of directory';

  @override
  String get communityGroupsSearchHint => 'Search community groups';

  @override
  String get communityGroupsDirectoryTitle => 'Group directory';

  @override
  String get communityGroupsDirectoryDescription => 'Find focused spaces for critiques, exhibitions, public art, events, and collaborations.';

  @override
  String get communityClearSearchTooltip => 'Clear search';

  @override
  String get communityFabNewPost => 'New post';

  @override
  String get communityFabCreateGroup => 'Create group';

  @override
  String get communityFabGroupPost => 'Group post';

  @override
  String get communityFabArtDrop => 'Share artwork';

  @override
  String get communityFabPostReview => 'Write a review';

  @override
  String get communityCreateGroupTitle => 'Create Group';

  @override
  String get communityCreateGroupNameLabel => 'Group Name';

  @override
  String get communityCreateGroupNameHint => 'e.g. Ljubljana creators';

  @override
  String get communityCreateGroupDescriptionLabel => 'Description';

  @override
  String get communityCreateGroupDescriptionHint => 'What is this group about?';

  @override
  String get communityCreateGroupPublicLabel => 'Public Group';

  @override
  String get communityCreateGroupPublicHint => 'Anyone can join and see posts.';

  @override
  String get communityCreateGroupPrivateHint => 'Members join by invitation.';

  @override
  String get communityCreateGroupButton => 'Create group';

  @override
  String get communityCreateGroupFailedToast => 'Unable to create group right now.';

  @override
  String communityGroupCreatedToast(Object name) {
    return 'Group \"$name\" created.';
  }

  @override
  String get communityViewPostButton => 'View post';

  @override
  String get communitySearchTypeProfiles => 'Profiles';

  @override
  String get communitySearchTypeArtworks => 'Artworks';

  @override
  String get communitySearchTypeInstitutions => 'Institutions';

  @override
  String get communitySearchTypeScreens => 'Screens';

  @override
  String get communitySearchTypePosts => 'Posts';

  @override
  String get communitySearchHintProfiles => 'Search people…';

  @override
  String get communitySearchHintArtworks => 'Search artworks…';

  @override
  String get communitySearchHintInstitutions => 'Search institutions…';

  @override
  String get communitySearchHintScreens => 'Search screens…';

  @override
  String get communitySearchHintPosts => 'Search posts…';

  @override
  String get communitySearchEmptyStartTyping => 'Start typing to search';

  @override
  String get communitySearchEmptyNoResults => 'No results found';

  @override
  String get communitySearchSheetHintTags => 'Search tags…';

  @override
  String get communitySearchSheetHintProfiles => 'Search users by name or @handle…';

  @override
  String get communitySearchSheetHintArtworks => 'Search artworks…';

  @override
  String get communitySearchSheetHintDefault => 'Search…';

  @override
  String get communitySearchUsersTitle => 'Search users';

  @override
  String get communitySearchAddNewTag => 'Add as new tag';

  @override
  String communitySearchTagUses(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uses',
      one: '1 use',
    );
    return '$_temp0';
  }

  @override
  String get communitySearchFallbackInstitution => 'Institution';

  @override
  String get communitySearchFallbackScreen => 'Screen';

  @override
  String get communityPopularTagsTitle => 'Popular tags';

  @override
  String get communitySuggestionsTitle => 'Suggestions';

  @override
  String get communityComposerTitle => 'Compose';

  @override
  String get communityComposerTextHint => 'Share what you are discovering, making, documenting, or discussing...';

  @override
  String get communityComposerTagsLabel => 'Tags';

  @override
  String get communityComposerTagsHint => 'Add topic (e.g. public-art, archive)';

  @override
  String get communityComposerMentionsLabel => 'Mentions';

  @override
  String get communityComposerMentionsHint => 'Add @handle';

  @override
  String communityComposerNoChipsYet(Object label) {
    return 'No $label yet';
  }

  @override
  String communityComposerLocationDropLabel(Object lat, Object lng) {
    return 'Drop at $lat, $lng';
  }

  @override
  String get communityComposerCurrentLocationLabel => 'Current location';

  @override
  String get communityComposerTargetGroupLabel => 'Target group';

  @override
  String get communityComposerGroupOptionalHelper => 'Optional - Join a group to unlock focused community discussions.';

  @override
  String communityComposerPostingInGroupHelper(Object groupName) {
    return 'Posting in $groupName. Tap to change or clear.';
  }

  @override
  String get communityComposerRemoveGroupTooltip => 'Remove group';

  @override
  String get communityComposerLinkArtworkTitle => 'Link artwork';

  @override
  String get communityComposerLinkArtworkDescription => 'Choose an artwork to attach to your post.';

  @override
  String communityComposerArtworkAttachedDescription(Object title) {
    return 'Attached artwork: $title';
  }

  @override
  String get communityComposerRemoveArtworkTooltip => 'Remove artwork';

  @override
  String get communityComposerAttachCurrentLocationButton => 'Attach current location';

  @override
  String get communityComposerAttachedLocationLabel => 'Attached location';

  @override
  String get communityComposerRemoveLocationTooltip => 'Remove location';

  @override
  String get communityComposerSubmitPostButton => 'Post';

  @override
  String get communityOpenScreenSubtitle => 'Open screen';

  @override
  String get communityBookmarkAddedToast => 'Post bookmarked!';

  @override
  String get communityBookmarkRemovedToast => 'Bookmark removed!';

  @override
  String get communityBookmarkUpdateFailedToast => 'Could not update bookmark.';

  @override
  String get communityComposerCategoryPostLabel => 'Post';

  @override
  String get communityComposerCategoryPostDescription => 'Share an update with the art community';

  @override
  String get communityComposerCategoryArtDropLabel => 'Share artwork';

  @override
  String get communityComposerCategoryArtDropDescription => 'Share a new artwork, exhibition, or collection';

  @override
  String get communityComposerCategoryArtReviewLabel => 'Art review';

  @override
  String get communityComposerCategoryArtReviewDescription => 'Share a review, context, or critique';

  @override
  String get communityComposerCategoryEventLabel => 'Event';

  @override
  String get communityComposerCategoryEventDescription => 'Announce an exhibition, workshop, or public event';

  @override
  String get communityComposerCategoryQuestionLabel => 'Question';

  @override
  String get communityComposerCategoryQuestionDescription => 'Ask the community';

  @override
  String get communityGroupFeedEmptyTitle => 'No posts in this group yet';

  @override
  String get communityGroupFeedEmptyDescription => 'Be the first to start the conversation.';

  @override
  String communityGroupFeedShareText(Object authorName, Object groupName) {
    return 'Check out $authorName\'s post in $groupName on art.kubus.';
  }

  @override
  String get communityArtFeedHeaderTitle => 'Community art feed';

  @override
  String communityArtFeedRadiusSubtitle(Object radius) {
    return 'Radius: $radius';
  }

  @override
  String communityArtFeedCenterSubtitle(Object lat, Object lng) {
    return 'Center: $lat, $lng';
  }

  @override
  String get communityArtFeedEnablePreciseLocationHint => 'Enable precise location for better results.';

  @override
  String get communityArtFeedLocationNeededTitle => 'Location needed';

  @override
  String get communityArtFeedLocationNeededDescription => 'Enable location to see public art and activations near you.';

  @override
  String get communityArtFeedNoNearbyActivationsTitle => 'No nearby public art activations';

  @override
  String get communityArtFeedNoNearbyActivationsDescription => 'Try refreshing your location or increasing the radius.';

  @override
  String get communityArtFeedRefreshLocationButton => 'Refresh location';

  @override
  String get communityArtFeedAboutTitle => 'About the art feed';

  @override
  String get communityArtFeedAboutBody => 'The art feed shows location-based artworks, exhibitions, and cultural activations shared by the community near you.';

  @override
  String get communityArtFeedAboutButton => 'About';

  @override
  String communityArtFeedShareText(Object authorName) {
    return 'Check out $authorName\'s art activation on art.kubus.';
  }

  @override
  String get communityNameThisPlaceTitle => 'Name this place';

  @override
  String get communityNamePlaceHint => 'e.g. City park';

  @override
  String get communityConnectWalletFirstToast => 'Sign in first; wallet access is only needed for wallet-linked actions.';

  @override
  String get communityUnableToAuthenticateToast => 'Unable to authenticate. Please try again.';

  @override
  String get communityComposerAddContentToast => 'Add text, an image, or a video.';

  @override
  String communityComposerSharedInGroupToast(Object groupName) {
    return 'Posted in $groupName';
  }

  @override
  String get communityGroupFallbackName => 'this group';

  @override
  String get communityGroupPickerTitle => 'Select group';

  @override
  String get communityGroupPickerJoinFirstToast => 'Join a group to target your drop.';

  @override
  String get communityComposerPostCreatedToast => 'Post created';

  @override
  String get communityComposerCreatePostFailedToast => 'Failed to create post.';

  @override
  String get communityToggleLikeFailedToast => 'Failed to update like.';

  @override
  String get communityPostLikesTitle => 'Post likes';

  @override
  String get communityCommentLikesTitle => 'Comment likes';

  @override
  String get communityReplyingToCommentLabel => 'Replying…';

  @override
  String get communityCommentAuthRequiredToast => 'Sign in to comment.';

  @override
  String get communityRepostedByTitle => 'Reposted by';

  @override
  String get communityRepostsLoadFailedMessage => 'Failed to load reposts.';

  @override
  String get communityNoRepostsTitle => 'No reposts yet';

  @override
  String get communityNoRepostsDescription => 'Be the first to repost this';

  @override
  String get communityUnrepostAction => 'Unrepost';

  @override
  String get communityUnrepostTitle => 'Remove repost?';

  @override
  String get communityUnrepostConfirmBody => 'Remove your repost of this post?';

  @override
  String get communityRepostRemovedToast => 'Repost removed';

  @override
  String get communityUnrepostFailedToast => 'Failed to remove repost.';

  @override
  String get commonSomethingWentWrong => 'Something went wrong. Try again.';

  @override
  String get commonGreetingMorning => 'Good morning';

  @override
  String get commonGreetingAfternoon => 'Good afternoon';

  @override
  String get commonGreetingEvening => 'Good evening';

  @override
  String get commonWeekdayMonShort => 'Mon';

  @override
  String get commonWeekdayTueShort => 'Tue';

  @override
  String get commonWeekdayWedShort => 'Wed';

  @override
  String get commonWeekdayThuShort => 'Thu';

  @override
  String get commonWeekdayFriShort => 'Fri';

  @override
  String get commonWeekdaySatShort => 'Sat';

  @override
  String get commonWeekdaySunShort => 'Sun';

  @override
  String get commonIosLabel => 'iOS';

  @override
  String get commonAndroidLabel => 'Android';

  @override
  String downloadAppCouldNotOpenStoreToast(Object url) {
    return 'Could not open the store. Please visit: $url';
  }

  @override
  String get downloadAppDefaultFeatureName => 'AR Features';

  @override
  String downloadAppExperienceInArTitle(Object featureName) {
    return 'Experience $featureName in AR';
  }

  @override
  String get downloadAppDefaultDescription => 'Mobile AR pilots are in development.';

  @override
  String get downloadAppFeatureViewInAr => 'Preview AR layers when available';

  @override
  String get downloadAppFeatureScanArtworks => 'Scan artworks';

  @override
  String get downloadAppFeatureInteractive3d => 'Interactive 3D models';

  @override
  String get downloadAppFeatureLocationDiscovery => 'Location-based discovery';

  @override
  String get downloadAppDownloadForLabel => 'Download for:';

  @override
  String get downloadAppScanQrTitle => 'Scan QR code';

  @override
  String get downloadAppScanQrSubtitle => 'Open this page on your phone to download the app.';

  @override
  String get downloadAppContinueBrowsingButton => 'Continue browsing';

  @override
  String get homeDefaultDisplayName => 'there';

  @override
  String get homeWelcomeSubtitle => 'Open art platform for discovery, artists, institutions, and community.';

  @override
  String get homeExploreWeb3Button => 'Wallet and Web3 access';

  @override
  String get homeQuickActionsTitle => 'Start Here';

  @override
  String get homeRecentlyUsedLabel => 'Recently Used';

  @override
  String get homeQuickActionsEmptyDescription => 'Start exploring and kubus will keep your useful shortcuts here.';

  @override
  String get homeYourStatsTitle => 'Your Cultural Activity';

  @override
  String get homeNoStatsAvailableTitle => 'Start discovering local art.';

  @override
  String get homeNoStatsAvailableDescription => 'Open the art map, follow artists, or explore institutions to build your cultural activity.';

  @override
  String get homeStatArtworks => 'Artworks shared';

  @override
  String get homeStatFollowers => 'Followers';

  @override
  String get homeStatViews => 'Views';

  @override
  String get homeStatLikes => 'Likes';

  @override
  String get homeStatVisitors => 'Visitors';

  @override
  String get homeStatEventsHosted => 'Events Hosted';

  @override
  String get homeStatExhibitions => 'Exhibitions';

  @override
  String get homeStatProgramViews => 'Program Views';

  @override
  String get homeStatDiscovered => 'Discovered';

  @override
  String get homeStatArSessions => 'AR layers';

  @override
  String get homeStatFollowing => 'Following';

  @override
  String get homeStatLikesGiven => 'Likes Given';

  @override
  String homeStatsDialogTitle(Object statName) {
    return '$statName Details';
  }

  @override
  String homeStatsTrendTitle(Object statName) {
    return '$statName Trend';
  }

  @override
  String get homeViewAdvancedButton => 'View details';

  @override
  String get homeRecentMilestonesTitle => 'Recent Recognition';

  @override
  String get homeStatsNoMilestonesYet => 'No milestones yet';

  @override
  String get homeStatsMilestoneArtworks1 => '1st artwork created';

  @override
  String get homeStatsMilestoneArtworks2 => '5 artworks created';

  @override
  String get homeStatsMilestoneArtworks3 => '10 artworks created';

  @override
  String get homeStatsMilestoneFollowers1 => 'First follower';

  @override
  String get homeStatsMilestoneFollowers2 => '10 followers';

  @override
  String get homeStatsMilestoneFollowers3 => '50 followers';

  @override
  String get homeStatsMilestoneViews1 => '100 views';

  @override
  String get homeStatsMilestoneViews2 => '500 views';

  @override
  String get homeStatsMilestoneViews3 => '1,000 views';

  @override
  String get homeRecentActivityTitle => 'Recent Activity';

  @override
  String get homeNoRecentActivityTitle => 'Start with the open art map.';

  @override
  String get homeNoRecentActivityDescription => 'Discover local art, follow artists, and contribute to the community archive.';

  @override
  String get homeUnableToLoadActivityTitle => 'Unable to load activity';

  @override
  String get homeFeaturedArtworksTitle => 'Featured Artworks and Places';

  @override
  String get homeNoFeaturedArtworksTitle => 'No featured artworks';

  @override
  String get homeNoFeaturedArtworksDescription => 'Check back soon for curated picks.';

  @override
  String get homeActivityTitle => 'Community Activity';

  @override
  String get homeMarkAllReadButton => 'Mark all read';

  @override
  String get homeUnableToLoadNotificationsTitle => 'Unable to load notifications';

  @override
  String get homeNoNotificationsTitle => 'No notifications';

  @override
  String get homeAllCaughtUpDescription => 'You\'re all caught up.';

  @override
  String get homeMockNotificationNewArtworkTitle => 'New artwork added';

  @override
  String get homeMockNotificationNewArtworkBody => 'A new piece has been added to the gallery.';

  @override
  String get homeMockNotificationCommunityTitle => 'Community update';

  @override
  String get homeMockNotificationCommunityBody => 'New posts are waiting in the community.';

  @override
  String get homeMockNotificationRewardsTitle => 'New recognition';

  @override
  String get homeMockNotificationRewardsBody => 'You have new participation recognition to review.';

  @override
  String get commonExplore => 'Explore';

  @override
  String get commonNoSuggestions => 'No suggestions';

  @override
  String get commonArShort => 'AR';

  @override
  String get desktopHomeWelcomeFallbackName => 'Welcome to art.kubus';

  @override
  String get desktopHomeDiscoverArtTitle => 'Open art platform.';

  @override
  String get desktopHomeDiscoverArtDescription => 'Discover artworks, places, creators, and institutions across public space and online. Wallet tools are available when needed, and AR layers are in development.';

  @override
  String get desktopHomeYourActivityTitle => 'Your Activity';

  @override
  String get desktopHomeYourActivitySubtitle => 'Track your progress and engagement';

  @override
  String get desktopHomeStatArtworksDiscovered => 'Artworks Discovered';

  @override
  String get desktopHomeStatArSessions => 'AR Sessions';

  @override
  String get desktopHomeStatNftsCollected => 'Digital editions';

  @override
  String get desktopHomeStatKub8Earned => 'KUB8 recognition';

  @override
  String get desktopHomeQuickActionsSubtitle => 'Based on your recent visits';

  @override
  String get desktopHomeQuickActionsEmptySubtitle => 'Start exploring to see your recent screens here';

  @override
  String get desktopHomeQuickActionsEmptyTitle => 'No recent visits yet';

  @override
  String get desktopHomeQuickActionsEmptyDescription => 'Navigate to different screens and they\'ll appear here for quick access. Cards disappear after 24 hours of inactivity.';

  @override
  String get desktopHomeFeaturedArtworksSubtitle => 'Discover featured art and future AR layers';

  @override
  String get desktopHomeWeb3HubTitle => 'Wallet features';

  @override
  String get desktopHomeWeb3HubSubtitle => 'Wallet access, continuity, and future participation';

  @override
  String get desktopHomeTrendingArtTitle => 'Trending Art';

  @override
  String get desktopHomeTrendingArtLoadFailed => 'Unable to load trending art.';

  @override
  String get desktopHomeTrendingArtEmpty => 'Trending artworks will appear here';

  @override
  String get desktopHomeTopCreatorsTitle => 'Top Creators';

  @override
  String get desktopHomeTopCreatorsLoadFailed => 'Unable to load creators.';

  @override
  String get desktopHomeTopCreatorsEmpty => 'Top creators will appear here';

  @override
  String get desktopHomeCreatorFallbackName => 'Creator';

  @override
  String get homeRailsUnavailableTitle => 'Home rails unavailable';

  @override
  String get homeRailsUnavailableDescription => 'We could not load ranked home rails right now.';

  @override
  String get homeRailsWarmingTitle => 'Discovery rails are warming up';

  @override
  String get homeRailsWarmingDescription => 'Featured artworks, artists, institutions, events, and exhibitions will appear here once ranked content is available.';

  @override
  String get homeRailArtworksTitle => 'Artworks';

  @override
  String get homeRailArtistsTitle => 'Artists';

  @override
  String get homeRailInstitutionsTitle => 'Institutions';

  @override
  String get homeRailEventsTitle => 'Events';

  @override
  String get homeRailExhibitionsTitle => 'Exhibitions';

  @override
  String desktopHomePostsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts',
      one: '1 post',
    );
    return '$_temp0';
  }

  @override
  String get desktopHomePlatformStatsTitle => 'Platform Stats';

  @override
  String get desktopHomePlatformStatsLoadFailed => 'Unable to load community stats.';

  @override
  String get desktopHomePlatformStatsTotalArtworks => 'Total Artworks';

  @override
  String get desktopHomePlatformStatsArEnabled => 'AR Enabled';

  @override
  String get desktopHomePlatformStatsCommunityPosts => 'Community Posts';

  @override
  String get desktopHomePlatformStatsActiveGroups => 'Active Groups';

  @override
  String get desktopHomeUnreadNotificationsLabel => 'unread notifications';

  @override
  String get homeWeb3SectionTitle => 'Wallet and Web3 access';

  @override
  String get homeAccountRequiredLabel => 'Wallet';

  @override
  String get homeWeb3DaoTitle => 'Community governance';

  @override
  String get homeWeb3DaoSubtitle => 'Community proposals';

  @override
  String get homeWeb3ArtistTitle => 'Artist Studio';

  @override
  String get homeWeb3ArtistSubtitle => 'Publish and document';

  @override
  String get homeWeb3InstitutionTitle => 'Institution';

  @override
  String get homeWeb3InstitutionSubtitle => 'Programs and exhibitions';

  @override
  String get homeWeb3MarketplaceTitle => 'Digital editions';

  @override
  String get homeWeb3MarketplaceSubtitle => 'Archive and collect';

  @override
  String get homeMockNotificationFriendRequestTitle => 'New friend request';

  @override
  String get homeMockNotificationFriendRequestBody => 'Someone sent you a friend request.';

  @override
  String get homeMockNotificationFeaturedTitle => 'Featured today';

  @override
  String get homeMockNotificationFeaturedBody => 'Check out today\'s featured artwork.';

  @override
  String get commonReset => 'Reset';

  @override
  String get season0BannerTitle => 'Season 0, Ljubljana (beta)';

  @override
  String get season0BannerTap => 'Read more about the launch program';

  @override
  String get season0ScreenTitle => 'Season 0';

  @override
  String get season0ScreenSubtitle => 'Ljubljana beta launch';

  @override
  String get season0ScreenDescription => 'Join the founding program of art.kubus in Ljubljana. Apply as an artist or institution to shape the first season of the platform.';

  @override
  String get season0ApplyArtistCta => 'Apply as artist';

  @override
  String get season0ApplyArtistSubtitle => 'Join as a creator or collective';

  @override
  String get season0ApplyInstitutionCta => 'Apply as institution';

  @override
  String get season0ApplyInstitutionSubtitle => 'Register your gallery or space';

  @override
  String get season0NewsletterCta => 'Subscribe to newsletter';

  @override
  String get season0NewsletterSubtitle => 'Get updates on progress and events';

  @override
  String get season0PointsLabel => 'KUB8 recognition';

  @override
  String get season0PointsTooltip => 'Off-chain progress points';

  @override
  String get season0OnChainNote => 'On-chain features available on dev-net for now';

  @override
  String get mnemonicRevealTitle => 'Reveal Recovery Phrase';

  @override
  String get mnemonicRevealPrivacyWarning => 'Your recovery phrase (keep it private)';

  @override
  String get mnemonicRevealBiometricUnavailable => 'Biometric unlock unavailable. Enter PIN to reveal your recovery phrase.';

  @override
  String get mnemonicRevealPinError => 'PIN must be at least 4 digits';

  @override
  String mnemonicRevealPinLockedError(Object seconds) {
    return 'PIN locked for $seconds seconds';
  }

  @override
  String securityPinAttemptsRemaining(Object remaining, Object max) {
    return 'Attempts remaining: $remaining / $max';
  }

  @override
  String get mnemonicRevealIncorrectPinError => 'Incorrect PIN';

  @override
  String get mnemonicRevealCopiedToast => 'Mnemonic copied to clipboard';

  @override
  String get mnemonicRevealShowButton => 'Show';

  @override
  String get mnemonicRevealEnterPinDialogTitle => 'Enter PIN';

  @override
  String get walletBackupConfirmAction => 'I backed it up safely';

  @override
  String get walletBackupMarkedCompleteToast => 'Recovery phrase backup marked as complete.';

  @override
  String get walletBackupProtectionNoWalletHeadline => 'No wallet is connected on this device yet.';

  @override
  String get walletBackupProtectionNoWalletBody => 'Connect or restore the wallet on this device before managing backup protection.';

  @override
  String get walletBackupProtectionAccountShellHeadline => 'Your account is ready, but this device does not have wallet access yet.';

  @override
  String get walletBackupProtectionAccountShellBody => 'Restore the account wallet on this device before you configure wallet backup protection, transfers, or future wallet-linked access.';

  @override
  String get walletBackupProtectionNoBackupHeadline => 'No encrypted server backup is configured yet.';

  @override
  String get walletBackupProtectionNoBackupBody => 'Create an encrypted server backup if you want a server-side recovery option, and store its recovery password separately from the recovery phrase.';

  @override
  String get walletBackupProtectionRecoveryPhraseHeadline => 'Recovery phrase backup is still required.';

  @override
  String get walletBackupProtectionRecoveryPhraseBody => 'Store the recovery phrase offline so you do not lose access to this wallet, account continuity, digital editions, points, and future rights tied to it.';

  @override
  String get walletBackupProtectionEncryptedHeadline => 'Encrypted server backup is configured.';

  @override
  String get walletBackupProtectionEncryptedBody => 'Keep the encrypted backup recovery password stored separately from the recovery phrase so both recovery paths remain usable.';

  @override
  String get walletBackupProtectionEncryptedRestoreHeadline => 'Encrypted backup is available, but signing is not restored on this device.';

  @override
  String get walletBackupProtectionEncryptedRestoreBody => 'Use the encrypted backup to restore wallet access on this device before transfers and other wallet-protected actions.';

  @override
  String get walletBackupProtectionPasskeyHeadline => 'Passkey-protected server backup is configured.';

  @override
  String get walletBackupProtectionPasskeyBody => 'This encrypted server backup is protected with a passkey on web. Keep the recovery password stored separately from the recovery phrase.';

  @override
  String get walletBackupProtectionReadOnlyHeadline => 'This device has read-only wallet access.';

  @override
  String get walletBackupProtectionReadOnlyBody => 'Restore signing access with your encrypted backup or recovery phrase before using transfers and other wallet-protected actions on this device.';

  @override
  String get walletSessionStateAccountShellOnly => 'Account shell only';

  @override
  String get walletSessionStateWalletReadOnly => 'Wallet identity, read-only';

  @override
  String get walletSessionStateLocalSignerReady => 'Wallet access ready on this device';

  @override
  String get walletSessionStateExternalWalletReady => 'External wallet ready';

  @override
  String get walletSessionStateRecoveryNeeded => 'Recovery needed';

  @override
  String get walletSessionStateEncryptedBackupAvailable => 'Encrypted backup available';

  @override
  String get walletSecurityStatusTitle => 'Wallet security status';

  @override
  String get walletSecuritySignInMethodLabel => 'Account sign-in';

  @override
  String get walletSecurityWalletAddressLabel => 'Wallet address';

  @override
  String get walletSecuritySignerStatusLabel => 'Wallet access status';

  @override
  String get walletSecurityLocalSignerLabel => 'Wallet access on this device';

  @override
  String get walletSecurityExternalWalletLabel => 'External wallet';

  @override
  String get walletSecurityEncryptedBackupLabel => 'Encrypted backup';

  @override
  String get walletSecurityPasskeyLabel => 'Passkey';

  @override
  String get walletSecurityRecoveryNeededLabel => 'Recovery';

  @override
  String get walletSecurityBackendBackupClarifier => 'Email or Google sign-in can restore account access only. Transfers still require Wallet access on this device or a connected external wallet. Encrypted backend backup supports recovery and never gives the backend control of your wallet.';

  @override
  String get walletSecuritySignedOutMethod => 'Signed out';

  @override
  String get walletSecuritySignInMethodEmail => 'Email';

  @override
  String walletSecuritySignInMethodEmailWithAddress(Object email) {
    return 'Email ($email)';
  }

  @override
  String get walletSecuritySignInMethodGoogle => 'Google';

  @override
  String walletSecuritySignInMethodGoogleWithAddress(Object email) {
    return 'Google ($email)';
  }

  @override
  String get walletSecuritySignInMethodWallet => 'Wallet signature';

  @override
  String get walletSecuritySignInMethodUnknown => 'Signed in';

  @override
  String get walletSecurityNotAvailable => 'Not available';

  @override
  String get walletSecurityAvailable => 'Available';

  @override
  String get walletSecurityUnavailable => 'Unavailable';

  @override
  String get walletSecurityUnknown => 'Unknown';

  @override
  String get walletSecurityConnected => 'Connected';

  @override
  String get walletSecurityDisconnected => 'Disconnected';

  @override
  String get walletSecurityConfigured => 'Configured';

  @override
  String get walletSecurityNotConfigured => 'Not configured';

  @override
  String get walletSecurityLocalSignerReadyValue => 'Present and ready';

  @override
  String get walletSecurityLocalSignerMissingValue => 'Not restored on this device';

  @override
  String get walletSecuritySignerLocalReadyValue => 'Wallet access ready on this device';

  @override
  String get walletSecuritySignerExternalReadyValue => 'External wallet ready';

  @override
  String get walletSecuritySignerRestoreAvailableValue => 'Restore available from encrypted backup';

  @override
  String get walletSecuritySignerMissingValue => 'Wallet access missing';

  @override
  String walletSecurityExternalWalletConnectedValue(Object walletName) {
    return 'Connected: $walletName';
  }

  @override
  String get walletSecurityRecoveryNeededValue => 'Needed';

  @override
  String get walletSecurityRecoveryNotNeededValue => 'Not needed';

  @override
  String get walletSecurityRestoreSignerAction => 'Restore wallet access';

  @override
  String get walletSecurityConnectExternalAction => 'Connect external wallet';

  @override
  String get walletBackupRecoveryPasswordLabel => 'Recovery password';

  @override
  String get walletBackupPasswordTooShortError => 'Use at least 8 characters.';

  @override
  String get walletBackupPasswordsMismatchError => 'Passwords do not match.';

  @override
  String walletBackupPromptRequiredError(Object field) {
    return '$field is required.';
  }

  @override
  String walletBackupPromptTooLongError(Object field) {
    return '$field must be 120 characters or less.';
  }

  @override
  String get walletBackupProtectionTitle => 'Protect your web3 wallet';

  @override
  String get walletBackupProtectionFeatureLabel => 'Wallet backup';

  @override
  String get walletBackupProtectionUnavailableTitle => 'Wallet backup unavailable';

  @override
  String get walletBackupProtectionCurrentWalletLabel => 'Current wallet';

  @override
  String get walletBackupProtectionOfflineReminder => 'Back up the recovery phrase offline and store the encrypted backup recovery password separately.';

  @override
  String walletBackupProtectionLastVerifiedLabel(Object date) {
    return 'Last verified: $date';
  }

  @override
  String get walletBackupProtectionCreateBackupTitle => 'Create encrypted backup';

  @override
  String get walletBackupProtectionCreateBackupDescription => 'Choose a recovery password. This password decrypts the wallet backup on a new device.';

  @override
  String get walletBackupProtectionCreateBackupAction => 'Create backup';

  @override
  String get walletBackupProtectionBackupSavedToast => 'Encrypted wallet backup saved.';

  @override
  String get walletBackupProtectionVerifyBackupTitle => 'Verify encrypted backup';

  @override
  String get walletBackupProtectionVerifyBackupDescription => 'Enter the recovery password to verify the encrypted backup can be decrypted locally.';

  @override
  String get walletBackupProtectionVerifyBackupAction => 'Verify encrypted backup';

  @override
  String get walletBackupProtectionBackupVerifiedToast => 'Encrypted backup verified.';

  @override
  String get walletBackupProtectionDeleteBackupTitle => 'Delete encrypted backup?';

  @override
  String get walletBackupProtectionDeleteBackupBody => 'This removes the encrypted server backup for the current wallet. Make sure you still have the recovery phrase stored safely offline.';

  @override
  String get walletBackupProtectionDeleteBackupAction => 'Delete encrypted backup';

  @override
  String get walletBackupProtectionBackupDeletedToast => 'Encrypted wallet backup deleted.';

  @override
  String get walletBackupProtectionRestoreSignerTitle => 'Restore wallet access';

  @override
  String get walletBackupProtectionRestoreSignerDescription => 'Restore signing access on this device. Passkey recovery is tried first when available; recovery password is the fallback.';

  @override
  String get walletBackupProtectionRestoreSignerAction => 'Restore wallet access';

  @override
  String get walletBackupProtectionSignerRestoredToast => 'Wallet access restored on this device.';

  @override
  String get walletBackupProtectionSignerRestoredWithPasskeyToast => 'Wallet access restored with passkey.';

  @override
  String get walletBackupProtectionSignerRestoredWithPasswordToast => 'Wallet access restored with recovery password.';

  @override
  String get walletBackupProtectionSignerStillMissingToast => 'Wallet access is still read-only on this device.';

  @override
  String get walletBackupProtectionRecoveryCancelledToast => 'Wallet recovery cancelled.';

  @override
  String get walletBackupProtectionSignerRestoreFailedToast => 'Unable to restore wallet access.';

  @override
  String get walletBackupProtectionUpdateEncryptedBackupButton => 'Update encrypted backup';

  @override
  String get walletBackupProtectionCreateEncryptedBackupButton => 'Create encrypted backup';

  @override
  String get walletBackupProtectionRevealRecoveryPhraseButton => 'Reveal and copy recovery phrase';

  @override
  String get walletBackupProtectionPasskeysTitle => 'Passkeys';

  @override
  String get walletBackupProtectionPasskeysBody => 'On web, passkeys are tried first for wallet recovery. Recovery password remains available as a fallback.';

  @override
  String get walletRecoveryFallbackTitle => 'Restore wallet access';

  @override
  String get walletRecoveryPasskeyFailedTitle => 'Passkey recovery failed';

  @override
  String get walletRecoveryPasskeyUnavailableTitle => 'Passkey recovery unavailable';

  @override
  String get walletRecoveryPasswordFailedTitle => 'Recovery password failed';

  @override
  String get walletRecoveryNoBackupTitle => 'No encrypted backup found';

  @override
  String get walletRecoveryFallbackDescription => 'Choose another way to restore wallet signing on this device.';

  @override
  String get walletRecoveryUsePasswordAction => 'Use recovery password';

  @override
  String get walletRecoveryImportPhraseAction => 'Import recovery phrase';

  @override
  String get walletRecoveryContinueReadOnlyAction => 'Continue without wallet';

  @override
  String get walletRecoveryReadOnlyDescription => 'You can still browse your account, but wallet actions will stay locked until you restore the signer.';

  @override
  String get walletRecoveryPhraseMustMatchDescription => 'The imported recovery phrase must match your account wallet.';

  @override
  String get walletRecoveryPhraseLabel => 'Recovery phrase';

  @override
  String get walletBackupProtectionAddPasskeyTitle => 'Add a passkey';

  @override
  String get walletBackupProtectionPasskeyNameLabel => 'Passkey name';

  @override
  String get walletBackupProtectionAddPasskeyDescription => 'Give this passkey a label so you can recognize the device or browser later.';

  @override
  String get walletBackupProtectionDefaultPasskeyName => 'This device';

  @override
  String get walletBackupProtectionAddPasskeyAction => 'Add passkey';

  @override
  String walletBackupProtectionPasskeyAddedToast(Object passkey) {
    return 'Passkey \"$passkey\" added.';
  }

  @override
  String get walletBackupProtectionStoredPasskeyLabel => 'Stored passkey';

  @override
  String walletBackupProtectionPasskeyTransports(Object transports) {
    return 'Transports: $transports';
  }

  @override
  String get walletBackupBannerTitle => 'Back up your recovery phrase';

  @override
  String get walletBackupBannerSubtitle => 'Store it safely offline. You need it to restore this wallet and keep long-term access.';

  @override
  String get walletBackupBannerAction => 'Back up now';

  @override
  String get walletReconnectSuccessToast => 'Wallet session restored.';

  @override
  String get walletReconnectReadOnlyToast => 'Session refreshed. Signing is still unavailable on this device.';

  @override
  String get walletReconnectManualRequiredToast => 'Reconnect with your wallet provider to enable signing.';

  @override
  String get walletSwapTitle => 'Token swap';

  @override
  String get walletSwapTemporarilyDisabledTitle => 'Swap is temporarily unavailable';

  @override
  String get walletSwapTemporarilyDisabledDescription => 'Token swapping is turned off in this app build. You can still use Send and Receive, and the full swap flow can be restored later.';

  @override
  String get walletSwapSwitchTokensTooltip => 'Switch tokens';

  @override
  String get walletSwapNoTokensTitle => 'No tradable tokens yet';

  @override
  String get walletSwapNoTokensDescription => 'Add funds or receive tokens to enable swaps. Once you hold supported assets they will appear here automatically.';

  @override
  String get walletSwapYouPayLabel => 'You pay';

  @override
  String get walletSwapYouReceiveLabel => 'You receive';

  @override
  String get walletSwapMaxAction => 'MAX';

  @override
  String get walletSwapAmountPlaceholder => '0.0';

  @override
  String get walletSwapSelectTokenAction => 'Select';

  @override
  String walletSwapBalanceLabel(Object balance) {
    return 'Balance: $balance';
  }

  @override
  String get walletSwapInvalidAmountTitle => 'Invalid amount';

  @override
  String get walletSwapRouteUnavailableTitle => 'Unable to fetch route';

  @override
  String get walletSwapSearchingRouteLabel => 'Searching best route on Jupiter…';

  @override
  String get walletSwapEnterAmountTitle => 'Enter an amount';

  @override
  String get walletSwapEnterAmountDescription => 'We will fetch live quotes with fees and minimum received once you type an amount.';

  @override
  String get walletSwapQuotePreviewTitle => 'Quote preview';

  @override
  String get walletSwapQuoteSidebarTitle => 'Quote details';

  @override
  String get walletSwapQuoteSidebarSubtitle => 'Route, slippage, and output update with every amount change.';

  @override
  String get walletSwapRecentPairsTitle => 'Recent pairs';

  @override
  String get walletSwapRecentPairsSubtitle => 'Jump back into recent routes without rebuilding the form.';

  @override
  String walletSwapRecentPairSubtitle(Object amount, Object date) {
    return '$amount · $date';
  }

  @override
  String get walletSwapSecuritySubtitle => 'Swap execution still depends on wallet access and recovery status.';

  @override
  String get walletSwapEstimatedOutputLabel => 'Estimated output';

  @override
  String get walletSwapMinReceivedLabel => 'Min received (after slippage)';

  @override
  String get walletSwapPriceImpactLabel => 'Price impact';

  @override
  String get walletSwapSlippageLabel => 'Slippage';

  @override
  String get walletSwapProtocolFeeLabel => 'Protocol fee';

  @override
  String walletSwapProtocolFeeValue(Object percent) {
    return '$percent% applied to output token';
  }

  @override
  String get walletSwapRouteFallbackLabel => 'Route';

  @override
  String get walletSwapSlippageToleranceLabel => 'Slippage tolerance';

  @override
  String get walletSwapEnterAmountCta => 'Enter amount';

  @override
  String walletSwapSubmitLabel(Object fromToken, Object toToken) {
    return 'Swap $fromToken ? $toToken';
  }

  @override
  String get walletSwapNoHistoryTitle => 'No swaps yet';

  @override
  String get walletSwapNoHistoryDescription => 'Executed swaps will appear here with detailed status once completed.';

  @override
  String get walletSwapPositiveAmountError => 'Enter a positive amount';

  @override
  String get walletSwapPositiveAmountDetailedError => 'Enter an amount greater than zero';

  @override
  String get walletSwapSelectTokensError => 'Select both tokens to continue';

  @override
  String get walletSwapDifferentTokensError => 'Choose two different tokens';

  @override
  String walletSwapSubmittedToast(Object fromToken, Object toToken) {
    return 'Swap submitted: $fromToken ? $toToken';
  }

  @override
  String walletSwapSubmittedToastWithSignature(Object fromToken, Object toToken, Object signature) {
    return 'Swap submitted: $fromToken ? $toToken. Tx: $signature';
  }

  @override
  String walletTransactionConfirmationsLabel(int count) {
    return '$count confirmations';
  }

  @override
  String get walletTransactionExplorerAction => 'Open explorer';

  @override
  String get walletTransactionSignatureLabel => 'Transaction ID';

  @override
  String get walletTransactionFromLabel => 'From';

  @override
  String get walletTransactionToLabel => 'To';

  @override
  String get walletTransactionCounterpartyLabel => 'Counterparty';

  @override
  String get walletTransactionSlotLabel => 'Slot';

  @override
  String get walletTransactionFinalityLabel => 'Finality';

  @override
  String get walletTransactionNetworkFeeLabel => 'Network fee';

  @override
  String get walletTransactionAssetChangesLabel => 'Asset changes';

  @override
  String get walletTransactionRelatedActionsLabel => 'Related actions';

  @override
  String get walletTransactionCopiedToast => 'Transaction ID copied.';

  @override
  String get walletTransactionExplorerUnavailableToast => 'Unable to open explorer.';

  @override
  String get walletTransactionFeeTransferTitle => 'Fee transfer';

  @override
  String get walletTransactionMovedTitle => 'Moved';

  @override
  String walletTransactionSwapSubtitle(Object fromToken, Object toToken) {
    return '$fromToken to $toToken';
  }

  @override
  String get walletTransactionStatusSubmitted => 'Submitted';

  @override
  String get walletTransactionStatusPending => 'Pending';

  @override
  String get walletTransactionStatusConfirmed => 'Confirmed';

  @override
  String get walletTransactionStatusFinalized => 'Finalized';

  @override
  String get walletTransactionStatusFailed => 'Failed';

  @override
  String get walletTransactionFinalityUnknown => 'Unknown';

  @override
  String get walletTransactionFinalityProcessed => 'Processed';

  @override
  String get walletTransactionFinalityConfirmed => 'Confirmed';

  @override
  String get walletTransactionFinalityFinalized => 'Finalized';

  @override
  String get walletTransactionCopySignatureTooltip => 'Copy transaction ID';

  @override
  String walletSwapFailedToast(Object message) {
    return 'Swap failed: $message';
  }

  @override
  String walletSwapTokenOptionSubtitle(Object symbol, Object balance) {
    return '$symbol · Balance $balance';
  }

  @override
  String get manageMarkersTitle => 'Manage markers';

  @override
  String get manageMarkersCardSubtitle => 'Create, publish, and edit your map markers';

  @override
  String get manageMarkersQuickActionSubtitle => 'Create, publish, and edit markers';

  @override
  String get manageMarkersSearchHint => 'Search markers';

  @override
  String get manageMarkersRefreshTooltip => 'Refresh';

  @override
  String get manageMarkersStatusDraft => 'Draft';

  @override
  String get manageMarkersStatusPublic => 'Public';

  @override
  String get manageMarkersStatusPrivate => 'Private';

  @override
  String get manageMarkersEmptyTitle => 'No markers yet';

  @override
  String get manageMarkersEmptySubtitle => 'Create your first marker to place an AR experience on the map.';

  @override
  String get manageMarkersSelectTitle => 'Select a marker';

  @override
  String get manageMarkersSelectSubtitle => 'Pick a marker from the list or create a new one.';

  @override
  String get manageMarkersLoadFailedTitle => 'Couldn\'t load markers';

  @override
  String get manageMarkersLoadFailedSubtitle => 'Check your connection and try again.';

  @override
  String get manageMarkersRetryButton => 'Retry';

  @override
  String get manageMarkersNewButton => 'New marker';

  @override
  String get manageMarkersEditTitle => 'Edit marker';

  @override
  String get manageMarkersCloseTooltip => 'Close';

  @override
  String get manageMarkersCreateButton => 'Create';

  @override
  String get manageMarkersSaveButton => 'Save';

  @override
  String get manageMarkersSaveFailed => 'Failed to save marker';

  @override
  String get manageMarkersCreatedToast => 'Marker created';

  @override
  String get manageMarkersUpdatedToast => 'Marker updated';

  @override
  String get manageMarkersDeleteConfirmTitle => 'Delete marker?';

  @override
  String get manageMarkersDeleteConfirmBody => 'This can\'t be undone.';

  @override
  String get manageMarkersDeleteButton => 'Delete';

  @override
  String get manageMarkersCancelButton => 'Cancel';

  @override
  String get manageMarkersDeleteFailed => 'Failed to delete marker';

  @override
  String get manageMarkersDeletedToast => 'Marker deleted';

  @override
  String get manageMarkersActivationRadiusLabel => 'Activation radius (m)';

  @override
  String get manageMarkersPublishedToggleTitle => 'Published';

  @override
  String get manageMarkersRequiresProximityTitle => 'Requires proximity';

  @override
  String get manageMarkersRequiresProximitySubtitle => 'Require users to be near the marker to activate AR';

  @override
  String get manageMarkersSearchNoResults => 'No results';

  @override
  String manageMarkersPickSubjectTitle(Object subjectType) {
    return 'Pick $subjectType';
  }

  @override
  String get manageMarkersSearchSubjectsHint => 'Search subjects';

  @override
  String get manageMarkersPickArAssetTitle => 'Pick AR asset';

  @override
  String get manageMarkersSearchArAssetsHint => 'Search AR assets';

  @override
  String get manageMarkersClearSelectionTooltip => 'Clear selection';

  @override
  String get artworkCommentAddButton => 'Add Comment';

  @override
  String get artworkCommentAddTitle => 'Add Comment';

  @override
  String get artworkCommentAddHint => 'Share your thoughts about this artwork...';

  @override
  String get artworkCommentPostButton => 'Post Comment';

  @override
  String get artworkCommentAddedToast => 'Comment added successfully!';

  @override
  String get profileFieldOfWorkLabel => 'Field of work';

  @override
  String get profileYearsActiveLabel => 'Years active';

  @override
  String profileYearsActiveValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '$count year',
    );
    return '$_temp0';
  }

  @override
  String get manageMarkersPickArAssetPlaceholder => 'Select an AR asset';

  @override
  String get commonExhibition => 'Exhibition';

  @override
  String get commonCollection => 'Collection';

  @override
  String get commonInstitution => 'Institution';

  @override
  String get commonDetails => 'Details';

  @override
  String communitySubjectLinkedLabel(Object subjectType) {
    return 'Linked $subjectType';
  }

  @override
  String get communitySubjectSelectTitle => 'Link a subject';

  @override
  String get communitySubjectSelectPrompt => 'Choose what this post references';

  @override
  String get communitySubjectRemoveTooltip => 'Remove subject';

  @override
  String get communitySubjectNoneLabel => 'No subject';

  @override
  String get communitySubjectPickerTitle => 'Select subject';

  @override
  String get communitySubjectPickerSearchHint => 'Search by name';

  @override
  String get communitySubjectPickerSearchPrompt => 'Start typing to search institutions';

  @override
  String get communitySubjectPickerLoadFailed => 'Unable to load subjects.';

  @override
  String get communitySubjectPickerEmptyArtwork => 'No artworks found.';

  @override
  String get communitySubjectPickerEmptyExhibition => 'No exhibitions found.';

  @override
  String get communitySubjectPickerEmptyCollection => 'No collections found.';

  @override
  String get communitySubjectPickerEmptyInstitution => 'No institutions found.';

  @override
  String get supportSectionTitle => 'Support';

  @override
  String get supportSectionSubtitle => 'Help us keep building art.kubus - every donation helps.';

  @override
  String get supportSectionMoreInfo => 'More info';

  @override
  String get supportMethodKofi => 'Ko-fi';

  @override
  String get supportMethodKofiHint => 'Coffee-sized support';

  @override
  String get supportMethodPaypal => 'PayPal';

  @override
  String get supportMethodPaypalHint => 'Donate via PayPal';

  @override
  String get supportMethodGithubSponsors => 'GitHub Sponsors';

  @override
  String get supportMethodGithubSponsorsHint => 'Support via GitHub';

  @override
  String get supportDialogTitle => 'What your support enables';

  @override
  String get supportDialogSubtitle => 'Three tiers - all meaningful. Thank you for helping us keep building.';

  @override
  String get supportTier5Amount => '€5';

  @override
  String get supportTier5Body => 'Helps cover monthly infrastructure costs.';

  @override
  String get supportTier15Amount => '€15';

  @override
  String get supportTier15Body => 'Supports steady weekly improvements.';

  @override
  String get supportTier50Amount => '€50';

  @override
  String get supportTier50Body => 'Funds one focused development session (new feature / fixes / content updates).';

  @override
  String get commonChange => 'Change';

  @override
  String get commonOpen => 'Open';

  @override
  String get commonLoading => 'Loading';

  @override
  String get desktopShellNavHome => 'Home';

  @override
  String get desktopShellNavExplore => 'Explore';

  @override
  String get desktopShellNavConnect => 'Connect';

  @override
  String get desktopShellNavCreate => 'Create';

  @override
  String get desktopShellNavOrganize => 'Organize';

  @override
  String get desktopShellNavGovern => 'Govern';

  @override
  String get desktopShellNavTrade => 'Artifacts';

  @override
  String get desktopShellNavWeb3 => 'Infrastructure';

  @override
  String get navigationScreenCreateAr => 'Create AR';

  @override
  String get navigationScreenExploreMap => 'Explore Map';

  @override
  String get navigationScreenCommunity => 'Community';

  @override
  String get navigationScreenProfile => 'Profile';

  @override
  String get navigationScreenMarketplace => 'Digital Editions';

  @override
  String get navigationScreenWallet => 'Wallet';

  @override
  String get navigationScreenAnalytics => 'Analytics';

  @override
  String get navigationScreenSettings => 'Settings';

  @override
  String get navigationScreenMyStats => 'My Stats';

  @override
  String get navigationScreenAchievements => 'Achievements';

  @override
  String get navigationScreenDaoHub => 'Community Governance';

  @override
  String get navigationScreenArtistStudio => 'Artist Studio';

  @override
  String get navigationScreenInstitutionHub => 'Institution Hub';

  @override
  String get daoHubAppBarTitle => 'Community governance';

  @override
  String get labsDaoSemanticLabel => 'Community Governance';

  @override
  String get labsMarketplaceSemanticLabel => 'Digital Editions';

  @override
  String get daoHubHeaderSubtitle => 'Experimental community governance for artists, institutions, and cultural participation';

  @override
  String get daoHubInfoDialogTitle => 'How community governance works';

  @override
  String get daoHubInfoDialogBody => 'This lab gives the community a transparent way to propose, review, and discuss platform decisions. KUB8 records participation and recognition; it is not financial value.';

  @override
  String get daoHubTabActiveProposals => 'Proposals';

  @override
  String get daoHubTabVotingHistory => 'Voting history';

  @override
  String get daoHubTabCreateProposal => 'Create';

  @override
  String get daoHubTabTreasury => 'Treasury';

  @override
  String get daoHubTabDelegation => 'Delegation';

  @override
  String get daoCreateProposalTitle => 'Create new proposal';

  @override
  String get daoCreateProposalSubtitle => 'Submit a proposal for governance review';

  @override
  String get daoCreateProposalFieldTitleLabel => 'Proposal title';

  @override
  String get daoCreateProposalFieldTitleHint => 'Enter a clear, descriptive title';

  @override
  String get daoCreateProposalFieldDescriptionHint => 'Provide detailed explanation of your proposal';

  @override
  String get daoCreateProposalFieldVotingPeriodLabel => 'Voting period (days)';

  @override
  String get daoCreateProposalFieldVotingPeriodHint => 'How many days should voting be open?';

  @override
  String get daoCreateProposalSubmitButtonLabel => 'Submit proposal';

  @override
  String get daoProposalCategoryPlatformUpdate => 'Platform update';

  @override
  String get daoProposalCategoryNewFeature => 'New feature';

  @override
  String get daoProposalCategoryPolicyChange => 'Policy change';

  @override
  String get daoProposalCategoryTreasuryAllocation => 'Treasury allocation';

  @override
  String get daoProposalCategoryCommunityInitiative => 'Community initiative';

  @override
  String get daoProposalCategoryTechnicalImprovement => 'Technical improvement';

  @override
  String get daoVoteResultPassed => 'Passed';

  @override
  String get daoVoteResultFailed => 'Not passed';

  @override
  String get daoVotingHistoryInfoDateLabel => 'Date';

  @override
  String get daoVotingHistoryInfoYourVoteLabel => 'Your vote';

  @override
  String get daoVotingHistoryInfoParticipationLabel => 'Participation';

  @override
  String get daoVotingHistoryInfoYourVotingPowerLabel => 'Your voting power';

  @override
  String get desktopGovernanceSidebarOverviewTitle => 'Research overview';

  @override
  String get desktopGovernanceSidebarQuickActionsTitle => 'Quick Actions';

  @override
  String get desktopGovernanceQuickActionCreateProposalTitle => 'Create proposal';

  @override
  String get desktopGovernanceQuickActionCreateProposalSubtitle => 'Submit new governance idea';

  @override
  String get desktopGovernanceQuickActionVoteTitle => 'Review proposals';

  @override
  String get desktopGovernanceQuickActionVoteSubtitle => 'Shape the platform';

  @override
  String get desktopGovernanceQuickActionAnalyticsTitle => 'Analytics';

  @override
  String get desktopGovernanceQuickActionAnalyticsSubtitle => 'View participation signals';

  @override
  String get desktopGovernanceAnalyticsScreenTitle => 'Governance Analytics';

  @override
  String get desktopGovernanceSidebarStatisticsTitle => 'Research Statistics';

  @override
  String get desktopGovernanceSidebarRecentActivityTitle => 'Recent Activity';

  @override
  String get desktopGovernanceAcquireKub8Hint => 'Build participation and recognition to take part in governance';

  @override
  String get profileEditTitle => 'Edit profile';

  @override
  String get profileEditSaveChanges => 'Save changes';

  @override
  String get profileEditCoverImageClickToUpload => 'Click to upload cover image';

  @override
  String get profileEditCoverImageTapToAdd => 'Tap to add cover image';

  @override
  String profileEditCoverImageRecommendedSize(String size) {
    return 'Recommended size: $size';
  }

  @override
  String get profileEditAvatarClickToChange => 'Click to change avatar';

  @override
  String get profileEditAvatarTapToChange => 'Tap to change avatar';

  @override
  String get profileEditProfilePictureTitle => 'Profile picture';

  @override
  String get profileEditBasicInformationTitle => 'Basic information';

  @override
  String get profileEditPublicProfileDetailsSubtitle => 'Your public profile details';

  @override
  String get profileEditUsernameLabel => 'Username';

  @override
  String get profileEditUsernameHint => 'Enter username';

  @override
  String get profileEditUsernameRequiredError => 'Username is required';

  @override
  String get profileEditUsernameMinLengthError => 'Username must be at least 3 characters';

  @override
  String get profileEditUsernameMaxLengthError => 'Username must be 50 characters or fewer';

  @override
  String get authUsernameAlreadyTaken => 'Username already taken';

  @override
  String get profileEditDisplayNameLabel => 'Display name';

  @override
  String get profileEditDisplayNameHint => 'Enter display name';

  @override
  String get profileEditDisplayNameRequiredError => 'Display name is required';

  @override
  String get profileEditBioLabel => 'Bio';

  @override
  String get profileEditBioHint => 'Tell us about yourself...';

  @override
  String get profileEditSocialLinksTitle => 'Social links';

  @override
  String get profileEditSocialLinksSubtitle => 'Connect your social profiles';

  @override
  String get profileEditSocialHandleHint => '@username';

  @override
  String get profileEditSocialTwitterLabel => 'Twitter';

  @override
  String get profileEditSocialInstagramLabel => 'Instagram';

  @override
  String get profileEditSocialWebsiteLabel => 'Website';

  @override
  String get profileEditSocialWebsiteHint => 'example.com or https://example.com';

  @override
  String get profileEditSocialUrlInvalidError => 'Enter a valid website URL';

  @override
  String get profileEditArtistInformationTitle => 'Artist information';

  @override
  String get profileEditArtistSpecialtiesLabel => 'Specialties';

  @override
  String get profileEditArtistSpecialtiesHint => 'e.g., Digital Art, Sculpture, Photography';

  @override
  String get profileEditArtistSpecialtiesHelper => 'Separate multiple specialties with commas';

  @override
  String get profileEditArtistYearsActiveLabel => 'Years active';

  @override
  String get profileEditArtistYearsActiveHint => 'How many years have you been creating art?';

  @override
  String get profileEditArtistYearsActiveInvalidError => 'Please enter a valid number';

  @override
  String get profileEditInstitutionInformationTitle => 'Institution information';

  @override
  String get profileEditInstitutionDetailsSubtitle => 'Information about your institution';

  @override
  String get profileEditArtistDetailsSubtitle => 'Additional details about your artistic practice';

  @override
  String get profileEditInstitutionFocusAreasLabel => 'Focus areas';

  @override
  String get profileEditInstitutionEstablishedYearLabel => 'Established year';

  @override
  String get profileEditPrivacyVisibilityTitle => 'Privacy & visibility';

  @override
  String get profileEditPrivacyVisibilitySubtitle => 'Control who can see your content';

  @override
  String get profileEditInstitutionAboutTitle => 'About your institution';

  @override
  String get profileEditInstitutionAboutBody => 'Use the bio and social links above to describe your institution. You can manage exhibitions and events from the Institution Hub.';

  @override
  String get profileEditVerifiedStatusTitle => 'Verified status';

  @override
  String get profileEditVerifiedArtistTitle => 'Verified artist';

  @override
  String get profileEditVerifiedInstitutionTitle => 'Verified institution';

  @override
  String get profileEditVerifiedArtistSubtitle => 'Your artist status is verified through governance review';

  @override
  String get profileEditVerifiedInstitutionSubtitle => 'Your institution status is verified through governance review';

  @override
  String get profileEditProfileUpdatedToast => 'Profile updated successfully!';

  @override
  String get profileEditErrorToast => 'Something went wrong. Please try again.';

  @override
  String get profileEditNoWalletUploadAvatarToast => 'Sign in first; wallet access is only needed for wallet-linked profile actions.';

  @override
  String get profileEditNoWalletUploadCoverToast => 'Sign in first; wallet access is only needed for wallet-linked profile actions.';

  @override
  String get profileEditAvatarCopiedToClipboardToast => 'Copied avatar URL to clipboard';

  @override
  String get profileEditAvatarUploadedSavedToast => 'Avatar uploaded and saved!';

  @override
  String get profileEditAvatarUploadedLocalToast => 'Avatar uploaded locally (save failed)';

  @override
  String get profileEditAvatarUploadFailedToast => 'Avatar upload failed. Please try again.';

  @override
  String get profileEditAvatarUploadTimeoutToast => 'Profile image upload timed out. Please try a smaller image or retry.';

  @override
  String get profileEditCoverUploadedSavedToast => 'Cover image uploaded!';

  @override
  String get profileEditCoverUploadedLocalToast => 'Cover image uploaded locally';

  @override
  String get profileEditCoverUploadFailedToast => 'Cover image upload failed. Please try again.';

  @override
  String get profileEditCoverUploadTimeoutToast => 'Cover image upload timed out. Please try a smaller image or retry.';

  @override
  String get profileEditSaveTimeoutToast => 'Profile save timed out. Your connection may be slow. Please retry.';

  @override
  String get profileEditPickImageFailedToast => 'Could not select the image. Please try again.';

  @override
  String get profileEditUploadDebugInfoTitle => 'Upload debug info';

  @override
  String get profileEditUploadDebugInfoCopiedToast => 'Debug info copied to clipboard';

  @override
  String get desktopCommunityTabDiscover => 'Discover';

  @override
  String get desktopCommunityTabFollowing => 'Following';

  @override
  String get desktopCommunityTabGroups => 'Groups';

  @override
  String get desktopCommunityTabArt => 'Art';

  @override
  String get desktopCommunityHeaderTitle => 'Community';

  @override
  String get desktopCommunityHeaderSubtitle => 'Connect with artists and collectors';

  @override
  String get desktopCommunitySearchHint => 'Search posts, users, tags...';

  @override
  String get desktopCommunitySearchMinCharsHint => 'Type at least 2 characters to search';

  @override
  String get desktopCommunitySearchNoResults => 'No results found';

  @override
  String get desktopCommunityFilterAllPosts => 'All posts';

  @override
  String get desktopCommunityFilterFollowing => 'Following';

  @override
  String get desktopCommunityFilterArOnly => 'AR only';

  @override
  String get desktopCommunitySortPopularity => 'Popularity';

  @override
  String get desktopCommunitySortRecent => 'Recent';

  @override
  String get desktopCommunitySortTitle => 'Sort';

  @override
  String get desktopCommunitySortTop => 'Top';

  @override
  String get desktopCommunityFollowButton => 'Follow';

  @override
  String get desktopCommunityFollowingButton => 'Following';

  @override
  String get desktopCommunityBackToFeedTooltip => 'Back to feed';

  @override
  String get desktopCommunitySortedByPopularityTooltip => 'Sorted by popularity';

  @override
  String get desktopCommunitySortedByRecentTooltip => 'Sorted by recent';

  @override
  String desktopCommunityTaggedPostsLabel(String count) {
    return '$count tagged posts';
  }

  @override
  String get desktopCommunityTagUnavailableTitle => 'Tag unavailable';

  @override
  String get desktopCommunityTagUnavailableBody => 'We could not open that tag. It may have been removed or is not available right now.';

  @override
  String desktopCommunityPopularForTagTitle(String tag) {
    return 'Popular for #$tag';
  }

  @override
  String get desktopCommunityLoadingPostsLabel => 'Loading posts...';

  @override
  String get desktopCommunityEmptyDiscoverTitle => 'No posts yet';

  @override
  String get desktopCommunityEmptyDiscoverBody => 'Posts from creators around the world will appear here.';

  @override
  String get desktopCommunityEmptySearchBody => 'No posts match your search.';

  @override
  String get desktopCommunityEmptyFollowingTitle => 'No posts from followed creators';

  @override
  String get desktopCommunityEmptyFollowingBody => 'Follow artists and creators to see their updates here.';

  @override
  String get desktopCommunityLoadingNearbyArtLabel => 'Loading nearby art...';

  @override
  String get desktopCommunityEmptyNearbyArtTitle => 'No nearby art found';

  @override
  String get desktopCommunityEmptyNearbyArtBody => 'Explore your surroundings to discover location-based art.';

  @override
  String get desktopCommunityEmptySearchTitle => 'No posts match your search';

  @override
  String get desktopCommunityEmptySearchSubtitle => 'Try adjusting your keywords to find relevant art posts.';

  @override
  String get desktopCommunityLoadingGroupsLabel => 'Loading groups...';

  @override
  String get desktopCommunityEmptyGroupsTitle => 'No groups yet';

  @override
  String get desktopCommunityEmptyGroupsBody => 'Join or create groups to connect with like-minded art enthusiasts.';

  @override
  String get desktopCommunityCreateFabLabel => 'Create';

  @override
  String get desktopCommunityCreateFabCloseLabel => 'Close';

  @override
  String get desktopCommunityCreateOptionCreateGroup => 'Create group';

  @override
  String get desktopCommunityCreateOptionGroupPost => 'Group post';

  @override
  String get desktopCommunityCreateOptionArtDrop => 'Art drop';

  @override
  String get desktopCommunityCreateOptionPostReview => 'Post review';

  @override
  String get desktopCommunityCreateOptionPost => 'Post';

  @override
  String get desktopCommunityComposerTypePostLabel => 'Post';

  @override
  String get desktopCommunityComposerTypePostDescription => 'Share an update with the community';

  @override
  String get desktopCommunityComposerTypeArtDropLabel => 'Art drop';

  @override
  String get desktopCommunityComposerTypeArtDropDescription => 'Highlight a location-based activation';

  @override
  String get desktopCommunityComposerTypeArtReviewLabel => 'Art review';

  @override
  String get desktopCommunityComposerTypeArtReviewDescription => 'Share your thoughts on an artwork';

  @override
  String get desktopCommunityComposerTypeEventLabel => 'Event';

  @override
  String get desktopCommunityComposerTypeEventDescription => 'Announce meetups and gatherings';

  @override
  String get desktopCommunityComposerTypeQuestionLabel => 'Question';

  @override
  String get desktopCommunityComposerTypeQuestionDescription => 'Ask the community for feedback';

  @override
  String get desktopNavigationExpandTooltip => 'Expand navigation';

  @override
  String get desktopNavigationCollapseTooltip => 'Collapse navigation';

  @override
  String get desktopNavigationSubtitle => 'Art platform';

  @override
  String get profilePersonaArtEnthusiast => 'Art Enthusiast';

  @override
  String get userProfileAchievementCategoryEvents => 'Events';

  @override
  String get userProfileAchievementCategoryDiscovery => 'Discovery';

  @override
  String get userProfileAchievementCategoryAr => 'AR';

  @override
  String get userProfileAchievementCategoryNft => 'Archive records';

  @override
  String get userProfileAchievementCategoryCommunity => 'Community';

  @override
  String get userProfileAchievementCategorySocial => 'Social';

  @override
  String get userProfileAchievementCategoryTrading => 'Trading';

  @override
  String get userProfileAchievementCategorySpecial => 'Special';

  @override
  String get userProfileAchievementCategoryStreetArt => 'Street Art';

  @override
  String get daoHubStatYourVotingPowerLabel => 'Your voting power';

  @override
  String get daoHubStatActiveProposalsLabel => 'Active proposals';

  @override
  String get daoHubStatTotalDelegatesLabel => 'Total delegates';

  @override
  String get daoDelegationCurrentStatusTitle => 'Your delegation status';

  @override
  String get daoDelegationDelegatorsLabel => 'Delegators';

  @override
  String get daoDelegationSelfLabel => 'Self';

  @override
  String get commonDialogSemanticLabel => 'Dialog';

  @override
  String get commonFailedToLoadLabel => 'Failed to load';

  @override
  String get commonSubmit => 'Submit';

  @override
  String get commonUser => 'User';

  @override
  String commonTimeAgoMonths(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}mo ago',
      one: '1mo ago',
    );
    return '$_temp0';
  }

  @override
  String commonTimeAgoYears(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}y ago',
      one: '1y ago',
    );
    return '$_temp0';
  }

  @override
  String get postDetailPostUnlikedToast => 'Post unliked';

  @override
  String get communityBookmarkSaveForLaterTooltip => 'Save for later';

  @override
  String get communityBookmarkRemoveTooltip => 'Remove bookmark';

  @override
  String get communityQuickRepostAction => 'Quick repost';

  @override
  String get communityRepostWithCommentAction => 'Repost with comment';

  @override
  String get communityRepostWithCommentHint => 'Add your thoughts (optional)';

  @override
  String get communityRepostButtonLabel => 'Repost';

  @override
  String get communityRepostedToast => 'Reposted';

  @override
  String get communityRepostedWithCommentToast => 'Reposted with comment';

  @override
  String get desktopCommunityActiveCommunitiesTitle => 'Active communities';

  @override
  String get desktopCommunityNoCommunitiesFoundLabel => 'No communities found';

  @override
  String desktopCommunityViewAllCommunitiesButtonLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count communities',
      one: '1 community',
    );
    return 'View all $_temp0';
  }

  @override
  String get desktopCommunityGroupJoinedLabel => 'Joined';

  @override
  String get desktopCommunityGroupsSearchHint => 'Search groups...';

  @override
  String desktopCommunityGroupMembersLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String desktopCommunityLatestLabel(Object timeAgo) {
    return 'Latest: $timeAgo';
  }

  @override
  String get desktopCommunitySearchMessagesHint => 'Search messages...';

  @override
  String get desktopCommunitySelectCommunityDialogTitle => 'Select a community';

  @override
  String get desktopCommunitySearchUsersHint => 'Search users...';

  @override
  String get desktopCommunitySearchUsersToMessageHint => 'Search for users to message';

  @override
  String get desktopCommunityNewMessageTitle => 'New message';

  @override
  String get desktopCommunitySearchFailedTryAgain => 'Search failed. Try again.';

  @override
  String get desktopCommunityMessagesEmptyTitle => 'No messages yet';

  @override
  String get desktopCommunityMessagesEmptySubtitle => 'Start a conversation with an artist';

  @override
  String get desktopCommunityMessagesNoMatchesTitle => 'No matches found';

  @override
  String desktopCommunityMessagesNoResultsBody(Object query) {
    return 'We couldn\'t find any conversations, members, or messages matching \"$query\".';
  }

  @override
  String desktopCommunityMessagesSearchResultsLabel(num count, Object query) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return 'Showing $_temp0 for \"$query\"';
  }

  @override
  String get desktopCommunityAddHandleButtonLabel => 'Add handle';

  @override
  String get desktopCommunityAddTagDialogTitle => 'Add tag';

  @override
  String get desktopCommunityAddTagDialogHint => 'Enter tag (e.g., art, photography)';

  @override
  String get desktopCommunityAddTagHint => 'Add tag';

  @override
  String get desktopCommunityMentionDialogTitle => 'Mention someone';

  @override
  String get desktopCommunitySearchPeopleHint => 'Search artists, collectors, or wallets';

  @override
  String get desktopCommunityMentionHint => 'Mention';

  @override
  String get desktopCommunityBrowseTagsTooltip => 'Browse tags';

  @override
  String get desktopCommunityFindProfilesTooltip => 'Find profiles';

  @override
  String get desktopCommunityAddToPostTooltip => 'Add to post';

  @override
  String get desktopCommunityTagLocationButtonLabel => 'Tag a location';

  @override
  String get desktopCommunityTagLocationDialogTitle => 'Tag a location';

  @override
  String get desktopCommunityLocationSearchHint => 'e.g. Ljubljana, Slovenia';

  @override
  String get desktopCommunityClearSelectionButtonLabel => 'Clear selection';

  @override
  String get desktopCommunityJoinGroupToPostToast => 'Join a group to post.';

  @override
  String get desktopCommunityTargetCommunityOptionalTitle => 'Target a community (optional)';

  @override
  String get desktopCommunityTargetCommunityNoGroupHint => 'Posts shared to groups notify members instantly.';

  @override
  String desktopCommunityTargetCommunityPostingToLabel(Object groupName) {
    return 'Posting to $groupName';
  }

  @override
  String get desktopCommunityRemoveGroupTooltip => 'Remove group';

  @override
  String get desktopCommunityArAttachmentsTitle => 'AR attachments';

  @override
  String get desktopCommunityArAttachmentsBody => 'Attach AR assets from your mobile device to ensure ARCore/ARKit compatibility. You can still tag this post and continue editing here.';

  @override
  String get desktopCommunityDownloadAppTitle => 'Download app';

  @override
  String get desktopCommunityDownloadAppButtonLabel => 'Download app';

  @override
  String get desktopCommunitySharedPhotoFallbackContent => 'Shared a photo';

  @override
  String get desktopCommunityPostPublishedToast => 'Post published!';

  @override
  String get desktopCommunityPostPublishFailedToast => 'Failed to post.';

  @override
  String get desktopCommunityPostCreatedSuccessToast => 'Post created successfully!';

  @override
  String get desktopCommunityPostCreateFailedToast => 'Failed to create post.';

  @override
  String get desktopCommunityCreatePostTitle => 'Create post';

  @override
  String get desktopCommunityComposerPromptHint => 'Share what you\'re building, discovering, or thinking...';

  @override
  String get desktopCommunityComposerWhatsHappeningHint => 'What\'s happening?';

  @override
  String get desktopCommunityComposerPhotoLabel => 'Photo';

  @override
  String get desktopCommunityComposerLocationLabel => 'Location';

  @override
  String get desktopCommunityComposerTagLabel => 'Tag';

  @override
  String get desktopCommunityComposerMentionLabel => 'Mention';

  @override
  String get desktopCommunityComposerAddImageTooltip => 'Add image';

  @override
  String get desktopCommunityComposerAddArContentTooltip => 'Add AR content';

  @override
  String get desktopCommunityComposerAddLocationTooltip => 'Add location';

  @override
  String get desktopCommunityComposerMentionUserTooltip => 'Mention user';

  @override
  String get desktopCommunityComposerAddEmojiTooltip => 'Add emoji';

  @override
  String get desktopCommunityCreateGroupNameLabel => 'Group name';

  @override
  String get desktopCommunityCreateGroupDescriptionLabel => 'Description (optional)';

  @override
  String get desktopCommunityArtUseCurrentAreaButton => 'Use current area';

  @override
  String get desktopCommunityArtWiderRadiusButton => 'Wider radius';

  @override
  String get desktopCommunityArArtworkLabel => 'AR artwork';

  @override
  String get desktopCommunityArArtworkSubtitle => 'AR preview in development';

  @override
  String desktopCommunityTagFeedLoadingPostsLabel(Object tag) {
    return 'Loading #$tag posts...';
  }

  @override
  String desktopCommunityTagFeedEmptyTitle(Object tag) {
    return 'No posts for #$tag';
  }

  @override
  String desktopCommunityTagFeedEmptyBody(Object tag) {
    return 'Create or discover posts tagged #$tag to see them here.';
  }

  @override
  String desktopCommunityTagFeedNoPostsFoundError(Object tag) {
    return 'No posts found for #$tag';
  }

  @override
  String desktopCommunityTagFeedTopPostsTitle(Object tag) {
    return 'Top posts for #$tag';
  }

  @override
  String get desktopCommunityTagFeedSortedByPopularityDescription => 'Sorted by popularity (likes, shares, comments, and views).';

  @override
  String desktopCommunityTagFeedTaggedPostsAcrossCommunityLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tagged posts across the community',
      one: '1 tagged post across the community',
    );
    return '$_temp0';
  }

  @override
  String get desktopCommunityTrendingTitle => 'Trending';

  @override
  String get desktopCommunityTrendingLoadFailedTapToRetry => 'Could not load trending topics. Tap to retry.';

  @override
  String get desktopCommunityTrendingEmptyLabel => 'No trending tags yet. Engage with the community to surface trends.';

  @override
  String get desktopCommunityTrendingBasedOnRecentPostsLabel => 'Based on recent posts';

  @override
  String get desktopCommunityWhoToFollowTitle => 'Who to follow';

  @override
  String get desktopCommunitySuggestionsLoadFailedTapToRetry => 'Unable to load suggestions. Tap to retry.';

  @override
  String get desktopCommunitySuggestionsEmptyLabel => 'Follow artists to personalize your feed.';

  @override
  String get profileInvitesTooltip => 'Invites';

  @override
  String get profileConnectWalletToSeeProfileLabel => 'Connect wallet to see profile';

  @override
  String get profileMoreOptionsTitle => 'More options';

  @override
  String get profileNoBioYetTitle => 'No bio yet';

  @override
  String get profileNoBioYetDescription => 'Tap \"Edit Profile\" to add a short bio about yourself.';

  @override
  String get profileNoPostsYetDescription => 'Share your perspective with the community to see it here.';

  @override
  String get profileUpcomingEventsTitle => 'Upcoming events';

  @override
  String get profileUpcomingEventsEmptyLabel => 'Plan an event or workshop to engage your audience.';

  @override
  String get profileArtistHighlightsSubtitle => 'Keep your artworks and collections front and center.';

  @override
  String get profileArtistArtworksEmptyLabel => 'Upload your first artwork to showcase it here.';

  @override
  String get profileArtistCollectionsEmptyLabel => 'Create a collection to curate your story.';

  @override
  String get profileInstitutionHighlightsSubtitle => 'Promote upcoming programs and featured collections.';

  @override
  String get profileInstitutionEventsEmptyLabel => 'Share your next exhibition or gathering here.';

  @override
  String get profileInstitutionCollectionsEmptyLabel => 'Curate institutional collections to highlight.';

  @override
  String profileShowcaseEmptyTitle(Object title) {
    return 'No $title';
  }

  @override
  String get profileArtworkMediumFallback => 'Digital art';

  @override
  String get profileCollectionFallbackTitle => 'New collection';

  @override
  String get profileCollectionCuratedByYouFooter => 'Curated by you';

  @override
  String get profileEventFallbackTitle => 'Event';

  @override
  String get profileEventLocationTba => 'TBA';

  @override
  String get profileAchievementsEmptyTitle => 'No achievements yet';

  @override
  String get profilePerformanceSectionTitle => 'Performance';

  @override
  String get profilePerformanceArtworksViewedTitle => 'Artworks viewed';

  @override
  String get profilePerformanceDiscoveriesTitle => 'Discoveries';

  @override
  String get profilePerformanceCreatedOwnedTitle => 'Created / owned';

  @override
  String get profilePerformanceFollowersFollowingTitle => 'Followers / following';

  @override
  String get profilePerformancePublicStreetArtAddedTitle => 'Added Public Art';

  @override
  String get profileMenuSavedItemsTitle => 'Saved items';

  @override
  String get savedItemsSummarySubtitleEmpty => 'Bookmark artworks, events, collections, exhibitions, and posts to keep them here.';

  @override
  String savedItemsSummarySubtitleLastSaved(Object timestamp) {
    return 'Last saved $timestamp';
  }

  @override
  String savedItemsSummaryCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saved items',
      one: '1 saved item',
    );
    return '$_temp0';
  }

  @override
  String get savedItemsClearAllTooltip => 'Clear saved items';

  @override
  String get savedItemsClearAllDialogTitle => 'Clear all saved items?';

  @override
  String get savedItemsClearAllDialogMessage => 'This removes every saved item from this device. You can save them again later.';

  @override
  String get savedItemsClearAllDialogAction => 'Clear all';

  @override
  String get savedItemsClearedToast => 'All saved items cleared';

  @override
  String get savedItemsRemoveDialogTitle => 'Remove saved item?';

  @override
  String get savedItemsRemoveDialogMessage => 'Remove this saved item from your saved items?';

  @override
  String get savedItemsRemoveDialogAction => 'Remove';

  @override
  String get savedItemsRemovedToast => 'Removed from saved items';

  @override
  String savedItemsSavedAtLabel(Object timestamp) {
    return 'Saved $timestamp';
  }

  @override
  String savedItemsSectionTitle(Object itemType) {
    return 'Saved $itemType';
  }

  @override
  String savedItemsEmptySectionTitle(Object itemType) {
    return 'No saved $itemType yet';
  }

  @override
  String savedItemsEmptySectionDescription(Object itemType) {
    return 'Bookmark $itemType to keep it here.';
  }

  @override
  String get savedItemsPlaceholderTitle => 'Saved item';

  @override
  String get savedItemsPlaceholderDescription => 'Loading details...';

  @override
  String get profileMenuViewHistoryTitle => 'View history';

  @override
  String get profileMenuHelpSupportTitle => 'Help & support';

  @override
  String get profileHelpSupportTitle => 'Help & support';

  @override
  String get profileHelpDocumentationOption => 'Documentation';

  @override
  String get profileHelpContactSupportOption => 'Contact support';

  @override
  String get profileHelpReportBugOption => 'Report a bug';

  @override
  String get profileHelpAboutOption => 'About art.kubus';

  @override
  String get profileHelpOpeningDocumentationToast => 'Opening documentation...';

  @override
  String get profileContactSupportTitle => 'Contact support';

  @override
  String get profileContactSupportSubtitle => 'Get help from our support team:';

  @override
  String get profileContactSupportEmailLabel => 'Email';

  @override
  String get profileContactSupportLiveChatLabel => 'Live chat';

  @override
  String get profileContactSupportLiveChatAvailability => 'Available Mon-Fri 9AM-5PM';

  @override
  String get profileContactSupportWebsiteLabel => 'Website';

  @override
  String get profileReportBugTitle => 'Report a bug';

  @override
  String get profileReportBugSubtitle => 'Describe the issue you encountered:';

  @override
  String get profileReportBugHint => 'Enter bug description...';

  @override
  String get profileReportBugEmailSubject => 'Bug report';

  @override
  String get profileAnalyticsProfileTitle => 'Profile analytics';

  @override
  String get profileAnalyticsCommunityTitle => 'Community analytics';

  @override
  String get profileAboutTitle => 'About art.kubus';

  @override
  String profileAboutVersionLabel(Object version) {
    return 'Version $version';
  }

  @override
  String get profileAboutDescription => 'Open art platform for discovering public art and connecting artists, institutions, and communities. AR layers are in development.';

  @override
  String get profileAboutCopyright => 'Copyright (c) 2024 kubus Project';

  @override
  String get groupFeedSignInToPostLabel => 'Sign in to post.';

  @override
  String get groupFeedJoinToPostLabel => 'Join this group to post.';

  @override
  String get analyticsDisabledTitle => 'Analytics disabled';

  @override
  String get analyticsDisabledDescription => 'This feature is currently turned off.';

  @override
  String get analyticsNoProfileSelectedTitle => 'No profile selected';

  @override
  String get analyticsNoProfileSelectedDescription => 'Missing wallet address.';

  @override
  String get analyticsPausedTitle => 'Analytics paused';

  @override
  String get analyticsPausedDescription => 'Enable analytics in Settings to load charts.';

  @override
  String get analyticsUnableToLoadTitle => 'Unable to load';

  @override
  String get analyticsUnableToLoadDescription => 'Please try again later.';

  @override
  String get analyticsNoDataYetTitle => 'No data yet';

  @override
  String get analyticsNoDataYetDescription => 'This chart will populate as activity happens.';

  @override
  String get analyticsTimeframeLabel => 'Timeframe';

  @override
  String get analyticsMetricLabel => 'Metric';

  @override
  String get analyticsYourAnalyticsTitle => 'Your analytics';

  @override
  String get analyticsPublicAnalyticsTitle => 'Public analytics';

  @override
  String get analyticsPostsCreatedTitle => 'Posts created';

  @override
  String get analyticsMetricLikesReceivedLabel => 'Likes received';

  @override
  String get analyticsMetricViewsReceivedLabel => 'Views received';

  @override
  String get analyticsMetricEngagementLabel => 'Engagement';

  @override
  String get analyticsMetricViewsGivenLabel => 'Views given';

  @override
  String get analyticsTabOverview => 'Overview';

  @override
  String get analyticsTabTrends => 'Trends';

  @override
  String get analyticsTabInsights => 'Insights';

  @override
  String get analyticsTabCompare => 'Compare';

  @override
  String get analyticsHomeContextLabel => 'Home';

  @override
  String get analyticsHomeSubtitle => 'Unified personal analytics for reach, activity, and momentum across the app.';

  @override
  String get analyticsProfileSubtitle => 'A single profile-focused analytics surface with public and owner-aware metrics.';

  @override
  String get analyticsCommunitySubtitle => 'The same analytics system, configured around community posting and response signals.';

  @override
  String get analyticsShowFiltersAction => 'Show filters';

  @override
  String get analyticsHideFiltersAction => 'Hide filters';

  @override
  String get analyticsThisPeriodLabel => 'This period';

  @override
  String analyticsVsPreviousPeriod(Object period) {
    return 'vs previous $period';
  }

  @override
  String analyticsChartOverTimeTitle(Object metric) {
    return '$metric over time';
  }

  @override
  String get analyticsSectionKeyMetrics => 'Key metrics';

  @override
  String get analyticsSectionGoalProgress => 'Goal progress';

  @override
  String analyticsPercentComplete(Object percent) {
    return '$percent complete';
  }

  @override
  String analyticsTargetValue(Object value) {
    return 'Target: $value';
  }

  @override
  String get analyticsSectionTrendAnalysis => 'Trend analysis';

  @override
  String get analyticsTrendOverall => 'Overall trend';

  @override
  String get analyticsTrendGrowthRate => 'Growth rate';

  @override
  String get analyticsTrendVolatility => 'Volatility';

  @override
  String get analyticsTrendMomentum => 'Momentum';

  @override
  String get analyticsSectionSeasonalityPattern => 'Seasonality pattern';

  @override
  String get analyticsNotEnoughDataTitle => 'Not enough data';

  @override
  String get analyticsSeasonalityEmptyDescription => 'Seasonality becomes available after more activity is recorded.';

  @override
  String get analyticsSectionGrowthProjections => 'Growth projections';

  @override
  String get analyticsGrowthProjectionEmptyDescription => 'Projections require enough historical data in the selected range.';

  @override
  String get analyticsSectionInsights => 'Insights';

  @override
  String get analyticsInsightsEmptyTitle => 'No insights yet';

  @override
  String get analyticsInsightsEmptyDescription => 'Interact with the platform to start generating analytics.';

  @override
  String get analyticsSectionPerformanceBreakdown => 'Performance breakdown';

  @override
  String get analyticsSectionRecommendations => 'Recommendations';

  @override
  String get analyticsRecommendationsEmptyDescription => 'Recommendations appear once enough analytics data is available.';

  @override
  String get analyticsSectionPeriodComparison => 'Period comparison';

  @override
  String get analyticsComparisonsEmptyDescription => 'Comparisons require enough analytics data.';

  @override
  String get analyticsSectionPeerAnalysis => 'Peer analysis';

  @override
  String get analyticsPeerAnalysisEmptyDescription => 'Peer benchmarking requires aggregate platform data.';

  @override
  String get analyticsSectionMarketPosition => 'Market position';

  @override
  String get analyticsMarketPositionEmptyDescription => 'Market position insights require aggregate platform data.';

  @override
  String get analyticsTrendStable => 'Stable';

  @override
  String get analyticsTrendUpward => 'Upward';

  @override
  String get analyticsTrendDownward => 'Downward';

  @override
  String get analyticsVolatilityLow => 'Low';

  @override
  String get analyticsVolatilityMedium => 'Medium';

  @override
  String get analyticsVolatilityHigh => 'High';

  @override
  String get analyticsMomentumStrong => 'Strong';

  @override
  String get analyticsMomentumWeak => 'Weak';

  @override
  String get analyticsKeyMetricHourlyAverage => 'Hourly avg';

  @override
  String get analyticsKeyMetricDailyAverage => 'Daily avg';

  @override
  String get analyticsKeyMetricPeakHour => 'Peak hour';

  @override
  String get analyticsKeyMetricPeak => 'Peak';

  @override
  String get analyticsKeyMetricConsistency => 'Consistency';

  @override
  String get analyticsProjectionNext7Days => 'Next 7 days';

  @override
  String get analyticsProjectionNext30Days => 'Next 30 days';

  @override
  String analyticsPeakBucket(Object value) {
    return 'Peak bucket: $value';
  }

  @override
  String analyticsAveragePerBucket(Object metric, Object bucket, Object value) {
    return 'Average $metric per $bucket: $value';
  }

  @override
  String analyticsConsistencyValue(Object value) {
    return 'Consistency: $value';
  }

  @override
  String get analyticsPerformanceStability => 'Stability';

  @override
  String get analyticsPerformanceGrowth => 'Growth';

  @override
  String get analyticsPerformanceActivity => 'Activity';

  @override
  String get analyticsRecommendationImproveConsistency => 'Improve consistency';

  @override
  String analyticsRecommendationConsistencyDescription(Object activeBuckets, Object totalBuckets) {
    return 'Activity was recorded on $activeBuckets of $totalBuckets buckets.';
  }

  @override
  String get analyticsRecommendationReverseDecline => 'Reverse the decline';

  @override
  String get analyticsRecommendationReverseDeclineDescription => 'This period is down vs the previous period.';

  @override
  String get analyticsRecommendationMaintainMomentum => 'Maintain momentum';

  @override
  String get analyticsRecommendationMaintainMomentumDescription => 'This period is up vs the previous period.';

  @override
  String get analyticsComparisonTotal => 'Total';

  @override
  String get analyticsComparisonAveragePerHour => 'Avg / hour';

  @override
  String get analyticsComparisonAveragePerDay => 'Avg / day';

  @override
  String analyticsSharePeriodValue(Object period) {
    return 'Period: $period';
  }

  @override
  String analyticsShareChangeValue(Object change) {
    return 'Change: $change';
  }

  @override
  String analyticsShareTrendValue(Object trend) {
    return 'Trend: $trend';
  }

  @override
  String get analyticsShareUnavailable => 'Unable to share analytics on this device.';

  @override
  String get analyticsBucketHour => 'hour';

  @override
  String get analyticsBucketDay => 'day';

  @override
  String get userProfileCollectionsDesktopSubtitle => 'Curated sets of work';

  @override
  String get userProfileNoCollectionsTitle => 'No collections yet';

  @override
  String get userProfileNoCollectionsDescription => 'Your collections will appear here';

  @override
  String get desktopProfileHeaderSubtitle => 'Manage your identity and content';

  @override
  String get desktopProfileShareProfileLabel => 'Share profile';

  @override
  String get desktopProfilePortfolioTitle => 'Portfolio';

  @override
  String get desktopProfilePortfolioSubtitle => 'Your artworks and creative works';

  @override
  String get desktopProfileNoCollectionsDescription => 'Create collections to organize and curate your work.';

  @override
  String get desktopProfileEventsTitle => 'Events & Exhibitions';

  @override
  String get desktopProfileEventsSubtitle => 'Your upcoming and past events';

  @override
  String get desktopProfileNoEventsTitle => 'No events yet';

  @override
  String get desktopProfileNoEventsDescription => 'Plan exhibitions, workshops, or meetups to engage with collectors.';

  @override
  String get desktopProfileInstitutionProgramsTitle => 'Exhibitions & Programs';

  @override
  String get desktopProfileInstitutionProgramsSubtitle => 'Your featured exhibitions and events';

  @override
  String get desktopProfileNoExhibitionsTitle => 'No exhibitions yet';

  @override
  String get desktopProfileNoExhibitionsDescription => 'Create exhibitions and programs to showcase your institutional activities.';

  @override
  String get desktopProfilePermanentCollectionTitle => 'Permanent Collection';

  @override
  String get desktopProfilePermanentCollectionSubtitle => 'Featured works in your collection';

  @override
  String get desktopProfilePermanentCollectionEmptyDescription => 'Curate collections to highlight your institutional holdings.';

  @override
  String get desktopProfileRecentlyViewedTitle => 'Recently Viewed';

  @override
  String get desktopProfileRecentlyViewedSubtitle => 'Artworks you\'ve discovered';

  @override
  String get desktopProfileNoViewedArtworksTitle => 'No viewed artworks yet';

  @override
  String get desktopProfileNoViewedArtworksDescription => 'Explore the map to discover artworks and build your viewing history.';

  @override
  String get desktopProfilePerformanceSubtitle => 'Your activity and engagement metrics';

  @override
  String get desktopProfilePerformanceCreatedTitle => 'Created';

  @override
  String get desktopProfilePerformanceNftsOwnedTitle => 'Archive records held';

  @override
  String get desktopProfileAchievementsSubtitle => 'Your progress and milestones';

  @override
  String get desktopProfileYourPostsTitle => 'Your posts';

  @override
  String get desktopProfileYourPostsSubtitle => 'Content you\'ve shared with the community';

  @override
  String get commonUnknownArtist => 'Unknown artist';

  @override
  String get daoAnalyticsTitle => 'DAO Analytics';

  @override
  String get daoAnalyticsProposalsByTypeTitle => 'Proposals by Type';

  @override
  String get daoAnalyticsProposalsByStatusTitle => 'Proposals by Status';

  @override
  String get daoAnalyticsNoProposalsYetLabel => 'No proposals yet.';

  @override
  String get daoTreasuryTotalLabel => 'Total';

  @override
  String get daoTreasuryTotalValueLabel => 'Total Treasury Value';

  @override
  String get daoDelegationSelectDelegateTitle => 'Select a Delegate';

  @override
  String get daoDelegationSelectDelegateSubtitle => 'Choose a trusted community member to vote on your behalf';

  @override
  String daoDelegationDelegatorsCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count delegators',
      one: '1 delegator',
    );
    return '$_temp0';
  }

  @override
  String daoDelegationParticipationRateLabel(Object percent) {
    return '$percent% participation';
  }

  @override
  String daoProposalVotesSupportSummaryLabel(Object totalVotes, Object supportPct) {
    return '$totalVotes votes · $supportPct% support';
  }

  @override
  String get commonSearchHint => 'Search…';

  @override
  String get onboardingWelcomeDiscoverTitle => 'Discover art with kubus';

  @override
  String get onboardingWelcomeDiscoverBody => 'Explore artworks, exhibitions, public works, institutions, and creative spaces on the open art map.';

  @override
  String get onboardingWelcomeCreateTitle => 'Contribute to the archive';

  @override
  String get onboardingWelcomeCreateBody => 'Share practice, publish artworks, add context, and take part in a community-driven cultural archive.';

  @override
  String get onboardingWelcomeJoinTitle => 'Ready to begin?';

  @override
  String get onboardingWelcomeJoinBody => 'Start exploring, then create a profile when you want to participate.';

  @override
  String get promotionBuilderTitle => 'Boost Visibility';

  @override
  String get promotionBuilderSelectTierTitle => 'Select placement tier';

  @override
  String get promotionBuilderTierPremium => 'Premium Spot';

  @override
  String get promotionBuilderTierPremiumDesc => 'Top 3 guaranteed positions on home screen';

  @override
  String get promotionBuilderTierFeatured => 'Featured';

  @override
  String get promotionBuilderTierFeaturedDesc => 'Priority placement after premium slots';

  @override
  String get promotionBuilderTierBoost => 'Boost';

  @override
  String get promotionBuilderTierBoostDesc => 'Increased rotation in discovery feeds';

  @override
  String promotionBuilderPerDay(Object price) {
    return '$price/day';
  }

  @override
  String promotionBuilderSlotsAvailable(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count slots',
      one: '1 slot',
    );
    return '$_temp0 available';
  }

  @override
  String get promotionBuilderDurationTitle => 'Duration';

  @override
  String promotionBuilderDurationDays(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get promotionBuilderQuickPick3Days => '3 days';

  @override
  String get promotionBuilderQuickPick1Week => '1 week';

  @override
  String get promotionBuilderQuickPick2Weeks => '2 weeks';

  @override
  String get promotionBuilderQuickPick1Month => '1 month';

  @override
  String promotionBuilderDiscountBadge(Object percent) {
    return '$percent% off';
  }

  @override
  String get promotionBuilderSelectSlotTitle => 'Select slot';

  @override
  String promotionBuilderSlotLabel(Object index) {
    return 'Slot $index';
  }

  @override
  String get promotionBuilderSlotAvailable => 'Available';

  @override
  String promotionBuilderSlotBookedUntil(Object date) {
    return 'Booked until $date';
  }

  @override
  String get promotionBuilderAlternativeDates => 'Try these available dates';

  @override
  String get promotionBuilderStartDateTitle => 'Start date';

  @override
  String get promotionBuilderStartImmediately => 'Start immediately';

  @override
  String get promotionBuilderStartScheduled => 'Schedule for later';

  @override
  String get promotionBuilderPriceSummaryTitle => 'Price Summary';

  @override
  String get promotionBuilderPriceBaseRate => 'Base rate';

  @override
  String get promotionBuilderPriceSubtotal => 'Subtotal';

  @override
  String get promotionBuilderPriceDiscount => 'Volume discount';

  @override
  String get promotionBuilderPriceTotal => 'Total';

  @override
  String get promotionBuilderPaymentFiat => 'Pay with card';

  @override
  String get promotionBuilderPaymentKub8 => 'Pay with KUB8';

  @override
  String promotionBuilderKub8Balance(Object amount) {
    return 'Balance: $amount KUB8';
  }

  @override
  String get promotionBuilderCancellationNote => 'Full refund if cancelled 24+ hours before start';

  @override
  String get promotionBuilderSubmitButton => 'Submit for Review';

  @override
  String get promotionBuilderSubmitting => 'Submitting...';

  @override
  String get promotionBuilderSubmitSuccess => 'Promotion request submitted!';

  @override
  String get promotionBuilderSubmitError => 'Failed to submit. Please try again.';

  @override
  String get promotionBuilderLoadingRates => 'Loading promotion options...';

  @override
  String get promotionBuilderNoRatesAvailable => 'No promotion options available for this item type.';

  @override
  String promotionBuilderPromoteEntityTitle(Object entityLabel) {
    return 'Promote $entityLabel';
  }

  @override
  String get promotionBuilderHeaderSubtitle => 'Choose your promotion tier, duration, and payment method';

  @override
  String get promotionBuilderSelectedSlotUnavailable => 'Selected slot is not available';

  @override
  String get promotionBuilderOpeningCheckout => 'Opening payment checkout...';

  @override
  String get promotionBuilderCheckoutOpenFailed => 'Request created but checkout could not be opened. Please try again.';

  @override
  String get promotionBuilderContinuePayment => 'Continue to payment';

  @override
  String get promotionBuilderScheduledTitle => 'Scheduled Promotions';

  @override
  String get promotionBuilderCancelDialogTitle => 'Cancel Promotion?';

  @override
  String get promotionBuilderCancelDialogBody => 'Are you sure you want to cancel this promotion? A full refund will be issued if cancelled 24+ hours before start.';

  @override
  String get promotionBuilderCancelKeepAction => 'Keep';

  @override
  String get promotionBuilderCancelConfirmAction => 'Cancel Promotion';

  @override
  String get promotionBuilderCancelRefundProcessed => 'Cancelled and refund processed';

  @override
  String get promotionBuilderCancelSuccess => 'Promotion cancelled';

  @override
  String get promotionBuilderCancelFailed => 'Failed to cancel promotion';

  @override
  String promotionBuilderStartsOn(Object date) {
    return 'Starts $date';
  }

  @override
  String get promotionBuilderCancelTooltip => 'Cancel promotion';

  @override
  String get promotionBuilderPremiumSlotsHint => 'Premium slots are guaranteed top positions';

  @override
  String get promotionBuilderNoAlternativeDates => 'No available dates within the booking window';

  @override
  String get promotionBuilderNoRefundNote => 'No refund available (starts soon)';

  @override
  String promotionBuilderInsufficientKub8Balance(Object amount) {
    return 'Insufficient KUB8 balance ($amount)';
  }

  @override
  String promotionBuilderGuaranteedSlots(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count guaranteed slots',
      one: '1 guaranteed slot',
    );
    return '$_temp0';
  }

  @override
  String get promotionActionPromote => 'Promote';

  @override
  String get promotionActionBoost => 'Boost';

  @override
  String get promotionFeaturedLabel => 'Featured';

  @override
  String get promotionCampaignLabel => 'Campaign';

  @override
  String get promotionCheckoutLabel => 'Checkout';

  @override
  String get profileAchievementsProgressOnlyTitle => 'Milestone recorded';

  @override
  String get profileAchievementsUnavailableTitle => 'Achievements unavailable';

  @override
  String get profileAchievementsUnavailableDescription => 'Achievement details could not be loaded right now.';

  @override
  String get recognitionBadgePanelLoadFailed => 'Could not load recognition right now.';

  @override
  String get recognitionBadgePanelEmpty => 'No recognition yet. Visit events and take part in approvals to receive badges.';

  @override
  String get recognitionBadgePanelAttendance => 'Visits';

  @override
  String get recognitionBadgePanelParticipation => 'Participation';

  @override
  String get recognitionBadgePanelApproval => 'Approvals';

  @override
  String get recognitionBadgePanelCuratorial => 'Curatorial';

  @override
  String get recognitionBadgePanelInstitutional => 'Institutional';

  @override
  String get recognitionBadgePanelCollectibleProof => 'Edition proof';

  @override
  String get recognitionBadgePanelMinted => 'Issued';

  @override
  String get exhibitionDetailPromoteTooltip => 'Promote exhibition';

  @override
  String get eventDetailPromoteLabel => 'Promote';

  @override
  String get eventDetailPromoteTooltip => 'Promote event';

  @override
  String get eventDetailInvitesLabel => 'Invites';

  @override
  String get eventDetailInvitesTooltip => 'Share invite options';

  @override
  String get eventDetailLinkedExhibitionsLabel => 'Linked exhibitions';

  @override
  String get eventDetailLinkedExhibitionsEmpty => 'No exhibitions are linked to this event yet.';

  @override
  String eventDetailLinkedExhibitionsSummary(Object count) {
    return 'Linked exhibitions: $count';
  }

  @override
  String get eventDetailPoapAggregationHint => 'Claims are handled on the linked exhibition cards below.';

  @override
  String exhibitionDetailHostedBy(Object name) {
    return 'Hosted by $name';
  }

  @override
  String get exhibitionDetailManagementTitle => 'Management';

  @override
  String get exhibitionDetailPoapTitle => 'Attendance record';

  @override
  String get exhibitionDetailPoapDescription => 'Claim this proof of visit to add it to your recognition history.';

  @override
  String get exhibitionDetailPoapClaimedStatus => 'Claimed';

  @override
  String get exhibitionDetailPoapNotClaimedStatus => 'Ready to record';

  @override
  String get exhibitionDetailPoapSignedOutHint => 'Sign in to record this proof of visit badge.';

  @override
  String get exhibitionDetailPoapClaimAction => 'Claim badge';

  @override
  String get exhibitionDetailPoapClaimingAction => 'Claiming…';

  @override
  String get exhibitionDetailPoapClaimSuccessToast => 'Attendance record saved.';

  @override
  String get exhibitionDetailPoapClaimFailedToast => 'Unable to save attendance record right now.';

  @override
  String get scanProofDetectedToast => 'Scan detected.';

  @override
  String get scanProofVerifiedToast => 'Proof verified.';

  @override
  String get scanProofClaimingToast => 'Claiming visit proof.';

  @override
  String get scanProofAlreadyClaimedToast => 'Visit proof already recorded.';

  @override
  String get scanProofExpiredToast => 'Proof expired. Scan again.';

  @override
  String get exhibitionDetailPoapAttendanceHint => 'Attendance verification appears below for live events.';

  @override
  String get exhibitionDetailPoapEligibilityClaimed => 'Already recorded';

  @override
  String get exhibitionDetailPoapEligibilityVerified => 'Attendance verified';

  @override
  String get exhibitionDetailPoapEligibilityVisitRequired => 'Visit required';

  @override
  String get exhibitionDetailPoapEligibilitySignedOut => 'Sign in required';

  @override
  String get exhibitionDetailPoapEligibilityClaimReadyHint => 'Your attendance is verified. You can save this badge now.';

  @override
  String get exhibitionDetailPoapEligibilityNotPublished => 'Not published';

  @override
  String get exhibitionDetailPoapEligibilityNotPublishedHint => 'Publish this exhibition before attendees can save the badge.';

  @override
  String get exhibitionDetailPoapEligibilityMarkerLinkRequired => 'Marker link required';

  @override
  String get exhibitionDetailPoapEligibilityMarkerLinkHint => 'Open the linked marker or QR path to unlock badge eligibility.';

  @override
  String get exhibitionDetailPoapEligibilityAttendanceRequired => 'Attendance required';

  @override
  String get exhibitionDetailPoapEligibilityAttendanceHint => 'Visit the exhibition marker to verify attendance before saving.';

  @override
  String get exhibitionDetailPoapProofTypeMarkerAttendance => 'Marker attendance';

  @override
  String get exhibitionDetailPoapLinkedMarkersLabel => 'Linked markers';

  @override
  String get exhibitionDetailPoapLatestCheckInLabel => 'Latest check-in';

  @override
  String get exhibitionDetailAttendanceConfirmAction => 'Confirm attendance';

  @override
  String get exhibitionDetailAttendanceConfirmingAction => 'Confirming…';

  @override
  String get exhibitionDetailAttendanceAlreadyCheckedIn => 'Already checked in';

  @override
  String get exhibitionDetailAttendanceMoveCloserHint => 'Move closer to confirm attendance.';

  @override
  String get exhibitionDetailAttendanceConfirmedToast => 'Attendance confirmed.';

  @override
  String get exhibitionDetailAttendanceAlreadyCheckedInToast => 'Already checked in.';

  @override
  String get exhibitionDetailAttendanceUnableToConfirmToast => 'Unable to confirm attendance.';

  @override
  String exhibitionDetailAttendanceRewardPending(Object amount) {
    return '+$amount KUB8 recognition (pending)';
  }

  @override
  String get mapMarkerMoreInfo => 'More info';

  @override
  String get exhibitionDetailOpenPageCta => 'Open exhibition page';

  @override
  String get exhibitionNotFound => 'Exhibition not found';

  @override
  String get exhibitionDetailProgramTitle => 'Program';

  @override
  String get exhibitionDetailProgramEmpty => 'No events linked to this exhibition yet.';

  @override
  String get exhibitionDetailProgramOpenEvent => 'Open event';

  @override
  String get exhibitionDetailProgramLinkEvent => 'Link event';

  @override
  String get exhibitionDetailProgramCreateEvent => 'Create event';

  @override
  String get exhibitionDetailProgramManage => 'Manage program';

  @override
  String get exhibitionDetailProgramRemoveEvent => 'Remove from program';

  @override
  String get exhibitionDetailPoapNoneConfiguredOwnerHint => 'No POAP badge is configured yet. Enable one in the exhibition editor.';

  @override
  String get eventRelationTypeOpening => 'Opening';

  @override
  String get eventRelationTypeArtistTalk => 'Artist talk';

  @override
  String get eventRelationTypeGuidedTour => 'Guided tour';

  @override
  String get eventRelationTypeWorkshop => 'Workshop';

  @override
  String get eventRelationTypePerformance => 'Performance';

  @override
  String get eventRelationTypeLecture => 'Lecture';

  @override
  String get eventRelationTypeScreening => 'Screening';

  @override
  String get eventRelationTypeProgram => 'Program';

  @override
  String get eventRelationTypeOther => 'Other';

  @override
  String get eventDetailLinkedExhibitionsTitle => 'Linked exhibitions';

  @override
  String get eventDetailOpenExhibitionCta => 'Open exhibition';

  @override
  String get eventDetailLinkExhibition => 'Link exhibition';

  @override
  String get eventDetailCreateExhibition => 'Create exhibition';

  @override
  String get eventDetailManageLinks => 'Manage links';

  @override
  String get eventDetailUnlinkExhibition => 'Unlink exhibition';

  @override
  String get eventDetailPoapTitle => 'Event POAP';

  @override
  String get eventDetailPoapDescription => 'Proof-of-attendance badge for this event.';

  @override
  String get eventDetailPoapEligibilityNotPublished => 'Event not published';

  @override
  String get eventDetailPoapEligibilityNotPublishedHint => 'The event POAP can be claimed once the event is published.';

  @override
  String get eventDetailPoapScanProofRequired => 'Scan proof required';

  @override
  String get eventDetailPoapScanProofRequiredHint => 'Scan the QR code at the event to claim this badge.';

  @override
  String get eventDetailPoapCheckInFirstHint => 'Check in at the event location to claim this badge.';

  @override
  String get eventDetailPoapClaimFailedToast => 'Could not claim the event POAP. Please try again.';

  @override
  String get eventDetailPoapClaimSuccessToast => 'Event POAP claimed!';

  @override
  String get creatorPoapSectionTitle => 'POAP badge';

  @override
  String get creatorPoapSectionSubtitle => 'Reward attendees with a proof-of-attendance badge.';

  @override
  String get creatorPoapEnableTitle => 'Enable POAP badge';

  @override
  String get creatorPoapEnableSubtitle => 'Visitors can claim a proof-of-attendance badge.';

  @override
  String get creatorPoapTitleLabel => 'Badge title';

  @override
  String get creatorPoapDescriptionLabel => 'Badge description';

  @override
  String get creatorPoapIconLabel => 'Badge icon';

  @override
  String get creatorPoapRarityLabel => 'Rarity';

  @override
  String get creatorPoapRewardLabel => 'KUB8 reward';

  @override
  String get creatorPoapProofTypeLabel => 'Claim proof';

  @override
  String get creatorPoapProofMarkerAttendance => 'Marker attendance';

  @override
  String get creatorPoapProofScan => 'QR / scan proof';

  @override
  String get creatorPoapPreviewLabel => 'Preview';

  @override
  String get creatorPoapTitleRequired => 'Badge title is required';

  @override
  String get creatorPoapSyncFailedWarning => 'Saved, but the POAP badge could not be updated. Try again from the editor.';

  @override
  String get creatorRelationSyncFailedWarning => 'Saved, but linking could not be completed. Try again from the editor.';

  @override
  String get creatorDescriptionTooLongError => 'Description is too long (maximum 10,000 characters).';

  @override
  String get markerEditorSavedLinkSyncingToast => 'Marker saved, syncing exhibition link…';

  @override
  String get markerEditorLinkSyncFailedWarning => 'Marker saved, but the exhibition link could not be synced. Try again from the editor.';

  @override
  String exhibitionCreatorProgramLinkedCount(Object count) {
    return 'Linked events: $count';
  }

  @override
  String get poapRarityCommon => 'Common';

  @override
  String get poapRarityUncommon => 'Uncommon';

  @override
  String get poapRarityRare => 'Rare';

  @override
  String get poapRarityEpic => 'Epic';

  @override
  String get poapRarityLegendary => 'Legendary';

  @override
  String get eventCreatorLinkedExhibitionsTitle => 'Linked exhibitions';

  @override
  String get eventCreatorLinkedExhibitionsSubtitle => 'Attach this event to one or more exhibitions.';

  @override
  String get eventCreatorLinkedExhibitionsEmpty => 'No exhibitions selected.';

  @override
  String get eventCreatorAddExhibition => 'Link exhibition';

  @override
  String get eventCreatorCreateExhibitionForEvent => 'Create exhibition for this event';

  @override
  String get eventCreatorNoExhibitionsToLink => 'You don\'t manage any exhibitions yet.';

  @override
  String get exhibitionCreatorProgramTitle => 'Program / linked events';

  @override
  String get exhibitionCreatorProgramSubtitle => 'Add openings, talks, tours and other events to this exhibition.';

  @override
  String get exhibitionCreatorProgramEmpty => 'No events linked yet.';

  @override
  String get exhibitionCreatorAttachEvent => 'Link event';

  @override
  String get exhibitionCreatorCreateEventForExhibition => 'Create event';

  @override
  String get exhibitionCreatorNoEventsToLink => 'You don\'t manage any events yet.';

  @override
  String get exhibitionCreatorRelationTypeLabel => 'Relation type';

  @override
  String get selectEventsDialogTitle => 'Select events';

  @override
  String get selectExhibitionsDialogTitle => 'Select exhibitions';

  @override
  String get authVerifyEmailSuccessTitle => 'Email confirmed';

  @override
  String get authVerifyEmailSuccessBodyAutoContinue => 'Opening your art.kubus workspace…';

  @override
  String authVerifyEmailSuccessBodyAutoContinueWithEmail(String email) {
    return '$email is verified. Opening your art.kubus workspace…';
  }

  @override
  String get authVerifyEmailSuccessBodyManual => 'Your email address is verified. Continue to finish your art.kubus setup.';

  @override
  String authVerifyEmailSuccessBodyManualWithEmail(String email) {
    return '$email is verified. Continue to finish your art.kubus setup.';
  }

  @override
  String get authVerifyEmailContinueNow => 'Continue now';

  @override
  String get authVerifyEmailContinue => 'Continue';

  @override
  String get authVerifyEmailSessionFailed => 'Could not continue from verification. Try again.';

  @override
  String get walletSetupTitle => 'Secure your art.kubus identity';

  @override
  String get walletSetupSubtitle => 'Create your wallet. You stay in control.';

  @override
  String get walletSetupAccountNote => 'You keep signing in with your account — the wallet becomes your public identity.';

  @override
  String get walletSetupCreateTitle => 'Create new art.kubus wallet';

  @override
  String get walletSetupCreateBody => 'Generate a new wallet and link it to the account you just created.';

  @override
  String get walletSetupCreateAction => 'Create wallet';

  @override
  String get walletSetupAlreadyHaveWallet => 'I already have a wallet';

  @override
  String walletSetupSignedInAs(String name) {
    return 'Signed in as $name';
  }

  @override
  String get walletSetupImportTitle => 'Import existing wallet';

  @override
  String get walletSetupImportBody => 'Use a recovery phrase for a wallet you already control.';

  @override
  String get walletSetupImportAction => 'Import wallet';

  @override
  String get walletSetupImportLinkAction => 'Link imported wallet';

  @override
  String get walletSetupConnectTitle => 'Connect external wallet';

  @override
  String get walletSetupConnectBody => 'Connect a browser or mobile wallet you already use.';

  @override
  String get walletSetupConnectAction => 'Connect wallet';

  @override
  String get walletSetupRecoveryPhraseLabel => 'Recovery phrase';

  @override
  String get walletSetupEnterRecoveryPhraseInline => 'Enter your recovery phrase to import a wallet.';

  @override
  String get walletSetupDisabledError => 'Wallet connection is disabled right now.';

  @override
  String get walletSetupSessionMissingError => 'Your account session could not be confirmed. Go back to the account step and sign in again — do not create a new account.';

  @override
  String get walletSetupGenericLinkError => 'Wallet linking failed. Try again.';

  @override
  String get walletSetupStatusLoginAccount => 'Login account';

  @override
  String walletSetupStatusAccountId(String id) {
    return 'Account ID $id';
  }

  @override
  String get walletSetupStatusAuthenticatedAccount => 'Authenticated account';

  @override
  String get walletSetupStatusLocalWallet => 'Local wallet';

  @override
  String get walletSetupStatusAccountLink => 'Account link';

  @override
  String get walletSetupStatusVerification => 'Verification';

  @override
  String walletSetupStatusVerifiedLinked(String wallet) {
    return 'Verified linked wallet $wallet';
  }

  @override
  String get walletSetupPhaseReady => 'Choose a wallet action to continue.';

  @override
  String get walletSetupPhaseCreating => 'Creating local wallet…';

  @override
  String get walletSetupPhaseWalletReady => 'Local wallet ready — preparing account link.';

  @override
  String get walletSetupPhaseLinking => 'Linking wallet to your account and verifying…';

  @override
  String get walletSetupPhaseLinked => 'Wallet linked to this account.';

  @override
  String get walletSetupPhaseFailed => 'Wallet link failed. Your account was not changed.';

  @override
  String get onboardingStageWelcome => 'Welcome';

  @override
  String get onboardingStageAccount => 'Account';

  @override
  String get onboardingStageProfile => 'Profile';

  @override
  String get onboardingStageWallet => 'Wallet';

  @override
  String get onboardingStageSecure => 'Secure';

  @override
  String get onboardingStageEnter => 'Enter art.kubus';

  @override
  String onboardingStageProgress(int current, int total) {
    return 'Step $current of $total';
  }
}
