import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sl')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'art.kubus'**
  String get appTitle;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get commonSignIn;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get commonSkip;

  /// No description provided for @commonSkipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get commonSkipForNow;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get commonSavedToast;

  /// No description provided for @commonActionFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get commonActionFailedToast;

  /// No description provided for @commonNetworkErrorToast.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please try again.'**
  String get commonNetworkErrorToast;

  /// No description provided for @commonTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get commonTitle;

  /// No description provided for @commonDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get commonDescription;

  /// No description provided for @commonPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get commonPrice;

  /// No description provided for @commonForSale.
  ///
  /// In en, this message translates to:
  /// **'For sale'**
  String get commonForSale;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get commonMore;

  /// No description provided for @commonEditedTag.
  ///
  /// In en, this message translates to:
  /// **'(edited)'**
  String get commonEditedTag;

  /// No description provided for @commonLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get commonLink;

  /// No description provided for @commonPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get commonPublish;

  /// No description provided for @commonUnpublish.
  ///
  /// In en, this message translates to:
  /// **'Unpublish'**
  String get commonUnpublish;

  /// No description provided for @commonDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get commonDraft;

  /// No description provided for @commonPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get commonPublished;

  /// No description provided for @commonStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get commonStatus;

  /// No description provided for @commonRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get commonGotIt;

  /// No description provided for @commonInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get commonInstall;

  /// No description provided for @commonNavigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get commonNavigate;

  /// Label for an action that opens the in-app map centered on the current item (artwork/event/exhibition).
  ///
  /// In en, this message translates to:
  /// **'Open on map'**
  String get commonOpenOnMap;

  /// No description provided for @commonReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get commonReplace;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get commonNotifications;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @shareOptionCreatePost.
  ///
  /// In en, this message translates to:
  /// **'Create community post'**
  String get shareOptionCreatePost;

  /// No description provided for @shareOptionSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send in message'**
  String get shareOptionSendMessage;

  /// No description provided for @shareOptionShareExternal.
  ///
  /// In en, this message translates to:
  /// **'Share outside app'**
  String get shareOptionShareExternal;

  /// No description provided for @shareLinkCopiedToast.
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard'**
  String get shareLinkCopiedToast;

  /// No description provided for @shareMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Send in message'**
  String get shareMessageTitle;

  /// No description provided for @shareMessageSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search profiles…'**
  String get shareMessageSearchHint;

  /// No description provided for @shareMessageNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a message (optional)'**
  String get shareMessageNoteHint;

  /// No description provided for @shareDmDefaultMessage.
  ///
  /// In en, this message translates to:
  /// **'Check this out on art.kubus'**
  String get shareDmDefaultMessage;

  /// Toast shown after a share DM is sent.
  ///
  /// In en, this message translates to:
  /// **'Sent to {recipient}'**
  String shareMessageSentToast(String recipient);

  /// No description provided for @shareMessageFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to send message.'**
  String get shareMessageFailedToast;

  /// No description provided for @commonFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get commonFeed;

  /// No description provided for @commonGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get commonGroup;

  /// No description provided for @commonImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get commonImage;

  /// No description provided for @commonCoverImage.
  ///
  /// In en, this message translates to:
  /// **'Cover image'**
  String get commonCoverImage;

  /// No description provided for @commonChangeCover.
  ///
  /// In en, this message translates to:
  /// **'Change cover'**
  String get commonChangeCover;

  /// No description provided for @commonVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get commonVideo;

  /// No description provided for @commonMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get commonMembers;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get commonUpload;

  /// No description provided for @commonViewInAr.
  ///
  /// In en, this message translates to:
  /// **'View in AR'**
  String get commonViewInAr;

  /// No description provided for @commonViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get commonViewAll;

  /// No description provided for @commonProceed.
  ///
  /// In en, this message translates to:
  /// **'Proceed'**
  String get commonProceed;

  /// No description provided for @commonGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get commonGetStarted;

  /// No description provided for @commonWorking.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get commonWorking;

  /// No description provided for @commentHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit history'**
  String get commentHistoryTitle;

  /// No description provided for @commentHistoryCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get commentHistoryCurrentLabel;

  /// No description provided for @commentHistoryOriginalLabel.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get commentHistoryOriginalLabel;

  /// No description provided for @commentEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit comment'**
  String get commentEditTitle;

  /// No description provided for @commentUpdatedToast.
  ///
  /// In en, this message translates to:
  /// **'Comment updated'**
  String get commentUpdatedToast;

  /// No description provided for @commentEditFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to update comment. Please try again.'**
  String get commentEditFailedToast;

  /// No description provided for @commentDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete comment?'**
  String get commentDeleteConfirmTitle;

  /// No description provided for @commentDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will delete the comment and all replies.'**
  String get commentDeleteConfirmMessage;

  /// No description provided for @commentDeletedToast.
  ///
  /// In en, this message translates to:
  /// **'Comment deleted'**
  String get commentDeletedToast;

  /// No description provided for @commentDeleteFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete comment. Please try again.'**
  String get commentDeleteFailedToast;

  /// No description provided for @commonEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get commonEmail;

  /// No description provided for @commonPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get commonPassword;

  /// No description provided for @commonConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get commonConfirmPassword;

  /// No description provided for @commonUsernameOptional.
  ///
  /// In en, this message translates to:
  /// **'Username (optional)'**
  String get commonUsernameOptional;

  /// No description provided for @commonUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get commonUnlock;

  /// No description provided for @commonPinLabel.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get commonPinLabel;

  /// No description provided for @personaOnboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'How do you want to use art.kubus?'**
  String get personaOnboardingTitle;

  /// No description provided for @personaOnboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose what you’re here for. This only changes what we highlight-not what you can access.'**
  String get personaOnboardingSubtitle;

  /// No description provided for @personaOptionLoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Art lover'**
  String get personaOptionLoverTitle;

  /// No description provided for @personaOptionLoverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discover nearby artworks, exhibitions, and community updates.'**
  String get personaOptionLoverSubtitle;

  /// No description provided for @personaOptionCreatorTitle.
  ///
  /// In en, this message translates to:
  /// **'Artist / collective'**
  String get personaOptionCreatorTitle;

  /// No description provided for @personaOptionCreatorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create artworks and exhibitions, and collaborate with others.'**
  String get personaOptionCreatorSubtitle;

  /// No description provided for @personaOptionInstitutionTitle.
  ///
  /// In en, this message translates to:
  /// **'Institution / gallery'**
  String get personaOptionInstitutionTitle;

  /// No description provided for @personaOptionInstitutionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Organize events and exhibitions, manage collaborators, and share your program.'**
  String get personaOptionInstitutionSubtitle;

  /// No description provided for @exhibitionCreatorAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Create exhibition'**
  String get exhibitionCreatorAppBarTitle;

  /// No description provided for @exhibitionCreatorDisabledAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Exhibition'**
  String get exhibitionCreatorDisabledAppBarTitle;

  /// No description provided for @exhibitionCreatorDisabledMessage.
  ///
  /// In en, this message translates to:
  /// **'Exhibitions are currently disabled.'**
  String get exhibitionCreatorDisabledMessage;

  /// No description provided for @exhibitionCreatorBasicsTitle.
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get exhibitionCreatorBasicsTitle;

  /// No description provided for @exhibitionCreatorTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get exhibitionCreatorTitleLabel;

  /// No description provided for @exhibitionCreatorTitleValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title.'**
  String get exhibitionCreatorTitleValidation;

  /// No description provided for @exhibitionCreatorDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get exhibitionCreatorDescriptionLabel;

  /// No description provided for @exhibitionCreatorLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location name (optional)'**
  String get exhibitionCreatorLocationLabel;

  /// No description provided for @exhibitionCreatorScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get exhibitionCreatorScheduleTitle;

  /// No description provided for @exhibitionCreatorStartsLabel.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get exhibitionCreatorStartsLabel;

  /// No description provided for @exhibitionCreatorEndsLabel.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get exhibitionCreatorEndsLabel;

  /// No description provided for @exhibitionCreatorNotSetLabel.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get exhibitionCreatorNotSetLabel;

  /// No description provided for @exhibitionCreatorPublishTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get exhibitionCreatorPublishTitle;

  /// No description provided for @exhibitionCreatorPublishVisible.
  ///
  /// In en, this message translates to:
  /// **'Visible to everyone'**
  String get exhibitionCreatorPublishVisible;

  /// No description provided for @exhibitionCreatorPublishDraft.
  ///
  /// In en, this message translates to:
  /// **'Save as draft'**
  String get exhibitionCreatorPublishDraft;

  /// No description provided for @exhibitionCreatorCollabHint.
  ///
  /// In en, this message translates to:
  /// **'After creating, you can invite collaborators from the exhibition detail screen.'**
  String get exhibitionCreatorCollabHint;

  /// No description provided for @exhibitionDetailInvitesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get exhibitionDetailInvitesTooltip;

  /// No description provided for @exhibitionDetailRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get exhibitionDetailRefreshTooltip;

  /// No description provided for @exhibitionDetailOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get exhibitionDetailOverviewTitle;

  /// No description provided for @exhibitionDetailArtworksTitle.
  ///
  /// In en, this message translates to:
  /// **'Artworks'**
  String get exhibitionDetailArtworksTitle;

  /// No description provided for @exhibitionDetailArtworksManageHint.
  ///
  /// In en, this message translates to:
  /// **'Link artworks so visitors can discover them from this exhibition.'**
  String get exhibitionDetailArtworksManageHint;

  /// No description provided for @exhibitionDetailArtworksViewHint.
  ///
  /// In en, this message translates to:
  /// **'Artworks linked to this exhibition will appear here.'**
  String get exhibitionDetailArtworksViewHint;

  /// No description provided for @exhibitionDetailNoArtworksLinkedYet.
  ///
  /// In en, this message translates to:
  /// **'No artworks linked yet.'**
  String get exhibitionDetailNoArtworksLinkedYet;

  /// No description provided for @exhibitionDetailNoArtworksAvailableToLinkToast.
  ///
  /// In en, this message translates to:
  /// **'No artworks available to link.'**
  String get exhibitionDetailNoArtworksAvailableToLinkToast;

  /// No description provided for @exhibitionDetailAddArtworksDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add artworks'**
  String get exhibitionDetailAddArtworksDialogTitle;

  /// No description provided for @exhibitionDetailArtworksLinkedToast.
  ///
  /// In en, this message translates to:
  /// **'Artworks linked to exhibition.'**
  String get exhibitionDetailArtworksLinkedToast;

  /// No description provided for @exhibitionDetailLinkArtworksFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to link artworks. Please try again.'**
  String get exhibitionDetailLinkArtworksFailedToast;

  /// No description provided for @exhibitionDetailStatusRowLabel.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String exhibitionDetailStatusRowLabel(Object status);

  /// No description provided for @exhibitionDetailBadgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Badge'**
  String get exhibitionDetailBadgeTitle;

  /// No description provided for @exhibitionDetailBadgeClaimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get exhibitionDetailBadgeClaimed;

  /// No description provided for @exhibitionDetailBadgeNotClaimed.
  ///
  /// In en, this message translates to:
  /// **'Not claimed'**
  String get exhibitionDetailBadgeNotClaimed;

  /// No description provided for @exhibitionCreatorEndDateAfterStartError.
  ///
  /// In en, this message translates to:
  /// **'End date must be after start date.'**
  String get exhibitionCreatorEndDateAfterStartError;

  /// No description provided for @exhibitionCreatorCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create exhibition.'**
  String get exhibitionCreatorCreateFailed;

  /// No description provided for @exhibitionCreatorCreateFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Failed to create exhibition: {error}'**
  String exhibitionCreatorCreateFailedWithError(Object error);

  /// No description provided for @lockAppLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'App locked'**
  String get lockAppLockedTitle;

  /// No description provided for @lockAppLockedDescription.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to unlock access to the wallet features.'**
  String get lockAppLockedDescription;

  /// No description provided for @lockEnterPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN to unlock'**
  String get lockEnterPinTitle;

  /// No description provided for @lockAppUnlockedToast.
  ///
  /// In en, this message translates to:
  /// **'App unlocked'**
  String get lockAppUnlockedToast;

  /// No description provided for @lockAuthenticationFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed'**
  String get lockAuthenticationFailedToast;

  /// No description provided for @authSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to art.kubus'**
  String get authSignInTitle;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'and start exploring, creating, and connecting with other artists.'**
  String get authSignInSubtitle;

  /// No description provided for @authRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authRegisterTitle;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a profile and join the community.'**
  String get authRegisterSubtitle;

  /// No description provided for @authHighlightSignInMethods.
  ///
  /// In en, this message translates to:
  /// **'Wallet, email, or Google sign-in'**
  String get authHighlightSignInMethods;

  /// No description provided for @authHighlightNoFees.
  ///
  /// In en, this message translates to:
  /// **'No fees required to authenticate'**
  String get authHighlightNoFees;

  /// No description provided for @authHighlightControl.
  ///
  /// In en, this message translates to:
  /// **'Control stays with you'**
  String get authHighlightControl;

  /// No description provided for @authHighlightOnboardingOptions.
  ///
  /// In en, this message translates to:
  /// **'Wallet or email onboarding'**
  String get authHighlightOnboardingOptions;

  /// No description provided for @authHighlightKeysLocal.
  ///
  /// In en, this message translates to:
  /// **'Keys stay on your device'**
  String get authHighlightKeysLocal;

  /// No description provided for @authHighlightOptionalWeb3.
  ///
  /// In en, this message translates to:
  /// **'Optional Web3 features available'**
  String get authHighlightOptionalWeb3;

  /// No description provided for @authSignedInProfileRefreshSoon.
  ///
  /// In en, this message translates to:
  /// **'Signed in. Your profile will refresh shortly.'**
  String get authSignedInProfileRefreshSoon;

  /// Title shown in a dialog when the user's session has expired and they need to re-authenticate.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get authReauthDialogTitle;

  /// Message shown in a dialog when the user's session has expired and they need to re-authenticate.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please verify your credentials to continue.'**
  String get authReauthDialogMessage;

  /// No description provided for @authAccountCreatedProfileLoading.
  ///
  /// In en, this message translates to:
  /// **'Account created. Loading your profile in the background.'**
  String get authAccountCreatedProfileLoading;

  /// No description provided for @authEmailSignInDisabled.
  ///
  /// In en, this message translates to:
  /// **'Email sign-in is disabled.'**
  String get authEmailSignInDisabled;

  /// No description provided for @authEmailRegistrationDisabled.
  ///
  /// In en, this message translates to:
  /// **'Email registration is disabled.'**
  String get authEmailRegistrationDisabled;

  /// No description provided for @authGoogleSignInDisabled.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is disabled.'**
  String get authGoogleSignInDisabled;

  /// No description provided for @authWalletConnectionDisabled.
  ///
  /// In en, this message translates to:
  /// **'Wallet connection is disabled right now.'**
  String get authWalletConnectionDisabled;

  /// No description provided for @authEnterValidEmailPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email and an 8+ character password.'**
  String get authEnterValidEmailPassword;

  /// No description provided for @authEnterValidEmailInline.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authEnterValidEmailInline;

  /// No description provided for @authPasswordPolicyError.
  ///
  /// In en, this message translates to:
  /// **'Password must be 8–128 characters and include a letter and a number.'**
  String get authPasswordPolicyError;

  /// No description provided for @authPasswordMismatchInline.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get authPasswordMismatchInline;

  /// No description provided for @authAccountAlreadyExistsToast.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists. Sign in instead.'**
  String get authAccountAlreadyExistsToast;

  /// No description provided for @authEmailSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Email sign-in failed. Please try again.'**
  String get authEmailSignInFailed;

  /// No description provided for @authRegistrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Please try again.'**
  String get authRegistrationFailed;

  /// No description provided for @authVerifyEmailRegistrationToast.
  ///
  /// In en, this message translates to:
  /// **'Registration successful. Check your email to verify your account.'**
  String get authVerifyEmailRegistrationToast;

  /// No description provided for @authEmailNotVerifiedToast.
  ///
  /// In en, this message translates to:
  /// **'Email not verified. Check your inbox to continue.'**
  String get authEmailNotVerifiedToast;

  /// No description provided for @authForgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPasswordLink;

  /// No description provided for @authVerifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get authVerifyEmailTitle;

  /// No description provided for @authVerifyEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link. Tap it to finish setting up your account.'**
  String get authVerifyEmailSubtitle;

  /// No description provided for @authVerifyEmailHighlightInbox.
  ///
  /// In en, this message translates to:
  /// **'Open your email app and find our message'**
  String get authVerifyEmailHighlightInbox;

  /// No description provided for @authVerifyEmailHighlightSpam.
  ///
  /// In en, this message translates to:
  /// **'Check spam/junk if you don’t see it'**
  String get authVerifyEmailHighlightSpam;

  /// No description provided for @authVerifyEmailHighlightSecure.
  ///
  /// In en, this message translates to:
  /// **'Links expire for security'**
  String get authVerifyEmailHighlightSecure;

  /// No description provided for @authVerifyEmailStatusVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get authVerifyEmailStatusVerifying;

  /// No description provided for @authVerifyEmailStatusVerified.
  ///
  /// In en, this message translates to:
  /// **'Email verified'**
  String get authVerifyEmailStatusVerified;

  /// No description provided for @authVerifyEmailStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for verification'**
  String get authVerifyEmailStatusPending;

  /// No description provided for @authVerifyEmailResendButton.
  ///
  /// In en, this message translates to:
  /// **'Resend verification email'**
  String get authVerifyEmailResendButton;

  /// No description provided for @authVerifyEmailEnterEmailInline.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to resend verification.'**
  String get authVerifyEmailEnterEmailInline;

  /// No description provided for @authVerifyEmailResendToast.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for this email, a verification email will be sent shortly.'**
  String get authVerifyEmailResendToast;

  /// No description provided for @authVerifyEmailResendFailedInline.
  ///
  /// In en, this message translates to:
  /// **'Could not resend verification email. Please try again.'**
  String get authVerifyEmailResendFailedInline;

  /// No description provided for @authVerifyEmailFailedInline.
  ///
  /// In en, this message translates to:
  /// **'This verification link is invalid or expired.'**
  String get authVerifyEmailFailedInline;

  /// No description provided for @authVerifyEmailSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Email verified. You can now sign in.'**
  String get authVerifyEmailSuccessToast;

  /// No description provided for @authVerifyEmailSignInHint.
  ///
  /// In en, this message translates to:
  /// **'After verifying, return here to sign in.'**
  String get authVerifyEmailSignInHint;

  /// No description provided for @authForgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get authForgotPasswordTitle;

  /// No description provided for @authForgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we’ll send a reset link.'**
  String get authForgotPasswordSubtitle;

  /// No description provided for @authForgotPasswordHighlightOne.
  ///
  /// In en, this message translates to:
  /// **'We never reveal whether an email exists'**
  String get authForgotPasswordHighlightOne;

  /// No description provided for @authForgotPasswordHighlightTwo.
  ///
  /// In en, this message translates to:
  /// **'Reset links expire quickly'**
  String get authForgotPasswordHighlightTwo;

  /// No description provided for @authForgotPasswordEnterEmailInline.
  ///
  /// In en, this message translates to:
  /// **'Enter your email.'**
  String get authForgotPasswordEnterEmailInline;

  /// No description provided for @authForgotPasswordSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get authForgotPasswordSendButton;

  /// No description provided for @authForgotPasswordSentToast.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for this email, a reset link will be sent shortly.'**
  String get authForgotPasswordSentToast;

  /// No description provided for @authForgotPasswordFailedInline.
  ///
  /// In en, this message translates to:
  /// **'Could not request a reset link. Please try again.'**
  String get authForgotPasswordFailedInline;

  /// No description provided for @authResetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get authResetPasswordTitle;

  /// No description provided for @authResetPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new password for your account.'**
  String get authResetPasswordSubtitle;

  /// No description provided for @authResetPasswordHighlightOne.
  ///
  /// In en, this message translates to:
  /// **'Use a strong password'**
  String get authResetPasswordHighlightOne;

  /// No description provided for @authResetPasswordHighlightTwo.
  ///
  /// In en, this message translates to:
  /// **'Reset links are single-use'**
  String get authResetPasswordHighlightTwo;

  /// No description provided for @authResetPasswordMissingTokenInline.
  ///
  /// In en, this message translates to:
  /// **'This reset link is missing a token.'**
  String get authResetPasswordMissingTokenInline;

  /// No description provided for @authResetPasswordSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get authResetPasswordSubmitButton;

  /// No description provided for @authResetPasswordSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Password updated. You can now sign in.'**
  String get authResetPasswordSuccessToast;

  /// No description provided for @authResetPasswordFailedInline.
  ///
  /// In en, this message translates to:
  /// **'Could not reset your password. The link may be invalid or expired.'**
  String get authResetPasswordFailedInline;

  /// No description provided for @authGoogleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Please try again.'**
  String get authGoogleSignInFailed;

  /// No description provided for @authGoogleRateLimitedRetryIn.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is temporarily rate limited. Retry in ~{duration}.'**
  String authGoogleRateLimitedRetryIn(Object duration);

  /// No description provided for @authConnectWalletButton.
  ///
  /// In en, this message translates to:
  /// **'Connect wallet'**
  String get authConnectWalletButton;

  /// No description provided for @authConnectWalletModalTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect a wallet'**
  String get authConnectWalletModalTitle;

  /// No description provided for @authConnectWalletModalDescriptionSignIn.
  ///
  /// In en, this message translates to:
  /// **'You’ll be asked to approve a signature in your wallet app. No fee is required to sign in.'**
  String get authConnectWalletModalDescriptionSignIn;

  /// No description provided for @authConnectWalletModalDescriptionRegister.
  ///
  /// In en, this message translates to:
  /// **'You’ll be asked to approve a signature in your wallet app. No fee is required to finish registration.'**
  String get authConnectWalletModalDescriptionRegister;

  /// No description provided for @authWalletOptionWalletConnect.
  ///
  /// In en, this message translates to:
  /// **'WalletConnect'**
  String get authWalletOptionWalletConnect;

  /// No description provided for @authWalletOptionOtherWallets.
  ///
  /// In en, this message translates to:
  /// **'Other wallets'**
  String get authWalletOptionOtherWallets;

  /// No description provided for @authOrLogInWithEmailOrUsername.
  ///
  /// In en, this message translates to:
  /// **'Or sign in with your email or username'**
  String get authOrLogInWithEmailOrUsername;

  /// No description provided for @authOrUseEmail.
  ///
  /// In en, this message translates to:
  /// **'Or use email'**
  String get authOrUseEmail;

  /// No description provided for @authNeedAccountRegister.
  ///
  /// In en, this message translates to:
  /// **'Need an account? Register'**
  String get authNeedAccountRegister;

  /// No description provided for @authHaveAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Have an account? Sign in'**
  String get authHaveAccountSignIn;

  /// No description provided for @authSignInWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Sign in with email'**
  String get authSignInWithEmail;

  /// No description provided for @authContinueWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Continue with email'**
  String get authContinueWithEmail;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to art.kubus'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Exhibition and community in one place'**
  String get onboardingWelcomeSubtitle;

  /// No description provided for @onboardingWelcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Discover artworks, explore places, and connect with creators. XR and Web3 are optional layers - the core experience works without them.'**
  String get onboardingWelcomeDescription;

  /// No description provided for @onboardingExploreTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore artworks'**
  String get onboardingExploreTitle;

  /// No description provided for @onboardingExploreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find art around you'**
  String get onboardingExploreSubtitle;

  /// No description provided for @onboardingExploreDescription.
  ///
  /// In en, this message translates to:
  /// **'Use the map to discover artworks and markers nearby. Every location can tell a story.'**
  String get onboardingExploreDescription;

  /// No description provided for @onboardingCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create and share'**
  String get onboardingCreateTitle;

  /// No description provided for @onboardingCreateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Express your creativity'**
  String get onboardingCreateSubtitle;

  /// No description provided for @onboardingCreateDescription.
  ///
  /// In en, this message translates to:
  /// **'Create AR experiences and share them with the community when you’re ready.'**
  String get onboardingCreateDescription;

  /// No description provided for @onboardingCommunityTitle.
  ///
  /// In en, this message translates to:
  /// **'Join the community'**
  String get onboardingCommunityTitle;

  /// No description provided for @onboardingCommunitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Collaborate by default'**
  String get onboardingCommunitySubtitle;

  /// No description provided for @onboardingCommunityDescription.
  ///
  /// In en, this message translates to:
  /// **'Follow artists, message, and collaborate on projects - cooperation is the default where it makes sense.'**
  String get onboardingCommunityDescription;

  /// No description provided for @onboardingCollectiblesTitle.
  ///
  /// In en, this message translates to:
  /// **'Collectibles (optional)'**
  String get onboardingCollectiblesTitle;

  /// No description provided for @onboardingCollectiblesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Proofs of visit and collectibles'**
  String get onboardingCollectiblesSubtitle;

  /// No description provided for @onboardingCollectiblesDescription.
  ///
  /// In en, this message translates to:
  /// **'Optionally connect a wallet to collect digital collectibles (NFT) and proofs of visit (POAP). The app remains useful without Web3.'**
  String get onboardingCollectiblesDescription;

  /// No description provided for @onboardingGrantPermissions.
  ///
  /// In en, this message translates to:
  /// **'Grant permissions'**
  String get onboardingGrantPermissions;

  /// No description provided for @onboardingSkipPermissions.
  ///
  /// In en, this message translates to:
  /// **'Skip permissions'**
  String get onboardingSkipPermissions;

  /// No description provided for @permissionsChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking permissions…'**
  String get permissionsChecking;

  /// No description provided for @permissionsSkipAll.
  ///
  /// In en, this message translates to:
  /// **'Skip all'**
  String get permissionsSkipAll;

  /// No description provided for @permissionsBenefitsTitle.
  ///
  /// In en, this message translates to:
  /// **'What you can do:'**
  String get permissionsBenefitsTitle;

  /// No description provided for @permissionsPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Your privacy is protected. We never share your data.'**
  String get permissionsPrivacyNote;

  /// No description provided for @permissionsGrantedLabel.
  ///
  /// In en, this message translates to:
  /// **'Permission granted'**
  String get permissionsGrantedLabel;

  /// No description provided for @permissionsGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get permissionsGetStarted;

  /// No description provided for @permissionsNextPermission.
  ///
  /// In en, this message translates to:
  /// **'Next permission'**
  String get permissionsNextPermission;

  /// No description provided for @permissionsGrantPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant permission'**
  String get permissionsGrantPermission;

  /// No description provided for @permissionsSkipThisPermission.
  ///
  /// In en, this message translates to:
  /// **'Skip this permission'**
  String get permissionsSkipThisPermission;

  /// No description provided for @permissionsPermissionGrantedToast.
  ///
  /// In en, this message translates to:
  /// **'Permission granted: {permission}'**
  String permissionsPermissionGrantedToast(Object permission);

  /// No description provided for @permissionsPermissionRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission required'**
  String get permissionsPermissionRequiredTitle;

  /// No description provided for @permissionsOpenSettingsDialogContent.
  ///
  /// In en, this message translates to:
  /// **'To enable {permission}, open Settings and grant the permission.'**
  String permissionsOpenSettingsDialogContent(Object permission);

  /// No description provided for @permissionsOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get permissionsOpenSettings;

  /// No description provided for @permissionsLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location access'**
  String get permissionsLocationTitle;

  /// No description provided for @permissionsLocationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discover art near you'**
  String get permissionsLocationSubtitle;

  /// No description provided for @permissionsLocationDescription.
  ///
  /// In en, this message translates to:
  /// **'We use your location to show artworks and markers placed in your area. Discover local artists and exhibitions nearby.'**
  String get permissionsLocationDescription;

  /// No description provided for @permissionsLocationBenefit1.
  ///
  /// In en, this message translates to:
  /// **'Find artworks near you'**
  String get permissionsLocationBenefit1;

  /// No description provided for @permissionsLocationBenefit2.
  ///
  /// In en, this message translates to:
  /// **'Discover local galleries and exhibitions'**
  String get permissionsLocationBenefit2;

  /// No description provided for @permissionsLocationBenefit3.
  ///
  /// In en, this message translates to:
  /// **'Get updates about nearby events'**
  String get permissionsLocationBenefit3;

  /// No description provided for @permissionsLocationBenefit4.
  ///
  /// In en, this message translates to:
  /// **'Track your exploration journey'**
  String get permissionsLocationBenefit4;

  /// No description provided for @permissionsCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera access'**
  String get permissionsCameraTitle;

  /// No description provided for @permissionsCameraSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Experience AR'**
  String get permissionsCameraSubtitle;

  /// No description provided for @permissionsCameraDescription.
  ///
  /// In en, this message translates to:
  /// **'The camera is essential for viewing AR artworks in your space. Place, interact with, and capture your experience.'**
  String get permissionsCameraDescription;

  /// No description provided for @permissionsCameraBenefit1.
  ///
  /// In en, this message translates to:
  /// **'View AR artworks in the real world'**
  String get permissionsCameraBenefit1;

  /// No description provided for @permissionsCameraBenefit2.
  ///
  /// In en, this message translates to:
  /// **'Place virtual sculptures in your space'**
  String get permissionsCameraBenefit2;

  /// No description provided for @permissionsCameraBenefit3.
  ///
  /// In en, this message translates to:
  /// **'Take photos to share'**
  String get permissionsCameraBenefit3;

  /// No description provided for @permissionsCameraBenefit4.
  ///
  /// In en, this message translates to:
  /// **'Scan QR codes to unlock content'**
  String get permissionsCameraBenefit4;

  /// No description provided for @permissionsNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get permissionsNotificationsTitle;

  /// No description provided for @permissionsNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stay connected'**
  String get permissionsNotificationsSubtitle;

  /// No description provided for @permissionsNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Get updates about new artworks, progress, collectibles (NFT), proofs of visit (POAP), and community activity.'**
  String get permissionsNotificationsDescription;

  /// No description provided for @permissionsNotificationsBenefit1.
  ///
  /// In en, this message translates to:
  /// **'New artwork updates'**
  String get permissionsNotificationsBenefit1;

  /// No description provided for @permissionsNotificationsBenefit2.
  ///
  /// In en, this message translates to:
  /// **'Progress and rewards'**
  String get permissionsNotificationsBenefit2;

  /// No description provided for @permissionsNotificationsBenefit3.
  ///
  /// In en, this message translates to:
  /// **'Collectible updates (NFT)'**
  String get permissionsNotificationsBenefit3;

  /// No description provided for @permissionsNotificationsBenefit4.
  ///
  /// In en, this message translates to:
  /// **'Community event reminders'**
  String get permissionsNotificationsBenefit4;

  /// No description provided for @permissionsPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo library access'**
  String get permissionsPhotosTitle;

  /// No description provided for @permissionsPhotosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save your creations'**
  String get permissionsPhotosSubtitle;

  /// No description provided for @permissionsPhotosDescription.
  ///
  /// In en, this message translates to:
  /// **'Save AR screenshots and downloads to your photo library so you can keep your memories and share them.'**
  String get permissionsPhotosDescription;

  /// No description provided for @permissionsPhotosBenefit1.
  ///
  /// In en, this message translates to:
  /// **'Save AR screenshots to your photos'**
  String get permissionsPhotosBenefit1;

  /// No description provided for @permissionsPhotosBenefit2.
  ///
  /// In en, this message translates to:
  /// **'Download artwork images'**
  String get permissionsPhotosBenefit2;

  /// No description provided for @permissionsPhotosBenefit3.
  ///
  /// In en, this message translates to:
  /// **'Export creations to share'**
  String get permissionsPhotosBenefit3;

  /// No description provided for @permissionsPhotosBenefit4.
  ///
  /// In en, this message translates to:
  /// **'Keep your collection accessible'**
  String get permissionsPhotosBenefit4;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the app language'**
  String get settingsLanguageDescription;

  /// No description provided for @languageSlovenian.
  ///
  /// In en, this message translates to:
  /// **'Slovene'**
  String get languageSlovenian;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @commonOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get commonOn;

  /// No description provided for @commonOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get commonOff;

  /// No description provided for @commonEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get commonEnabled;

  /// No description provided for @commonDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get commonDisabled;

  /// No description provided for @commonAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get commonAvailable;

  /// No description provided for @commonNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get commonNotAvailable;

  /// No description provided for @settingsGuestUserName.
  ///
  /// In en, this message translates to:
  /// **'Guest user'**
  String get settingsGuestUserName;

  /// No description provided for @desktopSettingsProfileSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your profile information visible to other users'**
  String get desktopSettingsProfileSectionSubtitle;

  /// No description provided for @desktopSettingsDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get desktopSettingsDisplayNameLabel;

  /// No description provided for @desktopSettingsDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get desktopSettingsDisplayNameHint;

  /// No description provided for @desktopSettingsUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get desktopSettingsUsernameLabel;

  /// No description provided for @desktopSettingsUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'@username'**
  String get desktopSettingsUsernameHint;

  /// No description provided for @desktopSettingsBioLabel.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get desktopSettingsBioLabel;

  /// No description provided for @desktopSettingsBioHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself'**
  String get desktopSettingsBioHint;

  /// No description provided for @desktopSettingsWebsiteLabel.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get desktopSettingsWebsiteLabel;

  /// No description provided for @desktopSettingsWebsiteHint.
  ///
  /// In en, this message translates to:
  /// **'https://'**
  String get desktopSettingsWebsiteHint;

  /// No description provided for @desktopSettingsLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get desktopSettingsLocationLabel;

  /// No description provided for @desktopSettingsLocationHint.
  ///
  /// In en, this message translates to:
  /// **'City, Country'**
  String get desktopSettingsLocationHint;

  /// No description provided for @desktopSettingsWalletSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your wallet connection and Web3 settings'**
  String get desktopSettingsWalletSectionSubtitle;

  /// No description provided for @desktopSettingsViewWalletButton.
  ///
  /// In en, this message translates to:
  /// **'View wallet'**
  String get desktopSettingsViewWalletButton;

  /// No description provided for @desktopSettingsSecuritySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get desktopSettingsSecuritySectionTitle;

  /// No description provided for @desktopSettingsDisconnectWalletTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect wallet'**
  String get desktopSettingsDisconnectWalletTileTitle;

  /// No description provided for @desktopSettingsDisconnectWalletTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out of Web3 features'**
  String get desktopSettingsDisconnectWalletTileSubtitle;

  /// No description provided for @desktopSettingsDisconnectWalletDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect wallet'**
  String get desktopSettingsDisconnectWalletDialogTitle;

  /// No description provided for @desktopSettingsDisconnectWalletDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Disconnect your wallet from this device? You can reconnect anytime.'**
  String get desktopSettingsDisconnectWalletDialogBody;

  /// No description provided for @desktopSettingsWalletDisconnectedToast.
  ///
  /// In en, this message translates to:
  /// **'Wallet disconnected'**
  String get desktopSettingsWalletDisconnectedToast;

  /// No description provided for @desktopSettingsDisconnectButton.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get desktopSettingsDisconnectButton;

  /// No description provided for @desktopSettingsExportingDataToast.
  ///
  /// In en, this message translates to:
  /// **'Exporting data…'**
  String get desktopSettingsExportingDataToast;

  /// No description provided for @desktopSettingsPlatformSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check which capabilities are available on this device'**
  String get desktopSettingsPlatformSubtitle;

  /// No description provided for @desktopSettingsAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customize the look and feel'**
  String get desktopSettingsAppearanceSubtitle;

  /// No description provided for @desktopSettingsShowFriendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Show friends'**
  String get desktopSettingsShowFriendsTitle;

  /// No description provided for @desktopSettingsShowFriendsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display your friends list on your profile'**
  String get desktopSettingsShowFriendsSubtitle;

  /// No description provided for @desktopSettingsShowAchievementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Show achievements'**
  String get desktopSettingsShowAchievementsTitle;

  /// No description provided for @desktopSettingsShowAchievementsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display your achievements on your profile'**
  String get desktopSettingsShowAchievementsSubtitle;

  /// No description provided for @desktopSettingsAllowMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow messages'**
  String get desktopSettingsAllowMessagesTitle;

  /// No description provided for @desktopSettingsAllowMessagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow others to message you'**
  String get desktopSettingsAllowMessagesSubtitle;

  /// No description provided for @desktopSettingsDangerZoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Irreversible actions that require caution'**
  String get desktopSettingsDangerZoneSubtitle;

  /// No description provided for @desktopSettingsAchievementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Achievements & rewards'**
  String get desktopSettingsAchievementsTitle;

  /// No description provided for @desktopSettingsAchievementsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track your progress and earn KUB8 points'**
  String get desktopSettingsAchievementsSubtitle;

  /// No description provided for @desktopSettingsAchievementsStatArtworksDiscovered.
  ///
  /// In en, this message translates to:
  /// **'Artworks discovered'**
  String get desktopSettingsAchievementsStatArtworksDiscovered;

  /// No description provided for @desktopSettingsAchievementsStatArViews.
  ///
  /// In en, this message translates to:
  /// **'AR views'**
  String get desktopSettingsAchievementsStatArViews;

  /// No description provided for @desktopSettingsAchievementsStatEventsAttended.
  ///
  /// In en, this message translates to:
  /// **'Events attended'**
  String get desktopSettingsAchievementsStatEventsAttended;

  /// No description provided for @desktopSettingsAchievementsStatKub8PointsEarned.
  ///
  /// In en, this message translates to:
  /// **'KUB8 points earned'**
  String get desktopSettingsAchievementsStatKub8PointsEarned;

  /// No description provided for @desktopSettingsAchievementFirstDiscoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'First discovery'**
  String get desktopSettingsAchievementFirstDiscoveryTitle;

  /// No description provided for @desktopSettingsAchievementFirstDiscoveryDescription.
  ///
  /// In en, this message translates to:
  /// **'Discover your first AR artwork'**
  String get desktopSettingsAchievementFirstDiscoveryDescription;

  /// No description provided for @desktopSettingsAchievementArtCollectorTitle.
  ///
  /// In en, this message translates to:
  /// **'Art collector'**
  String get desktopSettingsAchievementArtCollectorTitle;

  /// No description provided for @desktopSettingsAchievementArtCollectorDescription.
  ///
  /// In en, this message translates to:
  /// **'View 10 AR artworks'**
  String get desktopSettingsAchievementArtCollectorDescription;

  /// No description provided for @desktopSettingsAchievementCommunityMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Community member'**
  String get desktopSettingsAchievementCommunityMemberTitle;

  /// No description provided for @desktopSettingsAchievementCommunityMemberDescription.
  ///
  /// In en, this message translates to:
  /// **'Join 3 community groups'**
  String get desktopSettingsAchievementCommunityMemberDescription;

  /// No description provided for @desktopSettingsAchievementEventExplorerTitle.
  ///
  /// In en, this message translates to:
  /// **'Event explorer'**
  String get desktopSettingsAchievementEventExplorerTitle;

  /// No description provided for @desktopSettingsAchievementEventExplorerDescription.
  ///
  /// In en, this message translates to:
  /// **'Attend 5 art events'**
  String get desktopSettingsAchievementEventExplorerDescription;

  /// No description provided for @desktopSettingsAchievementNftCreatorTitle.
  ///
  /// In en, this message translates to:
  /// **'NFT creator'**
  String get desktopSettingsAchievementNftCreatorTitle;

  /// No description provided for @desktopSettingsAchievementNftCreatorDescription.
  ///
  /// In en, this message translates to:
  /// **'Mint your first NFT'**
  String get desktopSettingsAchievementNftCreatorDescription;

  /// No description provided for @desktopSettingsHelpSupportTitle.
  ///
  /// In en, this message translates to:
  /// **'Help & support'**
  String get desktopSettingsHelpSupportTitle;

  /// No description provided for @desktopSettingsHelpSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get help and find answers to common questions'**
  String get desktopSettingsHelpSupportSubtitle;

  /// No description provided for @desktopSettingsFaqTileTitle.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get desktopSettingsFaqTileTitle;

  /// No description provided for @desktopSettingsFaqTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Frequently asked questions'**
  String get desktopSettingsFaqTileSubtitle;

  /// No description provided for @desktopSettingsContactSupportTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get help from our team'**
  String get desktopSettingsContactSupportTileSubtitle;

  /// No description provided for @desktopSettingsReportBugTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Report a bug'**
  String get desktopSettingsReportBugTileTitle;

  /// No description provided for @desktopSettingsReportBugTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help us improve the app'**
  String get desktopSettingsReportBugTileSubtitle;

  /// No description provided for @desktopSettingsOpeningBugReportToast.
  ///
  /// In en, this message translates to:
  /// **'Opening bug report form…'**
  String get desktopSettingsOpeningBugReportToast;

  /// No description provided for @desktopSettingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'AR art platform connecting artists and institutions'**
  String get desktopSettingsAboutSubtitle;

  /// No description provided for @desktopSettingsFeaturesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get desktopSettingsFeaturesSectionTitle;

  /// No description provided for @desktopSettingsFeatureArDiscoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'AR art discovery'**
  String get desktopSettingsFeatureArDiscoveryTitle;

  /// No description provided for @desktopSettingsFeatureArDiscoveryDescription.
  ///
  /// In en, this message translates to:
  /// **'Experience artworks in augmented reality'**
  String get desktopSettingsFeatureArDiscoveryDescription;

  /// No description provided for @desktopSettingsFeatureWeb3IntegrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Web3 integration'**
  String get desktopSettingsFeatureWeb3IntegrationTitle;

  /// No description provided for @desktopSettingsFeatureWeb3IntegrationDescription.
  ///
  /// In en, this message translates to:
  /// **'Solana blockchain with KUB8 points'**
  String get desktopSettingsFeatureWeb3IntegrationDescription;

  /// No description provided for @desktopSettingsFeatureNftMintingTitle.
  ///
  /// In en, this message translates to:
  /// **'NFT minting'**
  String get desktopSettingsFeatureNftMintingTitle;

  /// No description provided for @desktopSettingsFeatureNftMintingDescription.
  ///
  /// In en, this message translates to:
  /// **'Create and trade digital art collectibles'**
  String get desktopSettingsFeatureNftMintingDescription;

  /// No description provided for @desktopSettingsFeatureCommunityTitle.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get desktopSettingsFeatureCommunityTitle;

  /// No description provided for @desktopSettingsFeatureCommunityDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect with artists and collectors'**
  String get desktopSettingsFeatureCommunityDescription;

  /// No description provided for @desktopSettingsFeatureInstitutionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Institutions'**
  String get desktopSettingsFeatureInstitutionsTitle;

  /// No description provided for @desktopSettingsFeatureInstitutionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Partner with galleries and museums'**
  String get desktopSettingsFeatureInstitutionsDescription;

  /// No description provided for @desktopSettingsLegalSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get desktopSettingsLegalSectionTitle;

  /// No description provided for @settingsNoWalletConnected.
  ///
  /// In en, this message translates to:
  /// **'No wallet connected'**
  String get settingsNoWalletConnected;

  /// No description provided for @settingsAppearanceSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearanceSectionTitle;

  /// No description provided for @settingsThemeModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get settingsThemeModeTitle;

  /// No description provided for @settingsThemeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeModeLight;

  /// No description provided for @settingsThemeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeModeDark;

  /// No description provided for @settingsThemeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeModeSystem;

  /// No description provided for @settingsAccentColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get settingsAccentColorTitle;

  /// No description provided for @settingsPlatformFeaturesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform features'**
  String get settingsPlatformFeaturesSectionTitle;

  /// No description provided for @settingsRunningOnPlatform.
  ///
  /// In en, this message translates to:
  /// **'Running on {platform}'**
  String settingsRunningOnPlatform(Object platform);

  /// No description provided for @settingsAvailableFeaturesLabel.
  ///
  /// In en, this message translates to:
  /// **'Available features:'**
  String get settingsAvailableFeaturesLabel;

  /// No description provided for @settingsDeveloperToolsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Developer tools'**
  String get settingsDeveloperToolsSectionTitle;

  /// No description provided for @settingsDeveloperResetOnboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset onboarding'**
  String get settingsDeveloperResetOnboardingTitle;

  /// No description provided for @settingsDeveloperResetOnboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reset onboarding state for testing'**
  String get settingsDeveloperResetOnboardingSubtitle;

  /// No description provided for @settingsDeveloperClearQuickActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear quick actions'**
  String get settingsDeveloperClearQuickActionsTitle;

  /// No description provided for @settingsDeveloperClearQuickActionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reset recently visited screens'**
  String get settingsDeveloperClearQuickActionsSubtitle;

  /// No description provided for @settingsDeveloperQuickActionsClearedToast.
  ///
  /// In en, this message translates to:
  /// **'Quick actions cleared'**
  String get settingsDeveloperQuickActionsClearedToast;

  /// No description provided for @settingsCapabilityCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera access (QR scanner, AR)'**
  String get settingsCapabilityCamera;

  /// No description provided for @settingsCapabilityAr.
  ///
  /// In en, this message translates to:
  /// **'Augmented reality features'**
  String get settingsCapabilityAr;

  /// No description provided for @settingsCapabilityNfc.
  ///
  /// In en, this message translates to:
  /// **'NFC communication'**
  String get settingsCapabilityNfc;

  /// No description provided for @settingsCapabilityGps.
  ///
  /// In en, this message translates to:
  /// **'Location services'**
  String get settingsCapabilityGps;

  /// No description provided for @settingsCapabilityBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication'**
  String get settingsCapabilityBiometrics;

  /// No description provided for @settingsCapabilityNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get settingsCapabilityNotifications;

  /// No description provided for @settingsCapabilityFileSystem.
  ///
  /// In en, this message translates to:
  /// **'File system access'**
  String get settingsCapabilityFileSystem;

  /// No description provided for @settingsCapabilityBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth connectivity'**
  String get settingsCapabilityBluetooth;

  /// No description provided for @settingsCapabilityVibration.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get settingsCapabilityVibration;

  /// No description provided for @settingsCapabilityOrientation.
  ///
  /// In en, this message translates to:
  /// **'Device orientation'**
  String get settingsCapabilityOrientation;

  /// No description provided for @settingsCapabilityBackground.
  ///
  /// In en, this message translates to:
  /// **'Background processing'**
  String get settingsCapabilityBackground;

  /// No description provided for @settingsProfileSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile settings'**
  String get settingsProfileSectionTitle;

  /// No description provided for @settingsProfileVisibilityPublicLabel.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get settingsProfileVisibilityPublicLabel;

  /// No description provided for @settingsProfileVisibilityPublicDescription.
  ///
  /// In en, this message translates to:
  /// **'Anyone can see your profile'**
  String get settingsProfileVisibilityPublicDescription;

  /// No description provided for @settingsProfileVisibilityPrivateLabel.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get settingsProfileVisibilityPrivateLabel;

  /// No description provided for @settingsProfileVisibilityPrivateDescription.
  ///
  /// In en, this message translates to:
  /// **'Only you can see your profile'**
  String get settingsProfileVisibilityPrivateDescription;

  /// No description provided for @settingsProfileVisibilityFriendsOnlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Friends only'**
  String get settingsProfileVisibilityFriendsOnlyLabel;

  /// No description provided for @settingsProfileVisibilityFriendsOnlyDescription.
  ///
  /// In en, this message translates to:
  /// **'Only friends can see your profile'**
  String get settingsProfileVisibilityFriendsOnlyDescription;

  /// No description provided for @settingsProfileVisibilityTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile visibility'**
  String get settingsProfileVisibilityTileTitle;

  /// No description provided for @settingsCurrentlyValue.
  ///
  /// In en, this message translates to:
  /// **'Currently: {value}'**
  String settingsCurrentlyValue(Object value);

  /// No description provided for @settingsPrivacySettingsTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy settings'**
  String get settingsPrivacySettingsTileTitle;

  /// No description provided for @settingsPrivacySummary.
  ///
  /// In en, this message translates to:
  /// **'Data: {dataState}, Ads: {adsState}'**
  String settingsPrivacySummary(Object dataState, Object adsState);

  /// No description provided for @settingsSecuritySettingsTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Security settings'**
  String get settingsSecuritySettingsTileTitle;

  /// No description provided for @settingsSecuritySummary.
  ///
  /// In en, this message translates to:
  /// **'2FA: {twoFactorStatus}, Auto-lock: {autoLockTime}'**
  String settingsSecuritySummary(Object twoFactorStatus, Object autoLockTime);

  /// No description provided for @settingsEditProfileTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get settingsEditProfileTileTitle;

  /// No description provided for @settingsEditProfileTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your username, bio, and avatar'**
  String get settingsEditProfileTileSubtitle;

  /// No description provided for @settingsAccountManagementTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Account management'**
  String get settingsAccountManagementTileTitle;

  /// No description provided for @settingsAccountSummary.
  ///
  /// In en, this message translates to:
  /// **'Type: {accountType}, Notifications: {notificationsState}'**
  String settingsAccountSummary(Object accountType, Object notificationsState);

  /// No description provided for @settingsRoleSimulationTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Role simulation'**
  String get settingsRoleSimulationTileTitle;

  /// No description provided for @settingsRoleSummary.
  ///
  /// In en, this message translates to:
  /// **'Artist: {artistStatus}, Institution: {institutionStatus}'**
  String settingsRoleSummary(Object artistStatus, Object institutionStatus);

  /// No description provided for @settingsRoleSimulationSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Role simulation'**
  String get settingsRoleSimulationSheetTitle;

  /// No description provided for @settingsRoleSimulationSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Toggle roles to preview profile layouts locally. Changes are local to this device.'**
  String get settingsRoleSimulationSheetSubtitle;

  /// No description provided for @settingsRoleArtistTitle.
  ///
  /// In en, this message translates to:
  /// **'Artist profile'**
  String get settingsRoleArtistTitle;

  /// No description provided for @settingsRoleArtistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show artist sections (artworks, collections)'**
  String get settingsRoleArtistSubtitle;

  /// No description provided for @settingsRoleInstitutionTitle.
  ///
  /// In en, this message translates to:
  /// **'Institution profile'**
  String get settingsRoleInstitutionTitle;

  /// No description provided for @settingsRoleInstitutionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show institution sections (events, collections)'**
  String get settingsRoleInstitutionSubtitle;

  /// No description provided for @settingsWalletSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet & Web3'**
  String get settingsWalletSectionTitle;

  /// No description provided for @settingsWalletConnectionTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet connection'**
  String get settingsWalletConnectionTileTitle;

  /// No description provided for @settingsWalletConnectionConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get settingsWalletConnectionConnected;

  /// No description provided for @settingsWalletConnectionNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get settingsWalletConnectionNotConnected;

  /// No description provided for @settingsNetworkTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get settingsNetworkTileTitle;

  /// No description provided for @settingsCurrentNetworkValue.
  ///
  /// In en, this message translates to:
  /// **'Current: {network}'**
  String settingsCurrentNetworkValue(Object network);

  /// No description provided for @settingsTransactionHistoryTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction history'**
  String get settingsTransactionHistoryTileTitle;

  /// No description provided for @settingsTransactionHistoryTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View all transactions'**
  String get settingsTransactionHistoryTileSubtitle;

  /// No description provided for @settingsBackupSettingsTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup settings'**
  String get settingsBackupSettingsTileTitle;

  /// No description provided for @settingsAutoBackupSummary.
  ///
  /// In en, this message translates to:
  /// **'Auto-backup: {status}'**
  String settingsAutoBackupSummary(Object status);

  /// No description provided for @settingsExportRecoveryPhraseTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Export recovery phrase'**
  String get settingsExportRecoveryPhraseTileTitle;

  /// No description provided for @settingsExportRecoveryPhraseTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Back up your wallet (sensitive)'**
  String get settingsExportRecoveryPhraseTileSubtitle;

  /// No description provided for @settingsImportWalletTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Import existing wallet (advanced)'**
  String get settingsImportWalletTileTitle;

  /// No description provided for @settingsImportWalletTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use a recovery phrase you already have'**
  String get settingsImportWalletTileSubtitle;

  /// No description provided for @settingsSecurityPrivacySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Security & privacy'**
  String get settingsSecurityPrivacySectionTitle;

  /// No description provided for @settingsBiometricTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication'**
  String get settingsBiometricTileTitle;

  /// No description provided for @settingsBiometricTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint or face unlock'**
  String get settingsBiometricTileSubtitle;

  /// No description provided for @settingsUseBiometricsOnUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Use biometrics on unlock'**
  String get settingsUseBiometricsOnUnlockTitle;

  /// No description provided for @settingsUseBiometricsOnUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prefer biometrics when unlocking the app'**
  String get settingsUseBiometricsOnUnlockSubtitle;

  /// No description provided for @settingsRequirePinTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Require PIN'**
  String get settingsRequirePinTileTitle;

  /// No description provided for @settingsRequirePinTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Require PIN to unlock the app'**
  String get settingsRequirePinTileSubtitle;

  /// No description provided for @settingsSetPinTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Set app PIN'**
  String get settingsSetPinTileTitle;

  /// No description provided for @settingsSetPinTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Protect the app with a numeric PIN'**
  String get settingsSetPinTileSubtitle;

  /// No description provided for @settingsAutoLockTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock'**
  String get settingsAutoLockTileTitle;

  /// No description provided for @settingsAutoLockTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lock app after inactivity'**
  String get settingsAutoLockTileSubtitle;

  /// No description provided for @settingsPrivacyModeTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy mode'**
  String get settingsPrivacyModeTileTitle;

  /// No description provided for @settingsPrivacyModeTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide sensitive information'**
  String get settingsPrivacyModeTileSubtitle;

  /// No description provided for @settingsClearCacheTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get settingsClearCacheTileTitle;

  /// No description provided for @settingsClearCacheTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove temporary files'**
  String get settingsClearCacheTileSubtitle;

  /// No description provided for @settingsDataAnalyticsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Data & analytics'**
  String get settingsDataAnalyticsSectionTitle;

  /// No description provided for @settingsAnalyticsTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get settingsAnalyticsTileTitle;

  /// No description provided for @settingsAnalyticsTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help improve the app'**
  String get settingsAnalyticsTileSubtitle;

  /// No description provided for @settingsCrashReportingTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Crash reporting'**
  String get settingsCrashReportingTileTitle;

  /// No description provided for @settingsCrashReportingTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send crash reports automatically'**
  String get settingsCrashReportingTileSubtitle;

  /// No description provided for @settingsSkipOnboardingTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip onboarding'**
  String get settingsSkipOnboardingTileTitle;

  /// No description provided for @settingsSkipOnboardingTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Skip welcome screens for returning users'**
  String get settingsSkipOnboardingTileSubtitle;

  /// No description provided for @settingsDataExportTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Data export'**
  String get settingsDataExportTileTitle;

  /// No description provided for @settingsDataExportTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download your data'**
  String get settingsDataExportTileSubtitle;

  /// No description provided for @settingsResetPermissionFlagsTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset permission flags'**
  String get settingsResetPermissionFlagsTileTitle;

  /// No description provided for @settingsResetPermissionFlagsTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear saved permission/service prompts'**
  String get settingsResetPermissionFlagsTileSubtitle;

  /// No description provided for @settingsAboutSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutSectionTitle;

  /// No description provided for @settingsAboutVersionTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsAboutVersionTileTitle;

  /// No description provided for @settingsAboutTermsTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get settingsAboutTermsTileTitle;

  /// No description provided for @settingsAboutTermsTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read our terms'**
  String get settingsAboutTermsTileSubtitle;

  /// No description provided for @settingsAboutPrivacyTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsAboutPrivacyTileTitle;

  /// No description provided for @settingsAboutPrivacyTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read our privacy policy'**
  String get settingsAboutPrivacyTileSubtitle;

  /// No description provided for @settingsAboutSupportTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsAboutSupportTileTitle;

  /// No description provided for @settingsAboutSupportTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get help or report issues'**
  String get settingsAboutSupportTileSubtitle;

  /// No description provided for @settingsAboutLicensesTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get settingsAboutLicensesTileTitle;

  /// No description provided for @settingsAboutLicensesTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View third-party licenses'**
  String get settingsAboutLicensesTileSubtitle;

  /// No description provided for @settingsAboutRateTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate app'**
  String get settingsAboutRateTileTitle;

  /// No description provided for @settingsAboutRateTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rate us on the app store'**
  String get settingsAboutRateTileSubtitle;

  /// No description provided for @settingsDangerZoneSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get settingsDangerZoneSectionTitle;

  /// No description provided for @settingsLogoutTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogoutTileTitle;

  /// No description provided for @settingsLogoutTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect wallet and clear session'**
  String get settingsLogoutTileSubtitle;

  /// No description provided for @settingsResetAppTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset app'**
  String get settingsResetAppTileTitle;

  /// No description provided for @settingsResetAppTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all data and settings'**
  String get settingsResetAppTileSubtitle;

  /// No description provided for @settingsDeleteAccountTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccountTileTitle;

  /// No description provided for @settingsDeleteAccountTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account'**
  String get settingsDeleteAccountTileSubtitle;

  /// No description provided for @settingsSelectNetworkDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Select network'**
  String get settingsSelectNetworkDialogTitle;

  /// No description provided for @settingsNetworkMainnetDescription.
  ///
  /// In en, this message translates to:
  /// **'Live Solana network'**
  String get settingsNetworkMainnetDescription;

  /// No description provided for @settingsNetworkDevnetDescription.
  ///
  /// In en, this message translates to:
  /// **'Development network for testing'**
  String get settingsNetworkDevnetDescription;

  /// No description provided for @settingsNetworkTestnetDescription.
  ///
  /// In en, this message translates to:
  /// **'Test network for development'**
  String get settingsNetworkTestnetDescription;

  /// No description provided for @settingsSwitchedToNetworkToast.
  ///
  /// In en, this message translates to:
  /// **'Switched to {network}'**
  String settingsSwitchedToNetworkToast(Object network);

  /// No description provided for @settingsConnectWalletFirstToast.
  ///
  /// In en, this message translates to:
  /// **'Please connect your wallet first'**
  String get settingsConnectWalletFirstToast;

  /// No description provided for @settingsBackupWalletDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup wallet'**
  String get settingsBackupWalletDialogTitle;

  /// No description provided for @settingsBackupWalletDialogIntro.
  ///
  /// In en, this message translates to:
  /// **'This will show your recovery phrase.'**
  String get settingsBackupWalletDialogIntro;

  /// No description provided for @settingsSecurityWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Security warning'**
  String get settingsSecurityWarningTitle;

  /// No description provided for @settingsSecurityWarningBullets.
  ///
  /// In en, this message translates to:
  /// **'• Make sure you\'re in a private place\n• Never share your recovery phrase\n• Write it down and store it safely'**
  String get settingsSecurityWarningBullets;

  /// No description provided for @settingsConnectOrCreateWalletFirstToast.
  ///
  /// In en, this message translates to:
  /// **'Connect or create a wallet first.'**
  String get settingsConnectOrCreateWalletFirstToast;

  /// No description provided for @settingsAutoLockImmediately.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get settingsAutoLockImmediately;

  /// No description provided for @settingsAutoLock10Seconds.
  ///
  /// In en, this message translates to:
  /// **'10 seconds'**
  String get settingsAutoLock10Seconds;

  /// No description provided for @settingsAutoLock30Seconds.
  ///
  /// In en, this message translates to:
  /// **'30 seconds'**
  String get settingsAutoLock30Seconds;

  /// No description provided for @settingsAutoLock1Minute.
  ///
  /// In en, this message translates to:
  /// **'1 minute'**
  String get settingsAutoLock1Minute;

  /// No description provided for @settingsAutoLock5Minutes.
  ///
  /// In en, this message translates to:
  /// **'5 minutes'**
  String get settingsAutoLock5Minutes;

  /// No description provided for @settingsAutoLock15Minutes.
  ///
  /// In en, this message translates to:
  /// **'15 minutes'**
  String get settingsAutoLock15Minutes;

  /// No description provided for @settingsAutoLock30Minutes.
  ///
  /// In en, this message translates to:
  /// **'30 minutes'**
  String get settingsAutoLock30Minutes;

  /// No description provided for @settingsAutoLock1Hour.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get settingsAutoLock1Hour;

  /// No description provided for @settingsAutoLock3Hours.
  ///
  /// In en, this message translates to:
  /// **'3 hours'**
  String get settingsAutoLock3Hours;

  /// No description provided for @settingsAutoLock6Hours.
  ///
  /// In en, this message translates to:
  /// **'6 hours'**
  String get settingsAutoLock6Hours;

  /// No description provided for @settingsAutoLock12Hours.
  ///
  /// In en, this message translates to:
  /// **'12 hours'**
  String get settingsAutoLock12Hours;

  /// No description provided for @settingsAutoLock1Day.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get settingsAutoLock1Day;

  /// No description provided for @settingsAutoLockNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get settingsAutoLockNever;

  /// No description provided for @settingsAutoLockTimerDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock timer'**
  String get settingsAutoLockTimerDialogTitle;

  /// No description provided for @settingsAutoLockSetToToast.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock set to {value}'**
  String settingsAutoLockSetToToast(Object value);

  /// No description provided for @settingsBiometricUnavailableToast.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock not available on this device.'**
  String get settingsBiometricUnavailableToast;

  /// No description provided for @settingsBiometricFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication failed.'**
  String get settingsBiometricFailedToast;

  /// No description provided for @settingsExportRecoveryPhraseDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Export recovery phrase'**
  String get settingsExportRecoveryPhraseDialogTitle;

  /// No description provided for @settingsExportRecoveryPhraseDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Only view your phrase in private. We never store it, and anyone with it can move your assets.'**
  String get settingsExportRecoveryPhraseDialogBody;

  /// No description provided for @settingsExportRecoveryPhraseDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm you are ready before revealing the words.'**
  String get settingsExportRecoveryPhraseDialogConfirm;

  /// No description provided for @settingsShowPhraseButton.
  ///
  /// In en, this message translates to:
  /// **'Show phrase'**
  String get settingsShowPhraseButton;

  /// No description provided for @settingsImportWalletDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Import existing wallet'**
  String get settingsImportWalletDialogTitle;

  /// No description provided for @settingsImportWalletDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Only paste a recovery phrase from a trusted source. Avoid public Wi-Fi and screensharing while importing.'**
  String get settingsImportWalletDialogBody;

  /// No description provided for @settingsImportWalletDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'We never store your seed phrase. You keep full ownership of your assets.'**
  String get settingsImportWalletDialogConfirm;

  /// No description provided for @settingsSetPinDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Set app PIN'**
  String get settingsSetPinDialogTitle;

  /// No description provided for @settingsConfirmPinLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get settingsConfirmPinLabel;

  /// No description provided for @settingsPinClearedToast.
  ///
  /// In en, this message translates to:
  /// **'PIN cleared'**
  String get settingsPinClearedToast;

  /// No description provided for @settingsClearPinButton.
  ///
  /// In en, this message translates to:
  /// **'Clear PIN'**
  String get settingsClearPinButton;

  /// No description provided for @settingsPinMinLengthError.
  ///
  /// In en, this message translates to:
  /// **'PIN must be at least 4 digits'**
  String get settingsPinMinLengthError;

  /// No description provided for @settingsPinMismatchError.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match'**
  String get settingsPinMismatchError;

  /// No description provided for @settingsPinSetSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'PIN set successfully'**
  String get settingsPinSetSuccessToast;

  /// No description provided for @settingsPinSetFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to set PIN'**
  String get settingsPinSetFailedToast;

  /// No description provided for @settingsClearCacheDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get settingsClearCacheDialogTitle;

  /// No description provided for @settingsClearCacheDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This will clear temporary files and may improve performance.'**
  String get settingsClearCacheDialogBody;

  /// No description provided for @settingsCacheClearedToast.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared successfully'**
  String get settingsCacheClearedToast;

  /// No description provided for @settingsClearButton.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsClearButton;

  /// No description provided for @settingsResetPermissionFlagsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset permission flags'**
  String get settingsResetPermissionFlagsDialogTitle;

  /// No description provided for @settingsResetPermissionFlagsDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This will clear the app\'s stored permission and service request flags. Use this to re-trigger permission prompts if needed.'**
  String get settingsResetPermissionFlagsDialogBody;

  /// No description provided for @settingsPermissionFlagsResetToast.
  ///
  /// In en, this message translates to:
  /// **'Permission flags reset'**
  String get settingsPermissionFlagsResetToast;

  /// No description provided for @settingsResetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsResetButton;

  /// No description provided for @settingsExportDataDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get settingsExportDataDialogTitle;

  /// No description provided for @settingsExportDataDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This will create a file with your app data (excluding private keys).'**
  String get settingsExportDataDialogBody;

  /// No description provided for @settingsDataExportedToast.
  ///
  /// In en, this message translates to:
  /// **'Data exported: {count} categories'**
  String settingsDataExportedToast(Object count);

  /// No description provided for @settingsExportButton.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get settingsExportButton;

  /// No description provided for @settingsResetAppDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset app'**
  String get settingsResetAppDialogTitle;

  /// No description provided for @settingsResetAppDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This will clear all app data and settings. Your wallet will be disconnected but not deleted.'**
  String get settingsResetAppDialogBody;

  /// No description provided for @settingsAppResetSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'App reset successfully. Please restart the app.'**
  String get settingsAppResetSuccessToast;

  /// No description provided for @settingsDeleteAccountDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccountDialogTitle;

  /// No description provided for @settingsDeleteAccountDialogBody.
  ///
  /// In en, this message translates to:
  /// **'We will remove your profile and community data from our servers. Your wallet stays yours and will remain functional.'**
  String get settingsDeleteAccountDialogBody;

  /// No description provided for @settingsFinalConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Final confirmation'**
  String get settingsFinalConfirmationTitle;

  /// No description provided for @settingsDeleteAccountFinalConfirmationBody.
  ///
  /// In en, this message translates to:
  /// **'Are you absolutely sure you want to delete your account? This action cannot be undone.'**
  String get settingsDeleteAccountFinalConfirmationBody;

  /// No description provided for @settingsConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get settingsConfirmButton;

  /// No description provided for @settingsDeleteAccountBackendFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Backend deletion failed. Please try again.'**
  String get settingsDeleteAccountBackendFailedToast;

  /// No description provided for @settingsAccountDeletedToast.
  ///
  /// In en, this message translates to:
  /// **'Account deleted. All data has been removed.'**
  String get settingsAccountDeletedToast;

  /// No description provided for @settingsDeleteForeverButton.
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get settingsDeleteForeverButton;

  /// No description provided for @settingsEnableNotificationsInSystemToast.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications in system settings to receive alerts.'**
  String get settingsEnableNotificationsInSystemToast;

  /// No description provided for @settingsLogoutDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogoutDialogTitle;

  /// No description provided for @settingsLogoutDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Disconnect your wallet and clear your session on this device?'**
  String get settingsLogoutDialogBody;

  /// No description provided for @settingsLogoutButton.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogoutButton;

  /// No description provided for @settingsTransactionHistoryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction history'**
  String get settingsTransactionHistoryDialogTitle;

  /// No description provided for @settingsRecentTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get settingsRecentTransactionsTitle;

  /// No description provided for @settingsNoTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'No transactions found'**
  String get settingsNoTransactionsTitle;

  /// No description provided for @settingsNoTransactionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Your transaction history will appear here when you start making transactions.'**
  String get settingsNoTransactionsDescription;

  /// No description provided for @settingsTxReceivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get settingsTxReceivedLabel;

  /// No description provided for @settingsTxSentLabel.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get settingsTxSentLabel;

  /// No description provided for @settingsTxFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get settingsTxFromLabel;

  /// No description provided for @settingsTxToLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get settingsTxToLabel;

  /// No description provided for @settingsTxFromToLabel.
  ///
  /// In en, this message translates to:
  /// **'{directionLabel}: {addressPrefix}...'**
  String settingsTxFromToLabel(Object directionLabel, Object addressPrefix);

  /// No description provided for @settingsAppVersionDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get settingsAppVersionDialogTitle;

  /// No description provided for @settingsVersionValue.
  ///
  /// In en, this message translates to:
  /// **'Version: {version}'**
  String settingsVersionValue(Object version);

  /// No description provided for @settingsBuildValue.
  ///
  /// In en, this message translates to:
  /// **'Build: {build}'**
  String settingsBuildValue(Object build);

  /// No description provided for @settingsAllRightsReserved.
  ///
  /// In en, this message translates to:
  /// **'All rights reserved.'**
  String get settingsAllRightsReserved;

  /// No description provided for @settingsCopyright.
  ///
  /// In en, this message translates to:
  /// **'© {year} kubus'**
  String settingsCopyright(Object year);

  /// No description provided for @settingsTermsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get settingsTermsDialogTitle;

  /// No description provided for @settingsTermsDialogBody.
  ///
  /// In en, this message translates to:
  /// **'By using art.kubus, you agree to these terms:\n\n1. You are responsible for maintaining the security of your wallet.\n2. We do not store your private keys or seed phrases.\n3. All transactions are final and irreversible.\n4. Use the app at your own risk.\n5. We reserve the right to update these terms.\n\nFor the complete terms, visit our website.'**
  String get settingsTermsDialogBody;

  /// No description provided for @settingsPrivacyPolicyDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsPrivacyPolicyDialogTitle;

  /// No description provided for @settingsPrivacyPolicyDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Your privacy is important to us:\n\n• We do not collect personal data without consent\n• Your wallet data is stored locally on your device\n• We may collect anonymous usage statistics\n• We do not share your data with third parties\n• You can disable analytics in Privacy settings\n\nFor our complete privacy policy, visit our website.'**
  String get settingsPrivacyPolicyDialogBody;

  /// No description provided for @settingsSupportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsSupportDialogTitle;

  /// No description provided for @settingsSupportDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Need help? Choose an option:'**
  String get settingsSupportDialogBody;

  /// No description provided for @settingsOpeningFaqToast.
  ///
  /// In en, this message translates to:
  /// **'Opening FAQ…'**
  String get settingsOpeningFaqToast;

  /// No description provided for @settingsViewFaqButton.
  ///
  /// In en, this message translates to:
  /// **'View FAQ'**
  String get settingsViewFaqButton;

  /// No description provided for @settingsOpeningEmailClientToast.
  ///
  /// In en, this message translates to:
  /// **'Opening email client…'**
  String get settingsOpeningEmailClientToast;

  /// No description provided for @settingsContactSupportButton.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get settingsContactSupportButton;

  /// No description provided for @settingsLicensesDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get settingsLicensesDialogTitle;

  /// No description provided for @settingsLicensesDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This app uses the following open source libraries:\n\n• Flutter SDK (BSD License)\n• Material Design Icons (Apache 2.0)\n• SharedPreferences (BSD License)\n• HTTP (BSD License)\n• Path Provider (BSD License)\n\nFull license texts are available in the app repository.'**
  String get settingsLicensesDialogBody;

  /// No description provided for @settingsRateAppDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate art.kubus'**
  String get settingsRateAppDialogTitle;

  /// No description provided for @settingsRateAppDialogBodyTitle.
  ///
  /// In en, this message translates to:
  /// **'Enjoying the app?'**
  String get settingsRateAppDialogBodyTitle;

  /// No description provided for @settingsRateAppDialogBodySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please consider rating us on the app store!'**
  String get settingsRateAppDialogBodySubtitle;

  /// No description provided for @settingsMaybeLaterButton.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get settingsMaybeLaterButton;

  /// No description provided for @settingsOpeningAppStoreToast.
  ///
  /// In en, this message translates to:
  /// **'Opening app store…'**
  String get settingsOpeningAppStoreToast;

  /// No description provided for @settingsRateNowButton.
  ///
  /// In en, this message translates to:
  /// **'Rate now'**
  String get settingsRateNowButton;

  /// No description provided for @settingsChangePasswordDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get settingsChangePasswordDialogTitle;

  /// No description provided for @settingsCurrentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get settingsCurrentPasswordLabel;

  /// No description provided for @settingsNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get settingsNewPasswordLabel;

  /// No description provided for @settingsConfirmNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get settingsConfirmNewPasswordLabel;

  /// No description provided for @settingsPasswordUpdatedToast.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully'**
  String get settingsPasswordUpdatedToast;

  /// No description provided for @settingsUpdateButton.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get settingsUpdateButton;

  /// No description provided for @settingsDeactivateAccountDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Deactivate account'**
  String get settingsDeactivateAccountDialogTitle;

  /// No description provided for @settingsDeactivateAccountDialogBodyTitle.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to deactivate your account?'**
  String get settingsDeactivateAccountDialogBodyTitle;

  /// No description provided for @settingsDeactivateAccountDialogBodySubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can reactivate it later by logging in.'**
  String get settingsDeactivateAccountDialogBodySubtitle;

  /// No description provided for @settingsAccountDeactivatedToast.
  ///
  /// In en, this message translates to:
  /// **'Account deactivated'**
  String get settingsAccountDeactivatedToast;

  /// No description provided for @settingsDeactivateButton.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get settingsDeactivateButton;

  /// No description provided for @settingsProfileVisibilityDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile visibility'**
  String get settingsProfileVisibilityDialogTitle;

  /// No description provided for @settingsProfileVisibilitySetToast.
  ///
  /// In en, this message translates to:
  /// **'Profile visibility set to {value}'**
  String settingsProfileVisibilitySetToast(Object value);

  /// No description provided for @settingsPrivacySettingsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy settings'**
  String get settingsPrivacySettingsDialogTitle;

  /// No description provided for @settingsPrivacyDataCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Data collection'**
  String get settingsPrivacyDataCollectionTitle;

  /// No description provided for @settingsPrivacyDataCollectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow app to collect usage data'**
  String get settingsPrivacyDataCollectionSubtitle;

  /// No description provided for @settingsPrivacyPersonalizedAdsTitle.
  ///
  /// In en, this message translates to:
  /// **'Personalized ads'**
  String get settingsPrivacyPersonalizedAdsTitle;

  /// No description provided for @settingsPrivacyPersonalizedAdsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show ads based on your interests'**
  String get settingsPrivacyPersonalizedAdsSubtitle;

  /// No description provided for @settingsPrivacyLocationTrackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Location tracking'**
  String get settingsPrivacyLocationTrackingTitle;

  /// No description provided for @settingsPrivacyLocationTrackingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow location-based features'**
  String get settingsPrivacyLocationTrackingSubtitle;

  /// No description provided for @settingsPrivacyDataRetentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Data retention'**
  String get settingsPrivacyDataRetentionTitle;

  /// No description provided for @settingsPrivacyDataRetentionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How long to keep your data'**
  String get settingsPrivacyDataRetentionSubtitle;

  /// No description provided for @settingsRetention3Months.
  ///
  /// In en, this message translates to:
  /// **'3 months'**
  String get settingsRetention3Months;

  /// No description provided for @settingsRetention6Months.
  ///
  /// In en, this message translates to:
  /// **'6 months'**
  String get settingsRetention6Months;

  /// No description provided for @settingsRetention1Year.
  ///
  /// In en, this message translates to:
  /// **'1 year'**
  String get settingsRetention1Year;

  /// No description provided for @settingsRetention2Years.
  ///
  /// In en, this message translates to:
  /// **'2 years'**
  String get settingsRetention2Years;

  /// No description provided for @settingsRetentionIndefinite.
  ///
  /// In en, this message translates to:
  /// **'Indefinite'**
  String get settingsRetentionIndefinite;

  /// No description provided for @settingsPrivacySettingsUpdatedToast.
  ///
  /// In en, this message translates to:
  /// **'Privacy settings updated'**
  String get settingsPrivacySettingsUpdatedToast;

  /// No description provided for @settingsSecuritySettingsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Security settings'**
  String get settingsSecuritySettingsDialogTitle;

  /// No description provided for @settingsChangePasswordTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get settingsChangePasswordTileTitle;

  /// No description provided for @settingsChangePasswordTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your account password'**
  String get settingsChangePasswordTileSubtitle;

  /// No description provided for @settingsTwoFactorTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get settingsTwoFactorTitle;

  /// No description provided for @settingsTwoFactorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add extra security to your account'**
  String get settingsTwoFactorSubtitle;

  /// No description provided for @settingsSessionTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Session timeout'**
  String get settingsSessionTimeoutTitle;

  /// No description provided for @settingsSessionTimeoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically sign out when idle'**
  String get settingsSessionTimeoutSubtitle;

  /// No description provided for @settingsAutoLockTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock time'**
  String get settingsAutoLockTimeTitle;

  /// No description provided for @settingsAutoLockTimeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lock app after inactivity'**
  String get settingsAutoLockTimeSubtitle;

  /// No description provided for @settingsLoginNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Login notifications'**
  String get settingsLoginNotificationsTitle;

  /// No description provided for @settingsLoginNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get notified of new sign-ins'**
  String get settingsLoginNotificationsSubtitle;

  /// No description provided for @settingsSecuritySettingsUpdatedToast.
  ///
  /// In en, this message translates to:
  /// **'Security settings updated'**
  String get settingsSecuritySettingsUpdatedToast;

  /// No description provided for @settingsAccountManagementDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Account management'**
  String get settingsAccountManagementDialogTitle;

  /// No description provided for @settingsEmailNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Email notifications'**
  String get settingsEmailNotificationsTitle;

  /// No description provided for @settingsEmailNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive updates via email'**
  String get settingsEmailNotificationsSubtitle;

  /// No description provided for @settingsPushNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get settingsPushNotificationsTitle;

  /// No description provided for @settingsPushNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get notifications on your device'**
  String get settingsPushNotificationsSubtitle;

  /// No description provided for @settingsMarketingEmailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Marketing emails'**
  String get settingsMarketingEmailsTitle;

  /// No description provided for @settingsMarketingEmailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive promotional content'**
  String get settingsMarketingEmailsSubtitle;

  /// No description provided for @settingsEmailPreferencesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Email preferences'**
  String get settingsEmailPreferencesSectionTitle;

  /// No description provided for @settingsEmailPreferencesTransactionalNote.
  ///
  /// In en, this message translates to:
  /// **'Account emails (verification and password reset) are always enabled.'**
  String get settingsEmailPreferencesTransactionalNote;

  /// No description provided for @settingsEmailPreferencesProductUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Product updates'**
  String get settingsEmailPreferencesProductUpdatesTitle;

  /// No description provided for @settingsEmailPreferencesProductUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Occasional announcements about new features'**
  String get settingsEmailPreferencesProductUpdatesSubtitle;

  /// No description provided for @settingsEmailPreferencesNewsletterTitle.
  ///
  /// In en, this message translates to:
  /// **'Newsletter'**
  String get settingsEmailPreferencesNewsletterTitle;

  /// No description provided for @settingsEmailPreferencesNewsletterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'News and highlights from art.kubus'**
  String get settingsEmailPreferencesNewsletterSubtitle;

  /// No description provided for @settingsEmailPreferencesCommunityDigestTitle.
  ///
  /// In en, this message translates to:
  /// **'Community digest'**
  String get settingsEmailPreferencesCommunityDigestTitle;

  /// No description provided for @settingsEmailPreferencesCommunityDigestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Periodic summary of community activity'**
  String get settingsEmailPreferencesCommunityDigestSubtitle;

  /// No description provided for @settingsEmailPreferencesSecurityAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Security alerts'**
  String get settingsEmailPreferencesSecurityAlertsTitle;

  /// No description provided for @settingsEmailPreferencesSecurityAlertsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Important account security notifications'**
  String get settingsEmailPreferencesSecurityAlertsSubtitle;

  /// No description provided for @settingsEmailPreferencesTransactionalTitle.
  ///
  /// In en, this message translates to:
  /// **'Account emails'**
  String get settingsEmailPreferencesTransactionalTitle;

  /// No description provided for @settingsEmailPreferencesTransactionalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verification and password reset emails are always enabled'**
  String get settingsEmailPreferencesTransactionalSubtitle;

  /// No description provided for @settingsEmailPreferencesUpdateFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Could not update email preferences. Please try again.'**
  String get settingsEmailPreferencesUpdateFailedToast;

  /// No description provided for @settingsAccountTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Account type'**
  String get settingsAccountTypeTitle;

  /// No description provided for @settingsAccountTypeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your current membership level'**
  String get settingsAccountTypeSubtitle;

  /// No description provided for @settingsAccountTypeStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get settingsAccountTypeStandard;

  /// No description provided for @settingsAccountTypePremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get settingsAccountTypePremium;

  /// No description provided for @settingsAccountTypeEnterprise.
  ///
  /// In en, this message translates to:
  /// **'Enterprise'**
  String get settingsAccountTypeEnterprise;

  /// No description provided for @settingsPublicProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Public profile'**
  String get settingsPublicProfileTitle;

  /// No description provided for @settingsPublicProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow others to find your profile'**
  String get settingsPublicProfileSubtitle;

  /// No description provided for @settingsProfilePrivacySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile privacy'**
  String get settingsProfilePrivacySectionTitle;

  /// No description provided for @settingsPrivateProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Private profile'**
  String get settingsPrivateProfileTitle;

  /// No description provided for @settingsPrivateProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only approved followers can see your posts'**
  String get settingsPrivateProfileSubtitle;

  /// No description provided for @settingsShowActivityStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Show activity status'**
  String get settingsShowActivityStatusTitle;

  /// No description provided for @settingsShowActivityStatusSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let others see when you\'re online'**
  String get settingsShowActivityStatusSubtitle;

  /// No description provided for @settingsShareLastVisitedLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Share last visited location'**
  String get settingsShareLastVisitedLocationTitle;

  /// No description provided for @settingsShareLastVisitedLocationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let others see what you last visited'**
  String get settingsShareLastVisitedLocationSubtitle;

  /// No description provided for @settingsShowCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Show collection'**
  String get settingsShowCollectionTitle;

  /// No description provided for @settingsShowCollectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display your NFT collection publicly'**
  String get settingsShowCollectionSubtitle;

  /// No description provided for @settingsAllowMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow messages'**
  String get settingsAllowMessagesTitle;

  /// No description provided for @settingsAllowMessagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive direct messages from others'**
  String get settingsAllowMessagesSubtitle;

  /// No description provided for @settingsDeactivateAccountTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Deactivate account'**
  String get settingsDeactivateAccountTileTitle;

  /// No description provided for @settingsDeactivateAccountTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Temporarily disable your account'**
  String get settingsDeactivateAccountTileSubtitle;

  /// No description provided for @settingsAccountSettingsUpdatedToast.
  ///
  /// In en, this message translates to:
  /// **'Account settings updated'**
  String get settingsAccountSettingsUpdatedToast;

  /// No description provided for @commonStepOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String commonStepOfTotal(Object current, Object total);

  /// No description provided for @web3OnboardingKeyFeaturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Key features:'**
  String get web3OnboardingKeyFeaturesTitle;

  /// No description provided for @web3FeatureWeb3Title.
  ///
  /// In en, this message translates to:
  /// **'Optional wallet features (Web3)'**
  String get web3FeatureWeb3Title;

  /// No description provided for @web3FeatureMarketplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Collectibles marketplace (NFT)'**
  String get web3FeatureMarketplaceTitle;

  /// No description provided for @web3FeatureArtistStudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Artist studio'**
  String get web3FeatureArtistStudioTitle;

  /// No description provided for @web3FeatureInstitutionHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Institution hub'**
  String get web3FeatureInstitutionHubTitle;

  /// No description provided for @web3FeatureGovernanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Community decision-making (DAO)'**
  String get web3FeatureGovernanceTitle;

  /// No description provided for @web3DaoP1Title.
  ///
  /// In en, this message translates to:
  /// **'Welcome to community decision-making'**
  String get web3DaoP1Title;

  /// No description provided for @web3DaoP1Description.
  ///
  /// In en, this message translates to:
  /// **'Participate in community decision-making for the art.kubus ecosystem. Your voice helps shape the platform.'**
  String get web3DaoP1Description;

  /// No description provided for @web3DaoP1Feature1.
  ///
  /// In en, this message translates to:
  /// **'Vote on community proposals'**
  String get web3DaoP1Feature1;

  /// No description provided for @web3DaoP1Feature2.
  ///
  /// In en, this message translates to:
  /// **'Create and submit proposals'**
  String get web3DaoP1Feature2;

  /// No description provided for @web3DaoP1Feature3.
  ///
  /// In en, this message translates to:
  /// **'Earn KUB8 points for participation'**
  String get web3DaoP1Feature3;

  /// No description provided for @web3DaoP1Feature4.
  ///
  /// In en, this message translates to:
  /// **'Discuss and collaborate with others'**
  String get web3DaoP1Feature4;

  /// No description provided for @web3DaoP2Title.
  ///
  /// In en, this message translates to:
  /// **'Your voting weight'**
  String get web3DaoP2Title;

  /// No description provided for @web3DaoP2Description.
  ///
  /// In en, this message translates to:
  /// **'Your voting weight can reflect your Season 0 progress (KUB8 points). No financial value-just participation and recognition.'**
  String get web3DaoP2Description;

  /// No description provided for @web3DaoP2Feature1.
  ///
  /// In en, this message translates to:
  /// **'Voting weight can follow your KUB8 points'**
  String get web3DaoP2Feature1;

  /// No description provided for @web3DaoP2Feature2.
  ///
  /// In en, this message translates to:
  /// **'Vote on active proposals'**
  String get web3DaoP2Feature2;

  /// No description provided for @web3DaoP2Feature3.
  ///
  /// In en, this message translates to:
  /// **'See results as they update'**
  String get web3DaoP2Feature3;

  /// No description provided for @web3DaoP2Feature4.
  ///
  /// In en, this message translates to:
  /// **'Track your participation history'**
  String get web3DaoP2Feature4;

  /// No description provided for @web3DaoP3Title.
  ///
  /// In en, this message translates to:
  /// **'Create proposals'**
  String get web3DaoP3Title;

  /// No description provided for @web3DaoP3Description.
  ///
  /// In en, this message translates to:
  /// **'Have an idea to improve the platform? Submit proposals for features, policies, or community initiatives.'**
  String get web3DaoP3Description;

  /// No description provided for @web3DaoP3Feature1.
  ///
  /// In en, this message translates to:
  /// **'Write clear proposals with context'**
  String get web3DaoP3Feature1;

  /// No description provided for @web3DaoP3Feature2.
  ///
  /// In en, this message translates to:
  /// **'Choose voting duration and requirements'**
  String get web3DaoP3Feature2;

  /// No description provided for @web3DaoP3Feature3.
  ///
  /// In en, this message translates to:
  /// **'Gather community support'**
  String get web3DaoP3Feature3;

  /// No description provided for @web3DaoP3Feature4.
  ///
  /// In en, this message translates to:
  /// **'Follow status and discussion'**
  String get web3DaoP3Feature4;

  /// No description provided for @web3DaoP4Title.
  ///
  /// In en, this message translates to:
  /// **'Ready to participate'**
  String get web3DaoP4Title;

  /// No description provided for @web3DaoP4Description.
  ///
  /// In en, this message translates to:
  /// **'You’re all set. Explore active proposals or start a new one when you’re ready.'**
  String get web3DaoP4Description;

  /// No description provided for @web3DaoP4Feature1.
  ///
  /// In en, this message translates to:
  /// **'Browse and vote on proposals'**
  String get web3DaoP4Feature1;

  /// No description provided for @web3DaoP4Feature2.
  ///
  /// In en, this message translates to:
  /// **'Review your voting history'**
  String get web3DaoP4Feature2;

  /// No description provided for @web3DaoP4Feature3.
  ///
  /// In en, this message translates to:
  /// **'See governance activity'**
  String get web3DaoP4Feature3;

  /// No description provided for @web3DaoP4Feature4.
  ///
  /// In en, this message translates to:
  /// **'Collaborate with the community'**
  String get web3DaoP4Feature4;

  /// No description provided for @web3ArtistStudioP1Title.
  ///
  /// In en, this message translates to:
  /// **'Welcome to artist studio'**
  String get web3ArtistStudioP1Title;

  /// No description provided for @web3ArtistStudioP1Description.
  ///
  /// In en, this message translates to:
  /// **'Your workspace for managing artworks, creating AR markers, and tracking your progress.'**
  String get web3ArtistStudioP1Description;

  /// No description provided for @web3ArtistStudioP1Feature1.
  ///
  /// In en, this message translates to:
  /// **'Manage your artwork collection'**
  String get web3ArtistStudioP1Feature1;

  /// No description provided for @web3ArtistStudioP1Feature2.
  ///
  /// In en, this message translates to:
  /// **'Create interactive AR markers'**
  String get web3ArtistStudioP1Feature2;

  /// No description provided for @web3ArtistStudioP1Feature3.
  ///
  /// In en, this message translates to:
  /// **'Track performance insights'**
  String get web3ArtistStudioP1Feature3;

  /// No description provided for @web3ArtistStudioP1Feature4.
  ///
  /// In en, this message translates to:
  /// **'Showcase and share with the community'**
  String get web3ArtistStudioP1Feature4;

  /// No description provided for @web3ArtistStudioP2Title.
  ///
  /// In en, this message translates to:
  /// **'Artwork gallery'**
  String get web3ArtistStudioP2Title;

  /// No description provided for @web3ArtistStudioP2Description.
  ///
  /// In en, this message translates to:
  /// **'Showcase your creations and digital collectibles (NFT). Upload, organize, and present your work.'**
  String get web3ArtistStudioP2Description;

  /// No description provided for @web3ArtistStudioP2Feature1.
  ///
  /// In en, this message translates to:
  /// **'Upload and organize artworks'**
  String get web3ArtistStudioP2Feature1;

  /// No description provided for @web3ArtistStudioP2Feature2.
  ///
  /// In en, this message translates to:
  /// **'Add titles and descriptions'**
  String get web3ArtistStudioP2Feature2;

  /// No description provided for @web3ArtistStudioP2Feature3.
  ///
  /// In en, this message translates to:
  /// **'Choose visibility and availability'**
  String get web3ArtistStudioP2Feature3;

  /// No description provided for @web3ArtistStudioP2Feature4.
  ///
  /// In en, this message translates to:
  /// **'Track views and engagement'**
  String get web3ArtistStudioP2Feature4;

  /// No description provided for @web3ArtistStudioP3Title.
  ///
  /// In en, this message translates to:
  /// **'AR marker creator'**
  String get web3ArtistStudioP3Title;

  /// No description provided for @web3ArtistStudioP3Description.
  ///
  /// In en, this message translates to:
  /// **'Turn artworks into AR experiences. Place markers in real-world locations for others to discover.'**
  String get web3ArtistStudioP3Description;

  /// No description provided for @web3ArtistStudioP3Feature1.
  ///
  /// In en, this message translates to:
  /// **'Create geo-located markers'**
  String get web3ArtistStudioP3Feature1;

  /// No description provided for @web3ArtistStudioP3Feature2.
  ///
  /// In en, this message translates to:
  /// **'Attach artworks to places'**
  String get web3ArtistStudioP3Feature2;

  /// No description provided for @web3ArtistStudioP3Feature3.
  ///
  /// In en, this message translates to:
  /// **'Add discovery rewards (KUB8 points)'**
  String get web3ArtistStudioP3Feature3;

  /// No description provided for @web3ArtistStudioP3Feature4.
  ///
  /// In en, this message translates to:
  /// **'Monitor marker interactions'**
  String get web3ArtistStudioP3Feature4;

  /// No description provided for @web3ArtistStudioP4Title.
  ///
  /// In en, this message translates to:
  /// **'Insights dashboard'**
  String get web3ArtistStudioP4Title;

  /// No description provided for @web3ArtistStudioP4Description.
  ///
  /// In en, this message translates to:
  /// **'Track performance with insights on views, discoveries, and community engagement.'**
  String get web3ArtistStudioP4Description;

  /// No description provided for @web3ArtistStudioP4Feature1.
  ///
  /// In en, this message translates to:
  /// **'Monitor artwork performance'**
  String get web3ArtistStudioP4Feature1;

  /// No description provided for @web3ArtistStudioP4Feature2.
  ///
  /// In en, this message translates to:
  /// **'Track KUB8 points progress'**
  String get web3ArtistStudioP4Feature2;

  /// No description provided for @web3ArtistStudioP4Feature3.
  ///
  /// In en, this message translates to:
  /// **'See discovery patterns'**
  String get web3ArtistStudioP4Feature3;

  /// No description provided for @web3ArtistStudioP4Feature4.
  ///
  /// In en, this message translates to:
  /// **'Export reports'**
  String get web3ArtistStudioP4Feature4;

  /// No description provided for @web3ArtistStudioP5Title.
  ///
  /// In en, this message translates to:
  /// **'Start creating'**
  String get web3ArtistStudioP5Title;

  /// No description provided for @web3ArtistStudioP5Description.
  ///
  /// In en, this message translates to:
  /// **'Your studio is ready. Upload your first artwork or create an AR marker to share with the community.'**
  String get web3ArtistStudioP5Description;

  /// No description provided for @web3ArtistStudioP5Feature1.
  ///
  /// In en, this message translates to:
  /// **'Upload your first artwork'**
  String get web3ArtistStudioP5Feature1;

  /// No description provided for @web3ArtistStudioP5Feature2.
  ///
  /// In en, this message translates to:
  /// **'Create your first AR marker'**
  String get web3ArtistStudioP5Feature2;

  /// No description provided for @web3ArtistStudioP5Feature3.
  ///
  /// In en, this message translates to:
  /// **'Explore community creations'**
  String get web3ArtistStudioP5Feature3;

  /// No description provided for @web3ArtistStudioP5Feature4.
  ///
  /// In en, this message translates to:
  /// **'Start earning KUB8 points'**
  String get web3ArtistStudioP5Feature4;

  /// No description provided for @web3InstitutionHubP1Title.
  ///
  /// In en, this message translates to:
  /// **'Welcome to institution hub'**
  String get web3InstitutionHubP1Title;

  /// No description provided for @web3InstitutionHubP1Description.
  ///
  /// In en, this message translates to:
  /// **'Manage events, exhibitions, and educational programs. Connect your institution with the art community.'**
  String get web3InstitutionHubP1Description;

  /// No description provided for @web3InstitutionHubP1Feature1.
  ///
  /// In en, this message translates to:
  /// **'Create and manage events'**
  String get web3InstitutionHubP1Feature1;

  /// No description provided for @web3InstitutionHubP1Feature2.
  ///
  /// In en, this message translates to:
  /// **'Host exhibitions'**
  String get web3InstitutionHubP1Feature2;

  /// No description provided for @web3InstitutionHubP1Feature3.
  ///
  /// In en, this message translates to:
  /// **'Engage with the community'**
  String get web3InstitutionHubP1Feature3;

  /// No description provided for @web3InstitutionHubP1Feature4.
  ///
  /// In en, this message translates to:
  /// **'Track reach and engagement'**
  String get web3InstitutionHubP1Feature4;

  /// No description provided for @web3InstitutionHubP2Title.
  ///
  /// In en, this message translates to:
  /// **'Event management'**
  String get web3InstitutionHubP2Title;

  /// No description provided for @web3InstitutionHubP2Description.
  ///
  /// In en, this message translates to:
  /// **'Organize exhibitions, workshops, and events. Manage scheduling, registrations, and updates.'**
  String get web3InstitutionHubP2Description;

  /// No description provided for @web3InstitutionHubP2Feature1.
  ///
  /// In en, this message translates to:
  /// **'Schedule exhibitions and workshops'**
  String get web3InstitutionHubP2Feature1;

  /// No description provided for @web3InstitutionHubP2Feature2.
  ///
  /// In en, this message translates to:
  /// **'Manage registrations'**
  String get web3InstitutionHubP2Feature2;

  /// No description provided for @web3InstitutionHubP2Feature3.
  ///
  /// In en, this message translates to:
  /// **'Send updates to attendees'**
  String get web3InstitutionHubP2Feature3;

  /// No description provided for @web3InstitutionHubP2Feature4.
  ///
  /// In en, this message translates to:
  /// **'Track attendance and engagement'**
  String get web3InstitutionHubP2Feature4;

  /// No description provided for @web3InstitutionHubP3Title.
  ///
  /// In en, this message translates to:
  /// **'Event creation tools'**
  String get web3InstitutionHubP3Title;

  /// No description provided for @web3InstitutionHubP3Description.
  ///
  /// In en, this message translates to:
  /// **'Create event pages with rich descriptions and media to help people join.'**
  String get web3InstitutionHubP3Description;

  /// No description provided for @web3InstitutionHubP3Feature1.
  ///
  /// In en, this message translates to:
  /// **'Design event pages with media'**
  String get web3InstitutionHubP3Feature1;

  /// No description provided for @web3InstitutionHubP3Feature2.
  ///
  /// In en, this message translates to:
  /// **'Set capacity and registration'**
  String get web3InstitutionHubP3Feature2;

  /// No description provided for @web3InstitutionHubP3Feature3.
  ///
  /// In en, this message translates to:
  /// **'Create promotional materials'**
  String get web3InstitutionHubP3Feature3;

  /// No description provided for @web3InstitutionHubP3Feature4.
  ///
  /// In en, this message translates to:
  /// **'Integrate with calendars'**
  String get web3InstitutionHubP3Feature4;

  /// No description provided for @web3InstitutionHubP4Title.
  ///
  /// In en, this message translates to:
  /// **'Analytics & insights'**
  String get web3InstitutionHubP4Title;

  /// No description provided for @web3InstitutionHubP4Description.
  ///
  /// In en, this message translates to:
  /// **'Measure success with insights on attendance, engagement, and community impact.'**
  String get web3InstitutionHubP4Description;

  /// No description provided for @web3InstitutionHubP4Feature1.
  ///
  /// In en, this message translates to:
  /// **'Track attendance and engagement'**
  String get web3InstitutionHubP4Feature1;

  /// No description provided for @web3InstitutionHubP4Feature2.
  ///
  /// In en, this message translates to:
  /// **'Monitor community interest'**
  String get web3InstitutionHubP4Feature2;

  /// No description provided for @web3InstitutionHubP4Feature3.
  ///
  /// In en, this message translates to:
  /// **'Analyze participant feedback'**
  String get web3InstitutionHubP4Feature3;

  /// No description provided for @web3InstitutionHubP4Feature4.
  ///
  /// In en, this message translates to:
  /// **'Export reports'**
  String get web3InstitutionHubP4Feature4;

  /// No description provided for @web3InstitutionHubP5Title.
  ///
  /// In en, this message translates to:
  /// **'Launch your events'**
  String get web3InstitutionHubP5Title;

  /// No description provided for @web3InstitutionHubP5Description.
  ///
  /// In en, this message translates to:
  /// **'Ready to connect with the art community? Create your first event or explore ongoing exhibitions.'**
  String get web3InstitutionHubP5Description;

  /// No description provided for @web3InstitutionHubP5Feature1.
  ///
  /// In en, this message translates to:
  /// **'Create your first event'**
  String get web3InstitutionHubP5Feature1;

  /// No description provided for @web3InstitutionHubP5Feature2.
  ///
  /// In en, this message translates to:
  /// **'Explore community events'**
  String get web3InstitutionHubP5Feature2;

  /// No description provided for @web3InstitutionHubP5Feature3.
  ///
  /// In en, this message translates to:
  /// **'Connect with other institutions'**
  String get web3InstitutionHubP5Feature3;

  /// No description provided for @web3InstitutionHubP5Feature4.
  ///
  /// In en, this message translates to:
  /// **'Build your cultural network'**
  String get web3InstitutionHubP5Feature4;

  /// No description provided for @web3MarketplaceP1Title.
  ///
  /// In en, this message translates to:
  /// **'Welcome to the marketplace'**
  String get web3MarketplaceP1Title;

  /// No description provided for @web3MarketplaceP1Description.
  ///
  /// In en, this message translates to:
  /// **'Discover, buy, and sell digital collectibles (NFT). Connect with creators and collectors.'**
  String get web3MarketplaceP1Description;

  /// No description provided for @web3MarketplaceP1Feature1.
  ///
  /// In en, this message translates to:
  /// **'Browse collectibles'**
  String get web3MarketplaceP1Feature1;

  /// No description provided for @web3MarketplaceP1Feature2.
  ///
  /// In en, this message translates to:
  /// **'Buy and sell securely'**
  String get web3MarketplaceP1Feature2;

  /// No description provided for @web3MarketplaceP1Feature3.
  ///
  /// In en, this message translates to:
  /// **'Discover featured artworks'**
  String get web3MarketplaceP1Feature3;

  /// No description provided for @web3MarketplaceP1Feature4.
  ///
  /// In en, this message translates to:
  /// **'Support creators you like'**
  String get web3MarketplaceP1Feature4;

  /// No description provided for @web3MarketplaceP2Title.
  ///
  /// In en, this message translates to:
  /// **'Discover great art'**
  String get web3MarketplaceP2Title;

  /// No description provided for @web3MarketplaceP2Description.
  ///
  /// In en, this message translates to:
  /// **'Explore curated collections and filter by category, rarity, and more.'**
  String get web3MarketplaceP2Description;

  /// No description provided for @web3MarketplaceP2Feature1.
  ///
  /// In en, this message translates to:
  /// **'Filter by category and rarity'**
  String get web3MarketplaceP2Feature1;

  /// No description provided for @web3MarketplaceP2Feature2.
  ///
  /// In en, this message translates to:
  /// **'View detailed artwork info'**
  String get web3MarketplaceP2Feature2;

  /// No description provided for @web3MarketplaceP2Feature3.
  ///
  /// In en, this message translates to:
  /// **'Check provenance and authenticity'**
  String get web3MarketplaceP2Feature3;

  /// No description provided for @web3MarketplaceP2Feature4.
  ///
  /// In en, this message translates to:
  /// **'Save favorites to a wishlist'**
  String get web3MarketplaceP2Feature4;

  /// No description provided for @web3MarketplaceP3Title.
  ///
  /// In en, this message translates to:
  /// **'List your creations'**
  String get web3MarketplaceP3Title;

  /// No description provided for @web3MarketplaceP3Description.
  ///
  /// In en, this message translates to:
  /// **'Creators can list digital collectibles (NFT) for others to collect. Add details and choose price and availability.'**
  String get web3MarketplaceP3Description;

  /// No description provided for @web3MarketplaceP3Feature1.
  ///
  /// In en, this message translates to:
  /// **'Upload your digital artwork'**
  String get web3MarketplaceP3Feature1;

  /// No description provided for @web3MarketplaceP3Feature2.
  ///
  /// In en, this message translates to:
  /// **'Add descriptions and tags'**
  String get web3MarketplaceP3Feature2;

  /// No description provided for @web3MarketplaceP3Feature3.
  ///
  /// In en, this message translates to:
  /// **'Set price and availability'**
  String get web3MarketplaceP3Feature3;

  /// No description provided for @web3MarketplaceP3Feature4.
  ///
  /// In en, this message translates to:
  /// **'Track interest and activity'**
  String get web3MarketplaceP3Feature4;

  /// No description provided for @web3MarketplaceP4Title.
  ///
  /// In en, this message translates to:
  /// **'Start exploring'**
  String get web3MarketplaceP4Title;

  /// No description provided for @web3MarketplaceP4Description.
  ///
  /// In en, this message translates to:
  /// **'You’re ready. Explore collections, make your first purchase, or list your first item.'**
  String get web3MarketplaceP4Description;

  /// No description provided for @web3MarketplaceP4Feature1.
  ///
  /// In en, this message translates to:
  /// **'Explore featured collections'**
  String get web3MarketplaceP4Feature1;

  /// No description provided for @web3MarketplaceP4Feature2.
  ///
  /// In en, this message translates to:
  /// **'Make your first purchase'**
  String get web3MarketplaceP4Feature2;

  /// No description provided for @web3MarketplaceP4Feature3.
  ///
  /// In en, this message translates to:
  /// **'List an item for sale'**
  String get web3MarketplaceP4Feature3;

  /// No description provided for @web3MarketplaceP4Feature4.
  ///
  /// In en, this message translates to:
  /// **'Join the creative community'**
  String get web3MarketplaceP4Feature4;

  /// No description provided for @web3FeaturesP1Title.
  ///
  /// In en, this message translates to:
  /// **'Connect a wallet (optional)'**
  String get web3FeaturesP1Title;

  /// No description provided for @web3FeaturesP1Description.
  ///
  /// In en, this message translates to:
  /// **'Connect your wallet to enable optional layers like collectibles (NFT) and proofs of visit (POAP). The core app works without it.'**
  String get web3FeaturesP1Description;

  /// No description provided for @web3FeaturesP1Feature1.
  ///
  /// In en, this message translates to:
  /// **'Wallet-based sign-in (optional)'**
  String get web3FeaturesP1Feature1;

  /// No description provided for @web3FeaturesP1Feature2.
  ///
  /// In en, this message translates to:
  /// **'Collectibles (NFT) and proofs of visit (POAP)'**
  String get web3FeaturesP1Feature2;

  /// No description provided for @web3FeaturesP1Feature3.
  ///
  /// In en, this message translates to:
  /// **'Keys stay in your wallet'**
  String get web3FeaturesP1Feature3;

  /// No description provided for @web3FeaturesP1Feature4.
  ///
  /// In en, this message translates to:
  /// **'Disconnect anytime'**
  String get web3FeaturesP1Feature4;

  /// No description provided for @web3FeaturesP2Title.
  ///
  /// In en, this message translates to:
  /// **'Collectibles marketplace (NFT)'**
  String get web3FeaturesP2Title;

  /// No description provided for @web3FeaturesP2Description.
  ///
  /// In en, this message translates to:
  /// **'Browse, buy, and sell digital collectibles (NFT) in an optional marketplace.'**
  String get web3FeaturesP2Description;

  /// No description provided for @web3FeaturesP2Feature1.
  ///
  /// In en, this message translates to:
  /// **'Browse featured drops'**
  String get web3FeaturesP2Feature1;

  /// No description provided for @web3FeaturesP2Feature2.
  ///
  /// In en, this message translates to:
  /// **'Search by category and rarity'**
  String get web3FeaturesP2Feature2;

  /// No description provided for @web3FeaturesP2Feature3.
  ///
  /// In en, this message translates to:
  /// **'View details and provenance'**
  String get web3FeaturesP2Feature3;

  /// No description provided for @web3FeaturesP2Feature4.
  ///
  /// In en, this message translates to:
  /// **'Buy and sell securely'**
  String get web3FeaturesP2Feature4;

  /// No description provided for @web3FeaturesP2Feature5.
  ///
  /// In en, this message translates to:
  /// **'Save favorites for later'**
  String get web3FeaturesP2Feature5;

  /// No description provided for @web3FeaturesP3Title.
  ///
  /// In en, this message translates to:
  /// **'Artist studio'**
  String get web3FeaturesP3Title;

  /// No description provided for @web3FeaturesP3Description.
  ///
  /// In en, this message translates to:
  /// **'Create and manage your digital works. Optionally publish collectibles (NFT) and share them with the community.'**
  String get web3FeaturesP3Description;

  /// No description provided for @web3FeaturesP3Feature1.
  ///
  /// In en, this message translates to:
  /// **'Upload and organize artworks'**
  String get web3FeaturesP3Feature1;

  /// No description provided for @web3FeaturesP3Feature2.
  ///
  /// In en, this message translates to:
  /// **'Create AR markers'**
  String get web3FeaturesP3Feature2;

  /// No description provided for @web3FeaturesP3Feature3.
  ///
  /// In en, this message translates to:
  /// **'Optionally publish collectibles (NFT)'**
  String get web3FeaturesP3Feature3;

  /// No description provided for @web3FeaturesP3Feature4.
  ///
  /// In en, this message translates to:
  /// **'Track insights and engagement'**
  String get web3FeaturesP3Feature4;

  /// No description provided for @web3FeaturesP3Feature5.
  ///
  /// In en, this message translates to:
  /// **'Collaborate with other creators'**
  String get web3FeaturesP3Feature5;

  /// No description provided for @web3FeaturesP4Title.
  ///
  /// In en, this message translates to:
  /// **'Community decision-making (DAO)'**
  String get web3FeaturesP4Title;

  /// No description provided for @web3FeaturesP4Description.
  ///
  /// In en, this message translates to:
  /// **'Vote on proposals and help guide the platform together.'**
  String get web3FeaturesP4Description;

  /// No description provided for @web3FeaturesP4Feature1.
  ///
  /// In en, this message translates to:
  /// **'Vote on proposals'**
  String get web3FeaturesP4Feature1;

  /// No description provided for @web3FeaturesP4Feature2.
  ///
  /// In en, this message translates to:
  /// **'Submit suggestions'**
  String get web3FeaturesP4Feature2;

  /// No description provided for @web3FeaturesP4Feature3.
  ///
  /// In en, this message translates to:
  /// **'Earn KUB8 points for participation'**
  String get web3FeaturesP4Feature3;

  /// No description provided for @web3FeaturesP4Feature4.
  ///
  /// In en, this message translates to:
  /// **'Follow discussions and outcomes'**
  String get web3FeaturesP4Feature4;

  /// No description provided for @web3FeaturesP4Feature5.
  ///
  /// In en, this message translates to:
  /// **'Help shape community guidelines'**
  String get web3FeaturesP4Feature5;

  /// No description provided for @web3FeaturesP5Title.
  ///
  /// In en, this message translates to:
  /// **'Institution hub'**
  String get web3FeaturesP5Title;

  /// No description provided for @web3FeaturesP5Description.
  ///
  /// In en, this message translates to:
  /// **'Partner with galleries and cultural institutions, and host events and exhibitions.'**
  String get web3FeaturesP5Description;

  /// No description provided for @web3FeaturesP5Feature1.
  ///
  /// In en, this message translates to:
  /// **'Partner with verified institutions'**
  String get web3FeaturesP5Feature1;

  /// No description provided for @web3FeaturesP5Feature2.
  ///
  /// In en, this message translates to:
  /// **'Host events and exhibitions'**
  String get web3FeaturesP5Feature2;

  /// No description provided for @web3FeaturesP5Feature3.
  ///
  /// In en, this message translates to:
  /// **'Curate collections together'**
  String get web3FeaturesP5Feature3;

  /// No description provided for @web3FeaturesP5Feature4.
  ///
  /// In en, this message translates to:
  /// **'Professional networking tools'**
  String get web3FeaturesP5Feature4;

  /// No description provided for @web3FeaturesP5Feature5.
  ///
  /// In en, this message translates to:
  /// **'Tools built for institutions'**
  String get web3FeaturesP5Feature5;

  /// No description provided for @web3FeaturesP6Title.
  ///
  /// In en, this message translates to:
  /// **'KUB8 points (Season 0)'**
  String get web3FeaturesP6Title;

  /// No description provided for @web3FeaturesP6Description.
  ///
  /// In en, this message translates to:
  /// **'KUB8 points are offchain season points: progress, reputation, and unlocks. Not a currency.'**
  String get web3FeaturesP6Description;

  /// No description provided for @web3FeaturesP6Feature1.
  ///
  /// In en, this message translates to:
  /// **'Earn points for participation and discoveries'**
  String get web3FeaturesP6Feature1;

  /// No description provided for @web3FeaturesP6Feature2.
  ///
  /// In en, this message translates to:
  /// **'Track progress over the season'**
  String get web3FeaturesP6Feature2;

  /// No description provided for @web3FeaturesP6Feature3.
  ///
  /// In en, this message translates to:
  /// **'Unlock badges and recognition'**
  String get web3FeaturesP6Feature3;

  /// No description provided for @web3FeaturesP6Feature4.
  ///
  /// In en, this message translates to:
  /// **'Rewards are access and recognition'**
  String get web3FeaturesP6Feature4;

  /// No description provided for @web3FeaturesP6Feature5.
  ///
  /// In en, this message translates to:
  /// **'Non-transferable season points'**
  String get web3FeaturesP6Feature5;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @commonView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get commonView;

  /// No description provided for @commonViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get commonViewDetails;

  /// No description provided for @commonContinueExploring.
  ///
  /// In en, this message translates to:
  /// **'Continue exploring'**
  String get commonContinueExploring;

  /// No description provided for @commonByArtist.
  ///
  /// In en, this message translates to:
  /// **'by {artist}'**
  String commonByArtist(Object artist);

  /// No description provided for @commonKub8PointsReward.
  ///
  /// In en, this message translates to:
  /// **'+{points} KUB8 points'**
  String commonKub8PointsReward(Object points);

  /// No description provided for @commonDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{value} km'**
  String commonDistanceKm(Object value);

  /// No description provided for @commonDistanceM.
  ///
  /// In en, this message translates to:
  /// **'{value} m'**
  String commonDistanceM(Object value);

  /// No description provided for @commonPercentComplete.
  ///
  /// In en, this message translates to:
  /// **'{percent}% complete'**
  String commonPercentComplete(Object percent);

  /// No description provided for @commonCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get commonCollapse;

  /// No description provided for @commonExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get commonExpand;

  /// No description provided for @mapNearbyRadiusTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby radius'**
  String get mapNearbyRadiusTitle;

  /// No description provided for @mapNearbyRadiusTooltip.
  ///
  /// In en, this message translates to:
  /// **'Nearby radius ({radiusKm} km)'**
  String mapNearbyRadiusTooltip(Object radiusKm);

  /// Tooltip for nearby radius when travel mode is enabled (worldwide).
  ///
  /// In en, this message translates to:
  /// **'Nearby radius (World)'**
  String get mapNearbyRadiusTooltipWorld;

  /// Short label shown in Nearby Art when travel mode is enabled.
  ///
  /// In en, this message translates to:
  /// **'Radius: World'**
  String get mapNearbyRadiusWorldShort;

  /// Short status label shown when Travel mode is enabled (instead of a numeric radius).
  ///
  /// In en, this message translates to:
  /// **'You are travelling'**
  String get mapTravelModeStatusTravelling;

  /// Tooltip shown near the Nearby Art radius control when Travel mode is enabled.
  ///
  /// In en, this message translates to:
  /// **'Travel mode is on - showing markers in view'**
  String get mapTravelModeStatusTravellingTooltip;

  /// No description provided for @mapArArtworkNearbyTitle.
  ///
  /// In en, this message translates to:
  /// **'AR artwork nearby!'**
  String get mapArArtworkNearbyTitle;

  /// No description provided for @mapArArtworkNearbySubtitle.
  ///
  /// In en, this message translates to:
  /// **'{name} · {distanceMeters}m away'**
  String mapArArtworkNearbySubtitle(Object name, Object distanceMeters);

  /// No description provided for @mapFailedToLaunchAr.
  ///
  /// In en, this message translates to:
  /// **'Failed to launch AR.'**
  String get mapFailedToLaunchAr;

  /// No description provided for @mapMarkerCreatedToast.
  ///
  /// In en, this message translates to:
  /// **'Marker created successfully!'**
  String get mapMarkerCreatedToast;

  /// No description provided for @mapMarkerCreateFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to create marker. Please try again.'**
  String get mapMarkerCreateFailedToast;

  /// No description provided for @mapLocationUnavailableToast.
  ///
  /// In en, this message translates to:
  /// **'Unable to determine your location.'**
  String get mapLocationUnavailableToast;

  /// No description provided for @mapMarkerCreateWalletRequired.
  ///
  /// In en, this message translates to:
  /// **'Connect your wallet and create an AR-ready artwork to place a marker.'**
  String get mapMarkerCreateWalletRequired;

  /// No description provided for @mapMarkerCreateNoArArtworks.
  ///
  /// In en, this message translates to:
  /// **'No AR-ready artworks found for your wallet. Create one first to place a marker.'**
  String get mapMarkerCreateNoArArtworks;

  /// No description provided for @mapMarkerDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create marker'**
  String get mapMarkerDialogTitle;

  /// No description provided for @mapMarkerDialogRefreshSubjectsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh subjects'**
  String get mapMarkerDialogRefreshSubjectsTooltip;

  /// No description provided for @mapMarkerDialogAttachHint.
  ///
  /// In en, this message translates to:
  /// **'Attach an existing subject and AR asset to this location.'**
  String get mapMarkerDialogAttachHint;

  /// No description provided for @mapMarkerDialogSubjectTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject type'**
  String get mapMarkerDialogSubjectTypeLabel;

  /// No description provided for @mapMarkerDialogSubjectRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'{subject} *'**
  String mapMarkerDialogSubjectRequiredLabel(Object subject);

  /// No description provided for @mapMarkerDialogMarkerForTitle.
  ///
  /// In en, this message translates to:
  /// **'Marker for {title}'**
  String mapMarkerDialogMarkerForTitle(Object title);

  /// No description provided for @mapMarkerDialogNoSubjectsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No {subjectType} available. Create one first.'**
  String mapMarkerDialogNoSubjectsAvailable(Object subjectType);

  /// No description provided for @mapMarkerDialogMiscHint.
  ///
  /// In en, this message translates to:
  /// **'Misc markers do not need a linked subject. Provide a custom title and description below.'**
  String get mapMarkerDialogMiscHint;

  /// No description provided for @mapMarkerDialogLinkedArAssetTitle.
  ///
  /// In en, this message translates to:
  /// **'Linked AR asset'**
  String get mapMarkerDialogLinkedArAssetTitle;

  /// No description provided for @mapMarkerDialogNoArEnabledArtworksHint.
  ///
  /// In en, this message translates to:
  /// **'No AR-enabled artworks available. Create one first.'**
  String get mapMarkerDialogNoArEnabledArtworksHint;

  /// No description provided for @mapMarkerDialogMarkerTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Marker title *'**
  String get mapMarkerDialogMarkerTitleLabel;

  /// No description provided for @mapMarkerDialogDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description *'**
  String get mapMarkerDialogDescriptionLabel;

  /// No description provided for @mapMarkerDialogCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get mapMarkerDialogCategoryLabel;

  /// No description provided for @mapMarkerDialogMarkerLayerLabel.
  ///
  /// In en, this message translates to:
  /// **'Marker layer'**
  String get mapMarkerDialogMarkerLayerLabel;

  /// No description provided for @mapMarkerDialogPublicMarkerTitle.
  ///
  /// In en, this message translates to:
  /// **'Public marker'**
  String get mapMarkerDialogPublicMarkerTitle;

  /// No description provided for @mapMarkerDialogPublicMarkerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Visible to all explorers on the map'**
  String get mapMarkerDialogPublicMarkerSubtitle;

  /// No description provided for @mapMarkerDialogLatitudeLabel.
  ///
  /// In en, this message translates to:
  /// **'Latitude *'**
  String get mapMarkerDialogLatitudeLabel;

  /// No description provided for @mapMarkerDialogLongitudeLabel.
  ///
  /// In en, this message translates to:
  /// **'Longitude *'**
  String get mapMarkerDialogLongitudeLabel;

  /// No description provided for @mapMarkerDialogUseMapCenterButton.
  ///
  /// In en, this message translates to:
  /// **'Use map center'**
  String get mapMarkerDialogUseMapCenterButton;

  /// No description provided for @mapMarkerDialogCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create marker'**
  String get mapMarkerDialogCreateButton;

  /// No description provided for @mapMarkerDialogSelectSubjectToast.
  ///
  /// In en, this message translates to:
  /// **'Select a subject to continue'**
  String get mapMarkerDialogSelectSubjectToast;

  /// No description provided for @mapMarkerDialogSelectArArtworkToast.
  ///
  /// In en, this message translates to:
  /// **'Select an AR-enabled artwork to link'**
  String get mapMarkerDialogSelectArArtworkToast;

  /// No description provided for @mapMarkerDialogEnterTitleError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get mapMarkerDialogEnterTitleError;

  /// No description provided for @mapMarkerDialogTitleMinLengthError.
  ///
  /// In en, this message translates to:
  /// **'Title must be at least {min} characters'**
  String mapMarkerDialogTitleMinLengthError(Object min);

  /// No description provided for @mapMarkerDialogEnterDescriptionError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a description'**
  String get mapMarkerDialogEnterDescriptionError;

  /// No description provided for @mapMarkerDialogDescriptionMinLengthError.
  ///
  /// In en, this message translates to:
  /// **'Description must be at least {min} characters'**
  String mapMarkerDialogDescriptionMinLengthError(Object min);

  /// No description provided for @mapMarkerDialogValidLatitudeError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid latitude'**
  String get mapMarkerDialogValidLatitudeError;

  /// No description provided for @mapMarkerDialogValidLongitudeError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid longitude'**
  String get mapMarkerDialogValidLongitudeError;

  /// No description provided for @mapMarkerSubjectTypeArtwork.
  ///
  /// In en, this message translates to:
  /// **'Artwork'**
  String get mapMarkerSubjectTypeArtwork;

  /// No description provided for @mapMarkerSubjectTypeExhibition.
  ///
  /// In en, this message translates to:
  /// **'Exhibition'**
  String get mapMarkerSubjectTypeExhibition;

  /// No description provided for @mapMarkerSubjectTypeInstitution.
  ///
  /// In en, this message translates to:
  /// **'Institution'**
  String get mapMarkerSubjectTypeInstitution;

  /// No description provided for @mapMarkerSubjectTypeEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get mapMarkerSubjectTypeEvent;

  /// No description provided for @mapMarkerSubjectTypeGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get mapMarkerSubjectTypeGroup;

  /// No description provided for @mapMarkerSubjectTypeMisc.
  ///
  /// In en, this message translates to:
  /// **'Misc'**
  String get mapMarkerSubjectTypeMisc;

  /// No description provided for @mapMarkerLayerArtwork.
  ///
  /// In en, this message translates to:
  /// **'Artwork'**
  String get mapMarkerLayerArtwork;

  /// No description provided for @mapMarkerLayerInstitution.
  ///
  /// In en, this message translates to:
  /// **'Institution'**
  String get mapMarkerLayerInstitution;

  /// No description provided for @mapMarkerLayerEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get mapMarkerLayerEvent;

  /// No description provided for @mapMarkerLayerResidency.
  ///
  /// In en, this message translates to:
  /// **'Residency'**
  String get mapMarkerLayerResidency;

  /// No description provided for @mapMarkerLayerDropReward.
  ///
  /// In en, this message translates to:
  /// **'Drop/Reward'**
  String get mapMarkerLayerDropReward;

  /// No description provided for @mapMarkerLayerArExperience.
  ///
  /// In en, this message translates to:
  /// **'AR experience'**
  String get mapMarkerLayerArExperience;

  /// No description provided for @mapMarkerLayerOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get mapMarkerLayerOther;

  /// No description provided for @mapArtDiscoveredTitle.
  ///
  /// In en, this message translates to:
  /// **'Art discovered!'**
  String get mapArtDiscoveredTitle;

  /// No description provided for @desktopMapTitleDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get desktopMapTitleDiscover;

  /// No description provided for @mapSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search artworks, artists, institutions…'**
  String get mapSearchHint;

  /// No description provided for @mapClearSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get mapClearSearchTooltip;

  /// No description provided for @mapHideFiltersTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide filters'**
  String get mapHideFiltersTooltip;

  /// No description provided for @mapShowFiltersTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show filters'**
  String get mapShowFiltersTooltip;

  /// No description provided for @mapSearchMinCharsHint.
  ///
  /// In en, this message translates to:
  /// **'Type at least 2 characters to search'**
  String get mapSearchMinCharsHint;

  /// No description provided for @mapNoSuggestions.
  ///
  /// In en, this message translates to:
  /// **'No suggestions'**
  String get mapNoSuggestions;

  /// No description provided for @commonNoResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get commonNoResultsFound;

  /// No description provided for @mapFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get mapFiltersTitle;

  /// No description provided for @mapFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get mapFilterAll;

  /// No description provided for @mapFilterNearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get mapFilterNearby;

  /// No description provided for @mapFilterAllNearby.
  ///
  /// In en, this message translates to:
  /// **'All nearby'**
  String get mapFilterAllNearby;

  /// No description provided for @mapFilterWithin1Km.
  ///
  /// In en, this message translates to:
  /// **'Within 1 km'**
  String get mapFilterWithin1Km;

  /// No description provided for @mapFilterDiscovered.
  ///
  /// In en, this message translates to:
  /// **'Discovered'**
  String get mapFilterDiscovered;

  /// No description provided for @mapFilterUndiscovered.
  ///
  /// In en, this message translates to:
  /// **'Undiscovered'**
  String get mapFilterUndiscovered;

  /// No description provided for @mapFilterArEnabled.
  ///
  /// In en, this message translates to:
  /// **'AR ready'**
  String get mapFilterArEnabled;

  /// No description provided for @mapFilterFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get mapFilterFavorites;

  /// No description provided for @mapLayersTitle.
  ///
  /// In en, this message translates to:
  /// **'Map layers'**
  String get mapLayersTitle;

  /// No description provided for @mapDiscoveryPathTitle.
  ///
  /// In en, this message translates to:
  /// **'Discovery path'**
  String get mapDiscoveryPathTitle;

  /// No description provided for @mapShowListViewTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show list view'**
  String get mapShowListViewTooltip;

  /// No description provided for @mapShowGridViewTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show grid view'**
  String get mapShowGridViewTooltip;

  /// No description provided for @mapSortResultsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort results'**
  String get mapSortResultsTooltip;

  /// No description provided for @mapCenterOnMeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Center on me'**
  String get mapCenterOnMeTooltip;

  /// No description provided for @mapAddMapMarkerTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add map marker'**
  String get mapAddMapMarkerTooltip;

  /// No description provided for @mapTravelModeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Travel mode'**
  String get mapTravelModeTooltip;

  /// Tooltip for the Travel Mode toggle when it is currently OFF (enables travel mode).
  ///
  /// In en, this message translates to:
  /// **'Enable travel mode'**
  String get mapTravelModeEnableTooltip;

  /// Tooltip for the Travel Mode toggle when it is currently ON (disables travel mode).
  ///
  /// In en, this message translates to:
  /// **'Disable travel mode'**
  String get mapTravelModeDisableTooltip;

  /// Tooltip for the Isometric View toggle when it is currently OFF (enables isometric view).
  ///
  /// In en, this message translates to:
  /// **'Enable isometric view'**
  String get mapIsometricViewEnableTooltip;

  /// Tooltip for the Isometric View toggle when it is currently ON (disables isometric view).
  ///
  /// In en, this message translates to:
  /// **'Disable isometric view'**
  String get mapIsometricViewDisableTooltip;

  /// Tooltip for the button that resets the map bearing/rotation to north (0 degrees).
  ///
  /// In en, this message translates to:
  /// **'Point north'**
  String get mapResetBearingTooltip;

  /// Toast/SnackBar shown when exhibitions can't be opened from the map (feature disabled or API unavailable).
  ///
  /// In en, this message translates to:
  /// **'Exhibitions are currently unavailable.'**
  String get mapExhibitionsUnavailableToast;

  /// Title for the first step of the interactive map tutorial (coach marks).
  ///
  /// In en, this message translates to:
  /// **'Your map'**
  String get mapTutorialStepMapTitle;

  /// Body text for the first step of the interactive map tutorial (coach marks).
  ///
  /// In en, this message translates to:
  /// **'Pan and zoom to explore. Tap a marker to see details and actions.'**
  String get mapTutorialStepMapBody;

  /// Title for the markers/types step of the interactive map tutorial.
  ///
  /// In en, this message translates to:
  /// **'Markers & types'**
  String get mapTutorialStepMarkersTitle;

  /// Body text for the markers/types step of the interactive map tutorial.
  ///
  /// In en, this message translates to:
  /// **'Markers can represent artworks, exhibitions, events, institutions, and more. Colors/icons help you spot what’s what.'**
  String get mapTutorialStepMarkersBody;

  /// Title for the create-marker step of the interactive map tutorial.
  ///
  /// In en, this message translates to:
  /// **'Create a marker'**
  String get mapTutorialStepCreateMarkerTitle;

  /// Body text for the create-marker step of the interactive map tutorial.
  ///
  /// In en, this message translates to:
  /// **'Tap this to add a marker at the current location (or the last long-press point).'**
  String get mapTutorialStepCreateMarkerBody;

  /// Title for the nearby-art step of the interactive map tutorial.
  ///
  /// In en, this message translates to:
  /// **'Nearby art'**
  String get mapTutorialStepNearbyTitle;

  /// Body text for the nearby-art step of the interactive map tutorial (mobile).
  ///
  /// In en, this message translates to:
  /// **'Browse artworks near you. The list updates as you move and as filters change.'**
  String get mapTutorialStepNearbyBody;

  /// Body text for the nearby-art step of the interactive map tutorial (desktop).
  ///
  /// In en, this message translates to:
  /// **'Open the Nearby panel to browse results near your current area and see details faster.'**
  String get mapTutorialStepNearbyDesktopBody;

  /// Title for the marker types step of the interactive map tutorial (desktop).
  ///
  /// In en, this message translates to:
  /// **'Marker types'**
  String get mapTutorialStepTypesTitle;

  /// Body text for the marker types step of the interactive map tutorial (desktop).
  ///
  /// In en, this message translates to:
  /// **'Use these chips to quickly focus on a category (artworks, events, institutions…).'**
  String get mapTutorialStepTypesDesktopBody;

  /// Title for the filters step of the interactive map tutorial.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get mapTutorialStepFiltersTitle;

  /// Body text for the filters step of the interactive map tutorial (mobile).
  ///
  /// In en, this message translates to:
  /// **'Use filters to narrow down what you see on the map and in the list.'**
  String get mapTutorialStepFiltersBody;

  /// Body text for the filters step of the interactive map tutorial (desktop).
  ///
  /// In en, this message translates to:
  /// **'Open the Filters panel to refine results (type, distance, discovery status, and more).'**
  String get mapTutorialStepFiltersDesktopBody;

  /// Title for the travel mode step of the interactive map tutorial.
  ///
  /// In en, this message translates to:
  /// **'Travel mode'**
  String get mapTutorialStepTravelTitle;

  /// Body text for the travel mode step of the interactive map tutorial.
  ///
  /// In en, this message translates to:
  /// **'Travel mode loads markers for the visible map area so you can explore anywhere.'**
  String get mapTutorialStepTravelBody;

  /// Title for the recenter step of the interactive map tutorial (mobile).
  ///
  /// In en, this message translates to:
  /// **'Recenter'**
  String get mapTutorialStepRecenterTitle;

  /// Body text for the recenter step of the interactive map tutorial (mobile).
  ///
  /// In en, this message translates to:
  /// **'Tap to jump back to your location and keep following you.'**
  String get mapTutorialStepRecenterBody;

  /// Title for the search step of the interactive map tutorial (desktop).
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get mapTutorialStepSearchTitle;

  /// Body text for the search step of the interactive map tutorial (desktop).
  ///
  /// In en, this message translates to:
  /// **'Search for artworks, artists, institutions, or places to jump to them quickly.'**
  String get mapTutorialStepSearchBody;

  /// No description provided for @mapTravelModeTutorialTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore beyond nearby'**
  String get mapTravelModeTutorialTitle;

  /// No description provided for @mapTravelModeTutorialBody.
  ///
  /// In en, this message translates to:
  /// **'Travel mode lets you browse markers anywhere. The map loads what’s currently in view.'**
  String get mapTravelModeTutorialBody;

  /// No description provided for @mapTravelModeTutorialHint.
  ///
  /// In en, this message translates to:
  /// **'Tip: Pan and zoom - markers refresh to match the viewport.'**
  String get mapTravelModeTutorialHint;

  /// No description provided for @mapTravelModeTutorialGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get mapTravelModeTutorialGotIt;

  /// No description provided for @mapTravelModeTutorialEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable travel mode'**
  String get mapTravelModeTutorialEnable;

  /// No description provided for @mapNearbyArtTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby art'**
  String get mapNearbyArtTitle;

  /// No description provided for @mapResultsDiscoveredLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} results · {percent}% discovered'**
  String mapResultsDiscoveredLabel(Object count, Object percent);

  /// No description provided for @mapEmptyNoArtworksTitle.
  ///
  /// In en, this message translates to:
  /// **'No artworks nearby'**
  String get mapEmptyNoArtworksTitle;

  /// No description provided for @mapEmptyNoArtworksDescription.
  ///
  /// In en, this message translates to:
  /// **'Explore different areas or adjust your filters to discover art around you.'**
  String get mapEmptyNoArtworksDescription;

  /// No description provided for @mapEmptyZoomOutAction.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get mapEmptyZoomOutAction;

  /// No description provided for @mapEmptyAdjustFiltersAction.
  ///
  /// In en, this message translates to:
  /// **'Adjust filters'**
  String get mapEmptyAdjustFiltersAction;

  /// No description provided for @mapNoLinkedArtworkForMarker.
  ///
  /// In en, this message translates to:
  /// **'No linked artwork found for this marker yet.'**
  String get mapNoLinkedArtworkForMarker;

  /// No description provided for @mapCreateMarkerHereTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create marker here'**
  String get mapCreateMarkerHereTooltip;

  /// No description provided for @mapMarkerDuplicateToast.
  ///
  /// In en, this message translates to:
  /// **'A marker already exists here.'**
  String get mapMarkerDuplicateToast;

  /// No description provided for @mapDistanceHere.
  ///
  /// In en, this message translates to:
  /// **'Here'**
  String get mapDistanceHere;

  /// No description provided for @mapDistanceAwaySuffix.
  ///
  /// In en, this message translates to:
  /// **' away'**
  String get mapDistanceAwaySuffix;

  /// No description provided for @commonGetDirections.
  ///
  /// In en, this message translates to:
  /// **'Get directions'**
  String get commonGetDirections;

  /// No description provided for @desktopMapNoArAssetToast.
  ///
  /// In en, this message translates to:
  /// **'No AR asset available for this artwork.'**
  String get desktopMapNoArAssetToast;

  /// No description provided for @desktopMapArtworkTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Artwork type'**
  String get desktopMapArtworkTypeTitle;

  /// No description provided for @desktopMapArtworkTypeArArt.
  ///
  /// In en, this message translates to:
  /// **'AR art'**
  String get desktopMapArtworkTypeArArt;

  /// No description provided for @desktopMapArtworkTypeNfts.
  ///
  /// In en, this message translates to:
  /// **'NFTs'**
  String get desktopMapArtworkTypeNfts;

  /// No description provided for @desktopMapArtworkTypeModels3d.
  ///
  /// In en, this message translates to:
  /// **'3D models'**
  String get desktopMapArtworkTypeModels3d;

  /// No description provided for @desktopMapArtworkTypeSculptures.
  ///
  /// In en, this message translates to:
  /// **'Sculptures'**
  String get desktopMapArtworkTypeSculptures;

  /// No description provided for @desktopMapSortByTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get desktopMapSortByTitle;

  /// No description provided for @desktopMapSortDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get desktopMapSortDistance;

  /// No description provided for @desktopMapSortPopularity.
  ///
  /// In en, this message translates to:
  /// **'Popularity'**
  String get desktopMapSortPopularity;

  /// No description provided for @desktopMapSortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get desktopMapSortNewest;

  /// No description provided for @desktopMapSortRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get desktopMapSortRating;

  /// No description provided for @desktopMapDiscoveriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {# discovery} other {# discoveries}}'**
  String desktopMapDiscoveriesCount(num count);

  /// No description provided for @mapMarkerTypeArtworks.
  ///
  /// In en, this message translates to:
  /// **'Artworks'**
  String get mapMarkerTypeArtworks;

  /// No description provided for @mapMarkerTypeInstitutions.
  ///
  /// In en, this message translates to:
  /// **'Institutions'**
  String get mapMarkerTypeInstitutions;

  /// No description provided for @mapMarkerTypeEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get mapMarkerTypeEvents;

  /// No description provided for @mapMarkerTypeResidencies.
  ///
  /// In en, this message translates to:
  /// **'Residencies'**
  String get mapMarkerTypeResidencies;

  /// No description provided for @mapMarkerTypeDrops.
  ///
  /// In en, this message translates to:
  /// **'Drops'**
  String get mapMarkerTypeDrops;

  /// No description provided for @mapMarkerTypeExperiences.
  ///
  /// In en, this message translates to:
  /// **'Experiences'**
  String get mapMarkerTypeExperiences;

  /// No description provided for @mapMarkerTypeMisc.
  ///
  /// In en, this message translates to:
  /// **'Misc'**
  String get mapMarkerTypeMisc;

  /// No description provided for @mapSortNearest.
  ///
  /// In en, this message translates to:
  /// **'Nearest'**
  String get mapSortNearest;

  /// No description provided for @mapSortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get mapSortNewest;

  /// No description provided for @mapSortRarity.
  ///
  /// In en, this message translates to:
  /// **'Rarity'**
  String get mapSortRarity;

  /// No description provided for @mapSortHighestRewards.
  ///
  /// In en, this message translates to:
  /// **'Highest rewards'**
  String get mapSortHighestRewards;

  /// No description provided for @mapSortMostViewed.
  ///
  /// In en, this message translates to:
  /// **'Most viewed'**
  String get mapSortMostViewed;

  /// No description provided for @mapArReadyChipLabel.
  ///
  /// In en, this message translates to:
  /// **'AR ready'**
  String get mapArReadyChipLabel;

  /// No description provided for @mapAlreadyDiscoveredTooltip.
  ///
  /// In en, this message translates to:
  /// **'Already discovered'**
  String get mapAlreadyDiscoveredTooltip;

  /// No description provided for @mapMarkAsDiscoveredTooltip.
  ///
  /// In en, this message translates to:
  /// **'Mark as discovered'**
  String get mapMarkAsDiscoveredTooltip;

  /// No description provided for @arWebFallbackFeature.
  ///
  /// In en, this message translates to:
  /// **'AR experience'**
  String get arWebFallbackFeature;

  /// No description provided for @arWebFallbackDescription.
  ///
  /// In en, this message translates to:
  /// **'Augmented Reality (AR) features require native device capabilities. Download the art.kubus app to view digital artworks in your physical space using your phone’s camera.'**
  String get arWebFallbackDescription;

  /// No description provided for @arModeScanName.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get arModeScanName;

  /// No description provided for @arModePlaceName.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get arModePlaceName;

  /// No description provided for @arModeViewName.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get arModeViewName;

  /// No description provided for @arModeCreateName.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get arModeCreateName;

  /// No description provided for @arModeScanDescription.
  ///
  /// In en, this message translates to:
  /// **'Scan AR markers to discover artworks around you.'**
  String get arModeScanDescription;

  /// No description provided for @arModePlaceDescription.
  ///
  /// In en, this message translates to:
  /// **'Place digital artworks into your space.'**
  String get arModePlaceDescription;

  /// No description provided for @arModeViewDescription.
  ///
  /// In en, this message translates to:
  /// **'View your placed artworks and revisit them.'**
  String get arModeViewDescription;

  /// No description provided for @arModeCreateDescription.
  ///
  /// In en, this message translates to:
  /// **'Create and experiment with AR placements.'**
  String get arModeCreateDescription;

  /// No description provided for @arMarkerNearbyToast.
  ///
  /// In en, this message translates to:
  /// **'Marker nearby: {name}'**
  String arMarkerNearbyToast(Object name);

  /// No description provided for @arInitializingTitle.
  ///
  /// In en, this message translates to:
  /// **'Initializing AR…'**
  String get arInitializingTitle;

  /// No description provided for @arReadyStatus.
  ///
  /// In en, this message translates to:
  /// **'AR is ready'**
  String get arReadyStatus;

  /// No description provided for @arSettingUpStatus.
  ///
  /// In en, this message translates to:
  /// **'Setting things up…'**
  String get arSettingUpStatus;

  /// No description provided for @arNoArtworksYetTitle.
  ///
  /// In en, this message translates to:
  /// **'No artworks yet'**
  String get arNoArtworksYetTitle;

  /// No description provided for @arNoArtworksYetDescription.
  ///
  /// In en, this message translates to:
  /// **'Scan a marker or place an artwork to start building your AR view.'**
  String get arNoArtworksYetDescription;

  /// No description provided for @arModelLoadedToast.
  ///
  /// In en, this message translates to:
  /// **'AR model loaded'**
  String get arModelLoadedToast;

  /// No description provided for @arModelLoadFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to load AR model. Please try again.'**
  String get arModelLoadFailedToast;

  /// No description provided for @arPlacingTitle.
  ///
  /// In en, this message translates to:
  /// **'Placing: {title}'**
  String arPlacingTitle(Object title);

  /// No description provided for @arPlacingInstruction.
  ///
  /// In en, this message translates to:
  /// **'Move your device to find a flat surface.'**
  String get arPlacingInstruction;

  /// No description provided for @arModePreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'{mode} mode'**
  String arModePreviewTitle(Object mode);

  /// No description provided for @arPlaceArtworkFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to place artwork. Please try again.'**
  String get arPlaceArtworkFailedToast;

  /// No description provided for @arActionScan.
  ///
  /// In en, this message translates to:
  /// **'Scan for artwork'**
  String get arActionScan;

  /// No description provided for @arActionPlace.
  ///
  /// In en, this message translates to:
  /// **'Place artwork here'**
  String get arActionPlace;

  /// No description provided for @arActionView.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get arActionView;

  /// No description provided for @arActionCreate.
  ///
  /// In en, this message translates to:
  /// **'Create AR artwork'**
  String get arActionCreate;

  /// No description provided for @arArtworkPlacedToast.
  ///
  /// In en, this message translates to:
  /// **'Artwork placed successfully!'**
  String get arArtworkPlacedToast;

  /// No description provided for @arNearbyArtworksTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby artworks'**
  String get arNearbyArtworksTitle;

  /// No description provided for @arSelectedArtworkToast.
  ///
  /// In en, this message translates to:
  /// **'Selected: {title}'**
  String arSelectedArtworkToast(Object title);

  /// No description provided for @arSelectArtworkBeforePlacingToast.
  ///
  /// In en, this message translates to:
  /// **'Select or create an artwork before placing it.'**
  String get arSelectArtworkBeforePlacingToast;

  /// No description provided for @arNoPlacedArtworksToast.
  ///
  /// In en, this message translates to:
  /// **'No artworks placed yet. Try placing some first!'**
  String get arNoPlacedArtworksToast;

  /// No description provided for @arPlacedArtworksTitle.
  ///
  /// In en, this message translates to:
  /// **'Placed artworks ({count})'**
  String arPlacedArtworksTitle(Object count);

  /// No description provided for @arArtworkRemovedToast.
  ///
  /// In en, this message translates to:
  /// **'Artwork removed'**
  String get arArtworkRemovedToast;

  /// No description provided for @arLocationUnavailableToast.
  ///
  /// In en, this message translates to:
  /// **'Current location unavailable. Move your device to calibrate AR tracking.'**
  String get arLocationUnavailableToast;

  /// No description provided for @arUnableToReadFileError.
  ///
  /// In en, this message translates to:
  /// **'Unable to read file data. Please try another file.'**
  String get arUnableToReadFileError;

  /// No description provided for @arFileSelectionFailedError.
  ///
  /// In en, this message translates to:
  /// **'File selection failed. Please try again.'**
  String get arFileSelectionFailedError;

  /// No description provided for @arSelectSubjectBeforeMarkerToast.
  ///
  /// In en, this message translates to:
  /// **'Select a subject before creating the marker.'**
  String get arSelectSubjectBeforeMarkerToast;

  /// No description provided for @arAttach3dModelError.
  ///
  /// In en, this message translates to:
  /// **'Attach a 3D model before continuing.'**
  String get arAttach3dModelError;

  /// No description provided for @arSelectedArtworkUnavailableToast.
  ///
  /// In en, this message translates to:
  /// **'Selected artwork is no longer available. Refresh data and try again.'**
  String get arSelectedArtworkUnavailableToast;

  /// No description provided for @arUploadFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Please try again.'**
  String get arUploadFailedToast;

  /// No description provided for @arMarkerCreatedSwitchToPlaceToast.
  ///
  /// In en, this message translates to:
  /// **'AR asset uploaded and marker created. Switching to Place mode.'**
  String get arMarkerCreatedSwitchToPlaceToast;

  /// No description provided for @arCreateMarkerFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to create AR marker. Please try again.'**
  String get arCreateMarkerFailedToast;

  /// No description provided for @arShareText.
  ///
  /// In en, this message translates to:
  /// **'Check out this AR artwork on art.kubus!\n\n\"{title}\"\nby {artist}\n\nExperience it in augmented reality!'**
  String arShareText(Object title, Object artist);

  /// No description provided for @arShareSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Artwork shared successfully!'**
  String get arShareSuccessToast;

  /// No description provided for @arShareFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Share failed. Please try again.'**
  String get arShareFailedToast;

  /// No description provided for @commonActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get commonActions;

  /// No description provided for @commonCurrentlyOn.
  ///
  /// In en, this message translates to:
  /// **'Currently ON'**
  String get commonCurrentlyOn;

  /// No description provided for @commonCurrentlyOff.
  ///
  /// In en, this message translates to:
  /// **'Currently OFF'**
  String get commonCurrentlyOff;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get commonJustNow;

  /// No description provided for @commonMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1m ago} other{{minutes}m ago}}'**
  String commonMinutesAgo(num minutes);

  /// No description provided for @commonHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{1h ago} other{{hours}h ago}}'**
  String commonHoursAgo(num hours);

  /// No description provided for @commonDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1d ago} other{{days}d ago}}'**
  String commonDaysAgo(num days);

  /// No description provided for @commonWeeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{weeks, plural, =1{1w ago} other{{weeks}w ago}}'**
  String commonWeeksAgo(num weeks);

  /// No description provided for @commonTba.
  ///
  /// In en, this message translates to:
  /// **'TBA'**
  String get commonTba;

  /// No description provided for @commonUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get commonUntitled;

  /// No description provided for @commonDigital.
  ///
  /// In en, this message translates to:
  /// **'Digital'**
  String get commonDigital;

  /// No description provided for @commonArtwork.
  ///
  /// In en, this message translates to:
  /// **'Artwork'**
  String get commonArtwork;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @messagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesTitle;

  /// No description provided for @messagesEmptyNoConversationsTitle.
  ///
  /// In en, this message translates to:
  /// **'No conversations'**
  String get messagesEmptyNoConversationsTitle;

  /// No description provided for @messagesEmptyNoConversationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation using the chat button below.'**
  String get messagesEmptyNoConversationsDescription;

  /// No description provided for @messagesEmptyStartChatAction.
  ///
  /// In en, this message translates to:
  /// **'Start a chat'**
  String get messagesEmptyStartChatAction;

  /// No description provided for @messagesFallbackGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get messagesFallbackGroupTitle;

  /// No description provided for @messagesFallbackConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get messagesFallbackConversationTitle;

  /// No description provided for @messagesFallbackConversationInitial.
  ///
  /// In en, this message translates to:
  /// **'C'**
  String get messagesFallbackConversationInitial;

  /// No description provided for @messagesCreateConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'Create conversation'**
  String get messagesCreateConversationTitle;

  /// No description provided for @messagesCreateConversationTitleOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Title (optional)'**
  String get messagesCreateConversationTitleOptionalLabel;

  /// No description provided for @messagesCreateConversationMembersLabel.
  ///
  /// In en, this message translates to:
  /// **'Members (username or wallet)'**
  String get messagesCreateConversationMembersLabel;

  /// No description provided for @messagesCreateConversationGroupAvatarOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Group avatar (optional)'**
  String get messagesCreateConversationGroupAvatarOptionalLabel;

  /// No description provided for @messagesCreateConversationIsGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get messagesCreateConversationIsGroupLabel;

  /// No description provided for @messagesReplyingToLabel.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String messagesReplyingToLabel(Object name);

  /// No description provided for @messagesCreatedNewGroupChatToast.
  ///
  /// In en, this message translates to:
  /// **'Created a new group chat.'**
  String get messagesCreatedNewGroupChatToast;

  /// No description provided for @messagesUploadingAvatarToast.
  ///
  /// In en, this message translates to:
  /// **'Uploading avatar…'**
  String get messagesUploadingAvatarToast;

  /// No description provided for @messagesAvatarUpdatedToast.
  ///
  /// In en, this message translates to:
  /// **'Avatar updated.'**
  String get messagesAvatarUpdatedToast;

  /// No description provided for @messagesUpdateAvatarFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Unable to update avatar right now.'**
  String get messagesUpdateAvatarFailedToast;

  /// No description provided for @messagesMenuAddMember.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get messagesMenuAddMember;

  /// No description provided for @messagesMenuRenameConversation.
  ///
  /// In en, this message translates to:
  /// **'Rename conversation'**
  String get messagesMenuRenameConversation;

  /// No description provided for @messagesMenuChangeGroupAvatar.
  ///
  /// In en, this message translates to:
  /// **'Change group avatar'**
  String get messagesMenuChangeGroupAvatar;

  /// No description provided for @messagesAttachmentDefaultFilename.
  ///
  /// In en, this message translates to:
  /// **'attachment'**
  String get messagesAttachmentDefaultFilename;

  /// No description provided for @messagesAttachmentFailedToLoadImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get messagesAttachmentFailedToLoadImage;

  /// No description provided for @messagesAttachmentVideoLabel.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get messagesAttachmentVideoLabel;

  /// No description provided for @messagesAttachmentPlayVideoButton.
  ///
  /// In en, this message translates to:
  /// **'Play Video'**
  String get messagesAttachmentPlayVideoButton;

  /// No description provided for @messagesAttachmentDownloadButton.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get messagesAttachmentDownloadButton;

  /// No description provided for @messagesTypeMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message…'**
  String get messagesTypeMessageHint;

  /// No description provided for @messagesAddMemberDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get messagesAddMemberDialogTitle;

  /// No description provided for @messagesAddMemberIdentifierLabel.
  ///
  /// In en, this message translates to:
  /// **'Username or wallet'**
  String get messagesAddMemberIdentifierLabel;

  /// No description provided for @messagesAddMemberDialogLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unable to load member'**
  String get messagesAddMemberDialogLoadFailedTitle;

  /// No description provided for @messagesAddMemberDialogLoadFailedBody.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load this user right now. Please try again.'**
  String get messagesAddMemberDialogLoadFailedBody;

  /// No description provided for @messagesConversationMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversation members'**
  String get messagesConversationMembersTitle;

  /// No description provided for @messagesMemberLabel.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get messagesMemberLabel;

  /// No description provided for @messagesMemberOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Member options'**
  String get messagesMemberOptionsTitle;

  /// No description provided for @messagesMemberOptionsBody.
  ///
  /// In en, this message translates to:
  /// **'What would you like to do with {displayName}?'**
  String messagesMemberOptionsBody(Object displayName);

  /// No description provided for @messagesTransferOwnershipAction.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership'**
  String get messagesTransferOwnershipAction;

  /// No description provided for @messagesRemoveMemberAction.
  ///
  /// In en, this message translates to:
  /// **'Remove member'**
  String get messagesRemoveMemberAction;

  /// No description provided for @messagesTransferOwnershipTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership'**
  String get messagesTransferOwnershipTitle;

  /// No description provided for @messagesTransferOwnershipBody.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership to {displayName} ({wallet})?'**
  String messagesTransferOwnershipBody(Object displayName, Object wallet);

  /// No description provided for @messagesOwnershipTransferredToast.
  ///
  /// In en, this message translates to:
  /// **'Ownership transferred.'**
  String get messagesOwnershipTransferredToast;

  /// No description provided for @messagesTransferFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Transfer failed.'**
  String get messagesTransferFailedToast;

  /// No description provided for @messagesManageMemberAction.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get messagesManageMemberAction;

  /// No description provided for @messagesRenameConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename conversation'**
  String get messagesRenameConversationTitle;

  /// No description provided for @messagesRenameConversationHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a new name'**
  String get messagesRenameConversationHint;

  /// No description provided for @messagesRenameConversationFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Conversation name'**
  String get messagesRenameConversationFieldLabel;

  /// No description provided for @userProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get userProfileTitle;

  /// No description provided for @userProfileNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get userProfileNotFound;

  /// No description provided for @userProfileNotFoundDescription.
  ///
  /// In en, this message translates to:
  /// **'This profile may have been deleted or doesn\'t exist.'**
  String get userProfileNotFoundDescription;

  /// No description provided for @userProfileShareTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get userProfileShareTooltip;

  /// No description provided for @userProfileMoreTooltip.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get userProfileMoreTooltip;

  /// No description provided for @userProfileSharedToast.
  ///
  /// In en, this message translates to:
  /// **'Profile shared!'**
  String get userProfileSharedToast;

  /// No description provided for @userProfileJoinedLabel.
  ///
  /// In en, this message translates to:
  /// **'Joined {date}'**
  String userProfileJoinedLabel(Object date);

  /// No description provided for @userProfileMessageButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get userProfileMessageButtonLabel;

  /// No description provided for @userProfileArtistPortfolioTitle.
  ///
  /// In en, this message translates to:
  /// **'Artist portfolio'**
  String get userProfileArtistPortfolioTitle;

  /// No description provided for @userProfileInstitutionHighlightsDesktopSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Featured exhibitions and programs'**
  String get userProfileInstitutionHighlightsDesktopSubtitle;

  /// No description provided for @userProfileArtistPortfolioDesktopSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Latest artworks and collections'**
  String get userProfileArtistPortfolioDesktopSubtitle;

  /// No description provided for @userProfileNoCreatorContentTitle.
  ///
  /// In en, this message translates to:
  /// **'No content available'**
  String get userProfileNoCreatorContentTitle;

  /// No description provided for @userProfileNoInstitutionContentDescription.
  ///
  /// In en, this message translates to:
  /// **'No exhibitions or programs to display yet'**
  String get userProfileNoInstitutionContentDescription;

  /// No description provided for @userProfileNoArtistContentDescription.
  ///
  /// In en, this message translates to:
  /// **'No artworks or collections to display yet'**
  String get userProfileNoArtistContentDescription;

  /// No description provided for @userProfileFollowButton.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get userProfileFollowButton;

  /// No description provided for @userProfileFollowingButton.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get userProfileFollowingButton;

  /// No description provided for @userProfileSignInToFollowToast.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to follow creators.'**
  String get userProfileSignInToFollowToast;

  /// No description provided for @userProfileFollowUpdateFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Could not update follow status. Please try again.'**
  String get userProfileFollowUpdateFailedToast;

  /// No description provided for @userProfileNowFollowingToast.
  ///
  /// In en, this message translates to:
  /// **'Following {name}'**
  String userProfileNowFollowingToast(Object name);

  /// No description provided for @userProfileUnfollowedToast.
  ///
  /// In en, this message translates to:
  /// **'Unfollowed {name}'**
  String userProfileUnfollowedToast(Object name);

  /// No description provided for @userProfilePostsStatLabel.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get userProfilePostsStatLabel;

  /// No description provided for @userProfileFollowersStatLabel.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get userProfileFollowersStatLabel;

  /// No description provided for @userProfileFollowingStatLabel.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get userProfileFollowingStatLabel;

  /// No description provided for @userProfileMessageLoginRequiredToast.
  ///
  /// In en, this message translates to:
  /// **'Please log in to message this user.'**
  String get userProfileMessageLoginRequiredToast;

  /// No description provided for @userProfileConversationOpenFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Could not open conversation.'**
  String get userProfileConversationOpenFailedToast;

  /// No description provided for @userProfileConversationOpenGenericErrorToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to open conversation. Please try again.'**
  String get userProfileConversationOpenGenericErrorToast;

  /// No description provided for @userProfileAchievementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get userProfileAchievementsTitle;

  /// No description provided for @userProfileAchievementsProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} unlocked'**
  String userProfileAchievementsProgressLabel(Object completed, Object total);

  /// No description provided for @userProfileAchievementsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} hasn\'t unlocked any achievements yet.'**
  String userProfileAchievementsEmptyTitle(Object name);

  /// No description provided for @userProfileAchievementsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Start exploring to unlock achievements'**
  String get userProfileAchievementsEmptyDescription;

  /// No description provided for @userProfileAchievementCompletedLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get userProfileAchievementCompletedLabel;

  /// No description provided for @userProfilePostsTitle.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get userProfilePostsTitle;

  /// No description provided for @userProfileRecentActivitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recent activity from {name}'**
  String userProfileRecentActivitySubtitle(Object name);

  /// No description provided for @userProfilePostsLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load posts'**
  String get userProfilePostsLoadFailedTitle;

  /// No description provided for @userProfilePostsLoadFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'Failed to load posts.'**
  String get userProfilePostsLoadFailedDescription;

  /// No description provided for @userProfilePostsLoadMoreFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'Failed to load more posts.'**
  String get userProfilePostsLoadMoreFailedDescription;

  /// No description provided for @userProfileNoPostsTitle.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get userProfileNoPostsTitle;

  /// No description provided for @userProfileNoPostsDescription.
  ///
  /// In en, this message translates to:
  /// **'{name} hasn\'t shared any posts so far.'**
  String userProfileNoPostsDescription(Object name);

  /// No description provided for @userProfileNoMorePostsLabel.
  ///
  /// In en, this message translates to:
  /// **'No more posts'**
  String get userProfileNoMorePostsLabel;

  /// No description provided for @userProfileArtistHighlightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Artist highlights'**
  String get userProfileArtistHighlightsTitle;

  /// No description provided for @userProfileArtistHighlightsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Latest drops from {name}.'**
  String userProfileArtistHighlightsSubtitle(Object name);

  /// No description provided for @userProfileInstitutionHighlightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Institution highlights'**
  String get userProfileInstitutionHighlightsTitle;

  /// No description provided for @userProfileInstitutionHighlightsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Programs and collections curated by {name}.'**
  String userProfileInstitutionHighlightsSubtitle(Object name);

  /// No description provided for @userProfileArtworksTitle.
  ///
  /// In en, this message translates to:
  /// **'Artworks'**
  String get userProfileArtworksTitle;

  /// No description provided for @userProfileCollectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get userProfileCollectionsTitle;

  /// No description provided for @userProfileEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get userProfileEventsTitle;

  /// No description provided for @userProfileEventsSubtitleFeaturing.
  ///
  /// In en, this message translates to:
  /// **'Upcoming experiences featuring {name}.'**
  String userProfileEventsSubtitleFeaturing(Object name);

  /// No description provided for @userProfileNoUpcomingEventsYetLabel.
  ///
  /// In en, this message translates to:
  /// **'No upcoming events from {name} just yet.'**
  String userProfileNoUpcomingEventsYetLabel(Object name);

  /// No description provided for @userProfileNoArtworksYetLabel.
  ///
  /// In en, this message translates to:
  /// **'{name} hasn\'t published any artworks yet.'**
  String userProfileNoArtworksYetLabel(Object name);

  /// No description provided for @userProfileNoCollectionsYetLabel.
  ///
  /// In en, this message translates to:
  /// **'{name} hasn\'t curated collections yet.'**
  String userProfileNoCollectionsYetLabel(Object name);

  /// No description provided for @userProfileNoItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'No {title}'**
  String userProfileNoItemsTitle(Object title);

  /// No description provided for @userProfileLikesLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 like} other{{count} likes}}'**
  String userProfileLikesLabel(num count);

  /// No description provided for @userProfileArtworksCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 artwork} other{{count} artworks}}'**
  String userProfileArtworksCountLabel(num count);

  /// No description provided for @userProfileCuratedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Curated by {name}'**
  String userProfileCuratedByLabel(Object name);

  /// No description provided for @userProfileCollectionFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get userProfileCollectionFallbackTitle;

  /// No description provided for @userProfileEventFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get userProfileEventFallbackTitle;

  /// No description provided for @collectionSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Collection Settings'**
  String get collectionSettingsTitle;

  /// No description provided for @artistStudioCreatePrompt.
  ///
  /// In en, this message translates to:
  /// **'What would you like to create?'**
  String get artistStudioCreatePrompt;

  /// No description provided for @artistStudioCreateOptionArtworkTitle.
  ///
  /// In en, this message translates to:
  /// **'Create artwork'**
  String get artistStudioCreateOptionArtworkTitle;

  /// No description provided for @artistStudioCreateOptionArtworkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload media, set details, and publish.'**
  String get artistStudioCreateOptionArtworkSubtitle;

  /// No description provided for @artistStudioCreateOptionCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Create collection'**
  String get artistStudioCreateOptionCollectionTitle;

  /// No description provided for @artistStudioCreateOptionCollectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Curate a set of artworks into a collection.'**
  String get artistStudioCreateOptionCollectionSubtitle;

  /// No description provided for @collectionCreatorTitle.
  ///
  /// In en, this message translates to:
  /// **'Create collection'**
  String get collectionCreatorTitle;

  /// No description provided for @collectionCreatorNameRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Collection name is required'**
  String get collectionCreatorNameRequiredError;

  /// No description provided for @collectionCreatorCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create collection.'**
  String get collectionCreatorCreateFailed;

  /// No description provided for @collectionCreatorCreateFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Failed to create collection: {error}'**
  String collectionCreatorCreateFailedWithError(Object error);

  /// No description provided for @collectionDetailLoadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load collection details. Please try again.'**
  String get collectionDetailLoadFailedMessage;

  /// No description provided for @collectionDetailNoArtworksYet.
  ///
  /// In en, this message translates to:
  /// **'No artworks yet.'**
  String get collectionDetailNoArtworksYet;

  /// No description provided for @collectionDetailAddArtwork.
  ///
  /// In en, this message translates to:
  /// **'Add Artwork'**
  String get collectionDetailAddArtwork;

  /// No description provided for @collectionDetailManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get collectionDetailManage;

  /// No description provided for @collectionDetailArtworks.
  ///
  /// In en, this message translates to:
  /// **'Artworks'**
  String get collectionDetailArtworks;

  /// No description provided for @collectionDetailDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get collectionDetailDescription;

  /// No description provided for @collectionDetailByYou.
  ///
  /// In en, this message translates to:
  /// **'by You'**
  String get collectionDetailByYou;

  /// No description provided for @collectionDetailSharingToast.
  ///
  /// In en, this message translates to:
  /// **'Sharing collection...'**
  String get collectionDetailSharingToast;

  /// No description provided for @collectionDetailOpeningEditorToast.
  ///
  /// In en, this message translates to:
  /// **'Opening collection editor...'**
  String get collectionDetailOpeningEditorToast;

  /// No description provided for @collectionDetailAddArtworkFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to add artwork to collection. Please try again.'**
  String get collectionDetailAddArtworkFailedToast;

  /// No description provided for @collectionDetailRemoveArtworkFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove artwork from collection. Please try again.'**
  String get collectionDetailRemoveArtworkFailedToast;

  /// No description provided for @collectionSettingsBasicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get collectionSettingsBasicInfo;

  /// No description provided for @collectionSettingsName.
  ///
  /// In en, this message translates to:
  /// **'Collection Name'**
  String get collectionSettingsName;

  /// No description provided for @collectionSettingsNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter collection name'**
  String get collectionSettingsNameHint;

  /// No description provided for @collectionSettingsDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get collectionSettingsDescriptionLabel;

  /// No description provided for @collectionSettingsDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your collection...'**
  String get collectionSettingsDescriptionHint;

  /// No description provided for @collectionSettingsCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get collectionSettingsCategory;

  /// No description provided for @collectionSettingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Settings'**
  String get collectionSettingsPrivacy;

  /// No description provided for @collectionSettingsPublic.
  ///
  /// In en, this message translates to:
  /// **'Public Collection'**
  String get collectionSettingsPublic;

  /// No description provided for @collectionSettingsPublicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Make this collection visible to everyone'**
  String get collectionSettingsPublicSubtitle;

  /// No description provided for @collectionSettingsCollaboration.
  ///
  /// In en, this message translates to:
  /// **'Collaboration'**
  String get collectionSettingsCollaboration;

  /// No description provided for @collectionSettingsAllowContributions.
  ///
  /// In en, this message translates to:
  /// **'Allow Contributions'**
  String get collectionSettingsAllowContributions;

  /// No description provided for @collectionSettingsAllowContributionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let other artists contribute to this collection'**
  String get collectionSettingsAllowContributionsSubtitle;

  /// No description provided for @collectionSettingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get collectionSettingsNotifications;

  /// No description provided for @collectionSettingsUpdates.
  ///
  /// In en, this message translates to:
  /// **'Collection Updates'**
  String get collectionSettingsUpdates;

  /// No description provided for @collectionSettingsUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get notified when artworks are added or removed'**
  String get collectionSettingsUpdatesSubtitle;

  /// No description provided for @collectionSettingsDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get collectionSettingsDangerZone;

  /// No description provided for @collectionSettingsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Collection'**
  String get collectionSettingsDeleteTitle;

  /// No description provided for @collectionSettingsDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'Once you delete a collection, there is no going back. This action cannot be undone.'**
  String get collectionSettingsDeleteWarning;

  /// No description provided for @collectionSettingsDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete Collection'**
  String get collectionSettingsDeleteButton;

  /// No description provided for @collectionSettingsSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Collection settings saved for \"{name}\"'**
  String collectionSettingsSavedToast(Object name);

  /// No description provided for @collectionSettingsSaveFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to save collection settings. Please try again.'**
  String get collectionSettingsSaveFailedToast;

  /// No description provided for @collectionSettingsDeleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Collection'**
  String get collectionSettingsDeleteDialogTitle;

  /// No description provided for @collectionSettingsDeleteDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This action cannot be undone.'**
  String collectionSettingsDeleteDialogContent(Object name);

  /// No description provided for @collectionSettingsDeletedToast.
  ///
  /// In en, this message translates to:
  /// **'Collection deleted'**
  String get collectionSettingsDeletedToast;

  /// No description provided for @userProfileMoreOptionsBlockUser.
  ///
  /// In en, this message translates to:
  /// **'Block user'**
  String get userProfileMoreOptionsBlockUser;

  /// No description provided for @userProfileMoreOptionsReportUser.
  ///
  /// In en, this message translates to:
  /// **'Report user'**
  String get userProfileMoreOptionsReportUser;

  /// No description provided for @userProfileMoreOptionsCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy profile link'**
  String get userProfileMoreOptionsCopyLink;

  /// No description provided for @userProfileLinkCopiedToast.
  ///
  /// In en, this message translates to:
  /// **'Profile link copied to clipboard'**
  String get userProfileLinkCopiedToast;

  /// No description provided for @userProfileBlockDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String userProfileBlockDialogTitle(Object name);

  /// No description provided for @userProfileBlockDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'They won\'t be able to see your profile or posts.'**
  String get userProfileBlockDialogDescription;

  /// No description provided for @userProfileUnableToBlockToast.
  ///
  /// In en, this message translates to:
  /// **'Unable to block user.'**
  String get userProfileUnableToBlockToast;

  /// No description provided for @userProfileBlockFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to block user. Please try again.'**
  String get userProfileBlockFailedToast;

  /// No description provided for @userProfileBlockedToast.
  ///
  /// In en, this message translates to:
  /// **'Blocked {name}'**
  String userProfileBlockedToast(Object name);

  /// No description provided for @userProfileBlockButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get userProfileBlockButtonLabel;

  /// No description provided for @userProfileReportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Report {name}'**
  String userProfileReportDialogTitle(Object name);

  /// No description provided for @userProfileReportDialogQuestion.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this user?'**
  String get userProfileReportDialogQuestion;

  /// No description provided for @userProfileReportReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get userProfileReportReasonSpam;

  /// No description provided for @userProfileReportReasonInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get userProfileReportReasonInappropriate;

  /// No description provided for @userProfileReportReasonHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment'**
  String get userProfileReportReasonHarassment;

  /// No description provided for @userProfileReportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get userProfileReportReasonOther;

  /// No description provided for @userProfileReportSubmittedToast.
  ///
  /// In en, this message translates to:
  /// **'Report submitted. Thank you for your feedback.'**
  String get userProfileReportSubmittedToast;

  /// No description provided for @arDetailModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get arDetailModelLabel;

  /// No description provided for @arDetailScaleLabel.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get arDetailScaleLabel;

  /// No description provided for @arDetailPlacedLabel.
  ///
  /// In en, this message translates to:
  /// **'Placed'**
  String get arDetailPlacedLabel;

  /// No description provided for @arShareButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get arShareButtonLabel;

  /// No description provided for @arLikeButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get arLikeButtonLabel;

  /// No description provided for @arLikedButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Liked'**
  String get arLikedButtonLabel;

  /// No description provided for @arSaveButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get arSaveButtonLabel;

  /// No description provided for @arSavedButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get arSavedButtonLabel;

  /// No description provided for @arLikeAddedToast.
  ///
  /// In en, this message translates to:
  /// **'Added to your likes!'**
  String get arLikeAddedToast;

  /// No description provided for @arLikeRemovedToast.
  ///
  /// In en, this message translates to:
  /// **'Removed from likes'**
  String get arLikeRemovedToast;

  /// No description provided for @arSaveAddedToast.
  ///
  /// In en, this message translates to:
  /// **'Saved to your collection!'**
  String get arSaveAddedToast;

  /// No description provided for @arSaveRemovedToast.
  ///
  /// In en, this message translates to:
  /// **'Removed from saved items'**
  String get arSaveRemovedToast;

  /// No description provided for @arNotSupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'AR not supported'**
  String get arNotSupportedTitle;

  /// No description provided for @arNotSupportedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your device does not support AR features. AR requires ARCore (Android) or ARKit (iOS).'**
  String get arNotSupportedMessage;

  /// No description provided for @arInitializationFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'AR initialization failed'**
  String get arInitializationFailedTitle;

  /// No description provided for @arInitializationFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not initialize AR. Please check camera permissions and try again.'**
  String get arInitializationFailedMessage;

  /// No description provided for @commonRequired.
  ///
  /// In en, this message translates to:
  /// **'required'**
  String get commonRequired;

  /// File size in kilobytes
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String commonFileSizeKb(String value);

  /// File size in megabytes
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String commonFileSizeMb(String value);

  /// No description provided for @arCreateUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload AR asset'**
  String get arCreateUploadTitle;

  /// No description provided for @arCreateUploadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Link an existing artwork, upload a 3D model (GLB/GLTF/USDZ), and we\'ll enrich its AR marker.'**
  String get arCreateUploadSubtitle;

  /// No description provided for @arCreateSubjectTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject type'**
  String get arCreateSubjectTypeLabel;

  /// Label for the subject dropdown, includes a required asterisk
  ///
  /// In en, this message translates to:
  /// **'{subjectType} *'**
  String arCreateSubjectLabel(String subjectType);

  /// Default marker description when the selected subject has no subtitle
  ///
  /// In en, this message translates to:
  /// **'Marker for {title}'**
  String arCreateDefaultDescription(String title);

  /// Message shown when no subjects exist for the chosen subject type
  ///
  /// In en, this message translates to:
  /// **'No {subjectTypeLower}s available. Use the respective module to create one first.'**
  String arCreateNoSubjectsAvailable(String subjectTypeLower);

  /// No description provided for @arCreateMarkerTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Marker title *'**
  String get arCreateMarkerTitleLabel;

  /// No description provided for @arCreateTitleRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get arCreateTitleRequiredError;

  /// No description provided for @arCreateTitleMinLengthError.
  ///
  /// In en, this message translates to:
  /// **'Title must be at least 3 characters'**
  String get arCreateTitleMinLengthError;

  /// No description provided for @arCreateDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description *'**
  String get arCreateDescriptionLabel;

  /// No description provided for @arCreateDescriptionRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Description is required'**
  String get arCreateDescriptionRequiredError;

  /// No description provided for @arCreateDescriptionMinLengthError.
  ///
  /// In en, this message translates to:
  /// **'Describe the experience in at least 10 characters'**
  String get arCreateDescriptionMinLengthError;

  /// No description provided for @arCreateCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get arCreateCategoryLabel;

  /// No description provided for @arCreateAttach3dAssetTitle.
  ///
  /// In en, this message translates to:
  /// **'Attach 3D asset'**
  String get arCreateAttach3dAssetTitle;

  /// No description provided for @arCreateSelectModelButton.
  ///
  /// In en, this message translates to:
  /// **'Select GLB / GLTF / USDZ'**
  String get arCreateSelectModelButton;

  /// No description provided for @arCreateReplaceModelButton.
  ///
  /// In en, this message translates to:
  /// **'Replace model'**
  String get arCreateReplaceModelButton;

  /// No description provided for @arCreatePublicMarkerTitle.
  ///
  /// In en, this message translates to:
  /// **'Public marker'**
  String get arCreatePublicMarkerTitle;

  /// No description provided for @arCreatePublicMarkerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Visible to nearby explorers'**
  String get arCreatePublicMarkerSubtitle;

  /// No description provided for @arCreateUploadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get arCreateUploadingLabel;

  /// No description provided for @arCreateUploadAndCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Upload & create marker'**
  String get arCreateUploadAndCreateButton;

  /// No description provided for @arSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'AR settings'**
  String get arSettingsTitle;

  /// No description provided for @arScannerSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Scanner settings'**
  String get arScannerSettingsTitle;

  /// No description provided for @arFlashControlTitle.
  ///
  /// In en, this message translates to:
  /// **'Flash control'**
  String get arFlashControlTitle;

  /// No description provided for @arFlashNotAvailableToast.
  ///
  /// In en, this message translates to:
  /// **'Flash is not available on this device.'**
  String get arFlashNotAvailableToast;

  /// No description provided for @arScannerOverlayTitle.
  ///
  /// In en, this message translates to:
  /// **'Scanner overlay'**
  String get arScannerOverlayTitle;

  /// No description provided for @arScannerOverlaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show/hide scanner guide'**
  String get arScannerOverlaySubtitle;

  /// No description provided for @arScannerOverlayResetToast.
  ///
  /// In en, this message translates to:
  /// **'Scanner overlay resets automatically after 3 seconds.'**
  String get arScannerOverlayResetToast;

  /// No description provided for @arDisplayTitle.
  ///
  /// In en, this message translates to:
  /// **'AR display'**
  String get arDisplayTitle;

  /// No description provided for @arShowFeaturePointsTitle.
  ///
  /// In en, this message translates to:
  /// **'Show feature points'**
  String get arShowFeaturePointsTitle;

  /// No description provided for @arShowFeaturePointsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display tracking points on surfaces'**
  String get arShowFeaturePointsSubtitle;

  /// No description provided for @arShowPlanesTitle.
  ///
  /// In en, this message translates to:
  /// **'Show planes'**
  String get arShowPlanesTitle;

  /// No description provided for @arShowPlanesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display detected plane surfaces'**
  String get arShowPlanesSubtitle;

  /// No description provided for @arAutoDetectSurfacesTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect surfaces'**
  String get arAutoDetectSurfacesTitle;

  /// No description provided for @arAutoDetectSurfacesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically detect flat surfaces'**
  String get arAutoDetectSurfacesSubtitle;

  /// No description provided for @arDebugInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Debug info'**
  String get arDebugInfoTitle;

  /// No description provided for @arDebugInfoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show technical information'**
  String get arDebugInfoSubtitle;

  /// No description provided for @arModelScaleLabel.
  ///
  /// In en, this message translates to:
  /// **'Model scale: {percent}%'**
  String arModelScaleLabel(Object percent);

  /// No description provided for @arClearAllArtworksTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all artworks'**
  String get arClearAllArtworksTitle;

  /// No description provided for @arClearAllArtworksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove all placed AR objects'**
  String get arClearAllArtworksSubtitle;

  /// No description provided for @arAllArtworksClearedToast.
  ///
  /// In en, this message translates to:
  /// **'All artworks cleared'**
  String get arAllArtworksClearedToast;

  /// No description provided for @arResetSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset AR session'**
  String get arResetSessionTitle;

  /// No description provided for @arResetSessionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restart AR tracking'**
  String get arResetSessionSubtitle;

  /// No description provided for @arSessionResetToast.
  ///
  /// In en, this message translates to:
  /// **'AR session reset'**
  String get arSessionResetToast;

  /// No description provided for @connectWalletSecureAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure access'**
  String get connectWalletSecureAccessTitle;

  /// No description provided for @connectWalletChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your wallet'**
  String get connectWalletChooseTitle;

  /// No description provided for @connectWalletChooseDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose how you want to connect. You can create a new wallet, import an existing one, or use WalletConnect.'**
  String get connectWalletChooseDescription;

  /// No description provided for @connectWalletOptionWalletConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'WalletConnect'**
  String get connectWalletOptionWalletConnectTitle;

  /// No description provided for @connectWalletOptionWalletConnectDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect using a QR code or WalletConnect URI'**
  String get connectWalletOptionWalletConnectDescription;

  /// No description provided for @connectWalletOptionSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get connectWalletOptionSignInTitle;

  /// No description provided for @connectWalletOptionSignInDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your e-mail and password'**
  String get connectWalletOptionSignInDescription;

  /// No description provided for @connectWalletOptionRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Register account'**
  String get connectWalletOptionRegisterTitle;

  /// No description provided for @connectWalletOptionRegisterDescription.
  ///
  /// In en, this message translates to:
  /// **'Register with your e-mail or Google account'**
  String get connectWalletOptionRegisterDescription;

  /// No description provided for @connectWalletHybridHelpLink.
  ///
  /// In en, this message translates to:
  /// **'What’s WalletConnect?'**
  String get connectWalletHybridHelpLink;

  /// No description provided for @connectWalletImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import wallet'**
  String get connectWalletImportTitle;

  /// No description provided for @connectWalletImportDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter your 12-word recovery phrase to import a wallet stored on another device.'**
  String get connectWalletImportDescription;

  /// No description provided for @connectWalletImportHint.
  ///
  /// In en, this message translates to:
  /// **'Enter 12 words separated by spaces'**
  String get connectWalletImportHint;

  /// No description provided for @connectWalletImportWarning.
  ///
  /// In en, this message translates to:
  /// **'Never share your recovery phrase. Anyone with it can control your wallet.'**
  String get connectWalletImportWarning;

  /// No description provided for @connectWalletImportButton.
  ///
  /// In en, this message translates to:
  /// **'Import wallet'**
  String get connectWalletImportButton;

  /// No description provided for @connectWalletImportEmptyMnemonicError.
  ///
  /// In en, this message translates to:
  /// **'Please enter your recovery phrase'**
  String get connectWalletImportEmptyMnemonicError;

  /// No description provided for @connectWalletImportInvalidMnemonicWordCountError.
  ///
  /// In en, this message translates to:
  /// **'Expected 12 words, got {count}.'**
  String connectWalletImportInvalidMnemonicWordCountError(Object count);

  /// No description provided for @connectWalletImportSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Wallet imported: {prefix}…'**
  String connectWalletImportSuccessToast(Object prefix);

  /// No description provided for @connectWalletImportFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Wallet import failed. Please try again.'**
  String get connectWalletImportFailedToast;

  /// No description provided for @connectWalletCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new wallet'**
  String get connectWalletCreateTitle;

  /// No description provided for @connectWalletCreateDescription.
  ///
  /// In en, this message translates to:
  /// **'We’ll generate a new wallet on this device. Make sure to back up your recovery phrase securely.'**
  String get connectWalletCreateDescription;

  /// No description provided for @connectWalletCreateInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get connectWalletCreateInfoTitle;

  /// No description provided for @connectWalletCreateInfoBody.
  ///
  /// In en, this message translates to:
  /// **'Write down your recovery phrase and store it somewhere safe. We can’t recover it for you.'**
  String get connectWalletCreateInfoBody;

  /// No description provided for @connectWalletCreateWarning.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you confirm you understand the risks.'**
  String get connectWalletCreateWarning;

  /// No description provided for @connectWalletCreateGenerateButton.
  ///
  /// In en, this message translates to:
  /// **'Generate wallet'**
  String get connectWalletCreateGenerateButton;

  /// No description provided for @connectWalletCreateAlreadyHaveWalletPrefix.
  ///
  /// In en, this message translates to:
  /// **'Already have a wallet?'**
  String get connectWalletCreateAlreadyHaveWalletPrefix;

  /// No description provided for @connectWalletCreateAlreadyHaveWalletLink.
  ///
  /// In en, this message translates to:
  /// **'Import it'**
  String get connectWalletCreateAlreadyHaveWalletLink;

  /// No description provided for @connectWalletCreateSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Wallet created and profile set up.'**
  String get connectWalletCreateSuccessToast;

  /// No description provided for @connectWalletCreateFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to create wallet. Please try again.'**
  String get connectWalletCreateFailedToast;

  /// No description provided for @connectWalletMnemonicDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save your recovery phrase'**
  String get connectWalletMnemonicDialogTitle;

  /// No description provided for @connectWalletMnemonicDialogWarning.
  ///
  /// In en, this message translates to:
  /// **'Write this down and keep it safe!'**
  String get connectWalletMnemonicDialogWarning;

  /// No description provided for @connectWalletMnemonicDialogConfirmPrompt.
  ///
  /// In en, this message translates to:
  /// **'Confirm by typing your recovery phrase:'**
  String get connectWalletMnemonicDialogConfirmPrompt;

  /// No description provided for @connectWalletMnemonicDialogConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Paste or type your recovery phrase'**
  String get connectWalletMnemonicDialogConfirmHint;

  /// No description provided for @connectWalletMnemonicDialogAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Your wallet address: {address}'**
  String connectWalletMnemonicDialogAddressLabel(Object address);

  /// No description provided for @connectWalletMnemonicDialogConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'I’ve saved it'**
  String get connectWalletMnemonicDialogConfirmButton;

  /// No description provided for @connectWalletConnectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet connected'**
  String get connectWalletConnectedTitle;

  /// No description provided for @connectWalletConnectedDescription.
  ///
  /// In en, this message translates to:
  /// **'Your wallet is now connected to art.kubus. You can explore AR art, trade NFTs, and participate in the ecosystem.'**
  String get connectWalletConnectedDescription;

  /// No description provided for @connectWalletConnectedStartExploringButton.
  ///
  /// In en, this message translates to:
  /// **'Start exploring'**
  String get connectWalletConnectedStartExploringButton;

  /// No description provided for @connectWalletConnectedDisconnectButton.
  ///
  /// In en, this message translates to:
  /// **'Disconnect wallet'**
  String get connectWalletConnectedDisconnectButton;

  /// No description provided for @connectWalletWeb3GuideTitle.
  ///
  /// In en, this message translates to:
  /// **'What is a Web3 wallet?'**
  String get connectWalletWeb3GuideTitle;

  /// No description provided for @connectWalletWeb3GuideDescription.
  ///
  /// In en, this message translates to:
  /// **'A Web3 wallet is your gateway to the decentralized internet:'**
  String get connectWalletWeb3GuideDescription;

  /// No description provided for @connectWalletWeb3GuideFeatureSecureTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure'**
  String get connectWalletWeb3GuideFeatureSecureTitle;

  /// No description provided for @connectWalletWeb3GuideFeatureSecureDescription.
  ///
  /// In en, this message translates to:
  /// **'Your keys, your crypto'**
  String get connectWalletWeb3GuideFeatureSecureDescription;

  /// No description provided for @connectWalletWeb3GuideFeatureNftsTitle.
  ///
  /// In en, this message translates to:
  /// **'NFTs'**
  String get connectWalletWeb3GuideFeatureNftsTitle;

  /// No description provided for @connectWalletWeb3GuideFeatureNftsDescription.
  ///
  /// In en, this message translates to:
  /// **'Store and trade digital art'**
  String get connectWalletWeb3GuideFeatureNftsDescription;

  /// No description provided for @connectWalletWeb3GuideFeatureGovernanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Governance'**
  String get connectWalletWeb3GuideFeatureGovernanceTitle;

  /// No description provided for @connectWalletWeb3GuideFeatureGovernanceDescription.
  ///
  /// In en, this message translates to:
  /// **'Vote on platform decisions'**
  String get connectWalletWeb3GuideFeatureGovernanceDescription;

  /// No description provided for @connectWalletWeb3GuideFeatureDefiTitle.
  ///
  /// In en, this message translates to:
  /// **'DeFi'**
  String get connectWalletWeb3GuideFeatureDefiTitle;

  /// No description provided for @connectWalletWeb3GuideFeatureDefiDescription.
  ///
  /// In en, this message translates to:
  /// **'Access decentralized finance'**
  String get connectWalletWeb3GuideFeatureDefiDescription;

  /// No description provided for @connectWalletWeb3GuideGotItButton.
  ///
  /// In en, this message translates to:
  /// **'Got it!'**
  String get connectWalletWeb3GuideGotItButton;

  /// No description provided for @connectWalletWalletConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect with WalletConnect'**
  String get connectWalletWalletConnectTitle;

  /// No description provided for @connectWalletWalletConnectDescription.
  ///
  /// In en, this message translates to:
  /// **'Use WalletConnect to connect your wallet app to art.kubus.'**
  String get connectWalletWalletConnectDescription;

  /// No description provided for @connectWalletWalletConnectSupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'Supported wallets'**
  String get connectWalletWalletConnectSupportedTitle;

  /// No description provided for @connectWalletWalletConnectSupportedList.
  ///
  /// In en, this message translates to:
  /// **'Phantom, Solflare, Backpack, and more'**
  String get connectWalletWalletConnectSupportedList;

  /// No description provided for @connectWalletWalletConnectHowToTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get connectWalletWalletConnectHowToTitle;

  /// No description provided for @connectWalletWalletConnectStep1.
  ///
  /// In en, this message translates to:
  /// **'Open WalletConnect in your wallet app'**
  String get connectWalletWalletConnectStep1;

  /// No description provided for @connectWalletWalletConnectStep2.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code or paste the URI'**
  String get connectWalletWalletConnectStep2;

  /// No description provided for @connectWalletWalletConnectStep3.
  ///
  /// In en, this message translates to:
  /// **'Approve the connection in your wallet'**
  String get connectWalletWalletConnectStep3;

  /// No description provided for @connectWalletWalletConnectConnectingLabel.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connectWalletWalletConnectConnectingLabel;

  /// No description provided for @connectWalletWalletConnectQuickConnectLabel.
  ///
  /// In en, this message translates to:
  /// **'Quick connect'**
  String get connectWalletWalletConnectQuickConnectLabel;

  /// No description provided for @connectWalletWalletConnectUriHint.
  ///
  /// In en, this message translates to:
  /// **'Paste WalletConnect URI (wc:...)'**
  String get connectWalletWalletConnectUriHint;

  /// No description provided for @connectWalletWalletConnectSecurityNote.
  ///
  /// In en, this message translates to:
  /// **'Only connect to wallets you trust. Never share your recovery phrase.'**
  String get connectWalletWalletConnectSecurityNote;

  /// No description provided for @connectWalletWalletConnectScanQrButton.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get connectWalletWalletConnectScanQrButton;

  /// No description provided for @connectWalletWalletConnectConnectButton.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectWalletWalletConnectConnectButton;

  /// No description provided for @connectWalletWalletConnectNoWalletPrefix.
  ///
  /// In en, this message translates to:
  /// **'Don’t have a wallet yet?'**
  String get connectWalletWalletConnectNoWalletPrefix;

  /// No description provided for @connectWalletWalletConnectNoWalletLink.
  ///
  /// In en, this message translates to:
  /// **'Create one'**
  String get connectWalletWalletConnectNoWalletLink;

  /// No description provided for @connectWalletWalletConnectScanQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan WalletConnect QR code'**
  String get connectWalletWalletConnectScanQrTitle;

  /// No description provided for @connectWalletWalletConnectScanQrHint.
  ///
  /// In en, this message translates to:
  /// **'Position the QR code within the frame'**
  String get connectWalletWalletConnectScanQrHint;

  /// No description provided for @connectWalletWalletConnectUriRequiredToast.
  ///
  /// In en, this message translates to:
  /// **'Please enter a WalletConnect URI'**
  String get connectWalletWalletConnectUriRequiredToast;

  /// No description provided for @connectWalletWalletConnectInvalidUriToast.
  ///
  /// In en, this message translates to:
  /// **'Invalid WalletConnect URI'**
  String get connectWalletWalletConnectInvalidUriToast;

  /// No description provided for @connectWalletWalletConnectNeedsLocalWalletToast.
  ///
  /// In en, this message translates to:
  /// **'Create or import a wallet before using WalletConnect'**
  String get connectWalletWalletConnectNeedsLocalWalletToast;

  /// No description provided for @connectWalletWalletConnectConnectedToast.
  ///
  /// In en, this message translates to:
  /// **'Connected to {address}'**
  String connectWalletWalletConnectConnectedToast(Object address);

  /// No description provided for @connectWalletWalletConnectConnectionErrorToast.
  ///
  /// In en, this message translates to:
  /// **'Connection error. Please try again.'**
  String get connectWalletWalletConnectConnectionErrorToast;

  /// No description provided for @connectWalletWalletConnectWaitingApprovalToast.
  ///
  /// In en, this message translates to:
  /// **'Waiting for wallet approval…'**
  String get connectWalletWalletConnectWaitingApprovalToast;

  /// No description provided for @connectWalletWalletConnectFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect with WalletConnect'**
  String get connectWalletWalletConnectFailedToast;

  /// No description provided for @walletHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'My wallet'**
  String get walletHomeTitle;

  /// No description provided for @walletHomeLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading your wallet…'**
  String get walletHomeLoadingLabel;

  /// No description provided for @walletHomeNoWalletDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect a wallet to get started.'**
  String get walletHomeNoWalletDescription;

  /// No description provided for @walletHomeAlreadyConnectedToast.
  ///
  /// In en, this message translates to:
  /// **'Wallet is already connected.'**
  String get walletHomeAlreadyConnectedToast;

  /// No description provided for @walletHomeTotalBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Total balance'**
  String get walletHomeTotalBalanceLabel;

  /// No description provided for @walletHomeAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address: {address}'**
  String walletHomeAddressLabel(Object address);

  /// No description provided for @walletHomeAddressCopiedToast.
  ///
  /// In en, this message translates to:
  /// **'Address copied to clipboard!'**
  String get walletHomeAddressCopiedToast;

  /// No description provided for @walletHomeActionSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get walletHomeActionSend;

  /// No description provided for @walletHomeActionReceive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get walletHomeActionReceive;

  /// No description provided for @walletHomeActionSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get walletHomeActionSwap;

  /// No description provided for @walletHomeActionNfts.
  ///
  /// In en, this message translates to:
  /// **'NFTs'**
  String get walletHomeActionNfts;

  /// No description provided for @walletHomeYourTokensTitle.
  ///
  /// In en, this message translates to:
  /// **'Your tokens'**
  String get walletHomeYourTokensTitle;

  /// No description provided for @walletHomeRecentTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get walletHomeRecentTransactionsTitle;

  /// No description provided for @walletHomeTimeAgoDays.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String walletHomeTimeAgoDays(Object count);

  /// No description provided for @walletHomeTimeAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String walletHomeTimeAgoHours(Object count);

  /// No description provided for @walletHomeTimeAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String walletHomeTimeAgoMinutes(Object count);

  /// No description provided for @walletHomeTxSwapLabel.
  ///
  /// In en, this message translates to:
  /// **'Swapped'**
  String get walletHomeTxSwapLabel;

  /// No description provided for @walletHomeTxStakeLabel.
  ///
  /// In en, this message translates to:
  /// **'Staked'**
  String get walletHomeTxStakeLabel;

  /// No description provided for @walletHomeTxUnstakeLabel.
  ///
  /// In en, this message translates to:
  /// **'Unstaked'**
  String get walletHomeTxUnstakeLabel;

  /// No description provided for @walletHomeTxGovernanceVoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Governance vote'**
  String get walletHomeTxGovernanceVoteLabel;

  /// No description provided for @receiveTokenTitle.
  ///
  /// In en, this message translates to:
  /// **'Receive tokens'**
  String get receiveTokenTitle;

  /// No description provided for @receiveTokenSelectTokenTitle.
  ///
  /// In en, this message translates to:
  /// **'Select token to receive'**
  String get receiveTokenSelectTokenTitle;

  /// No description provided for @receiveTokenBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Bal. {amount}'**
  String receiveTokenBalanceLabel(Object amount);

  /// No description provided for @receiveTokenQrError.
  ///
  /// In en, this message translates to:
  /// **'QR error\nGeneration failed'**
  String get receiveTokenQrError;

  /// No description provided for @receiveTokenQrRequiresWallet.
  ///
  /// In en, this message translates to:
  /// **'Create or import a wallet\nto generate a QR code'**
  String get receiveTokenQrRequiresWallet;

  /// No description provided for @receiveTokenScanToSend.
  ///
  /// In en, this message translates to:
  /// **'Scan to send {token}'**
  String receiveTokenScanToSend(Object token);

  /// No description provided for @receiveTokenAnyoneCanSend.
  ///
  /// In en, this message translates to:
  /// **'Anyone can send {token} to this address'**
  String receiveTokenAnyoneCanSend(Object token);

  /// No description provided for @receiveTokenFinishSetupToShare.
  ///
  /// In en, this message translates to:
  /// **'Finish wallet setup to share your address'**
  String get receiveTokenFinishSetupToShare;

  /// No description provided for @receiveTokenYourAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Your {token} address'**
  String receiveTokenYourAddressTitle(Object token);

  /// No description provided for @receiveTokenShareAddressTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share address'**
  String get receiveTokenShareAddressTooltip;

  /// No description provided for @receiveTokenCopyAddressTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get receiveTokenCopyAddressTooltip;

  /// No description provided for @receiveTokenRequiresWalletToReceive.
  ///
  /// In en, this message translates to:
  /// **'Create or import a wallet to receive tokens'**
  String get receiveTokenRequiresWalletToReceive;

  /// No description provided for @receiveTokenCopyAddressButton.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get receiveTokenCopyAddressButton;

  /// No description provided for @receiveTokenHowToReceiveTitle.
  ///
  /// In en, this message translates to:
  /// **'How to receive {token}'**
  String receiveTokenHowToReceiveTitle(Object token);

  /// No description provided for @receiveTokenStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Share your address'**
  String get receiveTokenStep1Title;

  /// No description provided for @receiveTokenStep1Description.
  ///
  /// In en, this message translates to:
  /// **'Send your wallet address to the person who wants to send you {token}'**
  String receiveTokenStep1Description(Object token);

  /// No description provided for @receiveTokenStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Or show QR code'**
  String get receiveTokenStep2Title;

  /// No description provided for @receiveTokenStep2Description.
  ///
  /// In en, this message translates to:
  /// **'Let them scan the QR code above with their wallet app'**
  String get receiveTokenStep2Description;

  /// No description provided for @receiveTokenStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Receive tokens'**
  String get receiveTokenStep3Title;

  /// No description provided for @receiveTokenStep3Description.
  ///
  /// In en, this message translates to:
  /// **'Tokens will appear in your wallet once the transaction is confirmed'**
  String get receiveTokenStep3Description;

  /// No description provided for @receiveTokenWarningOnlySend.
  ///
  /// In en, this message translates to:
  /// **'Only send {token} and compatible tokens to this address'**
  String receiveTokenWarningOnlySend(Object token);

  /// No description provided for @receiveTokenNoWalletAddressToast.
  ///
  /// In en, this message translates to:
  /// **'No wallet address available yet'**
  String get receiveTokenNoWalletAddressToast;

  /// No description provided for @receiveTokenShareText.
  ///
  /// In en, this message translates to:
  /// **'Send {token} to {address}\n{payload}'**
  String receiveTokenShareText(Object token, Object address, Object payload);

  /// No description provided for @receiveTokenNoTokensMessage.
  ///
  /// In en, this message translates to:
  /// **'Connect or import a wallet to display available tokens.'**
  String get receiveTokenNoTokensMessage;

  /// No description provided for @sendTokenTitle.
  ///
  /// In en, this message translates to:
  /// **'Send token'**
  String get sendTokenTitle;

  /// No description provided for @sendTokenScanQrTooltip.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get sendTokenScanQrTooltip;

  /// No description provided for @sendTokenQrScannerUnavailableTooltip.
  ///
  /// In en, this message translates to:
  /// **'QR scanner not available'**
  String get sendTokenQrScannerUnavailableTooltip;

  /// No description provided for @sendTokenSelectTokenTitle.
  ///
  /// In en, this message translates to:
  /// **'Select token'**
  String get sendTokenSelectTokenTitle;

  /// No description provided for @sendTokenRecipientAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Recipient address'**
  String get sendTokenRecipientAddressTitle;

  /// No description provided for @sendTokenRecipientAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Enter recipient address'**
  String get sendTokenRecipientAddressHint;

  /// No description provided for @sendTokenAmountTitle.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get sendTokenAmountTitle;

  /// No description provided for @sendTokenMaxButton.
  ///
  /// In en, this message translates to:
  /// **'MAX'**
  String get sendTokenMaxButton;

  /// No description provided for @sendTokenAvailableLabel.
  ///
  /// In en, this message translates to:
  /// **'Available: {amount} {token}'**
  String sendTokenAvailableLabel(Object amount, Object token);

  /// No description provided for @sendTokenTransactionSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction summary'**
  String get sendTokenTransactionSummaryTitle;

  /// No description provided for @sendTokenSummaryAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get sendTokenSummaryAmountLabel;

  /// No description provided for @sendTokenSummaryFeesLabel.
  ///
  /// In en, this message translates to:
  /// **'Kubus fees (~{percent}%)'**
  String sendTokenSummaryFeesLabel(Object percent);

  /// No description provided for @sendTokenSummaryEstimatedDebitLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated token debit'**
  String get sendTokenSummaryEstimatedDebitLabel;

  /// No description provided for @sendTokenSummaryUsdValueLabel.
  ///
  /// In en, this message translates to:
  /// **'USD value'**
  String get sendTokenSummaryUsdValueLabel;

  /// No description provided for @sendTokenSummaryNetworkFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Network fee'**
  String get sendTokenSummaryNetworkFeeLabel;

  /// No description provided for @sendTokenNetworkFeeNote.
  ///
  /// In en, this message translates to:
  /// **'Network fees are paid in SOL. Keep a small SOL balance for gas.'**
  String get sendTokenNetworkFeeNote;

  /// No description provided for @sendTokenNoTokensMessage.
  ///
  /// In en, this message translates to:
  /// **'Connect or create a wallet to select tokens for sending.'**
  String get sendTokenNoTokensMessage;

  /// No description provided for @sendTokenButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Send {token}'**
  String sendTokenButtonLabel(Object token);

  /// No description provided for @sendTokenAddressRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Address is required'**
  String get sendTokenAddressRequiredError;

  /// No description provided for @sendTokenAddressInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Solana address'**
  String get sendTokenAddressInvalidError;

  /// No description provided for @sendTokenAmountRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Amount is required'**
  String get sendTokenAmountRequiredError;

  /// No description provided for @sendTokenAmountGreaterThanZeroError.
  ///
  /// In en, this message translates to:
  /// **'Amount must be greater than 0'**
  String get sendTokenAmountGreaterThanZeroError;

  /// No description provided for @sendTokenInsufficientBalanceError.
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance'**
  String get sendTokenInsufficientBalanceError;

  /// No description provided for @sendTokenNoBalanceToast.
  ///
  /// In en, this message translates to:
  /// **'No balance available for this token'**
  String get sendTokenNoBalanceToast;

  /// No description provided for @sendTokenMaxAmountComputeFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Unable to compute max amount. Keep some balance for fees.'**
  String get sendTokenMaxAmountComputeFailedToast;

  /// No description provided for @sendTokenQrScannerUnsupportedWeb.
  ///
  /// In en, this message translates to:
  /// **'QR code scanning is not available on web browsers. Please use the mobile or desktop app for this feature.'**
  String get sendTokenQrScannerUnsupportedWeb;

  /// No description provided for @sendTokenQrScannerUnsupportedDesktop.
  ///
  /// In en, this message translates to:
  /// **'QR code scanning is not available on desktop platforms. Please use the mobile app for this feature.'**
  String get sendTokenQrScannerUnsupportedDesktop;

  /// No description provided for @sendTokenQrScannerUnsupportedPlatform.
  ///
  /// In en, this message translates to:
  /// **'QR code scanning is not supported on this platform.'**
  String get sendTokenQrScannerUnsupportedPlatform;

  /// No description provided for @sendTokenQrUnreadableToast.
  ///
  /// In en, this message translates to:
  /// **'Unable to read QR code payload.'**
  String get sendTokenQrUnreadableToast;

  /// No description provided for @sendTokenQrInvalidAddressToast.
  ///
  /// In en, this message translates to:
  /// **'QR code did not include a valid address.'**
  String get sendTokenQrInvalidAddressToast;

  /// No description provided for @sendTokenQrScannedAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address scanned'**
  String get sendTokenQrScannedAddressLabel;

  /// No description provided for @sendTokenQrScannedTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Token: {token}'**
  String sendTokenQrScannedTokenLabel(Object token);

  /// No description provided for @sendTokenQrScannedAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount: {amount}'**
  String sendTokenQrScannedAmountLabel(Object amount);

  /// No description provided for @sendTokenQrScanErrorToast.
  ///
  /// In en, this message translates to:
  /// **'Error scanning QR code. Please try again.'**
  String get sendTokenQrScanErrorToast;

  /// No description provided for @sendTokenSendSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Sent {amount} {token} successfully'**
  String sendTokenSendSuccessToast(Object amount, Object token);

  /// No description provided for @sendTokenSendFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to send tokens. Please try again.'**
  String get sendTokenSendFailedToast;

  /// No description provided for @sendTokenInsufficientAfterFeesToast.
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance after protocol fees. Reduce the amount or top up your wallet.'**
  String get sendTokenInsufficientAfterFeesToast;

  /// No description provided for @sendTokenNoKeypairToast.
  ///
  /// In en, this message translates to:
  /// **'No wallet keypair available. Reconnect or re-import your wallet.'**
  String get sendTokenNoKeypairToast;

  /// No description provided for @sendTokenInvalidAddressBeforeSendToast.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Solana address before sending.'**
  String get sendTokenInvalidAddressBeforeSendToast;

  /// No description provided for @sendTokenConnectWalletBeforeSendToast.
  ///
  /// In en, this message translates to:
  /// **'Connect your wallet before sending tokens.'**
  String get sendTokenConnectWalletBeforeSendToast;

  /// No description provided for @qrScannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get qrScannerTitle;

  /// No description provided for @qrScannerWebUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'QR scanner not available'**
  String get qrScannerWebUnavailableTitle;

  /// No description provided for @qrScannerWebUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'Camera-based QR scanning is not supported on web browsers. Please paste or type the address manually instead.'**
  String get qrScannerWebUnavailableDescription;

  /// No description provided for @qrScannerGoBackButton.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get qrScannerGoBackButton;

  /// No description provided for @qrScannerPreparingCameraLabel.
  ///
  /// In en, this message translates to:
  /// **'Preparing camera…'**
  String get qrScannerPreparingCameraLabel;

  /// No description provided for @qrScannerPermissionNeededTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera permission needed'**
  String get qrScannerPermissionNeededTitle;

  /// No description provided for @qrScannerPermissionNeededDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable camera access to scan wallet QR codes securely.'**
  String get qrScannerPermissionNeededDescription;

  /// No description provided for @qrScannerOpenSettingsButton.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get qrScannerOpenSettingsButton;

  /// No description provided for @qrScannerGrantCameraAccessButton.
  ///
  /// In en, this message translates to:
  /// **'Grant camera access'**
  String get qrScannerGrantCameraAccessButton;

  /// No description provided for @qrScannerCameraErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera error'**
  String get qrScannerCameraErrorTitle;

  /// No description provided for @qrScannerCameraErrorDescription.
  ///
  /// In en, this message translates to:
  /// **'Unable to start camera. Please check permissions and try again.'**
  String get qrScannerCameraErrorDescription;

  /// No description provided for @qrScannerStatusAddressCapturedTitle.
  ///
  /// In en, this message translates to:
  /// **'Address captured'**
  String get qrScannerStatusAddressCapturedTitle;

  /// No description provided for @qrScannerStatusUnsupportedQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsupported QR code'**
  String get qrScannerStatusUnsupportedQrTitle;

  /// No description provided for @qrScannerStatusUnsupportedQrDescription.
  ///
  /// In en, this message translates to:
  /// **'This QR code does not include a valid Solana address.'**
  String get qrScannerStatusUnsupportedQrDescription;

  /// No description provided for @qrScannerStatusReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Ready to scan'**
  String get qrScannerStatusReadyTitle;

  /// No description provided for @qrScannerStatusReadyDescription.
  ///
  /// In en, this message translates to:
  /// **'Align the QR code inside the frame to capture a Solana address.'**
  String get qrScannerStatusReadyDescription;

  /// No description provided for @qrScannerMetaAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get qrScannerMetaAmountLabel;

  /// No description provided for @qrScannerMetaMintLabel.
  ///
  /// In en, this message translates to:
  /// **'Mint'**
  String get qrScannerMetaMintLabel;

  /// No description provided for @qrScannerInvalidQrToast.
  ///
  /// In en, this message translates to:
  /// **'Please scan a Solana wallet QR code.'**
  String get qrScannerInvalidQrToast;

  /// No description provided for @qrScannerTorchNotSupportedToast.
  ///
  /// In en, this message translates to:
  /// **'Torch toggle not supported on this device.'**
  String get qrScannerTorchNotSupportedToast;

  /// No description provided for @qrScannerSwitchCameraFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Unable to switch camera.'**
  String get qrScannerSwitchCameraFailedToast;

  /// No description provided for @artworkNotFound.
  ///
  /// In en, this message translates to:
  /// **'Artwork not found'**
  String get artworkNotFound;

  /// No description provided for @web3DashboardComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Web3 dashboard - coming soon'**
  String get web3DashboardComingSoon;

  /// No description provided for @artDetailLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading artwork'**
  String get artDetailLoadingTitle;

  /// No description provided for @artDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Artwork'**
  String get artDetailTitle;

  /// No description provided for @artDetailLoadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load artwork details. Please try again.'**
  String get artDetailLoadFailedMessage;

  /// No description provided for @artworkDetailLike.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get artworkDetailLike;

  /// No description provided for @artworkDetailLiked.
  ///
  /// In en, this message translates to:
  /// **'Liked'**
  String get artworkDetailLiked;

  /// No description provided for @artworkDetailHideComments.
  ///
  /// In en, this message translates to:
  /// **'Hide comments'**
  String get artworkDetailHideComments;

  /// No description provided for @artworkDetailMintNft.
  ///
  /// In en, this message translates to:
  /// **'Mint as NFT'**
  String get artworkDetailMintNft;

  /// No description provided for @eventCreatorSelectStartEndDatesToast.
  ///
  /// In en, this message translates to:
  /// **'Please select start and end dates'**
  String get eventCreatorSelectStartEndDatesToast;

  /// No description provided for @eventCreatorEnterCapacityToast.
  ///
  /// In en, this message translates to:
  /// **'Please enter event capacity'**
  String get eventCreatorEnterCapacityToast;

  /// No description provided for @eventCreatorNoInstitutionAvailableToast.
  ///
  /// In en, this message translates to:
  /// **'No institution available for this event'**
  String get eventCreatorNoInstitutionAvailableToast;

  /// No description provided for @eventCreatorSelectedInstitutionNotFoundToast.
  ///
  /// In en, this message translates to:
  /// **'Selected institution not found'**
  String get eventCreatorSelectedInstitutionNotFoundToast;

  /// No description provided for @eventCreatorEndTimeAfterStartToast.
  ///
  /// In en, this message translates to:
  /// **'End time must be after start time'**
  String get eventCreatorEndTimeAfterStartToast;

  /// No description provided for @eventCreatorEventUpdatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Event updated'**
  String get eventCreatorEventUpdatedTitle;

  /// No description provided for @eventCreatorEventCreatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Event created'**
  String get eventCreatorEventCreatedTitle;

  /// No description provided for @eventCreatorEventUpdatedBody.
  ///
  /// In en, this message translates to:
  /// **'Your event has been updated successfully.'**
  String get eventCreatorEventUpdatedBody;

  /// No description provided for @eventCreatorEventCreatedBody.
  ///
  /// In en, this message translates to:
  /// **'Your event has been created successfully.'**
  String get eventCreatorEventCreatedBody;

  /// No description provided for @eventCreatorCreateAnotherButton.
  ///
  /// In en, this message translates to:
  /// **'Create another'**
  String get eventCreatorCreateAnotherButton;

  /// No description provided for @eventCreatorSaveFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to save event. Please try again.'**
  String get eventCreatorSaveFailedToast;

  /// No description provided for @activityNavigationUnableToOpenToast.
  ///
  /// In en, this message translates to:
  /// **'Unable to open this activity right now.'**
  String get activityNavigationUnableToOpenToast;

  /// No description provided for @navigationUnableToNavigateToScreen.
  ///
  /// In en, this message translates to:
  /// **'Unable to navigate to {screenName}'**
  String navigationUnableToNavigateToScreen(Object screenName);

  /// No description provided for @arMarkerScannerDefaultArtworkTitle.
  ///
  /// In en, this message translates to:
  /// **'AR artwork'**
  String get arMarkerScannerDefaultArtworkTitle;

  /// No description provided for @arMarkerScannerInvalidQrFormatToast.
  ///
  /// In en, this message translates to:
  /// **'Invalid QR code format'**
  String get arMarkerScannerInvalidQrFormatToast;

  /// No description provided for @arMarkerScannerMissingModelUrlToast.
  ///
  /// In en, this message translates to:
  /// **'QR code missing model URL'**
  String get arMarkerScannerMissingModelUrlToast;

  /// No description provided for @arMarkerScannerByArtist.
  ///
  /// In en, this message translates to:
  /// **'By {artist}'**
  String arMarkerScannerByArtist(Object artist);

  /// No description provided for @arMarkerScannerLaunchViewerPrompt.
  ///
  /// In en, this message translates to:
  /// **'Launch AR viewer?'**
  String get arMarkerScannerLaunchViewerPrompt;

  /// No description provided for @arMarkerScannerLaunchFailedInstallPrompt.
  ///
  /// In en, this message translates to:
  /// **'Failed to launch AR viewer. Install Google ARCore?'**
  String get arMarkerScannerLaunchFailedInstallPrompt;

  /// No description provided for @arMarkerScannerProcessingFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to process QR code. Please try again.'**
  String get arMarkerScannerProcessingFailedToast;

  /// No description provided for @arMarkerScannerProcessingQrLabel.
  ///
  /// In en, this message translates to:
  /// **'Processing QR code…'**
  String get arMarkerScannerProcessingQrLabel;

  /// No description provided for @arMarkerScannerPointCameraLabel.
  ///
  /// In en, this message translates to:
  /// **'Point camera at QR code to discover AR artwork'**
  String get arMarkerScannerPointCameraLabel;

  /// No description provided for @arMarkerScannerLaunchingViewerLabel.
  ///
  /// In en, this message translates to:
  /// **'Launching AR viewer…'**
  String get arMarkerScannerLaunchingViewerLabel;

  /// No description provided for @arArtworkCardLaunchFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to launch AR. Please try again.'**
  String get arArtworkCardLaunchFailedToast;

  /// No description provided for @arArtworkCardUnavailableLabel.
  ///
  /// In en, this message translates to:
  /// **'AR unavailable'**
  String get arArtworkCardUnavailableLabel;

  /// No description provided for @arArtworkCardGetCloserLabel.
  ///
  /// In en, this message translates to:
  /// **'Get closer'**
  String get arArtworkCardGetCloserLabel;

  /// No description provided for @artistGalleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Your gallery'**
  String get artistGalleryTitle;

  /// No description provided for @artistGalleryArtworkCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 artwork} other{{count} artworks}}'**
  String artistGalleryArtworkCount(num count);

  /// No description provided for @artistGalleryStatActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get artistGalleryStatActiveLabel;

  /// No description provided for @artistGalleryStatViewsLabel.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get artistGalleryStatViewsLabel;

  /// No description provided for @artistGalleryStatLikesLabel.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get artistGalleryStatLikesLabel;

  /// No description provided for @artistGalleryFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get artistGalleryFilterAll;

  /// No description provided for @artistGalleryFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get artistGalleryFilterActive;

  /// No description provided for @artistGalleryFilterDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get artistGalleryFilterDraft;

  /// No description provided for @artistGalleryFilterSold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get artistGalleryFilterSold;

  /// No description provided for @artistGallerySortByTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get artistGallerySortByTitle;

  /// No description provided for @artistGallerySortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get artistGallerySortNewest;

  /// No description provided for @artistGallerySortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get artistGallerySortOldest;

  /// No description provided for @artistGallerySortMostViews.
  ///
  /// In en, this message translates to:
  /// **'Most views'**
  String get artistGallerySortMostViews;

  /// No description provided for @artistGallerySortMostLikes.
  ///
  /// In en, this message translates to:
  /// **'Most likes'**
  String get artistGallerySortMostLikes;

  /// No description provided for @artistGallerySearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search artworks'**
  String get artistGallerySearchTitle;

  /// No description provided for @artistGallerySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Enter artwork title…'**
  String get artistGallerySearchHint;

  /// No description provided for @artistGalleryCreateNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Create new artwork'**
  String get artistGalleryCreateNewTitle;

  /// No description provided for @artistGalleryCreateNewDescription.
  ///
  /// In en, this message translates to:
  /// **'Navigate to the Create tab to upload and create your new artwork.'**
  String get artistGalleryCreateNewDescription;

  /// No description provided for @artistGalleryGoToCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Go to Create'**
  String get artistGalleryGoToCreateButton;

  /// No description provided for @artistGalleryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No artworks yet'**
  String get artistGalleryEmptyTitle;

  /// No description provided for @artistGalleryEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Create your first artwork to get started.'**
  String get artistGalleryEmptyDescription;

  /// No description provided for @artistGalleryCreateArtworkButton.
  ///
  /// In en, this message translates to:
  /// **'Create artwork'**
  String get artistGalleryCreateArtworkButton;

  /// No description provided for @artistGalleryEditingToast.
  ///
  /// In en, this message translates to:
  /// **'Editing {title}'**
  String artistGalleryEditingToast(Object title);

  /// No description provided for @artistGallerySharingToast.
  ///
  /// In en, this message translates to:
  /// **'Sharing {title}'**
  String artistGallerySharingToast(Object title);

  /// No description provided for @artistGalleryPublishSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" published'**
  String artistGalleryPublishSuccessToast(Object title);

  /// No description provided for @artistGalleryUnpublishSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" moved to draft'**
  String artistGalleryUnpublishSuccessToast(Object title);

  /// No description provided for @artistGalleryPublishFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to publish \"{title}\". Please try again.'**
  String artistGalleryPublishFailedToast(Object title);

  /// No description provided for @artistGalleryUnpublishFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to unpublish \"{title}\". Please try again.'**
  String artistGalleryUnpublishFailedToast(Object title);

  /// No description provided for @artistGalleryDeletedToast.
  ///
  /// In en, this message translates to:
  /// **'{title} deleted'**
  String artistGalleryDeletedToast(Object title);

  /// No description provided for @artistGalleryDeleteArtworkTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete artwork'**
  String get artistGalleryDeleteArtworkTitle;

  /// No description provided for @artistGalleryDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"? This action cannot be undone.'**
  String artistGalleryDeleteConfirmBody(Object title);

  /// No description provided for @artistCreatorCreateArtworkButton.
  ///
  /// In en, this message translates to:
  /// **'Create artwork'**
  String get artistCreatorCreateArtworkButton;

  /// No description provided for @artistCreatorCoverSelectedToast.
  ///
  /// In en, this message translates to:
  /// **'Cover selected'**
  String get artistCreatorCoverSelectedToast;

  /// No description provided for @artistCreatorPickImageFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick an image. Please try again.'**
  String get artistCreatorPickImageFailedToast;

  /// No description provided for @artistCreatorModelSelectedToast.
  ///
  /// In en, this message translates to:
  /// **'3D model selected'**
  String get artistCreatorModelSelectedToast;

  /// No description provided for @artistCreatorPickModelFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick a 3D model. Please try again.'**
  String get artistCreatorPickModelFailedToast;

  /// No description provided for @artistCreatorSelectImageToast.
  ///
  /// In en, this message translates to:
  /// **'Please select an image'**
  String get artistCreatorSelectImageToast;

  /// No description provided for @artistCreatorConnectWalletToPublishToast.
  ///
  /// In en, this message translates to:
  /// **'Connect your wallet to publish artwork.'**
  String get artistCreatorConnectWalletToPublishToast;

  /// No description provided for @artistCreatorSelectCoverImageToast.
  ///
  /// In en, this message translates to:
  /// **'Please select a cover image.'**
  String get artistCreatorSelectCoverImageToast;

  /// No description provided for @artistCreatorUploadModelToEnableArToast.
  ///
  /// In en, this message translates to:
  /// **'Upload a 3D model to enable AR.'**
  String get artistCreatorUploadModelToEnableArToast;

  /// No description provided for @artistCreatorEnterLatLngOrDisableToast.
  ///
  /// In en, this message translates to:
  /// **'Enter both latitude and longitude or disable coordinates.'**
  String get artistCreatorEnterLatLngOrDisableToast;

  /// No description provided for @artistCreatorInvalidCoordinatesToast.
  ///
  /// In en, this message translates to:
  /// **'Coordinates must be valid latitude/longitude values.'**
  String get artistCreatorInvalidCoordinatesToast;

  /// No description provided for @artistCreatorCoverUrlMissingToast.
  ///
  /// In en, this message translates to:
  /// **'Upload succeeded but cover URL is missing.'**
  String get artistCreatorCoverUrlMissingToast;

  /// No description provided for @artistCreatorSubmittedPendingToast.
  ///
  /// In en, this message translates to:
  /// **'Artwork submitted. Backend response pending.'**
  String get artistCreatorSubmittedPendingToast;

  /// No description provided for @artistCreatorSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Success!'**
  String get artistCreatorSuccessTitle;

  /// No description provided for @artistCreatorSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Your artwork has been created successfully!'**
  String get artistCreatorSuccessBody;

  /// No description provided for @artistCreatorViewGalleryButton.
  ///
  /// In en, this message translates to:
  /// **'View gallery'**
  String get artistCreatorViewGalleryButton;

  /// No description provided for @artistCreatorCreateFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to create artwork. Please try again.'**
  String get artistCreatorCreateFailedToast;

  /// No description provided for @artistCreatorHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'AR marker creation'**
  String get artistCreatorHelpTitle;

  /// No description provided for @artistCreatorHelpBody.
  ///
  /// In en, this message translates to:
  /// **'Follow the 4-step process to create your AR artwork:\n\n1. Upload: Select your artwork image\n2. Details: Enter title, description, and pricing\n3. Settings: Configure location and features\n4. Review: Confirm and publish your artwork'**
  String get artistCreatorHelpBody;

  /// No description provided for @artistStudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Artist Studio'**
  String get artistStudioTitle;

  /// No description provided for @artistStudioHeaderWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to your Studio'**
  String get artistStudioHeaderWelcome;

  /// No description provided for @artistStudioHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create AR markers for your artwork and share them with the world'**
  String get artistStudioHeaderSubtitle;

  /// No description provided for @artistStudioInstitutionRoleActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Institution role active'**
  String get artistStudioInstitutionRoleActiveTitle;

  /// No description provided for @artistStudioInstitutionReviewInProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Institution review in progress'**
  String get artistStudioInstitutionReviewInProgressTitle;

  /// No description provided for @artistStudioInstitutionRoleActiveDescription.
  ///
  /// In en, this message translates to:
  /// **'Institution accounts can view exhibitions and events but cannot maintain artist applications. Use a dedicated artist wallet to create artworks.'**
  String get artistStudioInstitutionRoleActiveDescription;

  /// No description provided for @artistStudioInstitutionReviewInProgressDescription.
  ///
  /// In en, this message translates to:
  /// **'You have an institution application pending. Complete or withdraw it before switching to an artist review.'**
  String get artistStudioInstitutionReviewInProgressDescription;

  /// No description provided for @artistStudioCrossRoleInstitutionBadgeActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Institution badge active'**
  String get artistStudioCrossRoleInstitutionBadgeActiveTitle;

  /// No description provided for @artistStudioCrossRoleInstitutionBadgeActiveDescription.
  ///
  /// In en, this message translates to:
  /// **'Institution accounts unlock curation & event tooling. Use a dedicated artist wallet if you need creator utilities.'**
  String get artistStudioCrossRoleInstitutionBadgeActiveDescription;

  /// No description provided for @artistStudioCrossRoleInstitutionReviewInProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Institution review in progress'**
  String get artistStudioCrossRoleInstitutionReviewInProgressTitle;

  /// No description provided for @artistStudioCrossRoleInstitutionReviewInProgressDescription.
  ///
  /// In en, this message translates to:
  /// **'You currently have an institution application pending. Complete that process or request a review reset before applying as an artist.'**
  String get artistStudioCrossRoleInstitutionReviewInProgressDescription;

  /// No description provided for @artistStudioCrossRoleConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Role conflict detected'**
  String get artistStudioCrossRoleConflictTitle;

  /// No description provided for @artistStudioCrossRoleConflictDescription.
  ///
  /// In en, this message translates to:
  /// **'We detected an existing institution record for this wallet. Clear it from settings before applying as an artist.'**
  String get artistStudioCrossRoleConflictDescription;

  /// No description provided for @artistStudioDaoCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Artist application (DAO)'**
  String get artistStudioDaoCardTitle;

  /// No description provided for @artistStudioDaoCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Submit your practice for DAO review. Future releases will route approvals directly through governance.'**
  String get artistStudioDaoCardSubtitle;

  /// No description provided for @artistStudioDaoStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'APPROVED'**
  String get artistStudioDaoStatusApproved;

  /// No description provided for @artistStudioDaoStatusPending.
  ///
  /// In en, this message translates to:
  /// **'PENDING'**
  String get artistStudioDaoStatusPending;

  /// No description provided for @artistStudioDaoStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'REJECTED'**
  String get artistStudioDaoStatusRejected;

  /// No description provided for @artistStudioDaoStatusNotApplied.
  ///
  /// In en, this message translates to:
  /// **'NOT APPLIED'**
  String get artistStudioDaoStatusNotApplied;

  /// No description provided for @artistStudioStatusSyncedFromDao.
  ///
  /// In en, this message translates to:
  /// **'Status synced from DAO'**
  String get artistStudioStatusSyncedFromDao;

  /// No description provided for @artistStudioReviewPendingInfo.
  ///
  /// In en, this message translates to:
  /// **'Your submission is in the DAO review queue. We\'ll notify you after a decision.'**
  String get artistStudioReviewPendingInfo;

  /// No description provided for @artistStudioReviewApprovedInfo.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! You\'ve been cleared by DAO reviewers.'**
  String get artistStudioReviewApprovedInfo;

  /// No description provided for @artistStudioReviewRejectedInfo.
  ///
  /// In en, this message translates to:
  /// **'Your last submission was rejected. You can resubmit with updates.'**
  String get artistStudioReviewRejectedInfo;

  /// No description provided for @artistStudioConnectWalletToSubmitForDaoReview.
  ///
  /// In en, this message translates to:
  /// **'Connect your wallet to submit for DAO review.'**
  String get artistStudioConnectWalletToSubmitForDaoReview;

  /// No description provided for @artistStudioCtaConnectWalletToApply.
  ///
  /// In en, this message translates to:
  /// **'Connect a wallet to apply'**
  String get artistStudioCtaConnectWalletToApply;

  /// No description provided for @artistStudioCtaApprovedByDao.
  ///
  /// In en, this message translates to:
  /// **'Approved by DAO'**
  String get artistStudioCtaApprovedByDao;

  /// No description provided for @artistStudioCtaPendingDaoReview.
  ///
  /// In en, this message translates to:
  /// **'Pending DAO review'**
  String get artistStudioCtaPendingDaoReview;

  /// No description provided for @artistStudioCtaResubmitForReview.
  ///
  /// In en, this message translates to:
  /// **'Resubmit for review'**
  String get artistStudioCtaResubmitForReview;

  /// No description provided for @artistStudioCtaApplyForDaoReview.
  ///
  /// In en, this message translates to:
  /// **'Apply for DAO review'**
  String get artistStudioCtaApplyForDaoReview;

  /// No description provided for @artistStudioTabGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get artistStudioTabGallery;

  /// No description provided for @artistStudioTabCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get artistStudioTabCreate;

  /// No description provided for @artistStudioTabExhibitions.
  ///
  /// In en, this message translates to:
  /// **'Exhibitions'**
  String get artistStudioTabExhibitions;

  /// No description provided for @artistStudioTabAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get artistStudioTabAnalytics;

  /// No description provided for @artistStudioUnlocksAfterDaoApprovalToast.
  ///
  /// In en, this message translates to:
  /// **'Artist Studio unlocks after DAO approval.'**
  String get artistStudioUnlocksAfterDaoApprovalToast;

  /// No description provided for @artistStudioSeparateWalletsTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: Use separate wallets for artist and institution roles to avoid DAO review conflicts.'**
  String get artistStudioSeparateWalletsTip;

  /// No description provided for @artistStudioLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Artist Studio is locked'**
  String get artistStudioLockedTitle;

  /// No description provided for @artistStudioLockedDescription.
  ///
  /// In en, this message translates to:
  /// **'Apply for DAO review to unlock gallery, creation tools, and analytics.'**
  String get artistStudioLockedDescription;

  /// No description provided for @artistStudioSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Studio Settings'**
  String get artistStudioSettingsTitle;

  /// No description provided for @artistStudioApplicationModalTitle.
  ///
  /// In en, this message translates to:
  /// **'Artist application'**
  String get artistStudioApplicationModalTitle;

  /// No description provided for @artistStudioApplicationModalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share a snapshot of your practice. Submissions are routed to the DAO review queue.'**
  String get artistStudioApplicationModalSubtitle;

  /// No description provided for @artistStudioApplicationFieldPortfolioLabel.
  ///
  /// In en, this message translates to:
  /// **'Portfolio or website'**
  String get artistStudioApplicationFieldPortfolioLabel;

  /// No description provided for @artistStudioApplicationFieldMediumLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary medium or focus'**
  String get artistStudioApplicationFieldMediumLabel;

  /// No description provided for @artistStudioApplicationFieldStatementLabel.
  ///
  /// In en, this message translates to:
  /// **'Artist statement'**
  String get artistStudioApplicationFieldStatementLabel;

  /// No description provided for @artistStudioApplicationValidationPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Please provide a link to your work'**
  String get artistStudioApplicationValidationPortfolio;

  /// No description provided for @artistStudioApplicationValidationMedium.
  ///
  /// In en, this message translates to:
  /// **'Let the DAO know what you create'**
  String get artistStudioApplicationValidationMedium;

  /// No description provided for @artistStudioApplicationValidationStatementMinChars.
  ///
  /// In en, this message translates to:
  /// **'Share at least {min} characters about your work'**
  String artistStudioApplicationValidationStatementMinChars(Object min);

  /// No description provided for @artistStudioApplicationWalletRequiredToast.
  ///
  /// In en, this message translates to:
  /// **'Connect your wallet before submitting to the DAO.'**
  String get artistStudioApplicationWalletRequiredToast;

  /// No description provided for @artistStudioApplicationReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Artist application'**
  String get artistStudioApplicationReviewTitle;

  /// No description provided for @artistStudioApplicationSubmittedToast.
  ///
  /// In en, this message translates to:
  /// **'Application submitted to DAO reviewers.'**
  String get artistStudioApplicationSubmittedToast;

  /// No description provided for @artistStudioApplicationUnableToSubmitToast.
  ///
  /// In en, this message translates to:
  /// **'Unable to submit application right now.'**
  String get artistStudioApplicationUnableToSubmitToast;

  /// No description provided for @artistStudioApplicationSubmissionFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Submission failed. Please try again.'**
  String get artistStudioApplicationSubmissionFailedToast;

  /// No description provided for @artistStudioApplicationSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Submit application'**
  String get artistStudioApplicationSubmitButton;

  /// No description provided for @desktopArtistStudioOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Studio Overview'**
  String get desktopArtistStudioOverviewTitle;

  /// No description provided for @desktopArtistStudioQuickActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get desktopArtistStudioQuickActionsTitle;

  /// No description provided for @desktopArtistStudioQuickActionInvitesTitle.
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get desktopArtistStudioQuickActionInvitesTitle;

  /// No description provided for @desktopArtistStudioQuickActionInvitesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View collaboration invites'**
  String get desktopArtistStudioQuickActionInvitesSubtitle;

  /// No description provided for @desktopArtistStudioQuickActionInvitesPendingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You have pending collaboration invites'**
  String get desktopArtistStudioQuickActionInvitesPendingSubtitle;

  /// No description provided for @desktopArtistStudioQuickActionCollaborationInvitesTitle.
  ///
  /// In en, this message translates to:
  /// **'Collaboration Invites'**
  String get desktopArtistStudioQuickActionCollaborationInvitesTitle;

  /// No description provided for @desktopArtistStudioQuickActionExhibitionsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Exhibitions'**
  String get desktopArtistStudioQuickActionExhibitionsTitle;

  /// No description provided for @desktopArtistStudioQuickActionExhibitionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View exhibitions you collaborate on'**
  String get desktopArtistStudioQuickActionExhibitionsSubtitle;

  /// No description provided for @desktopArtistStudioQuickActionCreateArtworkTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Artwork'**
  String get desktopArtistStudioQuickActionCreateArtworkTitle;

  /// No description provided for @desktopArtistStudioQuickActionCreateArtworkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload and mint new art'**
  String get desktopArtistStudioQuickActionCreateArtworkSubtitle;

  /// No description provided for @desktopArtistStudioQuickActionMyGalleryTitle.
  ///
  /// In en, this message translates to:
  /// **'My Gallery'**
  String get desktopArtistStudioQuickActionMyGalleryTitle;

  /// No description provided for @desktopArtistStudioQuickActionMyGallerySubtitle.
  ///
  /// In en, this message translates to:
  /// **'View all artworks'**
  String get desktopArtistStudioQuickActionMyGallerySubtitle;

  /// No description provided for @desktopArtistStudioQuickActionAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get desktopArtistStudioQuickActionAnalyticsTitle;

  /// No description provided for @desktopArtistStudioQuickActionAnalyticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View performance stats'**
  String get desktopArtistStudioQuickActionAnalyticsSubtitle;

  /// No description provided for @desktopArtistStudioStatisticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Studio Statistics'**
  String get desktopArtistStudioStatisticsTitle;

  /// No description provided for @desktopArtistStudioRecentActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get desktopArtistStudioRecentActivityTitle;

  /// No description provided for @desktopArtistStudioNoRecentActivityLabel.
  ///
  /// In en, this message translates to:
  /// **'No recent activity'**
  String get desktopArtistStudioNoRecentActivityLabel;

  /// No description provided for @desktopArtistStudioVerificationNotAppliedTitle.
  ///
  /// In en, this message translates to:
  /// **'Not Applied'**
  String get desktopArtistStudioVerificationNotAppliedTitle;

  /// No description provided for @desktopArtistStudioVerificationNotAppliedDescription.
  ///
  /// In en, this message translates to:
  /// **'Apply for artist verification'**
  String get desktopArtistStudioVerificationNotAppliedDescription;

  /// No description provided for @desktopArtistStudioVerificationLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get desktopArtistStudioVerificationLoadingTitle;

  /// No description provided for @desktopArtistStudioVerificationLoadingDescription.
  ///
  /// In en, this message translates to:
  /// **'Checking verification status'**
  String get desktopArtistStudioVerificationLoadingDescription;

  /// No description provided for @desktopArtistStudioVerificationApprovedTitle.
  ///
  /// In en, this message translates to:
  /// **'Verified Artist'**
  String get desktopArtistStudioVerificationApprovedTitle;

  /// No description provided for @desktopArtistStudioVerificationApprovedDescription.
  ///
  /// In en, this message translates to:
  /// **'Your studio is verified'**
  String get desktopArtistStudioVerificationApprovedDescription;

  /// No description provided for @desktopArtistStudioVerificationPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending Review'**
  String get desktopArtistStudioVerificationPendingTitle;

  /// No description provided for @desktopArtistStudioVerificationPendingDescription.
  ///
  /// In en, this message translates to:
  /// **'Application under review'**
  String get desktopArtistStudioVerificationPendingDescription;

  /// No description provided for @desktopArtistStudioVerificationRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Application Rejected'**
  String get desktopArtistStudioVerificationRejectedTitle;

  /// No description provided for @desktopArtistStudioVerificationRejectedDescription.
  ///
  /// In en, this message translates to:
  /// **'Please resubmit with improvements'**
  String get desktopArtistStudioVerificationRejectedDescription;

  /// No description provided for @desktopArtistStudioApplyForVerificationButton.
  ///
  /// In en, this message translates to:
  /// **'Apply for Verification'**
  String get desktopArtistStudioApplyForVerificationButton;

  /// No description provided for @desktopArtistStudioStatArtworks.
  ///
  /// In en, this message translates to:
  /// **'Artworks'**
  String get desktopArtistStudioStatArtworks;

  /// No description provided for @desktopArtistStudioStatViews.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get desktopArtistStudioStatViews;

  /// No description provided for @desktopArtistStudioStatLikes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get desktopArtistStudioStatLikes;

  /// No description provided for @desktopArtistStudioStatSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get desktopArtistStudioStatSales;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonNotAvailableShort.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get commonNotAvailableShort;

  /// No description provided for @marketplaceNetworkLabel.
  ///
  /// In en, this message translates to:
  /// **'Network: {network}'**
  String marketplaceNetworkLabel(Object network);

  /// No description provided for @marketplaceWalletLabel.
  ///
  /// In en, this message translates to:
  /// **'Wallet: {wallet}'**
  String marketplaceWalletLabel(Object wallet);

  /// No description provided for @marketplaceConnectWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your wallet'**
  String get marketplaceConnectWalletTitle;

  /// No description provided for @marketplaceConnectWalletDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect a Solana wallet to view your NFTs.'**
  String get marketplaceConnectWalletDescription;

  /// No description provided for @marketplaceEmptyCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'No NFTs in your collection'**
  String get marketplaceEmptyCollectionTitle;

  /// No description provided for @marketplaceEmptyCollectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Mint NFTs from AR artworks and collect them here.'**
  String get marketplaceEmptyCollectionDescription;

  /// No description provided for @marketplaceExploreArArtButton.
  ///
  /// In en, this message translates to:
  /// **'Explore AR art'**
  String get marketplaceExploreArArtButton;

  /// No description provided for @marketplaceListForSaleButton.
  ///
  /// In en, this message translates to:
  /// **'List for sale'**
  String get marketplaceListForSaleButton;

  /// No description provided for @marketplaceListForSaleSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'NFT listed for sale successfully!'**
  String get marketplaceListForSaleSuccessToast;

  /// No description provided for @marketplaceListForSaleFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Unable to list NFT for sale right now.'**
  String get marketplaceListForSaleFailedToast;

  /// No description provided for @marketplaceRemoveFromSaleTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from sale'**
  String get marketplaceRemoveFromSaleTitle;

  /// No description provided for @marketplaceRemoveFromSaleConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Remove this NFT from the marketplace?'**
  String get marketplaceRemoveFromSaleConfirmBody;

  /// No description provided for @marketplaceRemoveFromSaleSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'NFT removed from sale.'**
  String get marketplaceRemoveFromSaleSuccessToast;

  /// No description provided for @marketplaceMintConnectWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet required'**
  String get marketplaceMintConnectWalletTitle;

  /// No description provided for @marketplaceMintConnectWalletDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect a wallet to mint NFTs from AR artworks.'**
  String get marketplaceMintConnectWalletDescription;

  /// No description provided for @marketplaceMintSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Mint successful!'**
  String get marketplaceMintSuccessTitle;

  /// No description provided for @marketplaceMintSuccessDescription.
  ///
  /// In en, this message translates to:
  /// **'Your NFT has been successfully minted! You can view it in your wallet.'**
  String get marketplaceMintSuccessDescription;

  /// No description provided for @marketplaceViewInWalletButton.
  ///
  /// In en, this message translates to:
  /// **'View in wallet'**
  String get marketplaceViewInWalletButton;

  /// No description provided for @marketplaceMintFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Mint failed'**
  String get marketplaceMintFailedTitle;

  /// No description provided for @marketplaceMintFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'Unable to mint NFT right now. Please try again.'**
  String get marketplaceMintFailedDescription;

  /// No description provided for @daoModerationApproveLabel.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get daoModerationApproveLabel;

  /// No description provided for @daoModerationRejectLabel.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get daoModerationRejectLabel;

  /// No description provided for @daoModerationSetPendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Set pending'**
  String get daoModerationSetPendingLabel;

  /// No description provided for @daoModerationDecisionDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'{decision} submission?'**
  String daoModerationDecisionDialogTitle(Object decision);

  /// No description provided for @daoModerationDecisionDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'Provide optional reviewer notes for the applicant.'**
  String get daoModerationDecisionDialogDescription;

  /// No description provided for @daoModerationReviewerNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Reviewer notes (optional)'**
  String get daoModerationReviewerNotesLabel;

  /// No description provided for @daoModerationDisabledToast.
  ///
  /// In en, this message translates to:
  /// **'Review moderation is disabled.'**
  String get daoModerationDisabledToast;

  /// No description provided for @daoModerationWalletRequiredToast.
  ///
  /// In en, this message translates to:
  /// **'Connect a wallet to moderate submissions.'**
  String get daoModerationWalletRequiredToast;

  /// No description provided for @daoModerationSelfNotAllowedToast.
  ///
  /// In en, this message translates to:
  /// **'You cannot moderate your own submission.'**
  String get daoModerationSelfNotAllowedToast;

  /// No description provided for @daoModerationSubmissionApprovedToast.
  ///
  /// In en, this message translates to:
  /// **'Submission approved'**
  String get daoModerationSubmissionApprovedToast;

  /// No description provided for @daoModerationSubmissionUpdatedToast.
  ///
  /// In en, this message translates to:
  /// **'Submission updated'**
  String get daoModerationSubmissionUpdatedToast;

  /// No description provided for @daoModerationNoChangesSavedToast.
  ///
  /// In en, this message translates to:
  /// **'No changes saved'**
  String get daoModerationNoChangesSavedToast;

  /// No description provided for @daoModerationUpdateFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Unable to update review right now.'**
  String get daoModerationUpdateFailedToast;

  /// No description provided for @daoReviewDetailsVotingDisabledForApplicant.
  ///
  /// In en, this message translates to:
  /// **'Voting disabled for the applicant profile.'**
  String get daoReviewDetailsVotingDisabledForApplicant;

  /// No description provided for @daoReviewDetailsVotingDisabledForSubmission.
  ///
  /// In en, this message translates to:
  /// **'Voting is disabled for this submission.'**
  String get daoReviewDetailsVotingDisabledForSubmission;

  /// No description provided for @daoReviewDetailsVotingManagedByDao.
  ///
  /// In en, this message translates to:
  /// **'Review decisions are managed by the DAO review process.'**
  String get daoReviewDetailsVotingManagedByDao;

  /// No description provided for @daoReviewQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'DAO Review Queue'**
  String get daoReviewQueueTitle;

  /// No description provided for @daoReviewVotingHandledByDaoHelper.
  ///
  /// In en, this message translates to:
  /// **'Voting is handled directly by the DAO; use proposals to decide.'**
  String get daoReviewVotingHandledByDaoHelper;

  /// No description provided for @daoReviewCannotVoteOwnSubmissionHelper.
  ///
  /// In en, this message translates to:
  /// **'You cannot vote on your own submission'**
  String get daoReviewCannotVoteOwnSubmissionHelper;

  /// No description provided for @daoReviewVotingDisabledSubmissionHelper.
  ///
  /// In en, this message translates to:
  /// **'Voting is disabled for this submission'**
  String get daoReviewVotingDisabledSubmissionHelper;

  /// No description provided for @daoReviewVotingOpensAfterReviewHelper.
  ///
  /// In en, this message translates to:
  /// **'Voting opens after review'**
  String get daoReviewVotingOpensAfterReviewHelper;

  /// No description provided for @daoReviewDecisionRecordedHelper.
  ///
  /// In en, this message translates to:
  /// **'Decision recorded: {status}'**
  String daoReviewDecisionRecordedHelper(Object status);

  /// No description provided for @daoReviewMediumNotProvided.
  ///
  /// In en, this message translates to:
  /// **'Medium not provided'**
  String get daoReviewMediumNotProvided;

  /// No description provided for @daoReviewViewDetailsButton.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get daoReviewViewDetailsButton;

  /// No description provided for @daoReviewDetailsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Review submission'**
  String get daoReviewDetailsDialogTitle;

  /// No description provided for @daoReviewDetailsPortfolioLabel.
  ///
  /// In en, this message translates to:
  /// **'Portfolio: {url}'**
  String daoReviewDetailsPortfolioLabel(Object url);

  /// No description provided for @daoReviewDetailsMediumLabel.
  ///
  /// In en, this message translates to:
  /// **'Medium: {medium}'**
  String daoReviewDetailsMediumLabel(Object medium);

  /// No description provided for @daoReviewDetailsStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String daoReviewDetailsStatusLabel(Object status);

  /// No description provided for @daoReviewDetailsReviewerNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Reviewer notes:'**
  String get daoReviewDetailsReviewerNotesLabel;

  /// No description provided for @daoProposalCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get daoProposalCategoryLabel;

  /// No description provided for @daoCategoryPlatformUpdate.
  ///
  /// In en, this message translates to:
  /// **'Platform update'**
  String get daoCategoryPlatformUpdate;

  /// No description provided for @daoCategoryNewFeature.
  ///
  /// In en, this message translates to:
  /// **'New feature'**
  String get daoCategoryNewFeature;

  /// No description provided for @daoCategoryPolicyChange.
  ///
  /// In en, this message translates to:
  /// **'Policy change'**
  String get daoCategoryPolicyChange;

  /// No description provided for @daoCategoryTreasuryAllocation.
  ///
  /// In en, this message translates to:
  /// **'Treasury allocation'**
  String get daoCategoryTreasuryAllocation;

  /// No description provided for @daoCategoryCommunityInitiative.
  ///
  /// In en, this message translates to:
  /// **'Community initiative'**
  String get daoCategoryCommunityInitiative;

  /// No description provided for @daoCategoryTechnicalImprovement.
  ///
  /// In en, this message translates to:
  /// **'Technical improvement'**
  String get daoCategoryTechnicalImprovement;

  /// No description provided for @daoProposalRequirementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Proposal Requirements'**
  String get daoProposalRequirementsTitle;

  /// No description provided for @daoProposalRequirementWalletConnected.
  ///
  /// In en, this message translates to:
  /// **'Wallet connection required to submit'**
  String get daoProposalRequirementWalletConnected;

  /// No description provided for @daoProposalRequirementClearlyDefined.
  ///
  /// In en, this message translates to:
  /// **'Proposal must be clearly defined'**
  String get daoProposalRequirementClearlyDefined;

  /// No description provided for @daoProposalRequirementVotingPeriod.
  ///
  /// In en, this message translates to:
  /// **'Voting period: 3–14 days'**
  String get daoProposalRequirementVotingPeriod;

  /// No description provided for @daoProposalRequirementQuorumTargets.
  ///
  /// In en, this message translates to:
  /// **'Quorum targets are enforced by DAO config'**
  String get daoProposalRequirementQuorumTargets;

  /// No description provided for @daoProposalFillRequiredFieldsToast.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields'**
  String get daoProposalFillRequiredFieldsToast;

  /// No description provided for @daoProposalWalletRequiredToast.
  ///
  /// In en, this message translates to:
  /// **'Connect your wallet to submit proposals.'**
  String get daoProposalWalletRequiredToast;

  /// No description provided for @daoProposalSubmittedToast.
  ///
  /// In en, this message translates to:
  /// **'Proposal submitted to DAO'**
  String get daoProposalSubmittedToast;

  /// No description provided for @daoProposalSubmitFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Unable to submit proposal right now.'**
  String get daoProposalSubmitFailedToast;

  /// No description provided for @daoQuorumReached.
  ///
  /// In en, this message translates to:
  /// **'Quorum reached'**
  String get daoQuorumReached;

  /// No description provided for @daoQuorumPending.
  ///
  /// In en, this message translates to:
  /// **'Quorum pending'**
  String get daoQuorumPending;

  /// No description provided for @daoVoteWalletRequiredToast.
  ///
  /// In en, this message translates to:
  /// **'Connect your wallet before voting'**
  String get daoVoteWalletRequiredToast;

  /// No description provided for @daoVoteSubmittedYesToast.
  ///
  /// In en, this message translates to:
  /// **'Vote Yes submitted'**
  String get daoVoteSubmittedYesToast;

  /// No description provided for @daoVoteSubmittedNoToast.
  ///
  /// In en, this message translates to:
  /// **'Vote No submitted'**
  String get daoVoteSubmittedNoToast;

  /// No description provided for @daoVoteSubmitFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Unable to submit vote right now.'**
  String get daoVoteSubmitFailedToast;

  /// No description provided for @daoVoteYesButton.
  ///
  /// In en, this message translates to:
  /// **'Vote Yes'**
  String get daoVoteYesButton;

  /// No description provided for @daoVoteNoButton.
  ///
  /// In en, this message translates to:
  /// **'Vote No'**
  String get daoVoteNoButton;

  /// No description provided for @daoProposalVotesYesLabel.
  ///
  /// In en, this message translates to:
  /// **'Yes: {count}'**
  String daoProposalVotesYesLabel(Object count);

  /// No description provided for @daoProposalVotesNoLabel.
  ///
  /// In en, this message translates to:
  /// **'No: {count}'**
  String daoProposalVotesNoLabel(Object count);

  /// No description provided for @daoProposalVotesAbstainLabel.
  ///
  /// In en, this message translates to:
  /// **'Abstain: {count}'**
  String daoProposalVotesAbstainLabel(Object count);

  /// No description provided for @daoVotingHistoryUnknownProposal.
  ///
  /// In en, this message translates to:
  /// **'Unknown Proposal'**
  String get daoVotingHistoryUnknownProposal;

  /// No description provided for @daoVoteChoiceYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get daoVoteChoiceYes;

  /// No description provided for @daoVoteChoiceNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get daoVoteChoiceNo;

  /// No description provided for @daoVoteChoiceAbstain.
  ///
  /// In en, this message translates to:
  /// **'Abstain'**
  String get daoVoteChoiceAbstain;

  /// No description provided for @daoVotingResultPassing.
  ///
  /// In en, this message translates to:
  /// **'Passing'**
  String get daoVotingResultPassing;

  /// No description provided for @daoVotingResultNotPassing.
  ///
  /// In en, this message translates to:
  /// **'Not Passing'**
  String get daoVotingResultNotPassing;

  /// No description provided for @daoVotingHistoryYourPowerLabel.
  ///
  /// In en, this message translates to:
  /// **'Your power: {power}'**
  String daoVotingHistoryYourPowerLabel(Object power);

  /// No description provided for @daoVotingHistoryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No voting history yet'**
  String get daoVotingHistoryEmptyTitle;

  /// No description provided for @daoVotingHistoryEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Cast your first vote on an active proposal'**
  String get daoVotingHistoryEmptyDescription;

  /// No description provided for @daoActiveProposalsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No active proposals'**
  String get daoActiveProposalsEmptyTitle;

  /// No description provided for @daoActiveProposalsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Submit a proposal or review to get governance moving.'**
  String get daoActiveProposalsEmptyDescription;

  /// No description provided for @daoTreasuryTitle.
  ///
  /// In en, this message translates to:
  /// **'DAO Treasury'**
  String get daoTreasuryTitle;

  /// No description provided for @daoTreasurySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Community-controlled funds for platform development'**
  String get daoTreasurySubtitle;

  /// No description provided for @daoTreasuryInflowLabel.
  ///
  /// In en, this message translates to:
  /// **'Inflow'**
  String get daoTreasuryInflowLabel;

  /// No description provided for @daoTreasuryOutflowLabel.
  ///
  /// In en, this message translates to:
  /// **'Outflow'**
  String get daoTreasuryOutflowLabel;

  /// No description provided for @daoTreasuryProposalsLabel.
  ///
  /// In en, this message translates to:
  /// **'Proposals'**
  String get daoTreasuryProposalsLabel;

  /// No description provided for @daoRecentTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get daoRecentTransactionsTitle;

  /// No description provided for @daoRecentTransactionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No recent transactions'**
  String get daoRecentTransactionsEmptyTitle;

  /// No description provided for @daoRecentTransactionsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **''**
  String get daoRecentTransactionsEmptyDescription;

  /// No description provided for @commonTimeAgoDays.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String commonTimeAgoDays(Object count);

  /// No description provided for @commonTimeAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String commonTimeAgoHours(Object count);

  /// No description provided for @commonTimeAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String commonTimeAgoMinutes(Object count);

  /// No description provided for @daoTreasuryProposalsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No treasury proposals yet'**
  String get daoTreasuryProposalsEmptyTitle;

  /// No description provided for @daoTreasuryProposalsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a treasury request to allocate KUB8 to initiatives.'**
  String get daoTreasuryProposalsEmptyDescription;

  /// No description provided for @daoTreasuryProposalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Treasury Proposals'**
  String get daoTreasuryProposalsTitle;

  /// No description provided for @daoCreateProposalButton.
  ///
  /// In en, this message translates to:
  /// **'Create proposal'**
  String get daoCreateProposalButton;

  /// No description provided for @daoVoteDelegationTitle.
  ///
  /// In en, this message translates to:
  /// **'Vote Delegation'**
  String get daoVoteDelegationTitle;

  /// No description provided for @daoVoteDelegationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delegate your voting power to trusted community members'**
  String get daoVoteDelegationSubtitle;

  /// No description provided for @daoTopDelegatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Top Delegates'**
  String get daoTopDelegatesTitle;

  /// No description provided for @daoTopDelegatesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No delegates yet'**
  String get daoTopDelegatesEmptyTitle;

  /// No description provided for @daoTopDelegatesEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'No delegates have been registered yet.'**
  String get daoTopDelegatesEmptyDescription;

  /// No description provided for @daoDelegateActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get daoDelegateActiveLabel;

  /// No description provided for @daoTapToDelegateHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to delegate'**
  String get daoTapToDelegateHint;

  /// No description provided for @daoDelegationActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Delegation Actions'**
  String get daoDelegationActionsTitle;

  /// No description provided for @daoDelegationActionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how to use your voting power'**
  String get daoDelegationActionsSubtitle;

  /// No description provided for @daoDelegateToTrustedMembersButton.
  ///
  /// In en, this message translates to:
  /// **'Delegate to Trusted Members'**
  String get daoDelegateToTrustedMembersButton;

  /// No description provided for @daoSelfDelegateButton.
  ///
  /// In en, this message translates to:
  /// **'Self Delegate'**
  String get daoSelfDelegateButton;

  /// No description provided for @daoRevokeButton.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get daoRevokeButton;

  /// No description provided for @daoDelegateVotingPowerDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delegate Voting Power'**
  String get daoDelegateVotingPowerDialogTitle;

  /// No description provided for @daoDelegateVotingPowerDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delegate your {votingPower} voting power to {delegateName}?'**
  String daoDelegateVotingPowerDialogBody(Object votingPower, Object delegateName);

  /// No description provided for @daoDelegationBenefitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Delegation Benefits'**
  String get daoDelegationBenefitsTitle;

  /// No description provided for @daoDelegationBenefitsBody.
  ///
  /// In en, this message translates to:
  /// **'• Your delegate will vote on your behalf\n• You can revoke delegation anytime\n• Your voting power remains yours'**
  String get daoDelegationBenefitsBody;

  /// No description provided for @daoConfirmDelegationButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delegation'**
  String get daoConfirmDelegationButton;

  /// No description provided for @daoDelegationSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Voting power successfully delegated to {delegateName}'**
  String daoDelegationSuccessToast(Object delegateName);

  /// No description provided for @daoViewDelegationDetailsAction.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get daoViewDelegationDetailsAction;

  /// No description provided for @daoDelegationActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Delegation Active'**
  String get daoDelegationActiveTitle;

  /// No description provided for @daoDelegationDetailDelegateLabel.
  ///
  /// In en, this message translates to:
  /// **'Delegate'**
  String get daoDelegationDetailDelegateLabel;

  /// No description provided for @daoDelegationDetailVotingPowerLabel.
  ///
  /// In en, this message translates to:
  /// **'Voting Power'**
  String get daoDelegationDetailVotingPowerLabel;

  /// No description provided for @daoDelegationDetailStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get daoDelegationDetailStatusLabel;

  /// No description provided for @daoDelegationDetailStartedLabel.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get daoDelegationDetailStartedLabel;

  /// No description provided for @daoDelegationStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get daoDelegationStatusActive;

  /// No description provided for @daoDelegationStartedJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get daoDelegationStartedJustNow;

  /// No description provided for @daoRevokeDelegationButton.
  ///
  /// In en, this message translates to:
  /// **'Revoke Delegation'**
  String get daoRevokeDelegationButton;

  /// No description provided for @daoDelegationRevokedToast.
  ///
  /// In en, this message translates to:
  /// **'Delegation revoked successfully'**
  String get daoDelegationRevokedToast;

  /// No description provided for @daoSelfDelegationEnabledToast.
  ///
  /// In en, this message translates to:
  /// **'Self-delegation enabled'**
  String get daoSelfDelegationEnabledToast;

  /// No description provided for @commonPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get commonPost;

  /// No description provided for @commonComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commonComments;

  /// No description provided for @commonLikes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get commonLikes;

  /// No description provided for @commonReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get commonReply;

  /// No description provided for @commonSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commonSend;

  /// No description provided for @commonYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get commonYou;

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknown;

  /// No description provided for @commonUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed'**
  String get commonUnnamed;

  /// No description provided for @commonOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get commonOwner;

  /// No description provided for @commonJoined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get commonJoined;

  /// No description provided for @commonJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get commonJoin;

  /// No description provided for @commonPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get commonPublic;

  /// No description provided for @commonPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get commonPrivate;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String commonMembersCount(num count);

  /// No description provided for @commonCommentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 comment} other{{count} comments}}'**
  String commonCommentsCount(num count);

  /// No description provided for @commonDistanceKmAway.
  ///
  /// In en, this message translates to:
  /// **'{value} km away'**
  String commonDistanceKmAway(Object value);

  /// No description provided for @commonTimeAgoWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count}w ago'**
  String commonTimeAgoWeeks(Object count);

  /// No description provided for @commonTimeAgoJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get commonTimeAgoJustNow;

  /// No description provided for @presenceOnlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get presenceOnlineLabel;

  /// No description provided for @presenceLastSeenLabel.
  ///
  /// In en, this message translates to:
  /// **'Last seen {timeAgo}'**
  String presenceLastSeenLabel(Object timeAgo);

  /// No description provided for @presenceLastSeenAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Last seen at {location}'**
  String presenceLastSeenAtLabel(Object location);

  /// No description provided for @postDetailLoadPostFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load post.'**
  String get postDetailLoadPostFailedMessage;

  /// No description provided for @postDetailMoreOptionsReportAction.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get postDetailMoreOptionsReportAction;

  /// No description provided for @postDetailReportPostDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Report post'**
  String get postDetailReportPostDialogTitle;

  /// No description provided for @postDetailReportPostDialogQuestion.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this post?'**
  String get postDetailReportPostDialogQuestion;

  /// No description provided for @postDetailEditPostTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit post'**
  String get postDetailEditPostTitle;

  /// No description provided for @postDetailPostUpdatedToast.
  ///
  /// In en, this message translates to:
  /// **'Post updated'**
  String get postDetailPostUpdatedToast;

  /// No description provided for @postDetailUpdatePostFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to update post.'**
  String get postDetailUpdatePostFailedToast;

  /// No description provided for @postDetailDeletePostTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete post'**
  String get postDetailDeletePostTitle;

  /// No description provided for @postDetailDeletePostBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this post? This action cannot be undone.'**
  String get postDetailDeletePostBody;

  /// No description provided for @postDetailPostDeletedToast.
  ///
  /// In en, this message translates to:
  /// **'Post deleted'**
  String get postDetailPostDeletedToast;

  /// No description provided for @postDetailDeletePostFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete post.'**
  String get postDetailDeletePostFailedToast;

  /// No description provided for @postDetailPostLikedToast.
  ///
  /// In en, this message translates to:
  /// **'Post liked'**
  String get postDetailPostLikedToast;

  /// No description provided for @postDetailLikeRemovedToast.
  ///
  /// In en, this message translates to:
  /// **'Like removed'**
  String get postDetailLikeRemovedToast;

  /// No description provided for @postDetailUndoLikeFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to undo like.'**
  String get postDetailUndoLikeFailedToast;

  /// No description provided for @postDetailUpdateLikeFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to update like.'**
  String get postDetailUpdateLikeFailedToast;

  /// No description provided for @postDetailRetryLikeFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Retry failed.'**
  String get postDetailRetryLikeFailedToast;

  /// No description provided for @postDetailCommentAddedToast.
  ///
  /// In en, this message translates to:
  /// **'Comment added'**
  String get postDetailCommentAddedToast;

  /// No description provided for @postDetailAddCommentFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to add comment.'**
  String get postDetailAddCommentFailedToast;

  /// No description provided for @postDetailUpdateCommentLikeFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to update like.'**
  String get postDetailUpdateCommentLikeFailedToast;

  /// No description provided for @postDetailLoadLikesFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load likes.'**
  String get postDetailLoadLikesFailedMessage;

  /// No description provided for @postDetailNoLikesTitle.
  ///
  /// In en, this message translates to:
  /// **'No likes yet'**
  String get postDetailNoLikesTitle;

  /// No description provided for @postDetailNoLikesDescription.
  ///
  /// In en, this message translates to:
  /// **'Be the first to like this'**
  String get postDetailNoLikesDescription;

  /// No description provided for @postDetailSharePostTitle.
  ///
  /// In en, this message translates to:
  /// **'Share post'**
  String get postDetailSharePostTitle;

  /// No description provided for @postDetailSearchProfilesHint.
  ///
  /// In en, this message translates to:
  /// **'Search for profiles…'**
  String get postDetailSearchProfilesHint;

  /// No description provided for @postDetailCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get postDetailCopyLink;

  /// No description provided for @postDetailLinkCopiedToast.
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard'**
  String get postDetailLinkCopiedToast;

  /// No description provided for @postDetailShareViaEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Share via…'**
  String get postDetailShareViaEllipsis;

  /// No description provided for @postDetailNoProfilesFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'No profiles found'**
  String get postDetailNoProfilesFoundTitle;

  /// No description provided for @postDetailNoProfilesFoundDescription.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get postDetailNoProfilesFoundDescription;

  /// No description provided for @postDetailShareDmDefaultMessage.
  ///
  /// In en, this message translates to:
  /// **'Check out this post!'**
  String get postDetailShareDmDefaultMessage;

  /// No description provided for @postDetailShareSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Shared post with @{username}'**
  String postDetailShareSuccessToast(Object username);

  /// No description provided for @postDetailShareFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to share.'**
  String get postDetailShareFailedToast;

  /// No description provided for @postDetailRepostTitle.
  ///
  /// In en, this message translates to:
  /// **'Repost'**
  String get postDetailRepostTitle;

  /// No description provided for @postDetailRepostButton.
  ///
  /// In en, this message translates to:
  /// **'Repost'**
  String get postDetailRepostButton;

  /// No description provided for @postDetailRepostSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Reposted!'**
  String get postDetailRepostSuccessToast;

  /// No description provided for @postDetailRepostWithCommentSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Reposted with comment!'**
  String get postDetailRepostWithCommentSuccessToast;

  /// No description provided for @postDetailRepostFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to repost.'**
  String get postDetailRepostFailedToast;

  /// No description provided for @postDetailRepostThoughtsHint.
  ///
  /// In en, this message translates to:
  /// **'Add your thoughts (optional)…'**
  String get postDetailRepostThoughtsHint;

  /// No description provided for @postDetailRepostingLabel.
  ///
  /// In en, this message translates to:
  /// **'Reposting:'**
  String get postDetailRepostingLabel;

  /// No description provided for @postDetailNoCommentsTitle.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get postDetailNoCommentsTitle;

  /// No description provided for @postDetailNoCommentsDescription.
  ///
  /// In en, this message translates to:
  /// **'Be the first to start the conversation'**
  String get postDetailNoCommentsDescription;

  /// No description provided for @postDetailReplyingToLabel.
  ///
  /// In en, this message translates to:
  /// **'Replying to {author}'**
  String postDetailReplyingToLabel(Object author);

  /// No description provided for @postDetailWriteCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Write a comment…'**
  String get postDetailWriteCommentHint;

  /// No description provided for @postDetailLinkedArtworkLabel.
  ///
  /// In en, this message translates to:
  /// **'Linked artwork'**
  String get postDetailLinkedArtworkLabel;

  /// No description provided for @postDetailOriginalUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Original post is no longer available'**
  String get postDetailOriginalUnavailableMessage;

  /// No description provided for @communityGroupsRefreshFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh groups.'**
  String get communityGroupsRefreshFailedToast;

  /// No description provided for @communityGroupMembershipUpdateFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Could not update group membership.'**
  String get communityGroupMembershipUpdateFailedToast;

  /// No description provided for @communityGroupNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description provided.'**
  String get communityGroupNoDescription;

  /// No description provided for @communityGroupLatestPostLabel.
  ///
  /// In en, this message translates to:
  /// **'Latest post'**
  String get communityGroupLatestPostLabel;

  /// No description provided for @communityOpenGroupFeedButton.
  ///
  /// In en, this message translates to:
  /// **'Open group feed'**
  String get communityOpenGroupFeedButton;

  /// No description provided for @communityLocationEnableServicesToast.
  ///
  /// In en, this message translates to:
  /// **'Enable location services to attach your location.'**
  String get communityLocationEnableServicesToast;

  /// No description provided for @communityLocationPermissionRequiredToast.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required.'**
  String get communityLocationPermissionRequiredToast;

  /// No description provided for @communityLocationUnableToDetermineToast.
  ///
  /// In en, this message translates to:
  /// **'Unable to determine your location.'**
  String get communityLocationUnableToDetermineToast;

  /// No description provided for @communityLocationUnableToAccessToast.
  ///
  /// In en, this message translates to:
  /// **'Unable to access your location.'**
  String get communityLocationUnableToAccessToast;

  /// No description provided for @communityArtFeedLocationPermissionRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required for the art feed.'**
  String get communityArtFeedLocationPermissionRequiredError;

  /// No description provided for @communityArtFeedLoadFailedError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the art feed.'**
  String get communityArtFeedLoadFailedError;

  /// No description provided for @communityArtFeedLoadFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the art feed right now.'**
  String get communityArtFeedLoadFailedToast;

  /// No description provided for @communityFollowingFeedUnavailableToast.
  ///
  /// In en, this message translates to:
  /// **'Following feed is unavailable. Please try again later.'**
  String get communityFollowingFeedUnavailableToast;

  /// No description provided for @communityDiscoverFeedUnavailableToast.
  ///
  /// In en, this message translates to:
  /// **'Discover feed is unavailable. Please try again later.'**
  String get communityDiscoverFeedUnavailableToast;

  /// No description provided for @communityScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get communityScreenTitle;

  /// No description provided for @communityFollowingTab.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get communityFollowingTab;

  /// No description provided for @communityDiscoverTab.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get communityDiscoverTab;

  /// No description provided for @communityGroupsTab.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get communityGroupsTab;

  /// No description provided for @communityArtTab.
  ///
  /// In en, this message translates to:
  /// **'Art'**
  String get communityArtTab;

  /// No description provided for @communityFeedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get communityFeedEmptyTitle;

  /// No description provided for @communityFeedEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Follow creators to see their updates here.'**
  String get communityFeedEmptyDescription;

  /// No description provided for @communityDiscoverEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to discover yet'**
  String get communityDiscoverEmptyTitle;

  /// No description provided for @communityDiscoverEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Check back soon for new posts.'**
  String get communityDiscoverEmptyDescription;

  /// No description provided for @communityNewPostsBanner.
  ///
  /// In en, this message translates to:
  /// **'Show {count, plural, =1{1 new post} other{{count} new posts}}'**
  String communityNewPostsBanner(num count);

  /// No description provided for @communityGroupsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No groups yet'**
  String get communityGroupsEmptyTitle;

  /// No description provided for @communityGroupsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a group or join one to start collaborating.'**
  String get communityGroupsEmptyDescription;

  /// No description provided for @communityGroupsEmptySearchDescription.
  ///
  /// In en, this message translates to:
  /// **'No groups found for \"{query}\".'**
  String communityGroupsEmptySearchDescription(Object query);

  /// No description provided for @communityGroupsEndOfDirectory.
  ///
  /// In en, this message translates to:
  /// **'End of directory'**
  String get communityGroupsEndOfDirectory;

  /// No description provided for @communityGroupsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search community groups'**
  String get communityGroupsSearchHint;

  /// No description provided for @communityClearSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get communityClearSearchTooltip;

  /// No description provided for @communityFabNewPost.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get communityFabNewPost;

  /// No description provided for @communityFabCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get communityFabCreateGroup;

  /// No description provided for @communityFabGroupPost.
  ///
  /// In en, this message translates to:
  /// **'Group post'**
  String get communityFabGroupPost;

  /// No description provided for @communityFabArtDrop.
  ///
  /// In en, this message translates to:
  /// **'Art drop'**
  String get communityFabArtDrop;

  /// No description provided for @communityFabPostReview.
  ///
  /// In en, this message translates to:
  /// **'Post review'**
  String get communityFabPostReview;

  /// No description provided for @communityCreateGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get communityCreateGroupTitle;

  /// No description provided for @communityCreateGroupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Group Name'**
  String get communityCreateGroupNameLabel;

  /// No description provided for @communityCreateGroupNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Ljubljana creators'**
  String get communityCreateGroupNameHint;

  /// No description provided for @communityCreateGroupDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get communityCreateGroupDescriptionLabel;

  /// No description provided for @communityCreateGroupDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'What is this group about?'**
  String get communityCreateGroupDescriptionHint;

  /// No description provided for @communityCreateGroupPublicLabel.
  ///
  /// In en, this message translates to:
  /// **'Public Group'**
  String get communityCreateGroupPublicLabel;

  /// No description provided for @communityCreateGroupPublicHint.
  ///
  /// In en, this message translates to:
  /// **'Anyone can join and see posts.'**
  String get communityCreateGroupPublicHint;

  /// No description provided for @communityCreateGroupPrivateHint.
  ///
  /// In en, this message translates to:
  /// **'Members join by invitation.'**
  String get communityCreateGroupPrivateHint;

  /// No description provided for @communityCreateGroupButton.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get communityCreateGroupButton;

  /// No description provided for @communityCreateGroupFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Unable to create group right now.'**
  String get communityCreateGroupFailedToast;

  /// No description provided for @communityGroupCreatedToast.
  ///
  /// In en, this message translates to:
  /// **'Group \"{name}\" created.'**
  String communityGroupCreatedToast(Object name);

  /// No description provided for @communityViewPostButton.
  ///
  /// In en, this message translates to:
  /// **'View post'**
  String get communityViewPostButton;

  /// No description provided for @communitySearchTypeProfiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get communitySearchTypeProfiles;

  /// No description provided for @communitySearchTypeArtworks.
  ///
  /// In en, this message translates to:
  /// **'Artworks'**
  String get communitySearchTypeArtworks;

  /// No description provided for @communitySearchTypeInstitutions.
  ///
  /// In en, this message translates to:
  /// **'Institutions'**
  String get communitySearchTypeInstitutions;

  /// No description provided for @communitySearchTypeScreens.
  ///
  /// In en, this message translates to:
  /// **'Screens'**
  String get communitySearchTypeScreens;

  /// No description provided for @communitySearchTypePosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get communitySearchTypePosts;

  /// No description provided for @communitySearchHintProfiles.
  ///
  /// In en, this message translates to:
  /// **'Search people…'**
  String get communitySearchHintProfiles;

  /// No description provided for @communitySearchHintArtworks.
  ///
  /// In en, this message translates to:
  /// **'Search artworks…'**
  String get communitySearchHintArtworks;

  /// No description provided for @communitySearchHintInstitutions.
  ///
  /// In en, this message translates to:
  /// **'Search institutions…'**
  String get communitySearchHintInstitutions;

  /// No description provided for @communitySearchHintScreens.
  ///
  /// In en, this message translates to:
  /// **'Search screens…'**
  String get communitySearchHintScreens;

  /// No description provided for @communitySearchHintPosts.
  ///
  /// In en, this message translates to:
  /// **'Search posts…'**
  String get communitySearchHintPosts;

  /// No description provided for @communitySearchEmptyStartTyping.
  ///
  /// In en, this message translates to:
  /// **'Start typing to search'**
  String get communitySearchEmptyStartTyping;

  /// No description provided for @communitySearchEmptyNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get communitySearchEmptyNoResults;

  /// No description provided for @communitySearchSheetHintTags.
  ///
  /// In en, this message translates to:
  /// **'Search tags…'**
  String get communitySearchSheetHintTags;

  /// No description provided for @communitySearchSheetHintProfiles.
  ///
  /// In en, this message translates to:
  /// **'Search users by name or @handle…'**
  String get communitySearchSheetHintProfiles;

  /// No description provided for @communitySearchSheetHintArtworks.
  ///
  /// In en, this message translates to:
  /// **'Search artworks…'**
  String get communitySearchSheetHintArtworks;

  /// No description provided for @communitySearchSheetHintDefault.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get communitySearchSheetHintDefault;

  /// No description provided for @communityComposerTitle.
  ///
  /// In en, this message translates to:
  /// **'Compose'**
  String get communityComposerTitle;

  /// No description provided for @communityComposerTextHint.
  ///
  /// In en, this message translates to:
  /// **'Share what you’re building, discovering, or activating…'**
  String get communityComposerTextHint;

  /// No description provided for @communityComposerTargetGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Target group'**
  String get communityComposerTargetGroupLabel;

  /// No description provided for @communityComposerGroupOptionalHelper.
  ///
  /// In en, this message translates to:
  /// **'Optional • Join a group to unlock curator chats.'**
  String get communityComposerGroupOptionalHelper;

  /// No description provided for @communityComposerPostingInGroupHelper.
  ///
  /// In en, this message translates to:
  /// **'Posting in {groupName}. Tap to change or clear.'**
  String communityComposerPostingInGroupHelper(Object groupName);

  /// No description provided for @communityComposerRemoveGroupTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove group'**
  String get communityComposerRemoveGroupTooltip;

  /// No description provided for @communityComposerLinkArtworkTitle.
  ///
  /// In en, this message translates to:
  /// **'Link artwork'**
  String get communityComposerLinkArtworkTitle;

  /// No description provided for @communityComposerLinkArtworkDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose an artwork to attach to your post.'**
  String get communityComposerLinkArtworkDescription;

  /// No description provided for @communityComposerArtworkAttachedDescription.
  ///
  /// In en, this message translates to:
  /// **'Attached artwork: {title}'**
  String communityComposerArtworkAttachedDescription(Object title);

  /// No description provided for @communityComposerRemoveArtworkTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove artwork'**
  String get communityComposerRemoveArtworkTooltip;

  /// No description provided for @communityComposerAttachCurrentLocationButton.
  ///
  /// In en, this message translates to:
  /// **'Attach current location'**
  String get communityComposerAttachCurrentLocationButton;

  /// No description provided for @communityComposerAttachedLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Attached location'**
  String get communityComposerAttachedLocationLabel;

  /// No description provided for @communityComposerRemoveLocationTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove location'**
  String get communityComposerRemoveLocationTooltip;

  /// No description provided for @communityBookmarkAddedToast.
  ///
  /// In en, this message translates to:
  /// **'Post bookmarked!'**
  String get communityBookmarkAddedToast;

  /// No description provided for @communityBookmarkRemovedToast.
  ///
  /// In en, this message translates to:
  /// **'Bookmark removed!'**
  String get communityBookmarkRemovedToast;

  /// No description provided for @communityBookmarkUpdateFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Could not update bookmark.'**
  String get communityBookmarkUpdateFailedToast;

  /// No description provided for @communityComposerCategoryPostLabel.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get communityComposerCategoryPostLabel;

  /// No description provided for @communityComposerCategoryPostDescription.
  ///
  /// In en, this message translates to:
  /// **'Share an update with the community'**
  String get communityComposerCategoryPostDescription;

  /// No description provided for @communityComposerCategoryArtDropLabel.
  ///
  /// In en, this message translates to:
  /// **'Art drop'**
  String get communityComposerCategoryArtDropLabel;

  /// No description provided for @communityComposerCategoryArtDropDescription.
  ///
  /// In en, this message translates to:
  /// **'Share a new artwork or collection'**
  String get communityComposerCategoryArtDropDescription;

  /// No description provided for @communityComposerCategoryArtReviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Art review'**
  String get communityComposerCategoryArtReviewLabel;

  /// No description provided for @communityComposerCategoryArtReviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Share a review or critique'**
  String get communityComposerCategoryArtReviewDescription;

  /// No description provided for @communityComposerCategoryEventLabel.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get communityComposerCategoryEventLabel;

  /// No description provided for @communityComposerCategoryEventDescription.
  ///
  /// In en, this message translates to:
  /// **'Announce a meetup or event'**
  String get communityComposerCategoryEventDescription;

  /// No description provided for @communityComposerCategoryQuestionLabel.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get communityComposerCategoryQuestionLabel;

  /// No description provided for @communityComposerCategoryQuestionDescription.
  ///
  /// In en, this message translates to:
  /// **'Ask the community'**
  String get communityComposerCategoryQuestionDescription;

  /// No description provided for @communityGroupFeedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No posts in this group yet'**
  String get communityGroupFeedEmptyTitle;

  /// No description provided for @communityGroupFeedEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Be the first to start the conversation.'**
  String get communityGroupFeedEmptyDescription;

  /// No description provided for @communityGroupFeedShareText.
  ///
  /// In en, this message translates to:
  /// **'Check out {authorName}\'s post in {groupName} on art.kubus.'**
  String communityGroupFeedShareText(Object authorName, Object groupName);

  /// No description provided for @communityArtFeedHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Art feed'**
  String get communityArtFeedHeaderTitle;

  /// No description provided for @communityArtFeedRadiusSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Radius: {radius}'**
  String communityArtFeedRadiusSubtitle(Object radius);

  /// No description provided for @communityArtFeedCenterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Center: {lat}, {lng}'**
  String communityArtFeedCenterSubtitle(Object lat, Object lng);

  /// No description provided for @communityArtFeedEnablePreciseLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Enable precise location for better results.'**
  String get communityArtFeedEnablePreciseLocationHint;

  /// No description provided for @communityArtFeedLocationNeededTitle.
  ///
  /// In en, this message translates to:
  /// **'Location needed'**
  String get communityArtFeedLocationNeededTitle;

  /// No description provided for @communityArtFeedLocationNeededDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable location to see activations near you.'**
  String get communityArtFeedLocationNeededDescription;

  /// No description provided for @communityArtFeedNoNearbyActivationsTitle.
  ///
  /// In en, this message translates to:
  /// **'No nearby activations'**
  String get communityArtFeedNoNearbyActivationsTitle;

  /// No description provided for @communityArtFeedNoNearbyActivationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Try refreshing your location or increasing the radius.'**
  String get communityArtFeedNoNearbyActivationsDescription;

  /// No description provided for @communityArtFeedRefreshLocationButton.
  ///
  /// In en, this message translates to:
  /// **'Refresh location'**
  String get communityArtFeedRefreshLocationButton;

  /// No description provided for @communityArtFeedAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About the art feed'**
  String get communityArtFeedAboutTitle;

  /// No description provided for @communityArtFeedAboutBody.
  ///
  /// In en, this message translates to:
  /// **'The art feed shows location-based activations shared by the community near you.'**
  String get communityArtFeedAboutBody;

  /// No description provided for @communityArtFeedAboutButton.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get communityArtFeedAboutButton;

  /// No description provided for @communityArtFeedShareText.
  ///
  /// In en, this message translates to:
  /// **'Check out {authorName}\'s activation on art.kubus.'**
  String communityArtFeedShareText(Object authorName);

  /// No description provided for @communityNameThisPlaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Name this place'**
  String get communityNameThisPlaceTitle;

  /// No description provided for @communityNamePlaceHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. City park'**
  String get communityNamePlaceHint;

  /// No description provided for @communityConnectWalletFirstToast.
  ///
  /// In en, this message translates to:
  /// **'Please connect your wallet first.'**
  String get communityConnectWalletFirstToast;

  /// No description provided for @communityUnableToAuthenticateToast.
  ///
  /// In en, this message translates to:
  /// **'Unable to authenticate. Please try again.'**
  String get communityUnableToAuthenticateToast;

  /// No description provided for @communityComposerAddContentToast.
  ///
  /// In en, this message translates to:
  /// **'Add text, an image, or a video.'**
  String get communityComposerAddContentToast;

  /// No description provided for @communityComposerSharedInGroupToast.
  ///
  /// In en, this message translates to:
  /// **'Posted in {groupName}'**
  String communityComposerSharedInGroupToast(Object groupName);

  /// No description provided for @communityGroupFallbackName.
  ///
  /// In en, this message translates to:
  /// **'this group'**
  String get communityGroupFallbackName;

  /// No description provided for @communityComposerPostCreatedToast.
  ///
  /// In en, this message translates to:
  /// **'Post created'**
  String get communityComposerPostCreatedToast;

  /// No description provided for @communityComposerCreatePostFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to create post.'**
  String get communityComposerCreatePostFailedToast;

  /// No description provided for @communityToggleLikeFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to update like.'**
  String get communityToggleLikeFailedToast;

  /// No description provided for @communityPostLikesTitle.
  ///
  /// In en, this message translates to:
  /// **'Post likes'**
  String get communityPostLikesTitle;

  /// No description provided for @communityCommentLikesTitle.
  ///
  /// In en, this message translates to:
  /// **'Comment likes'**
  String get communityCommentLikesTitle;

  /// No description provided for @communityReplyingToCommentLabel.
  ///
  /// In en, this message translates to:
  /// **'Replying…'**
  String get communityReplyingToCommentLabel;

  /// No description provided for @communityCommentAuthRequiredToast.
  ///
  /// In en, this message translates to:
  /// **'Sign in to comment.'**
  String get communityCommentAuthRequiredToast;

  /// No description provided for @communityRepostedByTitle.
  ///
  /// In en, this message translates to:
  /// **'Reposted by'**
  String get communityRepostedByTitle;

  /// No description provided for @communityRepostsLoadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load reposts.'**
  String get communityRepostsLoadFailedMessage;

  /// No description provided for @communityNoRepostsTitle.
  ///
  /// In en, this message translates to:
  /// **'No reposts yet'**
  String get communityNoRepostsTitle;

  /// No description provided for @communityNoRepostsDescription.
  ///
  /// In en, this message translates to:
  /// **'Be the first to repost this'**
  String get communityNoRepostsDescription;

  /// No description provided for @communityUnrepostAction.
  ///
  /// In en, this message translates to:
  /// **'Unrepost'**
  String get communityUnrepostAction;

  /// No description provided for @communityUnrepostTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove repost?'**
  String get communityUnrepostTitle;

  /// No description provided for @communityUnrepostConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Remove your repost of this post?'**
  String get communityUnrepostConfirmBody;

  /// No description provided for @communityRepostRemovedToast.
  ///
  /// In en, this message translates to:
  /// **'Repost removed'**
  String get communityRepostRemovedToast;

  /// No description provided for @communityUnrepostFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove repost.'**
  String get communityUnrepostFailedToast;

  /// No description provided for @commonSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get commonSomethingWentWrong;

  /// No description provided for @commonGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get commonGreetingMorning;

  /// No description provided for @commonGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get commonGreetingAfternoon;

  /// No description provided for @commonGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get commonGreetingEvening;

  /// No description provided for @commonWeekdayMonShort.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get commonWeekdayMonShort;

  /// No description provided for @commonWeekdayTueShort.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get commonWeekdayTueShort;

  /// No description provided for @commonWeekdayWedShort.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get commonWeekdayWedShort;

  /// No description provided for @commonWeekdayThuShort.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get commonWeekdayThuShort;

  /// No description provided for @commonWeekdayFriShort.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get commonWeekdayFriShort;

  /// No description provided for @commonWeekdaySatShort.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get commonWeekdaySatShort;

  /// No description provided for @commonWeekdaySunShort.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get commonWeekdaySunShort;

  /// No description provided for @commonIosLabel.
  ///
  /// In en, this message translates to:
  /// **'iOS'**
  String get commonIosLabel;

  /// No description provided for @commonAndroidLabel.
  ///
  /// In en, this message translates to:
  /// **'Android'**
  String get commonAndroidLabel;

  /// No description provided for @downloadAppCouldNotOpenStoreToast.
  ///
  /// In en, this message translates to:
  /// **'Could not open the store. Please visit: {url}'**
  String downloadAppCouldNotOpenStoreToast(Object url);

  /// No description provided for @downloadAppDefaultFeatureName.
  ///
  /// In en, this message translates to:
  /// **'AR Features'**
  String get downloadAppDefaultFeatureName;

  /// No description provided for @downloadAppExperienceInArTitle.
  ///
  /// In en, this message translates to:
  /// **'Experience {featureName} in AR'**
  String downloadAppExperienceInArTitle(Object featureName);

  /// No description provided for @downloadAppDefaultDescription.
  ///
  /// In en, this message translates to:
  /// **'For the best AR experience, use the mobile app.'**
  String get downloadAppDefaultDescription;

  /// No description provided for @downloadAppFeatureViewInAr.
  ///
  /// In en, this message translates to:
  /// **'View artworks in AR'**
  String get downloadAppFeatureViewInAr;

  /// No description provided for @downloadAppFeatureScanArtworks.
  ///
  /// In en, this message translates to:
  /// **'Scan artworks'**
  String get downloadAppFeatureScanArtworks;

  /// No description provided for @downloadAppFeatureInteractive3d.
  ///
  /// In en, this message translates to:
  /// **'Interactive 3D models'**
  String get downloadAppFeatureInteractive3d;

  /// No description provided for @downloadAppFeatureLocationDiscovery.
  ///
  /// In en, this message translates to:
  /// **'Location-based discovery'**
  String get downloadAppFeatureLocationDiscovery;

  /// No description provided for @downloadAppDownloadForLabel.
  ///
  /// In en, this message translates to:
  /// **'Download for:'**
  String get downloadAppDownloadForLabel;

  /// No description provided for @downloadAppScanQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get downloadAppScanQrTitle;

  /// No description provided for @downloadAppScanQrSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open this page on your phone to download the app.'**
  String get downloadAppScanQrSubtitle;

  /// No description provided for @downloadAppContinueBrowsingButton.
  ///
  /// In en, this message translates to:
  /// **'Continue browsing'**
  String get downloadAppContinueBrowsingButton;

  /// No description provided for @homeDefaultDisplayName.
  ///
  /// In en, this message translates to:
  /// **'there'**
  String get homeDefaultDisplayName;

  /// No description provided for @homeWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ready to discover new art today?'**
  String get homeWelcomeSubtitle;

  /// No description provided for @homeExploreWeb3Button.
  ///
  /// In en, this message translates to:
  /// **'Explore Web3'**
  String get homeExploreWeb3Button;

  /// No description provided for @homeQuickActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get homeQuickActionsTitle;

  /// No description provided for @homeRecentlyUsedLabel.
  ///
  /// In en, this message translates to:
  /// **'Recently Used'**
  String get homeRecentlyUsedLabel;

  /// No description provided for @homeQuickActionsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Your shortcuts will appear here as you use the app.'**
  String get homeQuickActionsEmptyDescription;

  /// No description provided for @homeYourStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Stats'**
  String get homeYourStatsTitle;

  /// No description provided for @homeNoStatsAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'No stats yet'**
  String get homeNoStatsAvailableTitle;

  /// No description provided for @homeNoStatsAvailableDescription.
  ///
  /// In en, this message translates to:
  /// **'Check back later for your activity stats.'**
  String get homeNoStatsAvailableDescription;

  /// No description provided for @homeStatArtworks.
  ///
  /// In en, this message translates to:
  /// **'Artworks'**
  String get homeStatArtworks;

  /// No description provided for @homeStatFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get homeStatFollowers;

  /// No description provided for @homeStatViews.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get homeStatViews;

  /// No description provided for @homeStatsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'{statName} Details'**
  String homeStatsDialogTitle(Object statName);

  /// No description provided for @homeStatsTrendTitle.
  ///
  /// In en, this message translates to:
  /// **'{statName} Trend'**
  String homeStatsTrendTitle(Object statName);

  /// No description provided for @homeViewAdvancedButton.
  ///
  /// In en, this message translates to:
  /// **'View Advanced'**
  String get homeViewAdvancedButton;

  /// No description provided for @homeRecentMilestonesTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Milestones'**
  String get homeRecentMilestonesTitle;

  /// No description provided for @homeStatsNoMilestonesYet.
  ///
  /// In en, this message translates to:
  /// **'No milestones yet'**
  String get homeStatsNoMilestonesYet;

  /// No description provided for @homeStatsMilestoneArtworks1.
  ///
  /// In en, this message translates to:
  /// **'1st artwork created'**
  String get homeStatsMilestoneArtworks1;

  /// No description provided for @homeStatsMilestoneArtworks2.
  ///
  /// In en, this message translates to:
  /// **'5 artworks created'**
  String get homeStatsMilestoneArtworks2;

  /// No description provided for @homeStatsMilestoneArtworks3.
  ///
  /// In en, this message translates to:
  /// **'10 artworks created'**
  String get homeStatsMilestoneArtworks3;

  /// No description provided for @homeStatsMilestoneFollowers1.
  ///
  /// In en, this message translates to:
  /// **'First follower'**
  String get homeStatsMilestoneFollowers1;

  /// No description provided for @homeStatsMilestoneFollowers2.
  ///
  /// In en, this message translates to:
  /// **'10 followers'**
  String get homeStatsMilestoneFollowers2;

  /// No description provided for @homeStatsMilestoneFollowers3.
  ///
  /// In en, this message translates to:
  /// **'50 followers'**
  String get homeStatsMilestoneFollowers3;

  /// No description provided for @homeStatsMilestoneViews1.
  ///
  /// In en, this message translates to:
  /// **'100 views'**
  String get homeStatsMilestoneViews1;

  /// No description provided for @homeStatsMilestoneViews2.
  ///
  /// In en, this message translates to:
  /// **'500 views'**
  String get homeStatsMilestoneViews2;

  /// No description provided for @homeStatsMilestoneViews3.
  ///
  /// In en, this message translates to:
  /// **'1,000 views'**
  String get homeStatsMilestoneViews3;

  /// No description provided for @homeRecentActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get homeRecentActivityTitle;

  /// No description provided for @homeNoRecentActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'No recent activity'**
  String get homeNoRecentActivityTitle;

  /// No description provided for @homeNoRecentActivityDescription.
  ///
  /// In en, this message translates to:
  /// **'Your recent actions will show up here.'**
  String get homeNoRecentActivityDescription;

  /// No description provided for @homeUnableToLoadActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Unable to load activity'**
  String get homeUnableToLoadActivityTitle;

  /// No description provided for @homeFeaturedArtworksTitle.
  ///
  /// In en, this message translates to:
  /// **'Featured Artworks'**
  String get homeFeaturedArtworksTitle;

  /// No description provided for @homeNoFeaturedArtworksTitle.
  ///
  /// In en, this message translates to:
  /// **'No featured artworks'**
  String get homeNoFeaturedArtworksTitle;

  /// No description provided for @homeNoFeaturedArtworksDescription.
  ///
  /// In en, this message translates to:
  /// **'Check back soon for curated picks.'**
  String get homeNoFeaturedArtworksDescription;

  /// No description provided for @homeActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get homeActivityTitle;

  /// No description provided for @homeMarkAllReadButton.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get homeMarkAllReadButton;

  /// No description provided for @homeUnableToLoadNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Unable to load notifications'**
  String get homeUnableToLoadNotificationsTitle;

  /// No description provided for @homeNoNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get homeNoNotificationsTitle;

  /// No description provided for @homeAllCaughtUpDescription.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up.'**
  String get homeAllCaughtUpDescription;

  /// No description provided for @homeMockNotificationNewArtworkTitle.
  ///
  /// In en, this message translates to:
  /// **'New artwork added'**
  String get homeMockNotificationNewArtworkTitle;

  /// No description provided for @homeMockNotificationNewArtworkBody.
  ///
  /// In en, this message translates to:
  /// **'A new piece has been added to the gallery.'**
  String get homeMockNotificationNewArtworkBody;

  /// No description provided for @homeMockNotificationCommunityTitle.
  ///
  /// In en, this message translates to:
  /// **'Community update'**
  String get homeMockNotificationCommunityTitle;

  /// No description provided for @homeMockNotificationCommunityBody.
  ///
  /// In en, this message translates to:
  /// **'New posts are waiting in the community.'**
  String get homeMockNotificationCommunityBody;

  /// No description provided for @homeMockNotificationRewardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Rewards available'**
  String get homeMockNotificationRewardsTitle;

  /// No description provided for @homeMockNotificationRewardsBody.
  ///
  /// In en, this message translates to:
  /// **'You have new rewards ready to claim.'**
  String get homeMockNotificationRewardsBody;

  /// No description provided for @commonExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get commonExplore;

  /// No description provided for @commonNoSuggestions.
  ///
  /// In en, this message translates to:
  /// **'No suggestions'**
  String get commonNoSuggestions;

  /// No description provided for @commonArShort.
  ///
  /// In en, this message translates to:
  /// **'AR'**
  String get commonArShort;

  /// No description provided for @desktopHomeWelcomeFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Welcome to art.kubus'**
  String get desktopHomeWelcomeFallbackName;

  /// No description provided for @desktopHomeDiscoverArtTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover Art Around You'**
  String get desktopHomeDiscoverArtTitle;

  /// No description provided for @desktopHomeDiscoverArtDescription.
  ///
  /// In en, this message translates to:
  /// **'Explore immersive augmented reality artworks, connect with creators, and earn KUB8 tokens for discovering art.'**
  String get desktopHomeDiscoverArtDescription;

  /// No description provided for @desktopHomeYourActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Activity'**
  String get desktopHomeYourActivityTitle;

  /// No description provided for @desktopHomeYourActivitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track your progress and engagement'**
  String get desktopHomeYourActivitySubtitle;

  /// No description provided for @desktopHomeStatArtworksDiscovered.
  ///
  /// In en, this message translates to:
  /// **'Artworks Discovered'**
  String get desktopHomeStatArtworksDiscovered;

  /// No description provided for @desktopHomeStatArSessions.
  ///
  /// In en, this message translates to:
  /// **'AR Sessions'**
  String get desktopHomeStatArSessions;

  /// No description provided for @desktopHomeStatNftsCollected.
  ///
  /// In en, this message translates to:
  /// **'NFTs Collected'**
  String get desktopHomeStatNftsCollected;

  /// No description provided for @desktopHomeStatKub8Earned.
  ///
  /// In en, this message translates to:
  /// **'KUB8 Earned'**
  String get desktopHomeStatKub8Earned;

  /// No description provided for @desktopHomeQuickActionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Based on your recent visits'**
  String get desktopHomeQuickActionsSubtitle;

  /// No description provided for @desktopHomeQuickActionsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start exploring to see your recent screens here'**
  String get desktopHomeQuickActionsEmptySubtitle;

  /// No description provided for @desktopHomeQuickActionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No recent visits yet'**
  String get desktopHomeQuickActionsEmptyTitle;

  /// No description provided for @desktopHomeQuickActionsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Navigate to different screens and they\'ll appear here for quick access. Cards disappear after 24 hours of inactivity.'**
  String get desktopHomeQuickActionsEmptyDescription;

  /// No description provided for @desktopHomeFeaturedArtworksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discover trending AR art'**
  String get desktopHomeFeaturedArtworksSubtitle;

  /// No description provided for @desktopHomeWeb3HubTitle.
  ///
  /// In en, this message translates to:
  /// **'Web3 Hub'**
  String get desktopHomeWeb3HubTitle;

  /// No description provided for @desktopHomeWeb3HubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Access decentralized features'**
  String get desktopHomeWeb3HubSubtitle;

  /// No description provided for @desktopHomeTrendingArtTitle.
  ///
  /// In en, this message translates to:
  /// **'Trending Art'**
  String get desktopHomeTrendingArtTitle;

  /// No description provided for @desktopHomeTrendingArtLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load trending art.'**
  String get desktopHomeTrendingArtLoadFailed;

  /// No description provided for @desktopHomeTrendingArtEmpty.
  ///
  /// In en, this message translates to:
  /// **'Trending artworks will appear here'**
  String get desktopHomeTrendingArtEmpty;

  /// No description provided for @desktopHomeTopCreatorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Top Creators'**
  String get desktopHomeTopCreatorsTitle;

  /// No description provided for @desktopHomeTopCreatorsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load creators.'**
  String get desktopHomeTopCreatorsLoadFailed;

  /// No description provided for @desktopHomeTopCreatorsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Top creators will appear here'**
  String get desktopHomeTopCreatorsEmpty;

  /// No description provided for @desktopHomeCreatorFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get desktopHomeCreatorFallbackName;

  /// No description provided for @desktopHomePostsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 post} other{{count} posts}}'**
  String desktopHomePostsCount(num count);

  /// No description provided for @desktopHomePlatformStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform Stats'**
  String get desktopHomePlatformStatsTitle;

  /// No description provided for @desktopHomePlatformStatsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load community stats.'**
  String get desktopHomePlatformStatsLoadFailed;

  /// No description provided for @desktopHomePlatformStatsTotalArtworks.
  ///
  /// In en, this message translates to:
  /// **'Total Artworks'**
  String get desktopHomePlatformStatsTotalArtworks;

  /// No description provided for @desktopHomePlatformStatsArEnabled.
  ///
  /// In en, this message translates to:
  /// **'AR Enabled'**
  String get desktopHomePlatformStatsArEnabled;

  /// No description provided for @desktopHomePlatformStatsCommunityPosts.
  ///
  /// In en, this message translates to:
  /// **'Community Posts'**
  String get desktopHomePlatformStatsCommunityPosts;

  /// No description provided for @desktopHomePlatformStatsActiveGroups.
  ///
  /// In en, this message translates to:
  /// **'Active Groups'**
  String get desktopHomePlatformStatsActiveGroups;

  /// No description provided for @desktopHomeUnreadNotificationsLabel.
  ///
  /// In en, this message translates to:
  /// **'unread notifications'**
  String get desktopHomeUnreadNotificationsLabel;

  /// No description provided for @homeWeb3SectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Web3'**
  String get homeWeb3SectionTitle;

  /// No description provided for @homeAccountRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Wallet required'**
  String get homeAccountRequiredLabel;

  /// No description provided for @homeWeb3DaoTitle.
  ///
  /// In en, this message translates to:
  /// **'DAO'**
  String get homeWeb3DaoTitle;

  /// No description provided for @homeWeb3DaoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Governance & voting'**
  String get homeWeb3DaoSubtitle;

  /// No description provided for @homeWeb3ArtistTitle.
  ///
  /// In en, this message translates to:
  /// **'Artist Studio'**
  String get homeWeb3ArtistTitle;

  /// No description provided for @homeWeb3ArtistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mint & manage'**
  String get homeWeb3ArtistSubtitle;

  /// No description provided for @homeWeb3InstitutionTitle.
  ///
  /// In en, this message translates to:
  /// **'Institution'**
  String get homeWeb3InstitutionTitle;

  /// No description provided for @homeWeb3InstitutionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Events & collections'**
  String get homeWeb3InstitutionSubtitle;

  /// No description provided for @homeWeb3MarketplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get homeWeb3MarketplaceTitle;

  /// No description provided for @homeWeb3MarketplaceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discover & trade'**
  String get homeWeb3MarketplaceSubtitle;

  /// No description provided for @homeMockNotificationFriendRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'New friend request'**
  String get homeMockNotificationFriendRequestTitle;

  /// No description provided for @homeMockNotificationFriendRequestBody.
  ///
  /// In en, this message translates to:
  /// **'Someone sent you a friend request.'**
  String get homeMockNotificationFriendRequestBody;

  /// No description provided for @homeMockNotificationFeaturedTitle.
  ///
  /// In en, this message translates to:
  /// **'Featured today'**
  String get homeMockNotificationFeaturedTitle;

  /// No description provided for @homeMockNotificationFeaturedBody.
  ///
  /// In en, this message translates to:
  /// **'Check out today\'s featured artwork.'**
  String get homeMockNotificationFeaturedBody;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @onboardingResetToolTitle.
  ///
  /// In en, this message translates to:
  /// **'Onboarding Reset Tool'**
  String get onboardingResetToolTitle;

  /// No description provided for @onboardingResetDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset onboarding'**
  String get onboardingResetDialogTitle;

  /// No description provided for @onboardingResetDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This will reset all onboarding flags. The app will show onboarding screens on next launch.\n\nContinue?'**
  String get onboardingResetDialogBody;

  /// No description provided for @onboardingResetSnackBarMessage.
  ///
  /// In en, this message translates to:
  /// **'Onboarding state reset! Restart the app to see onboarding.'**
  String get onboardingResetSnackBarMessage;

  /// No description provided for @onboardingResetDeveloperToolTitle.
  ///
  /// In en, this message translates to:
  /// **'Developer tool'**
  String get onboardingResetDeveloperToolTitle;

  /// No description provided for @onboardingResetDeveloperToolDescription.
  ///
  /// In en, this message translates to:
  /// **'This tool shows the current onboarding state and allows you to reset it for testing.'**
  String get onboardingResetDeveloperToolDescription;

  /// No description provided for @onboardingResetCurrentStateTitle.
  ///
  /// In en, this message translates to:
  /// **'Current onboarding state'**
  String get onboardingResetCurrentStateTitle;

  /// No description provided for @onboardingResetConfigSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Config settings'**
  String get onboardingResetConfigSettingsTitle;

  /// No description provided for @onboardingResetButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reset onboarding state'**
  String get onboardingResetButtonLabel;

  /// No description provided for @onboardingResetHowToTestTitle.
  ///
  /// In en, this message translates to:
  /// **'How to test'**
  String get onboardingResetHowToTestTitle;

  /// No description provided for @onboardingResetHowToTestSteps.
  ///
  /// In en, this message translates to:
  /// **'1. Tap \"Reset onboarding state\"\n2. Restart the app (close and reopen)\n3. Onboarding should show on launch'**
  String get onboardingResetHowToTestSteps;

  /// No description provided for @season0BannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Season 0, Ljubljana (beta)'**
  String get season0BannerTitle;

  /// No description provided for @season0BannerTap.
  ///
  /// In en, this message translates to:
  /// **'Learn more about the launch program'**
  String get season0BannerTap;

  /// No description provided for @season0ScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Season 0'**
  String get season0ScreenTitle;

  /// No description provided for @season0ScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ljubljana beta launch'**
  String get season0ScreenSubtitle;

  /// No description provided for @season0ScreenDescription.
  ///
  /// In en, this message translates to:
  /// **'Join the founding program of art.kubus in Ljubljana. Apply as an artist or institution to shape the first season of the platform.'**
  String get season0ScreenDescription;

  /// No description provided for @season0ApplyArtistCta.
  ///
  /// In en, this message translates to:
  /// **'Apply as artist'**
  String get season0ApplyArtistCta;

  /// No description provided for @season0ApplyArtistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join as a creator or collective'**
  String get season0ApplyArtistSubtitle;

  /// No description provided for @season0ApplyInstitutionCta.
  ///
  /// In en, this message translates to:
  /// **'Apply as institution'**
  String get season0ApplyInstitutionCta;

  /// No description provided for @season0ApplyInstitutionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Register your gallery or space'**
  String get season0ApplyInstitutionSubtitle;

  /// No description provided for @season0NewsletterCta.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to newsletter'**
  String get season0NewsletterCta;

  /// No description provided for @season0NewsletterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get updates on progress and events'**
  String get season0NewsletterSubtitle;

  /// No description provided for @season0PointsLabel.
  ///
  /// In en, this message translates to:
  /// **'KUB8 points'**
  String get season0PointsLabel;

  /// No description provided for @season0PointsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Off-chain progress tokens'**
  String get season0PointsTooltip;

  /// No description provided for @season0OnChainNote.
  ///
  /// In en, this message translates to:
  /// **'On-chain features available in Labs'**
  String get season0OnChainNote;

  /// No description provided for @mnemonicRevealTitle.
  ///
  /// In en, this message translates to:
  /// **'Reveal Recovery Phrase'**
  String get mnemonicRevealTitle;

  /// No description provided for @mnemonicRevealPrivacyWarning.
  ///
  /// In en, this message translates to:
  /// **'Your recovery phrase (keep it private)'**
  String get mnemonicRevealPrivacyWarning;

  /// No description provided for @mnemonicRevealBiometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock unavailable. Enter PIN to reveal your recovery phrase.'**
  String get mnemonicRevealBiometricUnavailable;

  /// No description provided for @mnemonicRevealPinError.
  ///
  /// In en, this message translates to:
  /// **'PIN must be at least 4 digits'**
  String get mnemonicRevealPinError;

  /// No description provided for @mnemonicRevealPinLockedError.
  ///
  /// In en, this message translates to:
  /// **'PIN locked for {seconds} seconds'**
  String mnemonicRevealPinLockedError(Object seconds);

  /// No description provided for @securityPinAttemptsRemaining.
  ///
  /// In en, this message translates to:
  /// **'Attempts remaining: {remaining} / {max}'**
  String securityPinAttemptsRemaining(Object remaining, Object max);

  /// No description provided for @mnemonicRevealIncorrectPinError.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN'**
  String get mnemonicRevealIncorrectPinError;

  /// No description provided for @mnemonicRevealCopiedToast.
  ///
  /// In en, this message translates to:
  /// **'Mnemonic copied to clipboard'**
  String get mnemonicRevealCopiedToast;

  /// No description provided for @mnemonicRevealShowButton.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get mnemonicRevealShowButton;

  /// No description provided for @mnemonicRevealEnterPinDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get mnemonicRevealEnterPinDialogTitle;

  /// No description provided for @manageMarkersTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage markers'**
  String get manageMarkersTitle;

  /// No description provided for @manageMarkersCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create, publish, and edit your map markers'**
  String get manageMarkersCardSubtitle;

  /// No description provided for @manageMarkersQuickActionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create, publish, and edit markers'**
  String get manageMarkersQuickActionSubtitle;

  /// No description provided for @manageMarkersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search markers'**
  String get manageMarkersSearchHint;

  /// No description provided for @manageMarkersRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get manageMarkersRefreshTooltip;

  /// No description provided for @manageMarkersStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get manageMarkersStatusDraft;

  /// No description provided for @manageMarkersStatusPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get manageMarkersStatusPublic;

  /// No description provided for @manageMarkersStatusPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get manageMarkersStatusPrivate;

  /// No description provided for @manageMarkersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No markers yet'**
  String get manageMarkersEmptyTitle;

  /// No description provided for @manageMarkersEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your first marker to place an AR experience on the map.'**
  String get manageMarkersEmptySubtitle;

  /// No description provided for @manageMarkersSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a marker'**
  String get manageMarkersSelectTitle;

  /// No description provided for @manageMarkersSelectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a marker from the list or create a new one.'**
  String get manageMarkersSelectSubtitle;

  /// No description provided for @manageMarkersLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load markers'**
  String get manageMarkersLoadFailedTitle;

  /// No description provided for @manageMarkersLoadFailedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get manageMarkersLoadFailedSubtitle;

  /// No description provided for @manageMarkersRetryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get manageMarkersRetryButton;

  /// No description provided for @manageMarkersNewButton.
  ///
  /// In en, this message translates to:
  /// **'New marker'**
  String get manageMarkersNewButton;

  /// No description provided for @manageMarkersEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit marker'**
  String get manageMarkersEditTitle;

  /// No description provided for @manageMarkersCloseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get manageMarkersCloseTooltip;

  /// No description provided for @manageMarkersCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get manageMarkersCreateButton;

  /// No description provided for @manageMarkersSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get manageMarkersSaveButton;

  /// No description provided for @manageMarkersSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save marker'**
  String get manageMarkersSaveFailed;

  /// No description provided for @manageMarkersCreatedToast.
  ///
  /// In en, this message translates to:
  /// **'Marker created'**
  String get manageMarkersCreatedToast;

  /// No description provided for @manageMarkersUpdatedToast.
  ///
  /// In en, this message translates to:
  /// **'Marker updated'**
  String get manageMarkersUpdatedToast;

  /// No description provided for @manageMarkersDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete marker?'**
  String get manageMarkersDeleteConfirmTitle;

  /// No description provided for @manageMarkersDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get manageMarkersDeleteConfirmBody;

  /// No description provided for @manageMarkersDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get manageMarkersDeleteButton;

  /// No description provided for @manageMarkersCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get manageMarkersCancelButton;

  /// No description provided for @manageMarkersDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete marker'**
  String get manageMarkersDeleteFailed;

  /// No description provided for @manageMarkersDeletedToast.
  ///
  /// In en, this message translates to:
  /// **'Marker deleted'**
  String get manageMarkersDeletedToast;

  /// No description provided for @manageMarkersActivationRadiusLabel.
  ///
  /// In en, this message translates to:
  /// **'Activation radius (m)'**
  String get manageMarkersActivationRadiusLabel;

  /// No description provided for @manageMarkersPublishedToggleTitle.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get manageMarkersPublishedToggleTitle;

  /// No description provided for @manageMarkersRequiresProximityTitle.
  ///
  /// In en, this message translates to:
  /// **'Requires proximity'**
  String get manageMarkersRequiresProximityTitle;

  /// No description provided for @manageMarkersRequiresProximitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Require users to be near the marker to activate AR'**
  String get manageMarkersRequiresProximitySubtitle;

  /// No description provided for @manageMarkersSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get manageMarkersSearchNoResults;

  /// No description provided for @manageMarkersPickSubjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick {subjectType}'**
  String manageMarkersPickSubjectTitle(Object subjectType);

  /// No description provided for @manageMarkersSearchSubjectsHint.
  ///
  /// In en, this message translates to:
  /// **'Search subjects'**
  String get manageMarkersSearchSubjectsHint;

  /// No description provided for @manageMarkersPickArAssetTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick AR asset'**
  String get manageMarkersPickArAssetTitle;

  /// No description provided for @manageMarkersSearchArAssetsHint.
  ///
  /// In en, this message translates to:
  /// **'Search AR assets'**
  String get manageMarkersSearchArAssetsHint;

  /// No description provided for @manageMarkersClearSelectionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get manageMarkersClearSelectionTooltip;

  /// No description provided for @artworkCommentAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add Comment'**
  String get artworkCommentAddButton;

  /// No description provided for @artworkCommentAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Comment'**
  String get artworkCommentAddTitle;

  /// No description provided for @artworkCommentAddHint.
  ///
  /// In en, this message translates to:
  /// **'Share your thoughts about this artwork...'**
  String get artworkCommentAddHint;

  /// No description provided for @artworkCommentPostButton.
  ///
  /// In en, this message translates to:
  /// **'Post Comment'**
  String get artworkCommentPostButton;

  /// No description provided for @artworkCommentAddedToast.
  ///
  /// In en, this message translates to:
  /// **'Comment added successfully!'**
  String get artworkCommentAddedToast;

  /// No description provided for @profileFieldOfWorkLabel.
  ///
  /// In en, this message translates to:
  /// **'Field of work'**
  String get profileFieldOfWorkLabel;

  /// No description provided for @profileYearsActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Years active'**
  String get profileYearsActiveLabel;

  /// Humanized years active value for profile display.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {{count} year} other {{count} years}}'**
  String profileYearsActiveValue(int count);

  /// No description provided for @manageMarkersPickArAssetPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Select an AR asset'**
  String get manageMarkersPickArAssetPlaceholder;

  /// No description provided for @commonExhibition.
  ///
  /// In en, this message translates to:
  /// **'Exhibition'**
  String get commonExhibition;

  /// No description provided for @commonCollection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get commonCollection;

  /// No description provided for @commonInstitution.
  ///
  /// In en, this message translates to:
  /// **'Institution'**
  String get commonInstitution;

  /// No description provided for @commonDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get commonDetails;

  /// No description provided for @communitySubjectLinkedLabel.
  ///
  /// In en, this message translates to:
  /// **'Linked {subjectType}'**
  String communitySubjectLinkedLabel(Object subjectType);

  /// No description provided for @communitySubjectSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Link a subject'**
  String get communitySubjectSelectTitle;

  /// No description provided for @communitySubjectSelectPrompt.
  ///
  /// In en, this message translates to:
  /// **'Choose what this post references'**
  String get communitySubjectSelectPrompt;

  /// No description provided for @communitySubjectRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove subject'**
  String get communitySubjectRemoveTooltip;

  /// No description provided for @communitySubjectNoneLabel.
  ///
  /// In en, this message translates to:
  /// **'No subject'**
  String get communitySubjectNoneLabel;

  /// No description provided for @communitySubjectPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select subject'**
  String get communitySubjectPickerTitle;

  /// No description provided for @communitySubjectPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name'**
  String get communitySubjectPickerSearchHint;

  /// No description provided for @communitySubjectPickerSearchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Start typing to search institutions'**
  String get communitySubjectPickerSearchPrompt;

  /// No description provided for @communitySubjectPickerLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load subjects.'**
  String get communitySubjectPickerLoadFailed;

  /// No description provided for @communitySubjectPickerEmptyArtwork.
  ///
  /// In en, this message translates to:
  /// **'No artworks found.'**
  String get communitySubjectPickerEmptyArtwork;

  /// No description provided for @communitySubjectPickerEmptyExhibition.
  ///
  /// In en, this message translates to:
  /// **'No exhibitions found.'**
  String get communitySubjectPickerEmptyExhibition;

  /// No description provided for @communitySubjectPickerEmptyCollection.
  ///
  /// In en, this message translates to:
  /// **'No collections found.'**
  String get communitySubjectPickerEmptyCollection;

  /// No description provided for @communitySubjectPickerEmptyInstitution.
  ///
  /// In en, this message translates to:
  /// **'No institutions found.'**
  String get communitySubjectPickerEmptyInstitution;

  /// No description provided for @supportSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get supportSectionTitle;

  /// No description provided for @supportSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help us keep building art.kubus - every donation helps.'**
  String get supportSectionSubtitle;

  /// No description provided for @supportSectionMoreInfo.
  ///
  /// In en, this message translates to:
  /// **'More info'**
  String get supportSectionMoreInfo;

  /// No description provided for @supportMethodKofi.
  ///
  /// In en, this message translates to:
  /// **'Ko-fi'**
  String get supportMethodKofi;

  /// No description provided for @supportMethodKofiHint.
  ///
  /// In en, this message translates to:
  /// **'Coffee-sized support'**
  String get supportMethodKofiHint;

  /// No description provided for @supportMethodPaypal.
  ///
  /// In en, this message translates to:
  /// **'PayPal'**
  String get supportMethodPaypal;

  /// No description provided for @supportMethodPaypalHint.
  ///
  /// In en, this message translates to:
  /// **'Donate via PayPal'**
  String get supportMethodPaypalHint;

  /// No description provided for @supportMethodGithubSponsors.
  ///
  /// In en, this message translates to:
  /// **'GitHub Sponsors'**
  String get supportMethodGithubSponsors;

  /// No description provided for @supportMethodGithubSponsorsHint.
  ///
  /// In en, this message translates to:
  /// **'Support via GitHub'**
  String get supportMethodGithubSponsorsHint;

  /// No description provided for @supportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'What your support enables'**
  String get supportDialogTitle;

  /// No description provided for @supportDialogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Three tiers - all meaningful. Thank you for helping us keep building.'**
  String get supportDialogSubtitle;

  /// No description provided for @supportTier5Amount.
  ///
  /// In en, this message translates to:
  /// **'€5'**
  String get supportTier5Amount;

  /// No description provided for @supportTier5Body.
  ///
  /// In en, this message translates to:
  /// **'Helps cover monthly infrastructure costs.'**
  String get supportTier5Body;

  /// No description provided for @supportTier15Amount.
  ///
  /// In en, this message translates to:
  /// **'€15'**
  String get supportTier15Amount;

  /// No description provided for @supportTier15Body.
  ///
  /// In en, this message translates to:
  /// **'Supports steady weekly improvements.'**
  String get supportTier15Body;

  /// No description provided for @supportTier50Amount.
  ///
  /// In en, this message translates to:
  /// **'€50'**
  String get supportTier50Amount;

  /// No description provided for @supportTier50Body.
  ///
  /// In en, this message translates to:
  /// **'Funds one focused development session (new feature / fixes / content updates).'**
  String get supportTier50Body;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'sl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'sl': return AppLocalizationsSl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
