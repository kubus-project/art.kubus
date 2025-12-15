// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Slovenian (`sl`).
class AppLocalizationsSl extends AppLocalizations {
  AppLocalizationsSl([String locale = 'sl']) : super(locale);

  @override
  String get appTitle => 'art.kubus';

  @override
  String get commonCancel => 'Prekliči';

  @override
  String get commonClose => 'Zapri';

  @override
  String get commonContinue => 'Nadaljuj';

  @override
  String get commonSkip => 'Preskoči';

  @override
  String get commonSkipForNow => 'Preskoči za zdaj';

  @override
  String get commonBack => 'Nazaj';

  @override
  String get commonNext => 'Naprej';

  @override
  String get commonSave => 'Shrani';

  @override
  String get commonCopy => 'Kopiraj';

  @override
  String get commonDelete => 'Izbriši';

  @override
  String get commonDone => 'Končano';

  @override
  String get commonEdit => 'Uredi';

  @override
  String get commonRename => 'Preimenuj';

  @override
  String get commonCreate => 'Ustvari';

  @override
  String get commonGotIt => 'Razumem';

  @override
  String get commonInstall => 'Namesti';

  @override
  String get commonNavigate => 'Navigiraj';

  @override
  String get commonReplace => 'Zamenjaj';

  @override
  String get commonSearch => 'Išči';

  @override
  String get commonNotifications => 'Obvestila';

  @override
  String get commonShare => 'Deli';

  @override
  String get commonGroup => 'Skupina';

  @override
  String get commonImage => 'Slika';

  @override
  String get commonVideo => 'Video';

  @override
  String get commonMembers => 'Člani';

  @override
  String get commonAdd => 'Dodaj';

  @override
  String get commonUpload => 'Naloži';

  @override
  String get commonViewInAr => 'Ogled v AR';

  @override
  String get commonViewAll => 'Prikaži vse';

  @override
  String get commonProceed => 'Nadaljuj';

  @override
  String get commonGetStarted => 'Začnimo';

  @override
  String get commonWorking => 'V teku…';

  @override
  String get commonEmail => 'E-pošta';

  @override
  String get commonPassword => 'Geslo';

  @override
  String get commonUsernameOptional => 'Uporabniško ime (neobvezno)';

  @override
  String get commonUnlock => 'Odkleni';

  @override
  String get commonPinLabel => 'PIN';

  @override
  String get personaOnboardingTitle => 'Kako želiš uporabljati art.kubus?';

  @override
  String get personaOnboardingSubtitle => 'Izberi, zakaj si tukaj. To vpliva le na to, kaj izpostavimo — ne na dostop.';

  @override
  String get personaOptionLoverTitle => 'Ljubitelj umetnosti';

  @override
  String get personaOptionLoverSubtitle => 'Odkrij bližnja dela, razstave in dogajanje v skupnosti.';

  @override
  String get personaOptionCreatorTitle => 'Umetnik / kolektiv';

  @override
  String get personaOptionCreatorSubtitle => 'Ustvarjaj dela in razstave ter sodeluj z drugimi.';

  @override
  String get personaOptionInstitutionTitle => 'Institucija / galerija';

  @override
  String get personaOptionInstitutionSubtitle => 'Organiziraj dogodke in razstave, upravljaj sodelavce in deli program.';

  @override
  String get exhibitionCreatorAppBarTitle => 'Ustvari razstavo';

  @override
  String get exhibitionCreatorDisabledAppBarTitle => 'Razstava';

  @override
  String get exhibitionCreatorDisabledMessage => 'Razstave so trenutno onemogočene.';

  @override
  String get exhibitionCreatorBasicsTitle => 'Osnove';

  @override
  String get exhibitionCreatorTitleLabel => 'Naslov';

  @override
  String get exhibitionCreatorTitleValidation => 'Vnesite naslov.';

  @override
  String get exhibitionCreatorDescriptionLabel => 'Opis (neobvezno)';

  @override
  String get exhibitionCreatorLocationLabel => 'Ime lokacije (neobvezno)';

  @override
  String get exhibitionCreatorScheduleTitle => 'Termin';

  @override
  String get exhibitionCreatorStartsLabel => 'Začetek';

  @override
  String get exhibitionCreatorEndsLabel => 'Konec';

  @override
  String get exhibitionCreatorNotSetLabel => 'Ni nastavljeno';

  @override
  String get exhibitionCreatorPublishTitle => 'Objavi';

  @override
  String get exhibitionCreatorPublishVisible => 'Vidno vsem';

  @override
  String get exhibitionCreatorPublishDraft => 'Shrani kot osnutek';

  @override
  String get exhibitionCreatorEndDateAfterStartError => 'Datum konca mora biti po začetku.';

  @override
  String get exhibitionCreatorCreateFailed => 'Ustvarjanje razstave ni uspelo.';

  @override
  String exhibitionCreatorCreateFailedWithError(Object error) {
    return 'Ustvarjanje razstave ni uspelo: $error';
  }

  @override
  String get lockAppLockedTitle => 'Aplikacija je zaklenjena';

  @override
  String get lockAppLockedDescription => 'Overite se za dostop do funkcij denarnice.';

  @override
  String get lockEnterPinTitle => 'Vnesite PIN za odklep';

  @override
  String get lockAppUnlockedToast => 'Aplikacija odklenjena';

  @override
  String get lockAuthenticationFailedToast => 'Overitev ni uspela';

  @override
  String get authSignInTitle => 'Prijava v art.kubus';

  @override
  String get authSignInSubtitle => 'in začnite raziskovati, ustvarjati ter se povezovati z drugimi ustvarjalci.';

  @override
  String get authRegisterTitle => 'Ustvarite račun';

  @override
  String get authRegisterSubtitle => 'Ustvarite profil in se pridružite skupnosti.';

  @override
  String get authHighlightSignInMethods => 'Prijava z denarnico, e-pošto ali Googlom';

  @override
  String get authHighlightNoFees => 'Za prijavo ni potrebna provizija';

  @override
  String get authHighlightControl => 'Nadzor ostane pri vas';

  @override
  String get authHighlightOnboardingOptions => 'Začetek z denarnico ali e-pošto';

  @override
  String get authHighlightKeysLocal => 'Ključi ostanejo na vaši napravi';

  @override
  String get authHighlightOptionalWeb3 => 'Neobvezne Web3 funkcije';

  @override
  String get authSignedInProfileRefreshSoon => 'Prijava je uspela. Profil se bo kmalu osvežil.';

  @override
  String get authAccountCreatedProfileLoading => 'Račun je ustvarjen. Profil se nalaga v ozadju.';

  @override
  String get authEmailSignInDisabled => 'Prijava z e-pošto je onemogočena.';

  @override
  String get authEmailRegistrationDisabled => 'Registracija z e-pošto je onemogočena.';

  @override
  String get authGoogleSignInDisabled => 'Prijava z Googlom je onemogočena.';

  @override
  String get authWalletConnectionDisabled => 'Povezava denarnice je trenutno onemogočena.';

  @override
  String get authEnterValidEmailPassword => 'Vnesite veljavno e-pošto in geslo (vsaj 8 znakov).';

  @override
  String get authEmailSignInFailed => 'Prijava z e-pošto ni uspela. Poskusite znova.';

  @override
  String get authRegistrationFailed => 'Registracija ni uspela. Poskusite znova.';

  @override
  String get authGoogleSignInFailed => 'Prijava z Googlom ni uspela. Poskusite znova.';

  @override
  String authGoogleRateLimitedRetryIn(Object duration) {
    return 'Prijava z Googlom je začasno omejena. Poskusite znova čez ~$duration.';
  }

  @override
  String get authConnectWalletButton => 'Poveži denarnico';

  @override
  String get authConnectWalletModalTitle => 'Poveži denarnico';

  @override
  String get authConnectWalletModalDescriptionSignIn => 'V denarnici boste potrdili podpis. Za prijavo ni potrebna provizija.';

  @override
  String get authConnectWalletModalDescriptionRegister => 'V denarnici boste potrdili podpis. Za dokončanje registracije ni potrebna provizija.';

  @override
  String get authWalletOptionWalletConnect => 'WalletConnect';

  @override
  String get authWalletOptionOtherWallets => 'Druge denarnice';

  @override
  String get authOrLogInWithEmailOrUsername => 'Ali se prijavite z e-pošto ali uporabniškim imenom';

  @override
  String get authOrUseEmail => 'Ali uporabite e-pošto';

  @override
  String get authNeedAccountRegister => 'Nimate računa? Registracija';

  @override
  String get authHaveAccountSignIn => 'Že imate račun? Prijava';

  @override
  String get authSignInWithEmail => 'Prijava z e-pošto';

  @override
  String get authContinueWithEmail => 'Nadaljuj z e-pošto';

  @override
  String get onboardingWelcomeTitle => 'Dobrodošli v art.kubus';

  @override
  String get onboardingWelcomeSubtitle => 'Razstava in skupnost na enem mestu';

  @override
  String get onboardingWelcomeDescription => 'Odkrijte umetnine, raziskujte kraje in se povežite z ustvarjalci. XR in Web3 sta neobvezni plasti — osnovna izkušnja deluje tudi brez njiju.';

  @override
  String get onboardingExploreTitle => 'Raziskujte umetnine';

  @override
  String get onboardingExploreSubtitle => 'Poiščite umetnost v bližini';

  @override
  String get onboardingExploreDescription => 'Z zemljevidom odkrijte umetnine in označevalce v okolici. Vsaka lokacija lahko pripoveduje zgodbo.';

  @override
  String get onboardingCreateTitle => 'Ustvarjajte in delite';

  @override
  String get onboardingCreateSubtitle => 'Izrazite svojo ustvarjalnost';

  @override
  String get onboardingCreateDescription => 'Ustvarite AR izkušnje in jih delite s skupnostjo, ko boste pripravljeni.';

  @override
  String get onboardingCommunityTitle => 'Pridružite se skupnosti';

  @override
  String get onboardingCommunitySubtitle => 'Sodelovanje je privzeto';

  @override
  String get onboardingCommunityDescription => 'Sledite umetnikom, pošiljajte sporočila in sodelujte pri projektih — kjer je smiselno, je sodelovanje privzeto.';

  @override
  String get onboardingCollectiblesTitle => 'Zbirateljski predmeti (neobvezno)';

  @override
  String get onboardingCollectiblesSubtitle => 'Dokazi obiska in zbirateljski predmeti';

  @override
  String get onboardingCollectiblesDescription => 'Po želji povežite denarnico za zbiranje zbirateljskih predmetov (NFT) in digitalnih dokazov obiska (POAP). Aplikacija ostane uporabna tudi brez Web3.';

  @override
  String get onboardingGrantPermissions => 'Dovoli dostop';

  @override
  String get onboardingSkipPermissions => 'Preskoči dovoljenja';

  @override
  String get permissionsChecking => 'Preverjam dovoljenja…';

  @override
  String get permissionsSkipAll => 'Preskoči vse';

  @override
  String get permissionsBenefitsTitle => 'Kaj lahko počnete:';

  @override
  String get permissionsPrivacyNote => 'Vaša zasebnost je zaščitena. Vaših podatkov ne delimo.';

  @override
  String get permissionsGrantedLabel => 'Dovoljenje odobreno';

  @override
  String get permissionsGetStarted => 'Začnimo';

  @override
  String get permissionsNextPermission => 'Naslednje dovoljenje';

  @override
  String get permissionsGrantPermission => 'Dovoli';

  @override
  String get permissionsSkipThisPermission => 'Preskoči to dovoljenje';

  @override
  String permissionsPermissionGrantedToast(Object permission) {
    return 'Dovoljenje odobreno: $permission';
  }

  @override
  String get permissionsPermissionRequiredTitle => 'Potrebno dovoljenje';

  @override
  String permissionsOpenSettingsDialogContent(Object permission) {
    return 'Za omogočitev $permission odprite Nastavitve in odobrite dovoljenje.';
  }

  @override
  String get permissionsOpenSettings => 'Odpri nastavitve';

  @override
  String get permissionsLocationTitle => 'Dostop do lokacije';

  @override
  String get permissionsLocationSubtitle => 'Odkrijte umetnost v bližini';

  @override
  String get permissionsLocationDescription => 'Lokacijo uporabljamo za prikaz umetnin in označevalcev v vaši bližini. Odkrijte lokalne ustvarjalce in razstave.';

  @override
  String get permissionsLocationBenefit1 => 'Poiščite umetnine v bližini';

  @override
  String get permissionsLocationBenefit2 => 'Odkrijte lokalne galerije in razstave';

  @override
  String get permissionsLocationBenefit3 => 'Prejemajte obvestila o dogodkih v bližini';

  @override
  String get permissionsLocationBenefit4 => 'Spremljajte svoje raziskovanje';

  @override
  String get permissionsCameraTitle => 'Dostop do kamere';

  @override
  String get permissionsCameraSubtitle => 'Doživite AR';

  @override
  String get permissionsCameraDescription => 'Kamera je ključna za ogled AR umetnin v vašem prostoru. Postavljajte, sodelujte in shranite svojo izkušnjo.';

  @override
  String get permissionsCameraBenefit1 => 'Oglejte si AR umetnine v resničnem svetu';

  @override
  String get permissionsCameraBenefit2 => 'Postavite virtualne skulpture v svoj prostor';

  @override
  String get permissionsCameraBenefit3 => 'Ustvarite fotografije za deljenje';

  @override
  String get permissionsCameraBenefit4 => 'Skenirajte QR kode za odklep vsebine';

  @override
  String get permissionsNotificationsTitle => 'Obvestila';

  @override
  String get permissionsNotificationsSubtitle => 'Ostanite povezani';

  @override
  String get permissionsNotificationsDescription => 'Prejemajte obvestila o novih umetninah, napredku, zbirateljskih predmetih (NFT), digitalnih dokazih obiska (POAP) in dogajanju v skupnosti.';

  @override
  String get permissionsNotificationsBenefit1 => 'Obvestila o novih umetninah';

  @override
  String get permissionsNotificationsBenefit2 => 'Napredek in nagrade';

  @override
  String get permissionsNotificationsBenefit3 => 'Posodobitve o zbirateljskih predmetih (NFT)';

  @override
  String get permissionsNotificationsBenefit4 => 'Opomniki o dogodkih v skupnosti';

  @override
  String get permissionsPhotosTitle => 'Dostop do shrambe';

  @override
  String get permissionsPhotosSubtitle => 'Shranjujte svoje stvaritve';

  @override
  String get permissionsPhotosDescription => 'Shranjujte AR posnetke zaslona in prenose v fototeko, da lahko ohranite spomine in jih delite.';

  @override
  String get permissionsPhotosBenefit1 => 'Shranjujte AR posnetke zaslona med fotografije';

  @override
  String get permissionsPhotosBenefit2 => 'Prenesite slike umetnin';

  @override
  String get permissionsPhotosBenefit3 => 'Izvozite stvaritve za deljenje';

  @override
  String get permissionsPhotosBenefit4 => 'Ohranite zbirko dostopno';

  @override
  String get settingsTitle => 'Nastavitve';

  @override
  String get settingsLanguageTitle => 'Jezik';

  @override
  String get settingsLanguageDescription => 'Izberite jezik aplikacije';

  @override
  String get languageSlovenian => 'Slovenščina';

  @override
  String get languageEnglish => 'Angleščina';

  @override
  String get commonOn => 'Vklopljeno';

  @override
  String get commonOff => 'Izklopljeno';

  @override
  String get commonEnabled => 'Omogočeno';

  @override
  String get commonDisabled => 'Onemogočeno';

  @override
  String get commonAvailable => 'Na voljo';

  @override
  String get commonNotAvailable => 'Ni na voljo';

  @override
  String get settingsGuestUserName => 'Gost';

  @override
  String get desktopSettingsProfileSectionSubtitle => 'Posodobite podatke profila, ki so vidni drugim uporabnikom';

  @override
  String get desktopSettingsDisplayNameLabel => 'Prikazno ime';

  @override
  String get desktopSettingsDisplayNameHint => 'Vnesite svoje ime';

  @override
  String get desktopSettingsUsernameLabel => 'Uporabniško ime';

  @override
  String get desktopSettingsUsernameHint => '@username';

  @override
  String get desktopSettingsBioLabel => 'Opis';

  @override
  String get desktopSettingsBioHint => 'Povejte nam nekaj o sebi';

  @override
  String get desktopSettingsWebsiteLabel => 'Spletna stran';

  @override
  String get desktopSettingsWebsiteHint => 'https://';

  @override
  String get desktopSettingsLocationLabel => 'Lokacija';

  @override
  String get desktopSettingsLocationHint => 'Mesto, država';

  @override
  String get desktopSettingsWalletSectionSubtitle => 'Upravljajte povezavo denarnice in nastavitve Web3';

  @override
  String get desktopSettingsViewWalletButton => 'Ogled denarnice';

  @override
  String get desktopSettingsSecuritySectionTitle => 'Varnost';

  @override
  String get desktopSettingsDisconnectWalletTileTitle => 'Odklopi denarnico';

  @override
  String get desktopSettingsDisconnectWalletTileSubtitle => 'Odjavite se iz funkcij Web3';

  @override
  String get desktopSettingsDisconnectWalletDialogTitle => 'Odklopi denarnico';

  @override
  String get desktopSettingsDisconnectWalletDialogBody => 'Odklopim denarnico s te naprave? Kadarkoli jo lahko znova povežete.';

  @override
  String get desktopSettingsWalletDisconnectedToast => 'Denarnica je odklopljena';

  @override
  String get desktopSettingsDisconnectButton => 'Odklopi';

  @override
  String get desktopSettingsExportingDataToast => 'Izvažam podatke…';

  @override
  String get desktopSettingsPlatformSubtitle => 'Preverite, katere zmožnosti so na voljo na tej napravi';

  @override
  String get desktopSettingsAppearanceSubtitle => 'Prilagodite videz aplikacije';

  @override
  String get desktopSettingsShowFriendsTitle => 'Prikaži prijatelje';

  @override
  String get desktopSettingsShowFriendsSubtitle => 'Na profilu prikaži seznam prijateljev';

  @override
  String get desktopSettingsShowAchievementsTitle => 'Prikaži dosežke';

  @override
  String get desktopSettingsShowAchievementsSubtitle => 'Na profilu prikaži dosežke';

  @override
  String get desktopSettingsAllowMessagesTitle => 'Dovoli sporočila';

  @override
  String get desktopSettingsAllowMessagesSubtitle => 'Dovoli drugim, da vam pošljejo sporočilo';

  @override
  String get desktopSettingsDangerZoneSubtitle => 'Nepovratna dejanja, ki zahtevajo previdnost';

  @override
  String get desktopSettingsAchievementsTitle => 'Dosežki in nagrade';

  @override
  String get desktopSettingsAchievementsSubtitle => 'Spremljajte napredek in zbirajte KUB8 točke';

  @override
  String get desktopSettingsAchievementsStatArtworksDiscovered => 'Odkrite umetnine';

  @override
  String get desktopSettingsAchievementsStatArViews => 'Ogledi AR';

  @override
  String get desktopSettingsAchievementsStatEventsAttended => 'Obiskani dogodki';

  @override
  String get desktopSettingsAchievementsStatKub8PointsEarned => 'Pridobljene KUB8 točke';

  @override
  String get desktopSettingsAchievementFirstDiscoveryTitle => 'Prvo odkritje';

  @override
  String get desktopSettingsAchievementFirstDiscoveryDescription => 'Odkrijte svojo prvo AR umetnino';

  @override
  String get desktopSettingsAchievementArtCollectorTitle => 'Zbiralec umetnin';

  @override
  String get desktopSettingsAchievementArtCollectorDescription => 'Oglejte si 10 AR umetnin';

  @override
  String get desktopSettingsAchievementCommunityMemberTitle => 'Član skupnosti';

  @override
  String get desktopSettingsAchievementCommunityMemberDescription => 'Pridružite se 3 skupinam';

  @override
  String get desktopSettingsAchievementEventExplorerTitle => 'Raziskovalec dogodkov';

  @override
  String get desktopSettingsAchievementEventExplorerDescription => 'Obiščite 5 umetniških dogodkov';

  @override
  String get desktopSettingsAchievementNftCreatorTitle => 'Ustvarjalec NFT';

  @override
  String get desktopSettingsAchievementNftCreatorDescription => 'Ustvarite svoj prvi NFT';

  @override
  String get desktopSettingsHelpSupportTitle => 'Pomoč in podpora';

  @override
  String get desktopSettingsHelpSupportSubtitle => 'Poiščite pomoč in odgovore na pogosta vprašanja';

  @override
  String get desktopSettingsFaqTileTitle => 'Pogosta vprašanja';

  @override
  String get desktopSettingsFaqTileSubtitle => 'Najpogostejša vprašanja';

  @override
  String get desktopSettingsContactSupportTileSubtitle => 'Pomoč naše ekipe';

  @override
  String get desktopSettingsReportBugTileTitle => 'Prijavi napako';

  @override
  String get desktopSettingsReportBugTileSubtitle => 'Pomagajte izboljšati aplikacijo';

  @override
  String get desktopSettingsOpeningBugReportToast => 'Odpiram obrazec za prijavo napake…';

  @override
  String get desktopSettingsAboutSubtitle => 'AR umetniška platforma, ki povezuje umetnike in institucije';

  @override
  String get desktopSettingsFeaturesSectionTitle => 'Funkcije';

  @override
  String get desktopSettingsFeatureArDiscoveryTitle => 'Odkritje AR umetnosti';

  @override
  String get desktopSettingsFeatureArDiscoveryDescription => 'Doživite umetnine v razširjeni resničnosti';

  @override
  String get desktopSettingsFeatureWeb3IntegrationTitle => 'Integracija Web3';

  @override
  String get desktopSettingsFeatureWeb3IntegrationDescription => 'Veriga Solana s KUB8 točkami';

  @override
  String get desktopSettingsFeatureNftMintingTitle => 'Ustvarjanje NFT';

  @override
  String get desktopSettingsFeatureNftMintingDescription => 'Ustvarjajte in trgujte z digitalnimi umetniškimi zbirateljskimi predmeti';

  @override
  String get desktopSettingsFeatureCommunityTitle => 'Skupnost';

  @override
  String get desktopSettingsFeatureCommunityDescription => 'Povežite se z umetniki in zbiratelji';

  @override
  String get desktopSettingsFeatureInstitutionsTitle => 'Institucije';

  @override
  String get desktopSettingsFeatureInstitutionsDescription => 'Sodelujte z galerijami in muzeji';

  @override
  String get desktopSettingsLegalSectionTitle => 'Pravno';

  @override
  String get settingsNoWalletConnected => 'Denarnica ni povezana';

  @override
  String get settingsAppearanceSectionTitle => 'Videz';

  @override
  String get settingsThemeModeTitle => 'Način teme';

  @override
  String get settingsThemeModeLight => 'Svetla';

  @override
  String get settingsThemeModeDark => 'Temna';

  @override
  String get settingsThemeModeSystem => 'Sistemska';

  @override
  String get settingsAccentColorTitle => 'Poudarjena barva';

  @override
  String get settingsPlatformFeaturesSectionTitle => 'Funkcije platforme';

  @override
  String settingsRunningOnPlatform(Object platform) {
    return 'Zagnano na $platform';
  }

  @override
  String get settingsAvailableFeaturesLabel => 'Razpoložljive funkcije:';

  @override
  String get settingsDeveloperToolsSectionTitle => 'Razvijalska orodja';

  @override
  String get settingsDeveloperResetOnboardingTitle => 'Ponastavi uvod';

  @override
  String get settingsDeveloperResetOnboardingSubtitle => 'Ponastavi stanje uvoda za testiranje';

  @override
  String get settingsDeveloperClearQuickActionsTitle => 'Počisti hitre akcije';

  @override
  String get settingsDeveloperClearQuickActionsSubtitle => 'Ponastavi nedavno obiskane zaslone';

  @override
  String get settingsDeveloperQuickActionsClearedToast => 'Hitre akcije so počiščene';

  @override
  String get settingsCapabilityCamera => 'Dostop do kamere (QR skener, AR)';

  @override
  String get settingsCapabilityAr => 'Funkcije obogatene resničnosti';

  @override
  String get settingsCapabilityNfc => 'NFC komunikacija';

  @override
  String get settingsCapabilityGps => 'Lokacijske storitve';

  @override
  String get settingsCapabilityBiometrics => 'Biometrično preverjanje';

  @override
  String get settingsCapabilityNotifications => 'Potisna obvestila';

  @override
  String get settingsCapabilityFileSystem => 'Dostop do datotečnega sistema';

  @override
  String get settingsCapabilityBluetooth => 'Povezljivost Bluetooth';

  @override
  String get settingsCapabilityVibration => 'Haptični odziv';

  @override
  String get settingsCapabilityOrientation => 'Orientacija naprave';

  @override
  String get settingsCapabilityBackground => 'Obdelava v ozadju';

  @override
  String get settingsProfileSectionTitle => 'Nastavitve profila';

  @override
  String get settingsProfileVisibilityPublicLabel => 'Javno';

  @override
  String get settingsProfileVisibilityPublicDescription => 'Vaš profil lahko vidi vsak';

  @override
  String get settingsProfileVisibilityPrivateLabel => 'Zasebno';

  @override
  String get settingsProfileVisibilityPrivateDescription => 'Vaš profil lahko vidite samo vi';

  @override
  String get settingsProfileVisibilityFriendsOnlyLabel => 'Samo prijatelji';

  @override
  String get settingsProfileVisibilityFriendsOnlyDescription => 'Vaš profil lahko vidijo samo prijatelji';

  @override
  String get settingsProfileVisibilityTileTitle => 'Vidnost profila';

  @override
  String settingsCurrentlyValue(Object value) {
    return 'Trenutno: $value';
  }

  @override
  String get settingsPrivacySettingsTileTitle => 'Nastavitve zasebnosti';

  @override
  String settingsPrivacySummary(Object dataState, Object adsState) {
    return 'Podatki: $dataState, oglasi: $adsState';
  }

  @override
  String get settingsSecuritySettingsTileTitle => 'Varnostne nastavitve';

  @override
  String settingsSecuritySummary(Object twoFactorStatus, Object autoLockTime) {
    return '2FA: $twoFactorStatus, samodejno zaklepanje: $autoLockTime';
  }

  @override
  String get settingsEditProfileTileTitle => 'Uredi profil';

  @override
  String get settingsEditProfileTileSubtitle => 'Posodobite uporabniško ime, opis in avatar';

  @override
  String get settingsAccountManagementTileTitle => 'Upravljanje računa';

  @override
  String settingsAccountSummary(Object accountType, Object notificationsState) {
    return 'Vrsta: $accountType, obvestila: $notificationsState';
  }

  @override
  String get settingsRoleSimulationTileTitle => 'Simulacija vlog';

  @override
  String settingsRoleSummary(Object artistStatus, Object institutionStatus) {
    return 'Umetnik: $artistStatus, institucija: $institutionStatus';
  }

  @override
  String get settingsRoleSimulationSheetTitle => 'Simulacija vlog';

  @override
  String get settingsRoleSimulationSheetSubtitle => 'Preklapljajte vloge za predogled postavitev profila lokalno. Spremembe veljajo samo na tej napravi.';

  @override
  String get settingsRoleArtistTitle => 'Profil umetnika';

  @override
  String get settingsRoleArtistSubtitle => 'Pokaži razdelke umetnika (umetnine, zbirke)';

  @override
  String get settingsRoleInstitutionTitle => 'Profil institucije';

  @override
  String get settingsRoleInstitutionSubtitle => 'Pokaži razdelke institucije (dogodki, zbirke)';

  @override
  String get settingsWalletSectionTitle => 'Denarnica in Web3';

  @override
  String get settingsWalletConnectionTileTitle => 'Povezava denarnice';

  @override
  String get settingsWalletConnectionConnected => 'Povezano';

  @override
  String get settingsWalletConnectionNotConnected => 'Ni povezano';

  @override
  String get settingsNetworkTileTitle => 'Omrežje';

  @override
  String settingsCurrentNetworkValue(Object network) {
    return 'Trenutno: $network';
  }

  @override
  String get settingsTransactionHistoryTileTitle => 'Zgodovina transakcij';

  @override
  String get settingsTransactionHistoryTileSubtitle => 'Ogled vseh transakcij';

  @override
  String get settingsBackupSettingsTileTitle => 'Nastavitve varnostnega kopiranja';

  @override
  String settingsAutoBackupSummary(Object status) {
    return 'Samodejna varnostna kopija: $status';
  }

  @override
  String get settingsExportRecoveryPhraseTileTitle => 'Izvozi obnovitveno frazo';

  @override
  String get settingsExportRecoveryPhraseTileSubtitle => 'Varnostno kopirajte denarnico (občutljivo)';

  @override
  String get settingsImportWalletTileTitle => 'Uvozi obstoječo denarnico (napredno)';

  @override
  String get settingsImportWalletTileSubtitle => 'Uporabite obnovitveno frazo, ki jo že imate';

  @override
  String get settingsSecurityPrivacySectionTitle => 'Varnost in zasebnost';

  @override
  String get settingsBiometricTileTitle => 'Biometrično preverjanje';

  @override
  String get settingsBiometricTileSubtitle => 'Uporabite prstni odtis ali prepoznavo obraza';

  @override
  String get settingsSetPinTileTitle => 'Nastavi PIN aplikacije';

  @override
  String get settingsSetPinTileSubtitle => 'Zaščitite aplikacijo s številčnim PIN-om';

  @override
  String get settingsAutoLockTileTitle => 'Samodejno zaklepanje';

  @override
  String get settingsAutoLockTileSubtitle => 'Zakleni aplikacijo po neaktivnosti';

  @override
  String get settingsPrivacyModeTileTitle => 'Način zasebnosti';

  @override
  String get settingsPrivacyModeTileSubtitle => 'Skrij občutljive informacije';

  @override
  String get settingsClearCacheTileTitle => 'Počisti predpomnilnik';

  @override
  String get settingsClearCacheTileSubtitle => 'Odstrani začasne datoteke';

  @override
  String get settingsDataAnalyticsSectionTitle => 'Podatki in analitika';

  @override
  String get settingsAnalyticsTileTitle => 'Analitika';

  @override
  String get settingsAnalyticsTileSubtitle => 'Pomagajte izboljšati aplikacijo';

  @override
  String get settingsCrashReportingTileTitle => 'Poročanje o zrušitvah';

  @override
  String get settingsCrashReportingTileSubtitle => 'Samodejno pošlji poročila o zrušitvah';

  @override
  String get settingsSkipOnboardingTileTitle => 'Preskoči uvod';

  @override
  String get settingsSkipOnboardingTileSubtitle => 'Preskoči pozdravne zaslone za vračajoče uporabnike';

  @override
  String get settingsDataExportTileTitle => 'Izvoz podatkov';

  @override
  String get settingsDataExportTileSubtitle => 'Prenesite svoje podatke';

  @override
  String get settingsResetPermissionFlagsTileTitle => 'Ponastavi zastavice dovoljenj';

  @override
  String get settingsResetPermissionFlagsTileSubtitle => 'Počisti shranjene pozive za dovoljenja/storitve';

  @override
  String get settingsAboutSectionTitle => 'O aplikaciji';

  @override
  String get settingsAboutVersionTileTitle => 'Različica';

  @override
  String get settingsAboutTermsTileTitle => 'Pogoji uporabe';

  @override
  String get settingsAboutTermsTileSubtitle => 'Preberite pogoje';

  @override
  String get settingsAboutPrivacyTileTitle => 'Pravilnik o zasebnosti';

  @override
  String get settingsAboutPrivacyTileSubtitle => 'Preberite naš pravilnik';

  @override
  String get settingsAboutSupportTileTitle => 'Podpora';

  @override
  String get settingsAboutSupportTileSubtitle => 'Pomoč ali prijava težav';

  @override
  String get settingsAboutLicensesTileTitle => 'Licence odprtokodnih komponent';

  @override
  String get settingsAboutLicensesTileSubtitle => 'Ogled licenc tretjih oseb';

  @override
  String get settingsAboutRateTileTitle => 'Oceni aplikacijo';

  @override
  String get settingsAboutRateTileSubtitle => 'Ocenite nas v trgovini';

  @override
  String get settingsDangerZoneSectionTitle => 'Nevarno območje';

  @override
  String get settingsLogoutTileTitle => 'Odjava';

  @override
  String get settingsLogoutTileSubtitle => 'Odklopi denarnico in počisti sejo';

  @override
  String get settingsResetAppTileTitle => 'Ponastavi aplikacijo';

  @override
  String get settingsResetAppTileSubtitle => 'Počisti vse podatke in nastavitve';

  @override
  String get settingsDeleteAccountTileTitle => 'Izbriši račun';

  @override
  String get settingsDeleteAccountTileSubtitle => 'Trajno izbrišite svoj račun';

  @override
  String get settingsSelectNetworkDialogTitle => 'Izberite omrežje';

  @override
  String get settingsNetworkMainnetDescription => 'Živo omrežje Solana';

  @override
  String get settingsNetworkDevnetDescription => 'Razvojno omrežje za testiranje';

  @override
  String get settingsNetworkTestnetDescription => 'Testno omrežje za razvoj';

  @override
  String settingsSwitchedToNetworkToast(Object network) {
    return 'Preklopljeno na $network';
  }

  @override
  String get settingsConnectWalletFirstToast => 'Najprej povežite denarnico';

  @override
  String get settingsBackupWalletDialogTitle => 'Varnostna kopija denarnice';

  @override
  String get settingsBackupWalletDialogIntro => 'To bo prikazalo vašo obnovitveno frazo.';

  @override
  String get settingsSecurityWarningTitle => 'Varnostno opozorilo';

  @override
  String get settingsSecurityWarningBullets => '• Poskrbite, da ste na zasebnem mestu\n• Nikoli ne delite obnovitvene fraze\n• Zapišite jo in jo varno shranite';

  @override
  String get settingsConnectOrCreateWalletFirstToast => 'Najprej povežite ali ustvarite denarnico.';

  @override
  String get settingsAutoLock10Seconds => '10 sekund';

  @override
  String get settingsAutoLock30Seconds => '30 sekund';

  @override
  String get settingsAutoLock1Minute => '1 minuta';

  @override
  String get settingsAutoLock5Minutes => '5 minut';

  @override
  String get settingsAutoLock15Minutes => '15 minut';

  @override
  String get settingsAutoLock30Minutes => '30 minut';

  @override
  String get settingsAutoLock1Hour => '1 ura';

  @override
  String get settingsAutoLock3Hours => '3 ure';

  @override
  String get settingsAutoLock6Hours => '6 ur';

  @override
  String get settingsAutoLock12Hours => '12 ur';

  @override
  String get settingsAutoLock1Day => '1 dan';

  @override
  String get settingsAutoLockNever => 'Nikoli';

  @override
  String get settingsAutoLockTimerDialogTitle => 'Časovnik samodejnega zaklepa';

  @override
  String settingsAutoLockSetToToast(Object value) {
    return 'Samodejni zaklep nastavljen na $value';
  }

  @override
  String get settingsBiometricUnavailableToast => 'Biometrično odklepanje na tej napravi ni na voljo.';

  @override
  String get settingsBiometricFailedToast => 'Biometrično preverjanje ni uspelo.';

  @override
  String get settingsExportRecoveryPhraseDialogTitle => 'Izvozi obnovitveno frazo';

  @override
  String get settingsExportRecoveryPhraseDialogBody => 'Frazo si oglejte samo v zasebnosti. Nikoli je ne shranjujemo in vsak, ki jo ima, lahko premakne vaša sredstva.';

  @override
  String get settingsExportRecoveryPhraseDialogConfirm => 'Potrdite, da ste pripravljeni, preden prikažemo besede.';

  @override
  String get settingsShowPhraseButton => 'Prikaži frazo';

  @override
  String get settingsImportWalletDialogTitle => 'Uvozi obstoječo denarnico';

  @override
  String get settingsImportWalletDialogBody => 'Obnovitveno frazo vnesite le iz zaupanja vrednega vira. Med uvozom se izogibajte javnemu Wi‑Fi-ju in deljenju zaslona.';

  @override
  String get settingsImportWalletDialogConfirm => 'Fraze nikoli ne shranjujemo. Vi ohranite popolno lastništvo svojih sredstev.';

  @override
  String get settingsSetPinDialogTitle => 'Nastavi PIN aplikacije';

  @override
  String get settingsConfirmPinLabel => 'Potrdi PIN';

  @override
  String get settingsPinClearedToast => 'PIN je počiščen';

  @override
  String get settingsClearPinButton => 'Počisti PIN';

  @override
  String get settingsPinMinLengthError => 'PIN mora imeti vsaj 4 številke';

  @override
  String get settingsPinMismatchError => 'PIN-a se ne ujemata';

  @override
  String get settingsPinSetSuccessToast => 'PIN je uspešno nastavljen';

  @override
  String get settingsPinSetFailedToast => 'PIN ni bilo mogoče nastaviti';

  @override
  String get settingsClearCacheDialogTitle => 'Počisti predpomnilnik';

  @override
  String get settingsClearCacheDialogBody => 'To bo počistilo začasne datoteke in lahko izboljša delovanje.';

  @override
  String get settingsCacheClearedToast => 'Predpomnilnik je uspešno počiščen';

  @override
  String get settingsClearButton => 'Počisti';

  @override
  String get settingsResetPermissionFlagsDialogTitle => 'Ponastavi zastavice dovoljenj';

  @override
  String get settingsResetPermissionFlagsDialogBody => 'To bo počistilo shranjene zastavice pozivov za dovoljenja in storitve. Uporabite, če želite ponovno sprožiti pozive za dovoljenja.';

  @override
  String get settingsPermissionFlagsResetToast => 'Zastavice dovoljenj so ponastavljene';

  @override
  String get settingsResetButton => 'Ponastavi';

  @override
  String get settingsExportDataDialogTitle => 'Izvoz podatkov';

  @override
  String get settingsExportDataDialogBody => 'To bo ustvarilo datoteko z vašimi podatki aplikacije (brez zasebnih ključev).';

  @override
  String settingsDataExportedToast(Object count) {
    return 'Podatki izvoženi: $count kategorij';
  }

  @override
  String get settingsExportButton => 'Izvozi';

  @override
  String get settingsResetAppDialogTitle => 'Ponastavi aplikacijo';

  @override
  String get settingsResetAppDialogBody => 'To bo počistilo vse podatke in nastavitve. Denarnica bo odklopljena, ne pa izbrisana.';

  @override
  String get settingsAppResetSuccessToast => 'Aplikacija je uspešno ponastavljena. Prosimo, ponovno jo zaženite.';

  @override
  String get settingsDeleteAccountDialogTitle => 'Izbriši račun';

  @override
  String get settingsDeleteAccountDialogBody => 'Odstranili bomo vaš profil in podatke skupnosti s strežnikov. Denarnica ostane vaša in bo še vedno delovala.';

  @override
  String get settingsFinalConfirmationTitle => 'Končna potrditev';

  @override
  String get settingsDeleteAccountFinalConfirmationBody => 'Ste popolnoma prepričani, da želite izbrisati račun? Tega dejanja ni mogoče razveljaviti.';

  @override
  String get settingsConfirmButton => 'Potrdi';

  @override
  String get settingsDeleteAccountBackendFailedToast => 'Brisanje na strežniku ni uspelo. Poskusite znova.';

  @override
  String get settingsAccountDeletedToast => 'Račun je izbrisan. Vsi podatki so odstranjeni.';

  @override
  String get settingsDeleteForeverButton => 'Izbriši za vedno';

  @override
  String get settingsEnableNotificationsInSystemToast => 'Za prejemanje obvestil jih omogočite v sistemskih nastavitvah.';

  @override
  String get settingsLogoutDialogTitle => 'Odjava';

  @override
  String get settingsLogoutDialogBody => 'Odklopim denarnico in počistim sejo na tej napravi?';

  @override
  String get settingsLogoutButton => 'Odjava';

  @override
  String get settingsTransactionHistoryDialogTitle => 'Zgodovina transakcij';

  @override
  String get settingsRecentTransactionsTitle => 'Nedavne transakcije';

  @override
  String get settingsNoTransactionsTitle => 'Ni transakcij';

  @override
  String get settingsNoTransactionsDescription => 'Vaša zgodovina transakcij se bo prikazala tukaj, ko boste začeli izvajati transakcije.';

  @override
  String get settingsTxReceivedLabel => 'Prejeto';

  @override
  String get settingsTxSentLabel => 'Poslano';

  @override
  String get settingsTxFromLabel => 'Od';

  @override
  String get settingsTxToLabel => 'Za';

  @override
  String settingsTxFromToLabel(Object directionLabel, Object addressPrefix) {
    return '$directionLabel: $addressPrefix...';
  }

  @override
  String get settingsAppVersionDialogTitle => 'Različica aplikacije';

  @override
  String settingsVersionValue(Object version) {
    return 'Različica: $version';
  }

  @override
  String settingsBuildValue(Object build) {
    return 'Build: $build';
  }

  @override
  String get settingsAllRightsReserved => 'Vse pravice pridržane.';

  @override
  String settingsCopyright(Object year) {
    return '© $year kubus';
  }

  @override
  String get settingsTermsDialogTitle => 'Pogoji uporabe';

  @override
  String get settingsTermsDialogBody => 'Z uporabo art.kubus se strinjate s temi pogoji:\n\n1. Odgovorni ste za varnost svoje denarnice.\n2. Ne shranjujemo vaših zasebnih ključev ali obnovitvenih fraz.\n3. Vse transakcije so dokončne in nepovratne.\n4. Aplikacijo uporabljate na lastno odgovornost.\n5. Pridržujemo si pravico do posodobitve teh pogojev.\n\nZa celotne pogoje obiščite našo spletno stran.';

  @override
  String get settingsPrivacyPolicyDialogTitle => 'Pravilnik o zasebnosti';

  @override
  String get settingsPrivacyPolicyDialogBody => 'Vaša zasebnost nam je pomembna:\n\n• Osebnih podatkov ne zbiramo brez soglasja\n• Podatki denarnice so shranjeni lokalno na napravi\n• Lahko zbiramo anonimno statistiko uporabe\n• Podatkov ne delimo s tretjimi osebami\n• Analitiko lahko izključite v nastavitvah zasebnosti\n\nZa celoten pravilnik obiščite našo spletno stran.';

  @override
  String get settingsSupportDialogTitle => 'Podpora';

  @override
  String get settingsSupportDialogBody => 'Potrebujete pomoč? Izberite možnost:';

  @override
  String get settingsOpeningFaqToast => 'Odpiram FAQ…';

  @override
  String get settingsViewFaqButton => 'Ogled FAQ';

  @override
  String get settingsOpeningEmailClientToast => 'Odpiram e‑poštni odjemalec…';

  @override
  String get settingsContactSupportButton => 'Kontaktiraj podporo';

  @override
  String get settingsLicensesDialogTitle => 'Licence odprtokodnih komponent';

  @override
  String get settingsLicensesDialogBody => 'Ta aplikacija uporablja naslednje odprtokodne knjižnice:\n\n• Flutter SDK (BSD licenca)\n• Material Design Icons (Apache 2.0)\n• SharedPreferences (BSD licenca)\n• HTTP (BSD licenca)\n• Path Provider (BSD licenca)\n\nCelotna besedila licenc so na voljo v repozitoriju aplikacije.';

  @override
  String get settingsRateAppDialogTitle => 'Oceni art.kubus';

  @override
  String get settingsRateAppDialogBodyTitle => 'Uživate v aplikaciji?';

  @override
  String get settingsRateAppDialogBodySubtitle => 'Prosimo, ocenite nas v trgovini z aplikacijami!';

  @override
  String get settingsMaybeLaterButton => 'Mogoče pozneje';

  @override
  String get settingsOpeningAppStoreToast => 'Odpiram trgovino…';

  @override
  String get settingsRateNowButton => 'Oceni zdaj';

  @override
  String get settingsChangePasswordDialogTitle => 'Spremeni geslo';

  @override
  String get settingsCurrentPasswordLabel => 'Trenutno geslo';

  @override
  String get settingsNewPasswordLabel => 'Novo geslo';

  @override
  String get settingsConfirmNewPasswordLabel => 'Potrdi novo geslo';

  @override
  String get settingsPasswordUpdatedToast => 'Geslo je uspešno posodobljeno';

  @override
  String get settingsUpdateButton => 'Posodobi';

  @override
  String get settingsDeactivateAccountDialogTitle => 'Deaktiviraj račun';

  @override
  String get settingsDeactivateAccountDialogBodyTitle => 'Ste prepričani, da želite deaktivirati račun?';

  @override
  String get settingsDeactivateAccountDialogBodySubtitle => 'Kasneje ga lahko ponovno aktivirate s prijavo.';

  @override
  String get settingsAccountDeactivatedToast => 'Račun je deaktiviran';

  @override
  String get settingsDeactivateButton => 'Deaktiviraj';

  @override
  String get settingsProfileVisibilityDialogTitle => 'Vidnost profila';

  @override
  String settingsProfileVisibilitySetToast(Object value) {
    return 'Vidnost profila nastavljena na $value';
  }

  @override
  String get settingsPrivacySettingsDialogTitle => 'Nastavitve zasebnosti';

  @override
  String get settingsPrivacyDataCollectionTitle => 'Zbiranje podatkov';

  @override
  String get settingsPrivacyDataCollectionSubtitle => 'Dovoli zbiranje podatkov o uporabi';

  @override
  String get settingsPrivacyPersonalizedAdsTitle => 'Personalizirani oglasi';

  @override
  String get settingsPrivacyPersonalizedAdsSubtitle => 'Prikaži oglase glede na interese';

  @override
  String get settingsPrivacyLocationTrackingTitle => 'Sledenje lokaciji';

  @override
  String get settingsPrivacyLocationTrackingSubtitle => 'Dovoli funkcije na podlagi lokacije';

  @override
  String get settingsPrivacyDataRetentionTitle => 'Hramba podatkov';

  @override
  String get settingsPrivacyDataRetentionSubtitle => 'Kako dolgo hraniti vaše podatke';

  @override
  String get settingsRetention3Months => '3 mesece';

  @override
  String get settingsRetention6Months => '6 mesecev';

  @override
  String get settingsRetention1Year => '1 leto';

  @override
  String get settingsRetention2Years => '2 leti';

  @override
  String get settingsRetentionIndefinite => 'Nedoločno';

  @override
  String get settingsPrivacySettingsUpdatedToast => 'Nastavitve zasebnosti posodobljene';

  @override
  String get settingsSecuritySettingsDialogTitle => 'Varnostne nastavitve';

  @override
  String get settingsChangePasswordTileTitle => 'Spremeni geslo';

  @override
  String get settingsChangePasswordTileSubtitle => 'Posodobite geslo računa';

  @override
  String get settingsTwoFactorTitle => 'Dvostopenjska avtentikacija';

  @override
  String get settingsTwoFactorSubtitle => 'Dodajte dodatno zaščito računu';

  @override
  String get settingsSessionTimeoutTitle => 'Časovna omejitev seje';

  @override
  String get settingsSessionTimeoutSubtitle => 'Samodejna odjava ob neaktivnosti';

  @override
  String get settingsAutoLockTimeTitle => 'Čas samodejnega zaklepa';

  @override
  String get settingsAutoLockTimeSubtitle => 'Zakleni aplikacijo po neaktivnosti';

  @override
  String get settingsLoginNotificationsTitle => 'Obvestila o prijavi';

  @override
  String get settingsLoginNotificationsSubtitle => 'Obvestila ob novih prijavah';

  @override
  String get settingsSecuritySettingsUpdatedToast => 'Varnostne nastavitve posodobljene';

  @override
  String get settingsAccountManagementDialogTitle => 'Upravljanje računa';

  @override
  String get settingsEmailNotificationsTitle => 'E‑poštna obvestila';

  @override
  String get settingsEmailNotificationsSubtitle => 'Prejemajte posodobitve prek e‑pošte';

  @override
  String get settingsPushNotificationsTitle => 'Potisna obvestila';

  @override
  String get settingsPushNotificationsSubtitle => 'Obvestila na napravi';

  @override
  String get settingsMarketingEmailsTitle => 'Marketinška e‑pošta';

  @override
  String get settingsMarketingEmailsSubtitle => 'Prejemajte promocijsko vsebino';

  @override
  String get settingsAccountTypeTitle => 'Vrsta računa';

  @override
  String get settingsAccountTypeSubtitle => 'Vaša trenutna raven članstva';

  @override
  String get settingsAccountTypeStandard => 'Standard';

  @override
  String get settingsAccountTypePremium => 'Premium';

  @override
  String get settingsAccountTypeEnterprise => 'Enterprise';

  @override
  String get settingsPublicProfileTitle => 'Javni profil';

  @override
  String get settingsPublicProfileSubtitle => 'Dovoli drugim, da najdejo vaš profil';

  @override
  String get settingsDeactivateAccountTileTitle => 'Deaktiviraj račun';

  @override
  String get settingsDeactivateAccountTileSubtitle => 'Začasno onemogoči račun';

  @override
  String get settingsAccountSettingsUpdatedToast => 'Nastavitve računa posodobljene';

  @override
  String commonStepOfTotal(Object current, Object total) {
    return '$current od $total';
  }

  @override
  String get web3OnboardingKeyFeaturesTitle => 'Ključne funkcije:';

  @override
  String get web3FeatureWeb3Title => 'Neobvezne funkcije z denarnico (Web3)';

  @override
  String get web3FeatureMarketplaceTitle => 'Tržnica zbirateljskih predmetov (NFT)';

  @override
  String get web3FeatureArtistStudioTitle => 'Umetniški studio';

  @override
  String get web3FeatureInstitutionHubTitle => 'Središče za institucije';

  @override
  String get web3FeatureGovernanceTitle => 'Skupnostno odločanje (DAO)';

  @override
  String get web3DaoP1Title => 'Dobrodošli v skupnostnem odločanju';

  @override
  String get web3DaoP1Description => 'Sodelujte pri skupnostnem odločanju za ekosistem art.kubus. Vaš glas pomaga oblikovati platformo.';

  @override
  String get web3DaoP1Feature1 => 'Glasujte o skupnostnih predlogih';

  @override
  String get web3DaoP1Feature2 => 'Ustvarite in oddajte predloge';

  @override
  String get web3DaoP1Feature3 => 'Za sodelovanje prejmite KUB8 točke';

  @override
  String get web3DaoP1Feature4 => 'Razpravljajte in sodelujte z drugimi';

  @override
  String get web3DaoP2Title => 'Vaša glasovalna teža';

  @override
  String get web3DaoP2Description => 'Vaša glasovalna teža lahko odraža vaš napredek v Sezoni 0 (KUB8 točke). Brez finančne vrednosti — gre za sodelovanje in priznanje.';

  @override
  String get web3DaoP2Feature1 => 'Glasovalna teža lahko sledi vašim KUB8 točkam';

  @override
  String get web3DaoP2Feature2 => 'Glasujte o aktivnih predlogih';

  @override
  String get web3DaoP2Feature3 => 'Spremljajte rezultate v živo';

  @override
  String get web3DaoP2Feature4 => 'Spremljajte zgodovino sodelovanja';

  @override
  String get web3DaoP3Title => 'Ustvarite predloge';

  @override
  String get web3DaoP3Description => 'Imate idejo za izboljšavo platforme? Oddajte predloge za funkcije, pravila ali skupnostne pobude.';

  @override
  String get web3DaoP3Feature1 => 'Napišite jasne predloge s kontekstom';

  @override
  String get web3DaoP3Feature2 => 'Izberite trajanje glasovanja in pogoje';

  @override
  String get web3DaoP3Feature3 => 'Zberite podporo skupnosti';

  @override
  String get web3DaoP3Feature4 => 'Spremljajte stanje in razpravo';

  @override
  String get web3DaoP4Title => 'Pripravljeni na sodelovanje';

  @override
  String get web3DaoP4Description => 'Vse je pripravljeno. Raziščite aktivne predloge ali ustvarite svojega, ko boste pripravljeni.';

  @override
  String get web3DaoP4Feature1 => 'Brskajte in glasujte o predlogih';

  @override
  String get web3DaoP4Feature2 => 'Preglejte zgodovino glasovanj';

  @override
  String get web3DaoP4Feature3 => 'Oglejte si aktivnost odločanja';

  @override
  String get web3DaoP4Feature4 => 'Sodelujte s skupnostjo';

  @override
  String get web3ArtistStudioP1Title => 'Dobrodošli v umetniškem studiu';

  @override
  String get web3ArtistStudioP1Description => 'Vaš delovni prostor za upravljanje umetnin, ustvarjanje AR označevalcev in spremljanje napredka.';

  @override
  String get web3ArtistStudioP1Feature1 => 'Upravljajte svojo zbirko umetnin';

  @override
  String get web3ArtistStudioP1Feature2 => 'Ustvarjajte interaktivne AR označevalce';

  @override
  String get web3ArtistStudioP1Feature3 => 'Spremljajte vpoglede v uspešnost';

  @override
  String get web3ArtistStudioP1Feature4 => 'Predstavite in delite s skupnostjo';

  @override
  String get web3ArtistStudioP2Title => 'Galerija umetnin';

  @override
  String get web3ArtistStudioP2Description => 'Predstavite svoje stvaritve in zbirateljske predmete (NFT). Naložite, organizirajte in prikažite svoje umetnine.';

  @override
  String get web3ArtistStudioP2Feature1 => 'Naložite in organizirajte umetnine';

  @override
  String get web3ArtistStudioP2Feature2 => 'Dodajte naslove in opise';

  @override
  String get web3ArtistStudioP2Feature3 => 'Izberite vidnost in razpoložljivost';

  @override
  String get web3ArtistStudioP2Feature4 => 'Spremljajte oglede in odziv';

  @override
  String get web3ArtistStudioP3Title => 'Ustvarjalnik AR označevalcev';

  @override
  String get web3ArtistStudioP3Description => 'Spremenite umetnine v AR izkušnje. Postavite označevalce v resničnih lokacijah, da jih drugi odkrijejo.';

  @override
  String get web3ArtistStudioP3Feature1 => 'Ustvarite geo-locirane označevalce';

  @override
  String get web3ArtistStudioP3Feature2 => 'Povežite umetnine z lokacijami';

  @override
  String get web3ArtistStudioP3Feature3 => 'Dodajte nagrade za odkritja (KUB8 točke)';

  @override
  String get web3ArtistStudioP3Feature4 => 'Spremljajte interakcije z označevalci';

  @override
  String get web3ArtistStudioP4Title => 'Nadzorna plošča vpogledov';

  @override
  String get web3ArtistStudioP4Description => 'Spremljajte uspešnost z vpogledi v oglede, odkritja in odziv skupnosti.';

  @override
  String get web3ArtistStudioP4Feature1 => 'Spremljajte uspešnost umetnin';

  @override
  String get web3ArtistStudioP4Feature2 => 'Spremljajte napredek KUB8 točk';

  @override
  String get web3ArtistStudioP4Feature3 => 'Oglejte si vzorce odkritij';

  @override
  String get web3ArtistStudioP4Feature4 => 'Izvozite poročila';

  @override
  String get web3ArtistStudioP5Title => 'Začnite ustvarjati';

  @override
  String get web3ArtistStudioP5Description => 'Vaš studio je pripravljen. Naložite prvo umetnino ali ustvarite AR označevalec in delite s skupnostjo.';

  @override
  String get web3ArtistStudioP5Feature1 => 'Naložite prvo umetnino';

  @override
  String get web3ArtistStudioP5Feature2 => 'Ustvarite prvi AR označevalec';

  @override
  String get web3ArtistStudioP5Feature3 => 'Raziščite stvaritve skupnosti';

  @override
  String get web3ArtistStudioP5Feature4 => 'Začnite zbirati KUB8 točke';

  @override
  String get web3InstitutionHubP1Title => 'Dobrodošli v središču za institucije';

  @override
  String get web3InstitutionHubP1Description => 'Upravljajte dogodke, razstave in izobraževalne programe. Povežite institucijo z umetniško skupnostjo.';

  @override
  String get web3InstitutionHubP1Feature1 => 'Ustvarjajte in upravljajte dogodke';

  @override
  String get web3InstitutionHubP1Feature2 => 'Gostite razstave';

  @override
  String get web3InstitutionHubP1Feature3 => 'Povežite se s skupnostjo';

  @override
  String get web3InstitutionHubP1Feature4 => 'Spremljajte doseg in odziv';

  @override
  String get web3InstitutionHubP2Title => 'Upravljanje dogodkov';

  @override
  String get web3InstitutionHubP2Description => 'Organizirajte razstave, delavnice in dogodke. Upravljajte urnik, prijave in obvestila.';

  @override
  String get web3InstitutionHubP2Feature1 => 'Načrtujte razstave in delavnice';

  @override
  String get web3InstitutionHubP2Feature2 => 'Upravljajte prijave';

  @override
  String get web3InstitutionHubP2Feature3 => 'Pošiljajte obvestila udeležencem';

  @override
  String get web3InstitutionHubP2Feature4 => 'Spremljajte obisk in odziv';

  @override
  String get web3InstitutionHubP3Title => 'Orodja za ustvarjanje dogodkov';

  @override
  String get web3InstitutionHubP3Description => 'Ustvarite strani dogodkov z opisi in mediji, da se ljudje lažje pridružijo.';

  @override
  String get web3InstitutionHubP3Feature1 => 'Oblikujte strani dogodkov z mediji';

  @override
  String get web3InstitutionHubP3Feature2 => 'Nastavite kapaciteto in prijavo';

  @override
  String get web3InstitutionHubP3Feature3 => 'Ustvarite promocijske materiale';

  @override
  String get web3InstitutionHubP3Feature4 => 'Povežite s koledarji';

  @override
  String get web3InstitutionHubP4Title => 'Analitika in vpogledi';

  @override
  String get web3InstitutionHubP4Description => 'Merite uspešnost z vpogledi v obisk, odziv in vpliv na skupnost.';

  @override
  String get web3InstitutionHubP4Feature1 => 'Spremljajte obisk in odziv';

  @override
  String get web3InstitutionHubP4Feature2 => 'Spremljajte zanimanje skupnosti';

  @override
  String get web3InstitutionHubP4Feature3 => 'Analizirajte povratne informacije';

  @override
  String get web3InstitutionHubP4Feature4 => 'Izvozite poročila';

  @override
  String get web3InstitutionHubP5Title => 'Objavite svoje dogodke';

  @override
  String get web3InstitutionHubP5Description => 'Ste pripravljeni na povezovanje s skupnostjo? Ustvarite prvi dogodek ali raziščite aktualne razstave.';

  @override
  String get web3InstitutionHubP5Feature1 => 'Ustvarite prvi dogodek';

  @override
  String get web3InstitutionHubP5Feature2 => 'Raziščite dogodke skupnosti';

  @override
  String get web3InstitutionHubP5Feature3 => 'Povežite se z drugimi institucijami';

  @override
  String get web3InstitutionHubP5Feature4 => 'Zgradite kulturno mrežo';

  @override
  String get web3MarketplaceP1Title => 'Dobrodošli na tržnici';

  @override
  String get web3MarketplaceP1Description => 'Odkrijte, kupite ali prodajte zbirateljske predmete (NFT). Povežite se z ustvarjalci in zbiratelji.';

  @override
  String get web3MarketplaceP1Feature1 => 'Brskajte po zbirateljskih predmetih';

  @override
  String get web3MarketplaceP1Feature2 => 'Kupujte in prodajajte varno';

  @override
  String get web3MarketplaceP1Feature3 => 'Odkrijte izpostavljene umetnine';

  @override
  String get web3MarketplaceP1Feature4 => 'Podprite ustvarjalce, ki jih spremljate';

  @override
  String get web3MarketplaceP2Title => 'Odkrijte odlično umetnost';

  @override
  String get web3MarketplaceP2Description => 'Raziščite kurirane zbirke in filtrirajte po kategoriji, redkosti in več.';

  @override
  String get web3MarketplaceP2Feature1 => 'Filtrirajte po kategoriji in redkosti';

  @override
  String get web3MarketplaceP2Feature2 => 'Oglejte si podrobnosti umetnin';

  @override
  String get web3MarketplaceP2Feature3 => 'Preverite izvor in avtentičnost';

  @override
  String get web3MarketplaceP2Feature4 => 'Shranjujte priljubljene na seznam želja';

  @override
  String get web3MarketplaceP3Title => 'Objavite svoje stvaritve';

  @override
  String get web3MarketplaceP3Description => 'Ustvarjalci lahko objavijo zbirateljske predmete (NFT). Dodajte podrobnosti ter nastavite ceno in razpoložljivost.';

  @override
  String get web3MarketplaceP3Feature1 => 'Naložite digitalno umetnino';

  @override
  String get web3MarketplaceP3Feature2 => 'Dodajte opise in oznake';

  @override
  String get web3MarketplaceP3Feature3 => 'Nastavite ceno in razpoložljivost';

  @override
  String get web3MarketplaceP3Feature4 => 'Spremljajte zanimanje in aktivnost';

  @override
  String get web3MarketplaceP4Title => 'Začnite raziskovati';

  @override
  String get web3MarketplaceP4Description => 'Pripravljeni ste. Raziščite zbirke, opravite prvi nakup ali objavite svoj prvi predmet.';

  @override
  String get web3MarketplaceP4Feature1 => 'Raziščite izpostavljene zbirke';

  @override
  String get web3MarketplaceP4Feature2 => 'Opravite prvi nakup';

  @override
  String get web3MarketplaceP4Feature3 => 'Objavite predmet za prodajo';

  @override
  String get web3MarketplaceP4Feature4 => 'Pridružite se ustvarjalni skupnosti';

  @override
  String get web3FeaturesP1Title => 'Povežite denarnico (neobvezno)';

  @override
  String get web3FeaturesP1Description => 'Povežite denarnico za neobvezne plasti, kot so zbirateljski predmeti (NFT) in digitalni dokazi obiska (POAP). Osnovna aplikacija deluje tudi brez tega.';

  @override
  String get web3FeaturesP1Feature1 => 'Prijava z denarnico (neobvezno)';

  @override
  String get web3FeaturesP1Feature2 => 'Zbirateljski predmeti (NFT) in digitalni dokazi obiska (POAP)';

  @override
  String get web3FeaturesP1Feature3 => 'Ključi ostanejo v vaši denarnici';

  @override
  String get web3FeaturesP1Feature4 => 'Povezavo lahko prekinete kadarkoli';

  @override
  String get web3FeaturesP2Title => 'Tržnica zbirateljskih predmetov (NFT)';

  @override
  String get web3FeaturesP2Description => 'V neobvezni tržnici brskajte, kupujte in prodajajte zbirateljske predmete (NFT).';

  @override
  String get web3FeaturesP2Feature1 => 'Brskajte po izpostavljenih izdajah';

  @override
  String get web3FeaturesP2Feature2 => 'Iščite po kategoriji in redkosti';

  @override
  String get web3FeaturesP2Feature3 => 'Oglejte si podrobnosti in izvor';

  @override
  String get web3FeaturesP2Feature4 => 'Kupujte in prodajajte varno';

  @override
  String get web3FeaturesP2Feature5 => 'Shranjujte priljubljene za pozneje';

  @override
  String get web3FeaturesP3Title => 'Umetniški studio';

  @override
  String get web3FeaturesP3Description => 'Ustvarjajte in upravljajte digitalne umetnine. Po želji objavite zbirateljske predmete (NFT) in jih delite s skupnostjo.';

  @override
  String get web3FeaturesP3Feature1 => 'Naložite in organizirajte umetnine';

  @override
  String get web3FeaturesP3Feature2 => 'Ustvarjajte AR označevalce';

  @override
  String get web3FeaturesP3Feature3 => 'Po želji objavite zbirateljske predmete (NFT)';

  @override
  String get web3FeaturesP3Feature4 => 'Spremljajte vpoglede in odziv';

  @override
  String get web3FeaturesP3Feature5 => 'Sodelujte z drugimi ustvarjalci';

  @override
  String get web3FeaturesP4Title => 'Skupnostno odločanje (DAO)';

  @override
  String get web3FeaturesP4Description => 'Glasujte o predlogih in skupaj usmerjajte platformo.';

  @override
  String get web3FeaturesP4Feature1 => 'Glasujte o predlogih';

  @override
  String get web3FeaturesP4Feature2 => 'Oddajte predloge izboljšav';

  @override
  String get web3FeaturesP4Feature3 => 'Za sodelovanje prejmite KUB8 točke';

  @override
  String get web3FeaturesP4Feature4 => 'Spremljajte razprave in rezultate';

  @override
  String get web3FeaturesP4Feature5 => 'Sooblikujte smernice skupnosti';

  @override
  String get web3FeaturesP5Title => 'Središče za institucije';

  @override
  String get web3FeaturesP5Description => 'Povežite se z galerijami in kulturnimi institucijami ter gostite dogodke in razstave.';

  @override
  String get web3FeaturesP5Feature1 => 'Povežite se s preverjenimi institucijami';

  @override
  String get web3FeaturesP5Feature2 => 'Gostite dogodke in razstave';

  @override
  String get web3FeaturesP5Feature3 => 'Skupaj kurirajte zbirke';

  @override
  String get web3FeaturesP5Feature4 => 'Orodja za profesionalno mreženje';

  @override
  String get web3FeaturesP5Feature5 => 'Orodja prilagojena institucijam';

  @override
  String get web3FeaturesP6Title => 'KUB8 točke (Sezona 0)';

  @override
  String get web3FeaturesP6Description => 'KUB8 točke so neprenosljive sezonske točke: napredek, ugled in odklenitve. Ne gre za valuto.';

  @override
  String get web3FeaturesP6Feature1 => 'Točke pridobivate z sodelovanjem in odkritji';

  @override
  String get web3FeaturesP6Feature2 => 'Spremljajte napredek skozi sezono';

  @override
  String get web3FeaturesP6Feature3 => 'Odklenite značke in priznanja';

  @override
  String get web3FeaturesP6Feature4 => 'Nagrade so dostop in priznanje';

  @override
  String get web3FeaturesP6Feature5 => 'Neprenosljive sezonske točke';

  @override
  String get commonApply => 'Uveljavi';

  @override
  String get commonView => 'Poglej';

  @override
  String get commonViewDetails => 'Poglej podrobnosti';

  @override
  String get commonContinueExploring => 'Nadaljuj z raziskovanjem';

  @override
  String commonByArtist(Object artist) {
    return 'od $artist';
  }

  @override
  String commonKub8PointsReward(Object points) {
    return '+$points KUB8 točk';
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
    return '$percent% dokončano';
  }

  @override
  String get commonCollapse => 'Skrči';

  @override
  String get commonExpand => 'Razširi';

  @override
  String get mapNearbyRadiusTitle => 'Radij bližine';

  @override
  String mapNearbyRadiusTooltip(Object radiusKm) {
    return 'Radij bližine ($radiusKm km)';
  }

  @override
  String get mapArArtworkNearbyTitle => 'AR umetnina v bližini!';

  @override
  String mapArArtworkNearbySubtitle(Object name, Object distanceMeters) {
    return '$name · $distanceMeters m stran';
  }

  @override
  String get mapFailedToLaunchAr => 'AR ni bilo mogoče zagnati.';

  @override
  String get mapMarkerCreatedToast => 'Označevalec je ustvarjen.';

  @override
  String get mapMarkerCreateFailedToast => 'Označevalca ni bilo mogoče ustvariti. Poskusite znova.';

  @override
  String get mapMarkerCreateWalletRequired => 'Povežite denarnico in ustvarite AR-pripravljeno umetnino, da postavite označevalec.';

  @override
  String get mapMarkerCreateNoArArtworks => 'Za vašo denarnico ni AR-pripravljenih umetnin. Najprej ustvarite eno, nato postavite označevalec.';

  @override
  String get mapMarkerDialogTitle => 'Ustvari označevalec';

  @override
  String get mapMarkerDialogRefreshSubjectsTooltip => 'Osveži predmete';

  @override
  String get mapMarkerDialogAttachHint => 'Na to lokacijo pripnite obstoječi predmet in AR sredstvo.';

  @override
  String get mapMarkerDialogSubjectTypeLabel => 'Vrsta predmeta';

  @override
  String mapMarkerDialogSubjectRequiredLabel(Object subject) {
    return '$subject *';
  }

  @override
  String mapMarkerDialogMarkerForTitle(Object title) {
    return 'Označevalec za $title';
  }

  @override
  String mapMarkerDialogNoSubjectsAvailable(Object subjectType) {
    return 'Ni na voljo: $subjectType. Najprej ustvarite enega.';
  }

  @override
  String get mapMarkerDialogMiscHint => 'Označevalci »Razno« ne potrebujejo povezanega predmeta. Spodaj vnesite naslov in opis.';

  @override
  String get mapMarkerDialogLinkedArAssetTitle => 'Povezano AR sredstvo';

  @override
  String get mapMarkerDialogNoArEnabledArtworksHint => 'Ni AR-omogočenih umetnin. Najprej ustvarite eno.';

  @override
  String get mapMarkerDialogMarkerTitleLabel => 'Naslov označevalca *';

  @override
  String get mapMarkerDialogDescriptionLabel => 'Opis *';

  @override
  String get mapMarkerDialogCategoryLabel => 'Kategorija';

  @override
  String get mapMarkerDialogMarkerLayerLabel => 'Sloj označevalca';

  @override
  String get mapMarkerDialogPublicMarkerTitle => 'Javni označevalec';

  @override
  String get mapMarkerDialogPublicMarkerSubtitle => 'Viden vsem raziskovalcem na zemljevidu';

  @override
  String get mapMarkerDialogLatitudeLabel => 'Zemljepisna širina *';

  @override
  String get mapMarkerDialogLongitudeLabel => 'Zemljepisna dolžina *';

  @override
  String get mapMarkerDialogUseMapCenterButton => 'Uporabi središče zemljevida';

  @override
  String get mapMarkerDialogCreateButton => 'Ustvari označevalec';

  @override
  String get mapMarkerDialogSelectSubjectToast => 'Za nadaljevanje izberite predmet';

  @override
  String get mapMarkerDialogSelectArArtworkToast => 'Izberite AR-omogočeno umetnino za povezavo';

  @override
  String get mapMarkerDialogEnterTitleError => 'Vnesite naslov';

  @override
  String mapMarkerDialogTitleMinLengthError(Object min) {
    return 'Naslov mora imeti vsaj $min znake';
  }

  @override
  String get mapMarkerDialogEnterDescriptionError => 'Vnesite opis';

  @override
  String mapMarkerDialogDescriptionMinLengthError(Object min) {
    return 'Opis mora imeti vsaj $min znakov';
  }

  @override
  String get mapMarkerDialogValidLatitudeError => 'Vnesite veljavno zemljepisno širino';

  @override
  String get mapMarkerDialogValidLongitudeError => 'Vnesite veljavno zemljepisno dolžino';

  @override
  String get mapMarkerSubjectTypeArtwork => 'Umetnina';

  @override
  String get mapMarkerSubjectTypeExhibition => 'Razstava';

  @override
  String get mapMarkerSubjectTypeInstitution => 'Institucija';

  @override
  String get mapMarkerSubjectTypeEvent => 'Dogodek';

  @override
  String get mapMarkerSubjectTypeGroup => 'Skupina';

  @override
  String get mapMarkerSubjectTypeMisc => 'Razno';

  @override
  String get mapMarkerLayerArtwork => 'Umetnina';

  @override
  String get mapMarkerLayerInstitution => 'Institucija';

  @override
  String get mapMarkerLayerEvent => 'Dogodek';

  @override
  String get mapMarkerLayerResidency => 'Rezidenca';

  @override
  String get mapMarkerLayerDropReward => 'Drop/Nagrada';

  @override
  String get mapMarkerLayerArExperience => 'AR izkušnja';

  @override
  String get mapMarkerLayerOther => 'Drugo';

  @override
  String get mapArtDiscoveredTitle => 'Umetnina odkrita!';

  @override
  String get desktopMapTitleDiscover => 'Odkrij';

  @override
  String get mapSearchHint => 'Išči umetnine, umetnike, institucije…';

  @override
  String get mapClearSearchTooltip => 'Počisti iskanje';

  @override
  String get mapHideFiltersTooltip => 'Skrij filtre';

  @override
  String get mapShowFiltersTooltip => 'Pokaži filtre';

  @override
  String get mapSearchMinCharsHint => 'Za iskanje vnesite vsaj 2 znaka';

  @override
  String get mapNoSuggestions => 'Ni predlogov';

  @override
  String get commonNoResultsFound => 'Ni rezultatov';

  @override
  String get mapFiltersTitle => 'Filtri';

  @override
  String get mapFilterAll => 'Vse';

  @override
  String get mapFilterNearby => 'V bližini';

  @override
  String get mapFilterAllNearby => 'Vse v bližini';

  @override
  String get mapFilterWithin1Km => 'Znotraj 1 km';

  @override
  String get mapFilterDiscovered => 'Odkrito';

  @override
  String get mapFilterUndiscovered => 'Neodkrito';

  @override
  String get mapFilterArEnabled => 'AR pripravljeno';

  @override
  String get mapFilterFavorites => 'Priljubljene';

  @override
  String get mapLayersTitle => 'Sloji zemljevida';

  @override
  String get mapDiscoveryPathTitle => 'Pot odkrivanja';

  @override
  String get mapShowListViewTooltip => 'Prikaži seznam';

  @override
  String get mapShowGridViewTooltip => 'Prikaži mrežo';

  @override
  String get mapSortResultsTooltip => 'Razvrsti rezultate';

  @override
  String get mapCenterOnMeTooltip => 'Središči na meni';

  @override
  String get mapAddMapMarkerTooltip => 'Dodaj označevalec';

  @override
  String get mapNearbyArtTitle => 'Umetnost v bližini';

  @override
  String mapResultsDiscoveredLabel(Object count, Object percent) {
    return '$count rezultatov · $percent% odkrito';
  }

  @override
  String get mapEmptyNoArtworksTitle => 'Ni umetnin v bližini';

  @override
  String get mapEmptyNoArtworksDescription => 'Raziščite druga območja ali prilagodite filtre, da odkrijete umetnost v okolici.';

  @override
  String get mapEmptyZoomOutAction => 'Oddalji';

  @override
  String get mapEmptyAdjustFiltersAction => 'Prilagodi filtre';

  @override
  String get mapNoLinkedArtworkForMarker => 'Za ta označevalec še ni povezane umetnine.';

  @override
  String get mapCreateMarkerHereTooltip => 'Ustvari označevalnik tukaj';

  @override
  String get mapMarkerDuplicateToast => 'Na tej lokaciji že obstaja označevalnik.';

  @override
  String get mapDistanceHere => 'Tukaj';

  @override
  String get mapDistanceAwaySuffix => ' stran';

  @override
  String get commonGetDirections => 'Navodila za pot';

  @override
  String get desktopMapNoArAssetToast => 'Za to umetnino ni na voljo AR sredstva.';

  @override
  String get desktopMapArtworkTypeTitle => 'Vrsta umetnine';

  @override
  String get desktopMapArtworkTypeArArt => 'AR umetnost';

  @override
  String get desktopMapArtworkTypeNfts => 'NFT-ji';

  @override
  String get desktopMapArtworkTypeModels3d => '3D modeli';

  @override
  String get desktopMapArtworkTypeSculptures => 'Skulpture';

  @override
  String get desktopMapSortByTitle => 'Razvrsti po';

  @override
  String get desktopMapSortDistance => 'Razdalja';

  @override
  String get desktopMapSortPopularity => 'Priljubljenost';

  @override
  String get desktopMapSortNewest => 'Najnovejše';

  @override
  String get desktopMapSortRating => 'Ocena';

  @override
  String desktopMapDiscoveriesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# odkritij',
      few: '# odkritja',
      two: '# odkritji',
      one: '# odkritje',
    );
    return '$_temp0';
  }

  @override
  String get mapMarkerTypeArtworks => 'Umetnine';

  @override
  String get mapMarkerTypeInstitutions => 'Institucije';

  @override
  String get mapMarkerTypeEvents => 'Dogodki';

  @override
  String get mapMarkerTypeResidencies => 'Rezidence';

  @override
  String get mapMarkerTypeDrops => 'Izidi';

  @override
  String get mapMarkerTypeExperiences => 'Izkušnje';

  @override
  String get mapMarkerTypeMisc => 'Razno';

  @override
  String get mapSortNearest => 'Najbližje';

  @override
  String get mapSortNewest => 'Najnovejše';

  @override
  String get mapSortRarity => 'Redkost';

  @override
  String get mapSortHighestRewards => 'Največ nagrad';

  @override
  String get mapSortMostViewed => 'Največ ogledov';

  @override
  String get mapArReadyChipLabel => 'AR pripravljeno';

  @override
  String get mapAlreadyDiscoveredTooltip => 'Že odkrito';

  @override
  String get mapMarkAsDiscoveredTooltip => 'Označi kot odkrito';

  @override
  String get arWebFallbackFeature => 'AR izkušnja';

  @override
  String get arWebFallbackDescription => 'Funkcije razširjene resničnosti (AR) zahtevajo zmogljivosti na napravi. Prenesite aplikacijo art.kubus, da si ogledate digitalne umetnine v fizičnem prostoru s kamero telefona.';

  @override
  String get arModeScanName => 'Skeniraj';

  @override
  String get arModePlaceName => 'Postavi';

  @override
  String get arModeViewName => 'Ogled';

  @override
  String get arModeCreateName => 'Ustvari';

  @override
  String get arModeScanDescription => 'Skenirajte AR označevalce za odkrivanje umetnin v okolici.';

  @override
  String get arModePlaceDescription => 'Postavite digitalne umetnine v svoj prostor.';

  @override
  String get arModeViewDescription => 'Oglejte si postavljene umetnine in se vrnite k njim.';

  @override
  String get arModeCreateDescription => 'Ustvarjajte in preizkušajte AR postavitve.';

  @override
  String arMarkerNearbyToast(Object name) {
    return 'Označevalec v bližini: $name';
  }

  @override
  String get arInitializingTitle => 'Inicializiram AR…';

  @override
  String get arReadyStatus => 'AR je pripravljen';

  @override
  String get arSettingUpStatus => 'Pripravljam…';

  @override
  String get arNoArtworksYetTitle => 'Še ni umetnin';

  @override
  String get arNoArtworksYetDescription => 'Skenirajte označevalec ali postavite umetnino, da začnete z AR ogledom.';

  @override
  String get arModelLoadedToast => 'AR model naložen';

  @override
  String get arModelLoadFailedToast => 'AR modela ni bilo mogoče naložiti. Poskusite znova.';

  @override
  String arPlacingTitle(Object title) {
    return 'Postavljanje: $title';
  }

  @override
  String get arPlacingInstruction => 'Premaknite napravo, da najdete ravno površino.';

  @override
  String arModePreviewTitle(Object mode) {
    return 'Način: $mode';
  }

  @override
  String get arPlaceArtworkFailedToast => 'Umetnine ni bilo mogoče postaviti. Poskusite znova.';

  @override
  String get arActionScan => 'Skeniraj umetnino';

  @override
  String get arActionPlace => 'Postavi umetnino sem';

  @override
  String get arActionView => 'Ogled podrobnosti';

  @override
  String get arActionCreate => 'Ustvari AR umetnino';

  @override
  String get arArtworkPlacedToast => 'Umetnina je postavljena!';

  @override
  String get arNearbyArtworksTitle => 'Umetnine v bližini';

  @override
  String arSelectedArtworkToast(Object title) {
    return 'Izbrano: $title';
  }

  @override
  String get arSelectArtworkBeforePlacingToast => 'Pred postavljanjem izberite ali ustvarite umetnino.';

  @override
  String get arNoPlacedArtworksToast => 'Še ni postavljenih umetnin. Najprej postavite kakšno.';

  @override
  String arPlacedArtworksTitle(Object count) {
    return 'Postavljene umetnine ($count)';
  }

  @override
  String get arArtworkRemovedToast => 'Umetnina odstranjena';

  @override
  String get arLocationUnavailableToast => 'Trenutna lokacija ni na voljo. Premaknite napravo za umerjanje AR sledenja.';

  @override
  String get arUnableToReadFileError => 'Podatkov datoteke ni mogoče prebrati. Poskusite drugo datoteko.';

  @override
  String get arFileSelectionFailedError => 'Izbira datoteke ni uspela. Poskusite znova.';

  @override
  String get arSelectSubjectBeforeMarkerToast => 'Pred ustvarjanjem označevalca izberite vsebino.';

  @override
  String get arAttach3dModelError => 'Pred nadaljevanjem priložite 3D model.';

  @override
  String get arSelectedArtworkUnavailableToast => 'Izbrana umetnina ni več na voljo. Osvežite podatke in poskusite znova.';

  @override
  String get arUploadFailedToast => 'Nalaganje ni uspelo. Poskusite znova.';

  @override
  String get arMarkerCreatedSwitchToPlaceToast => 'AR vsebina je naložena in označevalec ustvarjen. Preklapljam na način Postavi.';

  @override
  String get arCreateMarkerFailedToast => 'Označevalca AR ni bilo mogoče ustvariti. Poskusite znova.';

  @override
  String arShareText(Object title, Object artist) {
    return 'Oglejte si to AR umetnino na art.kubus!\n\n\"$title\"\n— $artist\n\nDoživite jo v razširjeni resničnosti!';
  }

  @override
  String get arShareSuccessToast => 'Umetnina je deljena!';

  @override
  String get arShareFailedToast => 'Deljenje ni uspelo. Poskusite znova.';

  @override
  String get commonActions => 'Dejanja';

  @override
  String get commonCurrentlyOn => 'Trenutno VKLOPLJENO';

  @override
  String get commonCurrentlyOff => 'Trenutno IZKLOPLJENO';

  @override
  String get commonOk => 'V redu';

  @override
  String get commonRetry => 'Poskusi znova';

  @override
  String get commonJustNow => 'Pravkar';

  @override
  String commonMinutesAgo(num minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'pred $minutes minutami',
      few: 'pred $minutes minutami',
      two: 'pred $minutes minutama',
      one: 'pred $minutes minuto',
    );
    return '$_temp0';
  }

  @override
  String commonHoursAgo(num hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'pred $hours urami',
      few: 'pred $hours urami',
      two: 'pred $hours urama',
      one: 'pred $hours uro',
    );
    return '$_temp0';
  }

  @override
  String commonDaysAgo(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'pred $days dnevi',
      few: 'pred $days dnevi',
      two: 'pred $days dnevoma',
      one: 'pred $days dnem',
    );
    return '$_temp0';
  }

  @override
  String commonWeeksAgo(num weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'pred $weeks tedni',
      few: 'pred $weeks tedni',
      two: 'pred $weeks tednoma',
      one: 'pred $weeks tednom',
    );
    return '$_temp0';
  }

  @override
  String get commonTba => 'Kmalu';

  @override
  String get commonUntitled => 'Brez naslova';

  @override
  String get commonDigital => 'Digitalno';

  @override
  String get commonArtwork => 'Umetnina';

  @override
  String get commonUndo => 'Razveljavi';

  @override
  String get messagesTitle => 'Sporočila';

  @override
  String get messagesEmptyNoConversationsTitle => 'Ni pogovorov';

  @override
  String get messagesEmptyNoConversationsDescription => 'Začnite pogovor z gumbom za klepet spodaj.';

  @override
  String get messagesEmptyStartChatAction => 'Začni klepet';

  @override
  String get messagesFallbackGroupTitle => 'Skupina';

  @override
  String get messagesFallbackConversationTitle => 'Pogovor';

  @override
  String get messagesFallbackConversationInitial => 'P';

  @override
  String get messagesCreateConversationTitle => 'Ustvari pogovor';

  @override
  String get messagesCreateConversationTitleOptionalLabel => 'Naslov (neobvezno)';

  @override
  String get messagesCreateConversationMembersLabel => 'Člani (uporabniško ime ali denarnica)';

  @override
  String get messagesCreateConversationGroupAvatarOptionalLabel => 'Avatar skupine (neobvezno)';

  @override
  String get messagesCreateConversationIsGroupLabel => 'Skupina';

  @override
  String messagesReplyingToLabel(Object name) {
    return 'Odgovarjaš $name';
  }

  @override
  String get messagesCreatedNewGroupChatToast => 'Ustvarjen je nov skupinski klepet.';

  @override
  String get messagesUploadingAvatarToast => 'Nalaganje avatarja…';

  @override
  String get messagesAvatarUpdatedToast => 'Avatar je posodobljen.';

  @override
  String get messagesUpdateAvatarFailedToast => 'Avatarja trenutno ni mogoče posodobiti.';

  @override
  String get messagesMenuAddMember => 'Dodaj člana';

  @override
  String get messagesMenuRenameConversation => 'Preimenuj pogovor';

  @override
  String get messagesMenuChangeGroupAvatar => 'Spremeni avatar skupine';

  @override
  String get messagesAttachmentDefaultFilename => 'priloga';

  @override
  String get messagesAttachmentFailedToLoadImage => 'Slike ni mogoče naložiti';

  @override
  String get messagesAttachmentVideoLabel => 'Video';

  @override
  String get messagesAttachmentPlayVideoButton => 'Predvajaj video';

  @override
  String get messagesAttachmentDownloadButton => 'Prenesi';

  @override
  String get messagesTypeMessageHint => 'Vpiši sporočilo…';

  @override
  String get messagesAddMemberDialogTitle => 'Dodaj člana';

  @override
  String get messagesAddMemberIdentifierLabel => 'Uporabniško ime ali denarnica';

  @override
  String get messagesAddMemberDialogLoadFailedTitle => 'Uporabnika ni mogoče naložiti';

  @override
  String get messagesAddMemberDialogLoadFailedBody => 'Uporabnika trenutno ni mogoče naložiti. Poskusite znova.';

  @override
  String get messagesConversationMembersTitle => 'Člani pogovora';

  @override
  String get messagesMemberLabel => 'Član';

  @override
  String get messagesMemberOptionsTitle => 'Možnosti člana';

  @override
  String messagesMemberOptionsBody(Object displayName) {
    return 'Kaj želite narediti z $displayName?';
  }

  @override
  String get messagesTransferOwnershipAction => 'Prenesi lastništvo';

  @override
  String get messagesRemoveMemberAction => 'Odstrani člana';

  @override
  String get messagesTransferOwnershipTitle => 'Prenos lastništva';

  @override
  String messagesTransferOwnershipBody(Object displayName, Object wallet) {
    return 'Prenesem lastništvo na $displayName ($wallet)?';
  }

  @override
  String get messagesOwnershipTransferredToast => 'Lastništvo je preneseno.';

  @override
  String get messagesTransferFailedToast => 'Prenos ni uspel.';

  @override
  String get messagesManageMemberAction => 'Upravljaj';

  @override
  String get messagesRenameConversationTitle => 'Preimenuj pogovor';

  @override
  String get messagesRenameConversationHint => 'Vnesi novo ime';

  @override
  String get messagesRenameConversationFieldLabel => 'Ime pogovora';

  @override
  String get userProfileTitle => 'Profil';

  @override
  String get userProfileNotFound => 'Uporabnik ni najden';

  @override
  String get userProfileNotFoundDescription => 'Ta profil je bil morda izbrisan ali ne obstaja.';

  @override
  String get userProfileShareTooltip => 'Deli';

  @override
  String get userProfileMoreTooltip => 'Več';

  @override
  String get userProfileSharedToast => 'Profil deljen!';

  @override
  String userProfileJoinedLabel(Object date) {
    return 'Pridružil(-a) se $date';
  }

  @override
  String get userProfileMessageButtonLabel => 'Sporočilo';

  @override
  String get userProfileArtistPortfolioTitle => 'Portfelj umetnika';

  @override
  String get userProfileInstitutionHighlightsDesktopSubtitle => 'Izbrane razstave in programi';

  @override
  String get userProfileArtistPortfolioDesktopSubtitle => 'Najnovejše umetnine in zbirke';

  @override
  String get userProfileNoCreatorContentTitle => 'Ni vsebine';

  @override
  String get userProfileNoInstitutionContentDescription => 'Za zdaj ni razstav ali programov za prikaz';

  @override
  String get userProfileNoArtistContentDescription => 'Za zdaj ni umetnin ali zbirk za prikaz';

  @override
  String get userProfileFollowButton => 'Sledi';

  @override
  String get userProfileFollowingButton => 'Slediš';

  @override
  String get userProfileSignInToFollowToast => 'Za sledenje ustvarjalcem se prijavite.';

  @override
  String get userProfileFollowUpdateFailedToast => 'Stanja sledenja ni bilo mogoče posodobiti. Poskusite znova.';

  @override
  String userProfileNowFollowingToast(Object name) {
    return 'Sledite: $name';
  }

  @override
  String userProfileUnfollowedToast(Object name) {
    return 'Ne sledite več: $name';
  }

  @override
  String get userProfilePostsStatLabel => 'Objave';

  @override
  String get userProfileFollowersStatLabel => 'Sledilci';

  @override
  String get userProfileFollowingStatLabel => 'Sledim';

  @override
  String get userProfileMessageLoginRequiredToast => 'Za sporočanje se prijavite.';

  @override
  String get userProfileConversationOpenFailedToast => 'Pogovora ni bilo mogoče odpreti.';

  @override
  String get userProfileConversationOpenGenericErrorToast => 'Pogovora ni bilo mogoče odpreti. Poskusite znova.';

  @override
  String get userProfileAchievementsTitle => 'Dosežki';

  @override
  String userProfileAchievementsProgressLabel(Object completed, Object total) {
    return 'Odklenjenih $completed od $total';
  }

  @override
  String userProfileAchievementsEmptyTitle(Object name) {
    return '$name še nima odklenjenih dosežkov.';
  }

  @override
  String get userProfileAchievementsEmptyDescription => 'Začnite raziskovati in odklenite dosežke';

  @override
  String get userProfileAchievementCompletedLabel => 'Zaključeno';

  @override
  String get userProfilePostsTitle => 'Objave';

  @override
  String userProfileRecentActivitySubtitle(Object name) {
    return 'Nedavna aktivnost uporabnika $name';
  }

  @override
  String get userProfilePostsLoadFailedTitle => 'Objav ni bilo mogoče naložiti';

  @override
  String get userProfilePostsLoadFailedDescription => 'Objav ni bilo mogoče naložiti.';

  @override
  String get userProfilePostsLoadMoreFailedDescription => 'Dodatnih objav ni bilo mogoče naložiti.';

  @override
  String get userProfileNoPostsTitle => 'Brez objav';

  @override
  String userProfileNoPostsDescription(Object name) {
    return '$name še ni delil(-a) objav.';
  }

  @override
  String get userProfileNoMorePostsLabel => 'Ni več objav';

  @override
  String get userProfileArtistHighlightsTitle => 'Poudarki umetnika';

  @override
  String userProfileArtistHighlightsSubtitle(Object name) {
    return 'Najnovejše objave od $name.';
  }

  @override
  String get userProfileInstitutionHighlightsTitle => 'Poudarki institucije';

  @override
  String userProfileInstitutionHighlightsSubtitle(Object name) {
    return 'Programi in zbirke, ki jih kurira $name.';
  }

  @override
  String get userProfileArtworksTitle => 'Umetnine';

  @override
  String get userProfileCollectionsTitle => 'Zbirke';

  @override
  String get userProfileEventsTitle => 'Dogodki';

  @override
  String userProfileEventsSubtitleFeaturing(Object name) {
    return 'Prihajajoče izkušnje z $name.';
  }

  @override
  String userProfileNoUpcomingEventsYetLabel(Object name) {
    return 'Za zdaj ni prihajajočih dogodkov od $name.';
  }

  @override
  String userProfileNoArtworksYetLabel(Object name) {
    return '$name še ni objavil(-a) nobene umetnine.';
  }

  @override
  String userProfileNoCollectionsYetLabel(Object name) {
    return '$name še ni kuriral(-a) zbirk.';
  }

  @override
  String userProfileNoItemsTitle(Object title) {
    return 'Brez: $title';
  }

  @override
  String userProfileLikesLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count všečkov',
      few: '$count všečki',
      two: '$count všečka',
      one: '$count všeček',
    );
    return '$_temp0';
  }

  @override
  String userProfileArtworksCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count umetnin',
      few: '$count umetnine',
      two: '$count umetnini',
      one: '$count umetnina',
    );
    return '$_temp0';
  }

  @override
  String userProfileCuratedByLabel(Object name) {
    return 'Kuratira $name';
  }

  @override
  String get userProfileCollectionFallbackTitle => 'Zbirka';

  @override
  String get userProfileEventFallbackTitle => 'Dogodek';

  @override
  String get userProfileMoreOptionsBlockUser => 'Blokiraj uporabnika';

  @override
  String get userProfileMoreOptionsReportUser => 'Prijavi uporabnika';

  @override
  String get userProfileMoreOptionsCopyLink => 'Kopiraj povezavo do profila';

  @override
  String get userProfileLinkCopiedToast => 'Povezava do profila kopirana';

  @override
  String userProfileBlockDialogTitle(Object name) {
    return 'Blokiraj $name?';
  }

  @override
  String get userProfileBlockDialogDescription => 'Ne bo mogel(-la) videti vašega profila ali objav.';

  @override
  String get userProfileUnableToBlockToast => 'Uporabnika ni mogoče blokirati.';

  @override
  String get userProfileBlockFailedToast => 'Uporabnika ni bilo mogoče blokirati. Poskusite znova.';

  @override
  String userProfileBlockedToast(Object name) {
    return 'Blokiran(-a): $name';
  }

  @override
  String get userProfileBlockButtonLabel => 'Blokiraj';

  @override
  String userProfileReportDialogTitle(Object name) {
    return 'Prijavi $name';
  }

  @override
  String get userProfileReportDialogQuestion => 'Zakaj prijavljate tega uporabnika?';

  @override
  String get userProfileReportReasonSpam => 'Neželena vsebina';

  @override
  String get userProfileReportReasonInappropriate => 'Neprimerna vsebina';

  @override
  String get userProfileReportReasonHarassment => 'Nadlegovanje';

  @override
  String get userProfileReportReasonOther => 'Drugo';

  @override
  String get userProfileReportSubmittedToast => 'Prijava poslana. Hvala za povratne informacije.';

  @override
  String get arDetailModelLabel => 'Model';

  @override
  String get arDetailScaleLabel => 'Merilo';

  @override
  String get arDetailPlacedLabel => 'Postavljeno';

  @override
  String get arShareButtonLabel => 'Deli';

  @override
  String get arLikeButtonLabel => 'Všečkaj';

  @override
  String get arLikedButtonLabel => 'Všečkano';

  @override
  String get arSaveButtonLabel => 'Shrani';

  @override
  String get arSavedButtonLabel => 'Shranjeno';

  @override
  String get arLikeAddedToast => 'Dodano med všečke!';

  @override
  String get arLikeRemovedToast => 'Odstranjeno iz všečkov';

  @override
  String get arSaveAddedToast => 'Shranjeno v vašo zbirko!';

  @override
  String get arSaveRemovedToast => 'Odstranjeno iz shranjenih';

  @override
  String get arNotSupportedTitle => 'AR ni podprt';

  @override
  String get arNotSupportedMessage => 'Vaša naprava ne podpira funkcij razširjene resničnosti (AR). AR zahteva ARCore (Android) ali ARKit (iOS).';

  @override
  String get arInitializationFailedTitle => 'Inicializacija AR ni uspela';

  @override
  String get arInitializationFailedMessage => 'AR ni bilo mogoče inicializirati. Preverite dovoljenja za kamero in poskusite znova.';

  @override
  String get commonRequired => 'obvezno';

  @override
  String commonFileSizeKb(String value) {
    return '$value KB';
  }

  @override
  String commonFileSizeMb(String value) {
    return '$value MB';
  }

  @override
  String get arCreateUploadTitle => 'Naloži AR sredstvo';

  @override
  String get arCreateUploadSubtitle => 'Povežite obstoječo umetnino, naložite 3D model (GLB/GLTF/USDZ) in obogatili bomo njen AR označevalnik.';

  @override
  String get arCreateSubjectTypeLabel => 'Vrsta subjekta';

  @override
  String arCreateSubjectLabel(String subjectType) {
    return '$subjectType *';
  }

  @override
  String arCreateDefaultDescription(String title) {
    return 'Označevalnik za $title';
  }

  @override
  String arCreateNoSubjectsAvailable(String subjectTypeLower) {
    return 'Ni razpoložljivih $subjectTypeLower. Najprej ustvarite enega v ustreznem modulu.';
  }

  @override
  String get arCreateMarkerTitleLabel => 'Naslov označevalnika *';

  @override
  String get arCreateTitleRequiredError => 'Naslov je obvezen';

  @override
  String get arCreateTitleMinLengthError => 'Naslov mora imeti vsaj 3 znake';

  @override
  String get arCreateDescriptionLabel => 'Opis *';

  @override
  String get arCreateDescriptionRequiredError => 'Opis je obvezen';

  @override
  String get arCreateDescriptionMinLengthError => 'Opišite izkušnjo z vsaj 10 znaki';

  @override
  String get arCreateCategoryLabel => 'Kategorija';

  @override
  String get arCreateAttach3dAssetTitle => 'Priloži 3D sredstvo';

  @override
  String get arCreateSelectModelButton => 'Izberi GLB / GLTF / USDZ';

  @override
  String get arCreateReplaceModelButton => 'Zamenjaj model';

  @override
  String get arCreatePublicMarkerTitle => 'Javni označevalnik';

  @override
  String get arCreatePublicMarkerSubtitle => 'Viden bližnjim raziskovalcem';

  @override
  String get arCreateUploadingLabel => 'Nalaganje…';

  @override
  String get arCreateUploadAndCreateButton => 'Naloži in ustvari označevalnik';

  @override
  String get arSettingsTitle => 'AR nastavitve';

  @override
  String get arScannerSettingsTitle => 'Nastavitve skenerja';

  @override
  String get arFlashControlTitle => 'Nadzor bliskavice';

  @override
  String get arFlashNotAvailableToast => 'Bliskavica na tej napravi ni na voljo.';

  @override
  String get arScannerOverlayTitle => 'Prekrivni prikaz skenerja';

  @override
  String get arScannerOverlaySubtitle => 'Prikaži/skrij vodič skenerja';

  @override
  String get arScannerOverlayResetToast => 'Prekrivni prikaz skenerja se po 3 sekundah samodejno ponastavi.';

  @override
  String get arDisplayTitle => 'AR prikaz';

  @override
  String get arShowFeaturePointsTitle => 'Pokaži točke sledenja';

  @override
  String get arShowFeaturePointsSubtitle => 'Prikaži točke sledenja na površinah';

  @override
  String get arShowPlanesTitle => 'Pokaži ravnine';

  @override
  String get arShowPlanesSubtitle => 'Prikaži zaznane ravninske površine';

  @override
  String get arAutoDetectSurfacesTitle => 'Samodejno zaznaj površine';

  @override
  String get arAutoDetectSurfacesSubtitle => 'Samodejno zaznaj ravne površine';

  @override
  String get arDebugInfoTitle => 'Podatki za odpravljanje napak';

  @override
  String get arDebugInfoSubtitle => 'Prikaži tehnične informacije';

  @override
  String arModelScaleLabel(Object percent) {
    return 'Merilo modela: $percent%';
  }

  @override
  String get arClearAllArtworksTitle => 'Počisti vse umetnine';

  @override
  String get arClearAllArtworksSubtitle => 'Odstrani vse postavljene AR objekte';

  @override
  String get arAllArtworksClearedToast => 'Vse umetnine so počiščene';

  @override
  String get arResetSessionTitle => 'Ponastavi AR sejo';

  @override
  String get arResetSessionSubtitle => 'Znova zaženi AR sledenje';

  @override
  String get arSessionResetToast => 'AR seja ponastavljena';

  @override
  String get connectWalletSecureAccessTitle => 'Varni dostop';

  @override
  String get connectWalletChooseTitle => 'Povežite denarnico';

  @override
  String get connectWalletChooseDescription => 'Izberite način povezave. Ustvarite novo denarnico, uvozite obstoječo ali uporabite WalletConnect.';

  @override
  String get connectWalletOptionWalletConnectTitle => 'WalletConnect';

  @override
  String get connectWalletOptionWalletConnectDescription => 'Povežite z QR kodo ali URI WalletConnect';

  @override
  String get connectWalletOptionSignInTitle => 'Uvozi denarnico';

  @override
  String get connectWalletOptionSignInDescription => 'Uporabite obstoječo obnovitveno frazo';

  @override
  String get connectWalletOptionRegisterTitle => 'Ustvari novo denarnico';

  @override
  String get connectWalletOptionRegisterDescription => 'Ustvarite novo denarnico na tej napravi';

  @override
  String get connectWalletHybridHelpLink => 'Kaj je WalletConnect?';

  @override
  String get connectWalletImportTitle => 'Uvozi denarnico';

  @override
  String get connectWalletImportDescription => 'Vnesite 12-besedno obnovitveno frazo za uvoz denarnice z druge naprave.';

  @override
  String get connectWalletImportHint => 'Vnesite 12 besed, ločenih s presledki';

  @override
  String get connectWalletImportWarning => 'Nikoli ne delite obnovitvene fraze. Kdor jo ima, lahko upravlja vašo denarnico.';

  @override
  String get connectWalletImportButton => 'Uvozi denarnico';

  @override
  String get connectWalletImportEmptyMnemonicError => 'Vnesite obnovitveno frazo';

  @override
  String connectWalletImportInvalidMnemonicWordCountError(Object count) {
    return 'Pričakovano je 12 besed, vnesli ste $count.';
  }

  @override
  String connectWalletImportSuccessToast(Object prefix) {
    return 'Denarnica uvožena: $prefix…';
  }

  @override
  String get connectWalletImportFailedToast => 'Uvoz denarnice ni uspel. Poskusite znova.';

  @override
  String get connectWalletCreateTitle => 'Ustvarite novo denarnico';

  @override
  String get connectWalletCreateDescription => 'Ustvarili bomo novo denarnico na tej napravi. Obnovitveno frazo varno shranite.';

  @override
  String get connectWalletCreateInfoTitle => 'Pomembno';

  @override
  String get connectWalletCreateInfoBody => 'Zapišite obnovitveno frazo in jo shranite na varno. Ne moremo je obnoviti namesto vas.';

  @override
  String get connectWalletCreateWarning => 'Z nadaljevanjem potrjujete, da razumete tveganja.';

  @override
  String get connectWalletCreateGenerateButton => 'Ustvari denarnico';

  @override
  String get connectWalletCreateAlreadyHaveWalletPrefix => 'Že imate denarnico?';

  @override
  String get connectWalletCreateAlreadyHaveWalletLink => 'Uvozite jo';

  @override
  String get connectWalletCreateSuccessToast => 'Denarnica je ustvarjena in profil je nastavljen.';

  @override
  String get connectWalletCreateFailedToast => 'Ustvarjanje denarnice ni uspelo. Poskusite znova.';

  @override
  String get connectWalletMnemonicDialogTitle => 'Shrani obnovitveno frazo';

  @override
  String get connectWalletMnemonicDialogWarning => 'Zapišite in varno shranite!';

  @override
  String get connectWalletMnemonicDialogConfirmPrompt => 'Potrdite z vnosom obnovitvene fraze:';

  @override
  String get connectWalletMnemonicDialogConfirmHint => 'Prilepite ali vnesite obnovitveno frazo';

  @override
  String connectWalletMnemonicDialogAddressLabel(Object address) {
    return 'Naslov denarnice: $address';
  }

  @override
  String get connectWalletMnemonicDialogConfirmButton => 'Shranjeno';

  @override
  String get connectWalletConnectedTitle => 'Denarnica povezana';

  @override
  String get connectWalletConnectedDescription => 'Denarnica je zdaj povezana z art.kubus. Lahko raziskujete AR umetnost, trgujete z NFT in sodelujete v ekosistemu.';

  @override
  String get connectWalletConnectedStartExploringButton => 'Začni raziskovati';

  @override
  String get connectWalletConnectedDisconnectButton => 'Odklopi denarnico';

  @override
  String get connectWalletWeb3GuideTitle => 'Kaj je Web3 denarnica?';

  @override
  String get connectWalletWeb3GuideDescription => 'Web3 denarnica je vaš prehod v decentraliziran internet:';

  @override
  String get connectWalletWeb3GuideFeatureSecureTitle => 'Varno';

  @override
  String get connectWalletWeb3GuideFeatureSecureDescription => 'Vaši ključi, vaša sredstva';

  @override
  String get connectWalletWeb3GuideFeatureNftsTitle => 'NFT';

  @override
  String get connectWalletWeb3GuideFeatureNftsDescription => 'Hranite in trgujte z digitalno umetnostjo';

  @override
  String get connectWalletWeb3GuideFeatureGovernanceTitle => 'Upravljanje';

  @override
  String get connectWalletWeb3GuideFeatureGovernanceDescription => 'Glasujte o odločitvah platforme';

  @override
  String get connectWalletWeb3GuideFeatureDefiTitle => 'DeFi';

  @override
  String get connectWalletWeb3GuideFeatureDefiDescription => 'Dostop do decentraliziranih financ';

  @override
  String get connectWalletWeb3GuideGotItButton => 'Razumem!';

  @override
  String get connectWalletWalletConnectTitle => 'Poveži z WalletConnect';

  @override
  String get connectWalletWalletConnectDescription => 'WalletConnect omogoča povezavo vaše denarnice z art.kubus.';

  @override
  String get connectWalletWalletConnectSupportedTitle => 'Podprte denarnice';

  @override
  String get connectWalletWalletConnectSupportedList => 'Phantom, Solflare, Backpack in druge';

  @override
  String get connectWalletWalletConnectHowToTitle => 'Kako deluje';

  @override
  String get connectWalletWalletConnectStep1 => 'V aplikaciji denarnice odprite WalletConnect';

  @override
  String get connectWalletWalletConnectStep2 => 'Skenirajte QR kodo ali prilepite URI';

  @override
  String get connectWalletWalletConnectStep3 => 'V denarnici potrdite povezavo';

  @override
  String get connectWalletWalletConnectConnectingLabel => 'Povezujem…';

  @override
  String get connectWalletWalletConnectQuickConnectLabel => 'Hitro poveži';

  @override
  String get connectWalletWalletConnectUriHint => 'Prilepite URI WalletConnect (wc:...)';

  @override
  String get connectWalletWalletConnectSecurityNote => 'Povezujte se samo z denarnicami, ki jim zaupate. Nikoli ne delite obnovitvene fraze.';

  @override
  String get connectWalletWalletConnectScanQrButton => 'Skeniraj QR kodo';

  @override
  String get connectWalletWalletConnectConnectButton => 'Poveži';

  @override
  String get connectWalletWalletConnectNoWalletPrefix => 'Še nimate denarnice?';

  @override
  String get connectWalletWalletConnectNoWalletLink => 'Ustvarite jo';

  @override
  String get connectWalletWalletConnectScanQrTitle => 'Skeniraj WalletConnect QR kodo';

  @override
  String get connectWalletWalletConnectScanQrHint => 'Postavite QR kodo v okvir';

  @override
  String get connectWalletWalletConnectUriRequiredToast => 'Vnesite URI WalletConnect';

  @override
  String get connectWalletWalletConnectInvalidUriToast => 'Neveljaven URI WalletConnect';

  @override
  String get connectWalletWalletConnectNeedsLocalWalletToast => 'Pred uporabo WalletConnect ustvarite ali uvozite denarnico';

  @override
  String connectWalletWalletConnectConnectedToast(Object address) {
    return 'Povezano z $address';
  }

  @override
  String get connectWalletWalletConnectConnectionErrorToast => 'Napaka pri povezavi. Poskusite znova.';

  @override
  String get connectWalletWalletConnectWaitingApprovalToast => 'Čakam na potrditev v denarnici…';

  @override
  String get connectWalletWalletConnectFailedToast => 'Povezava prek WalletConnect ni uspela';

  @override
  String get walletHomeTitle => 'Moja denarnica';

  @override
  String get walletHomeLoadingLabel => 'Nalaganje denarnice…';

  @override
  String get walletHomeNoWalletDescription => 'Za začetek povežite denarnico.';

  @override
  String get walletHomeAlreadyConnectedToast => 'Denarnica je že povezana.';

  @override
  String get walletHomeTotalBalanceLabel => 'Skupno stanje';

  @override
  String walletHomeAddressLabel(Object address) {
    return 'Naslov: $address';
  }

  @override
  String get walletHomeAddressCopiedToast => 'Naslov kopiran v odložišče!';

  @override
  String get walletHomeActionSend => 'Pošlji';

  @override
  String get walletHomeActionReceive => 'Prejmi';

  @override
  String get walletHomeActionSwap => 'Zamenjaj';

  @override
  String get walletHomeActionNfts => 'NFT';

  @override
  String get walletHomeYourTokensTitle => 'Vaši žetoni';

  @override
  String get walletHomeRecentTransactionsTitle => 'Nedavne transakcije';

  @override
  String walletHomeTimeAgoDays(Object count) {
    return 'pred $count d';
  }

  @override
  String walletHomeTimeAgoHours(Object count) {
    return 'pred $count h';
  }

  @override
  String walletHomeTimeAgoMinutes(Object count) {
    return 'pred $count min';
  }

  @override
  String get walletHomeTxSwapLabel => 'Zamenjano';

  @override
  String get walletHomeTxStakeLabel => 'Zastavljeno';

  @override
  String get walletHomeTxUnstakeLabel => 'Od-zastavljeno';

  @override
  String get walletHomeTxGovernanceVoteLabel => 'Glasovanje (upravljanje)';

  @override
  String get receiveTokenTitle => 'Prejmi žetone';

  @override
  String get receiveTokenSelectTokenTitle => 'Izberite žeton za prejem';

  @override
  String receiveTokenBalanceLabel(Object amount) {
    return 'Stanje: $amount';
  }

  @override
  String get receiveTokenQrError => 'Napaka QR\nUstvarjanje ni uspelo';

  @override
  String get receiveTokenQrRequiresWallet => 'Ustvarite ali uvozite denarnico\nza ustvarjanje QR kode';

  @override
  String receiveTokenScanToSend(Object token) {
    return 'Skeniraj za pošiljanje $token';
  }

  @override
  String receiveTokenAnyoneCanSend(Object token) {
    return 'Vsak lahko pošlje $token na ta naslov';
  }

  @override
  String get receiveTokenFinishSetupToShare => 'Dokončajte nastavitev denarnice za deljenje naslova';

  @override
  String receiveTokenYourAddressTitle(Object token) {
    return 'Vaš naslov za $token';
  }

  @override
  String get receiveTokenShareAddressTooltip => 'Deli naslov';

  @override
  String get receiveTokenCopyAddressTooltip => 'Kopiraj naslov';

  @override
  String get receiveTokenRequiresWalletToReceive => 'Za prejem žetonov ustvarite ali uvozite denarnico';

  @override
  String get receiveTokenCopyAddressButton => 'Kopiraj naslov';

  @override
  String receiveTokenHowToReceiveTitle(Object token) {
    return 'Kako prejeti $token';
  }

  @override
  String get receiveTokenStep1Title => 'Delite svoj naslov';

  @override
  String receiveTokenStep1Description(Object token) {
    return 'Osebi, ki vam želi poslati $token, pošljite naslov denarnice';
  }

  @override
  String get receiveTokenStep2Title => 'Ali pokažite QR kodo';

  @override
  String get receiveTokenStep2Description => 'Naj s svojo denarnico skenirajo zgornjo QR kodo';

  @override
  String get receiveTokenStep3Title => 'Prejmite žetone';

  @override
  String get receiveTokenStep3Description => 'Žetoni se bodo prikazali v denarnici, ko bo transakcija potrjena';

  @override
  String receiveTokenWarningOnlySend(Object token) {
    return 'Na ta naslov pošiljajte samo $token in združljive žetone';
  }

  @override
  String get receiveTokenNoWalletAddressToast => 'Naslov denarnice še ni na voljo';

  @override
  String receiveTokenShareText(Object token, Object address, Object payload) {
    return 'Pošljite $token na $address\n$payload';
  }

  @override
  String get receiveTokenNoTokensMessage => 'Za prikaz žetonov povežite ali uvozite denarnico.';

  @override
  String get sendTokenTitle => 'Pošlji žeton';

  @override
  String get sendTokenScanQrTooltip => 'Skeniraj QR kodo';

  @override
  String get sendTokenQrScannerUnavailableTooltip => 'QR skener ni na voljo';

  @override
  String get sendTokenSelectTokenTitle => 'Izberi žeton';

  @override
  String get sendTokenRecipientAddressTitle => 'Naslov prejemnika';

  @override
  String get sendTokenRecipientAddressHint => 'Vnesite naslov prejemnika';

  @override
  String get sendTokenAmountTitle => 'Znesek';

  @override
  String get sendTokenMaxButton => 'MAX';

  @override
  String sendTokenAvailableLabel(Object amount, Object token) {
    return 'Na voljo: $amount $token';
  }

  @override
  String get sendTokenTransactionSummaryTitle => 'Povzetek transakcije';

  @override
  String get sendTokenSummaryAmountLabel => 'Znesek';

  @override
  String sendTokenSummaryFeesLabel(Object percent) {
    return 'Kubus provizije (~$percent%)';
  }

  @override
  String get sendTokenSummaryEstimatedDebitLabel => 'Ocenjen odtegljaj';

  @override
  String get sendTokenSummaryUsdValueLabel => 'Vrednost v USD';

  @override
  String get sendTokenSummaryNetworkFeeLabel => 'Omrežna provizija';

  @override
  String get sendTokenNetworkFeeNote => 'Omrežne provizije se plačujejo v SOL. Imejte nekaj SOL za provizije.';

  @override
  String get sendTokenNoTokensMessage => 'Povežite ali ustvarite denarnico, da izberete žetone za pošiljanje.';

  @override
  String sendTokenButtonLabel(Object token) {
    return 'Pošlji $token';
  }

  @override
  String get sendTokenAddressRequiredError => 'Naslov je obvezen';

  @override
  String get sendTokenAddressInvalidError => 'Vnesite veljaven Solana naslov';

  @override
  String get sendTokenAmountRequiredError => 'Znesek je obvezen';

  @override
  String get sendTokenAmountGreaterThanZeroError => 'Znesek mora biti večji od 0';

  @override
  String get sendTokenInsufficientBalanceError => 'Premalo sredstev';

  @override
  String get sendTokenNoBalanceToast => 'Za ta žeton ni na voljo stanja';

  @override
  String get sendTokenMaxAmountComputeFailedToast => 'Največjega zneska ni mogoče izračunati. Pustite nekaj sredstev za provizije.';

  @override
  String get sendTokenQrScannerUnsupportedWeb => 'Skeniranje QR kod ni na voljo v spletnih brskalnikih. Za to funkcijo uporabite mobilno ali namizno aplikacijo.';

  @override
  String get sendTokenQrScannerUnsupportedDesktop => 'Skeniranje QR kod ni na voljo na namiznih platformah. Za to funkcijo uporabite mobilno aplikacijo.';

  @override
  String get sendTokenQrScannerUnsupportedPlatform => 'Skeniranje QR kod na tej platformi ni podprto.';

  @override
  String get sendTokenQrUnreadableToast => 'Ni mogoče prebrati vsebine QR kode.';

  @override
  String get sendTokenQrInvalidAddressToast => 'QR koda ne vsebuje veljavnega naslova.';

  @override
  String get sendTokenQrScannedAddressLabel => 'Naslov skeniran';

  @override
  String sendTokenQrScannedTokenLabel(Object token) {
    return 'Žeton: $token';
  }

  @override
  String sendTokenQrScannedAmountLabel(Object amount) {
    return 'Znesek: $amount';
  }

  @override
  String get sendTokenQrScanErrorToast => 'Napaka pri skeniranju QR kode. Poskusite znova.';

  @override
  String sendTokenSendSuccessToast(Object amount, Object token) {
    return 'Uspešno poslano $amount $token';
  }

  @override
  String get sendTokenSendFailedToast => 'Pošiljanje žetonov ni uspelo. Poskusite znova.';

  @override
  String get sendTokenInsufficientAfterFeesToast => 'Premalo sredstev po protokolnih provizijah. Zmanjšajte znesek ali dopolnite denarnico.';

  @override
  String get sendTokenNoKeypairToast => 'Ni na voljo ključnega para denarnice. Ponovno povežite ali znova uvozite denarnico.';

  @override
  String get sendTokenInvalidAddressBeforeSendToast => 'Pred pošiljanjem vnesite veljaven Solana naslov.';

  @override
  String get sendTokenConnectWalletBeforeSendToast => 'Pred pošiljanjem povežite denarnico.';

  @override
  String get qrScannerTitle => 'Skeniraj QR kodo';

  @override
  String get qrScannerWebUnavailableTitle => 'QR skener ni na voljo';

  @override
  String get qrScannerWebUnavailableDescription => 'Skeniranje QR kod s kamero ni podprto v spletnih brskalnikih. Namesto tega prilepite ali vnesite naslov ročno.';

  @override
  String get qrScannerGoBackButton => 'Nazaj';

  @override
  String get qrScannerPreparingCameraLabel => 'Pripravljam kamero…';

  @override
  String get qrScannerPermissionNeededTitle => 'Potrebno dovoljenje za kamero';

  @override
  String get qrScannerPermissionNeededDescription => 'Omogočite dostop do kamere za varno skeniranje QR kod denarnice.';

  @override
  String get qrScannerOpenSettingsButton => 'Odpri nastavitve';

  @override
  String get qrScannerGrantCameraAccessButton => 'Dovoli dostop do kamere';

  @override
  String get qrScannerCameraErrorTitle => 'Napaka kamere';

  @override
  String get qrScannerCameraErrorDescription => 'Kamere ni mogoče zagnati. Preverite dovoljenja in poskusite znova.';

  @override
  String get qrScannerStatusAddressCapturedTitle => 'Naslov zajet';

  @override
  String get qrScannerStatusUnsupportedQrTitle => 'Nepodprta QR koda';

  @override
  String get qrScannerStatusUnsupportedQrDescription => 'Ta QR koda ne vsebuje veljavnega Solana naslova.';

  @override
  String get qrScannerStatusReadyTitle => 'Pripravljeno na skeniranje';

  @override
  String get qrScannerStatusReadyDescription => 'Poravnajte QR kodo znotraj okvirja, da zajamete Solana naslov.';

  @override
  String get qrScannerMetaAmountLabel => 'Znesek';

  @override
  String get qrScannerMetaMintLabel => 'Mint';

  @override
  String get qrScannerInvalidQrToast => 'Prosimo, skenirajte QR kodo Solana denarnice.';

  @override
  String get qrScannerTorchNotSupportedToast => 'Vklop bliskavice na tej napravi ni podprt.';

  @override
  String get qrScannerSwitchCameraFailedToast => 'Kamere ni mogoče zamenjati.';

  @override
  String get artworkNotFound => 'Umetnina ni najdena';

  @override
  String get web3DashboardComingSoon => 'Web3 nadzorna plošča – kmalu';

  @override
  String get artDetailLoadingTitle => 'Nalaganje umetnine';

  @override
  String get artDetailTitle => 'Umetnina';

  @override
  String get artDetailLoadFailedMessage => 'Nalaganje podrobnosti umetnine ni uspelo. Poskusite znova.';

  @override
  String get eventCreatorSelectStartEndDatesToast => 'Prosimo, izberite začetni in končni datum';

  @override
  String get eventCreatorEnterCapacityToast => 'Prosimo, vnesite kapaciteto dogodka';

  @override
  String get eventCreatorNoInstitutionAvailableToast => 'Za ta dogodek ni na voljo institucije';

  @override
  String get eventCreatorSelectedInstitutionNotFoundToast => 'Izbrana institucija ni najdena';

  @override
  String get eventCreatorEndTimeAfterStartToast => 'Končni čas mora biti po začetnem času';

  @override
  String get eventCreatorEventUpdatedTitle => 'Dogodek posodobljen';

  @override
  String get eventCreatorEventCreatedTitle => 'Dogodek ustvarjen';

  @override
  String get eventCreatorEventUpdatedBody => 'Vaš dogodek je bil uspešno posodobljen.';

  @override
  String get eventCreatorEventCreatedBody => 'Vaš dogodek je bil uspešno ustvarjen.';

  @override
  String get eventCreatorCreateAnotherButton => 'Ustvari še enega';

  @override
  String get eventCreatorSaveFailedToast => 'Shranjevanje dogodka ni uspelo. Poskusite znova.';

  @override
  String get activityNavigationUnableToOpenToast => 'Trenutno ni mogoče odpreti te dejavnosti.';

  @override
  String navigationUnableToNavigateToScreen(Object screenName) {
    return 'Ni mogoče odpreti zaslona »$screenName«.';
  }

  @override
  String get arMarkerScannerDefaultArtworkTitle => 'AR umetnina';

  @override
  String get arMarkerScannerInvalidQrFormatToast => 'Neveljavna oblika QR kode';

  @override
  String get arMarkerScannerMissingModelUrlToast => 'QR kodi manjka povezava do modela';

  @override
  String arMarkerScannerByArtist(Object artist) {
    return 'Avtor: $artist';
  }

  @override
  String get arMarkerScannerLaunchViewerPrompt => 'Zaženem AR pregledovalnik?';

  @override
  String get arMarkerScannerLaunchFailedInstallPrompt => 'AR pregledovalnika ni mogoče zagnati. Namestim Google ARCore?';

  @override
  String get arMarkerScannerProcessingFailedToast => 'Obdelava QR kode ni uspela. Poskusite znova.';

  @override
  String get arMarkerScannerProcessingQrLabel => 'Obdelujem QR kodo…';

  @override
  String get arMarkerScannerPointCameraLabel => 'Usmerite kamero v QR kodo za odkrivanje AR umetnin';

  @override
  String get arMarkerScannerLaunchingViewerLabel => 'Zaganjam AR pregledovalnik…';

  @override
  String get arArtworkCardLaunchFailedToast => 'Zagon AR ni uspel. Poskusite znova.';

  @override
  String get arArtworkCardUnavailableLabel => 'AR ni na voljo';

  @override
  String get arArtworkCardGetCloserLabel => 'Približajte se';

  @override
  String get artistGalleryTitle => 'Vaša galerija';

  @override
  String artistGalleryArtworkCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count umetnin',
      few: '$count umetnine',
      two: '2 umetnini',
      one: '1 umetnina',
    );
    return '$_temp0';
  }

  @override
  String get artistGalleryStatActiveLabel => 'Aktivno';

  @override
  String get artistGalleryStatViewsLabel => 'Ogledi';

  @override
  String get artistGalleryStatLikesLabel => 'Všečki';

  @override
  String get artistGalleryFilterAll => 'Vse';

  @override
  String get artistGalleryFilterActive => 'Aktivno';

  @override
  String get artistGalleryFilterDraft => 'Osnutki';

  @override
  String get artistGalleryFilterSold => 'Prodano';

  @override
  String get artistGallerySortByTitle => 'Razvrsti po';

  @override
  String get artistGallerySortNewest => 'Najnovejše';

  @override
  String get artistGallerySortOldest => 'Najstarejše';

  @override
  String get artistGallerySortMostViews => 'Največ ogledov';

  @override
  String get artistGallerySortMostLikes => 'Največ všečkov';

  @override
  String get artistGallerySearchTitle => 'Išči umetnine';

  @override
  String get artistGallerySearchHint => 'Vnesite naslov umetnine…';

  @override
  String get artistGalleryCreateNewTitle => 'Ustvari novo umetnino';

  @override
  String get artistGalleryCreateNewDescription => 'Pojdite na zavihek Ustvari, da naložite in ustvarite novo umetnino.';

  @override
  String get artistGalleryGoToCreateButton => 'Pojdi na Ustvari';

  @override
  String get artistGalleryEmptyTitle => 'Še ni umetnin';

  @override
  String get artistGalleryEmptyDescription => 'Ustvarite svojo prvo umetnino, da začnete.';

  @override
  String get artistGalleryCreateArtworkButton => 'Ustvari umetnino';

  @override
  String artistGalleryEditingToast(Object title) {
    return 'Urejanje: $title';
  }

  @override
  String artistGallerySharingToast(Object title) {
    return 'Deljenje: $title';
  }

  @override
  String artistGalleryDeletedToast(Object title) {
    return '\"$title\" izbrisana';
  }

  @override
  String get artistGalleryDeleteArtworkTitle => 'Izbriši umetnino';

  @override
  String artistGalleryDeleteConfirmBody(Object title) {
    return 'Ali ste prepričani, da želite izbrisati \"$title\"? Tega dejanja ni mogoče razveljaviti.';
  }

  @override
  String get artistCreatorCreateArtworkButton => 'Ustvari umetnino';

  @override
  String get artistCreatorCoverSelectedToast => 'Naslovna slika izbrana';

  @override
  String get artistCreatorPickImageFailedToast => 'Izbira slike ni uspela. Poskusite znova.';

  @override
  String get artistCreatorModelSelectedToast => '3D model izbran';

  @override
  String get artistCreatorPickModelFailedToast => 'Izbira 3D modela ni uspela. Poskusite znova.';

  @override
  String get artistCreatorSelectImageToast => 'Prosimo, izberite sliko';

  @override
  String get artistCreatorConnectWalletToPublishToast => 'Povežite denarnico za objavo umetnine.';

  @override
  String get artistCreatorSelectCoverImageToast => 'Prosimo, izberite naslovno sliko.';

  @override
  String get artistCreatorUploadModelToEnableArToast => 'Naložite 3D model za omogočanje AR.';

  @override
  String get artistCreatorEnterLatLngOrDisableToast => 'Vnesite tako zemljepisno širino kot dolžino ali izklopite koordinate.';

  @override
  String get artistCreatorInvalidCoordinatesToast => 'Koordinate morajo biti veljavne vrednosti zemljepisne širine/dolžine.';

  @override
  String get artistCreatorCoverUrlMissingToast => 'Nalaganje je uspelo, vendar manjka povezava do naslovne slike.';

  @override
  String get artistCreatorSubmittedPendingToast => 'Umetnina je poslana. Odgovor strežnika še čaka.';

  @override
  String get artistCreatorSuccessTitle => 'Uspeh!';

  @override
  String get artistCreatorSuccessBody => 'Vaša umetnina je bila uspešno ustvarjena!';

  @override
  String get artistCreatorViewGalleryButton => 'Prikaži galerijo';

  @override
  String get artistCreatorCreateFailedToast => 'Ustvarjanje umetnine ni uspelo. Poskusite znova.';

  @override
  String get artistCreatorHelpTitle => 'Ustvarjanje AR označevalca';

  @override
  String get artistCreatorHelpBody => 'Sledite 4-koraknemu postopku za ustvarjanje AR umetnine:\n\n1. Naloži: Izberite sliko umetnine\n2. Podrobnosti: Vnesite naslov, opis in ceno\n3. Nastavitve: Nastavite lokacijo in funkcije\n4. Pregled: Potrdite in objavite umetnino';

  @override
  String get artistStudioTitle => 'Umetniški studio';

  @override
  String get artistStudioHeaderWelcome => 'Dobrodošli v vašem studiu';

  @override
  String get artistStudioHeaderSubtitle => 'Ustvarite AR označevalce za svojo umetnino in jih delite s svetom';

  @override
  String get artistStudioInstitutionRoleActiveTitle => 'Aktivna vloga institucije';

  @override
  String get artistStudioInstitutionReviewInProgressTitle => 'Pregled institucije v teku';

  @override
  String get artistStudioInstitutionRoleActiveDescription => 'Institucijski računi lahko vidijo razstave in dogodke, vendar ne morejo vzdrževati umetniških prijav. Za ustvarjanje umetnin uporabite ločeno umetniško denarnico.';

  @override
  String get artistStudioInstitutionReviewInProgressDescription => 'Imate odprto prijavo za institucijo. Pred preklopom na umetniški pregled jo zaključite ali umaknite.';

  @override
  String get artistStudioCrossRoleInstitutionBadgeActiveTitle => 'Značka institucije je aktivna';

  @override
  String get artistStudioCrossRoleInstitutionBadgeActiveDescription => 'Institucijski računi odklenejo kuratorstvo in orodja za dogodke. Če potrebujete ustvarjalna orodja, uporabite ločeno umetniško denarnico.';

  @override
  String get artistStudioCrossRoleInstitutionReviewInProgressTitle => 'Pregled institucije v teku';

  @override
  String get artistStudioCrossRoleInstitutionReviewInProgressDescription => 'Trenutno imate odprto prijavo za institucijo. Pred prijavo kot umetnik dokončajte postopek ali zahtevajte ponastavitev pregleda.';

  @override
  String get artistStudioCrossRoleConflictTitle => 'Zaznan konflikt vlog';

  @override
  String get artistStudioCrossRoleConflictDescription => 'Za to denarnico smo zaznali obstoječ institucijski zapis. Pred prijavo kot umetnik ga počistite v nastavitvah.';

  @override
  String get artistStudioDaoCardTitle => 'Umetniška prijava (DAO)';

  @override
  String get artistStudioDaoCardSubtitle => 'Predstavite svojo prakso v pregled DAO. Prihodnje izdaje bodo odobritve usmerjale neposredno skozi upravljanje.';

  @override
  String get artistStudioDaoStatusApproved => 'ODOBRENO';

  @override
  String get artistStudioDaoStatusPending => 'V OBRAVNAVI';

  @override
  String get artistStudioDaoStatusRejected => 'ZAVRNJENO';

  @override
  String get artistStudioDaoStatusNotApplied => 'NI PRIJAVE';

  @override
  String get artistStudioStatusSyncedFromDao => 'Stanje sinhronizirano iz DAO';

  @override
  String get artistStudioReviewPendingInfo => 'Vaša prijava je v čakalni vrsti za pregled DAO. Po odločitvi vas bomo obvestili.';

  @override
  String get artistStudioReviewApprovedInfo => 'Čestitamo! Pregledovalci DAO so vas odobrili.';

  @override
  String get artistStudioReviewRejectedInfo => 'Vaša zadnja prijava je bila zavrnjena. Lahko jo ponovno oddate z dopolnitvami.';

  @override
  String get artistStudioConnectWalletToSubmitForDaoReview => 'Povežite denarnico za oddajo v pregled DAO.';

  @override
  String get artistStudioCtaConnectWalletToApply => 'Povežite denarnico za prijavo';

  @override
  String get artistStudioCtaApprovedByDao => 'Odobreno s strani DAO';

  @override
  String get artistStudioCtaPendingDaoReview => 'V pregledu DAO';

  @override
  String get artistStudioCtaResubmitForReview => 'Ponovno oddaj v pregled';

  @override
  String get artistStudioCtaApplyForDaoReview => 'Prijavi za pregled DAO';

  @override
  String get artistStudioTabGallery => 'Galerija';

  @override
  String get artistStudioTabCreate => 'Ustvari';

  @override
  String get artistStudioTabAnalytics => 'Analitika';

  @override
  String get artistStudioUnlocksAfterDaoApprovalToast => 'Umetniški studio se odklene po odobritvi DAO.';

  @override
  String get artistStudioSeparateWalletsTip => 'Namig: Uporabite ločene denarnice za vloge umetnika in institucije, da se izognete konfliktom pri pregledih DAO.';

  @override
  String get artistStudioLockedTitle => 'Umetniški studio je zaklenjen';

  @override
  String get artistStudioLockedDescription => 'Prijavite se v pregled DAO, da odklenete galerijo, orodja za ustvarjanje in analitiko.';

  @override
  String get artistStudioSettingsTitle => 'Nastavitve studia';

  @override
  String get artistStudioApplicationModalTitle => 'Umetniška prijava';

  @override
  String get artistStudioApplicationModalSubtitle => 'Delite kratek vpogled v svojo prakso. Prijave se usmerijo v čakalno vrsto za pregled DAO.';

  @override
  String get artistStudioApplicationFieldPortfolioLabel => 'Portfelj ali spletna stran';

  @override
  String get artistStudioApplicationFieldMediumLabel => 'Glavni medij ali fokus';

  @override
  String get artistStudioApplicationFieldStatementLabel => 'Umetniška izjava';

  @override
  String get artistStudioApplicationValidationPortfolio => 'Prosimo, navedite povezavo do svojega dela';

  @override
  String get artistStudioApplicationValidationMedium => 'Povejte DAO, kaj ustvarjate';

  @override
  String artistStudioApplicationValidationStatementMinChars(Object min) {
    return 'Delite vsaj $min znakov o svojem delu';
  }

  @override
  String get artistStudioApplicationWalletRequiredToast => 'Pred oddajo v DAO povežite denarnico.';

  @override
  String get artistStudioApplicationReviewTitle => 'Umetniška prijava';

  @override
  String get artistStudioApplicationSubmittedToast => 'Prijava je poslana pregledovalcem DAO.';

  @override
  String get artistStudioApplicationUnableToSubmitToast => 'Trenutno ni mogoče oddati prijave.';

  @override
  String get artistStudioApplicationSubmissionFailedToast => 'Oddaja ni uspela. Poskusite znova.';

  @override
  String get artistStudioApplicationSubmitButton => 'Oddaj prijavo';

  @override
  String get desktopArtistStudioOverviewTitle => 'Pregled studia';

  @override
  String get desktopArtistStudioQuickActionsTitle => 'Hitre akcije';

  @override
  String get desktopArtistStudioQuickActionCreateArtworkTitle => 'Ustvari umetnino';

  @override
  String get desktopArtistStudioQuickActionCreateArtworkSubtitle => 'Naložite in izdajte novo umetnino';

  @override
  String get desktopArtistStudioQuickActionMyGalleryTitle => 'Moja galerija';

  @override
  String get desktopArtistStudioQuickActionMyGallerySubtitle => 'Prikaži vse umetnine';

  @override
  String get desktopArtistStudioQuickActionAnalyticsTitle => 'Analitika';

  @override
  String get desktopArtistStudioQuickActionAnalyticsSubtitle => 'Oglejte si statistiko uspešnosti';

  @override
  String get desktopArtistStudioStatisticsTitle => 'Statistika studia';

  @override
  String get desktopArtistStudioRecentActivityTitle => 'Nedavna dejavnost';

  @override
  String get desktopArtistStudioNoRecentActivityLabel => 'Ni nedavne dejavnosti';

  @override
  String get desktopArtistStudioVerificationNotAppliedTitle => 'Ni prijave';

  @override
  String get desktopArtistStudioVerificationNotAppliedDescription => 'Prijavite se za preverjanje umetnika';

  @override
  String get desktopArtistStudioVerificationLoadingTitle => 'Nalagam…';

  @override
  String get desktopArtistStudioVerificationLoadingDescription => 'Preverjam stanje preverjanja';

  @override
  String get desktopArtistStudioVerificationApprovedTitle => 'Preverjen umetnik';

  @override
  String get desktopArtistStudioVerificationApprovedDescription => 'Vaš studio je preverjen';

  @override
  String get desktopArtistStudioVerificationPendingTitle => 'Pregled v teku';

  @override
  String get desktopArtistStudioVerificationPendingDescription => 'Prijava je v pregledu';

  @override
  String get desktopArtistStudioVerificationRejectedTitle => 'Prijava zavrnjena';

  @override
  String get desktopArtistStudioVerificationRejectedDescription => 'Ponovno oddajte z izboljšavami';

  @override
  String get desktopArtistStudioApplyForVerificationButton => 'Prijavi za preverjanje';

  @override
  String get desktopArtistStudioStatArtworks => 'Umetnine';

  @override
  String get desktopArtistStudioStatViews => 'Ogledi';

  @override
  String get desktopArtistStudioStatLikes => 'Všečki';

  @override
  String get desktopArtistStudioStatSales => 'Prodaje';

  @override
  String get commonRemove => 'Odstrani';

  @override
  String get commonNotAvailableShort => 'N/A';

  @override
  String marketplaceNetworkLabel(Object network) {
    return 'Omrežje: $network';
  }

  @override
  String marketplaceWalletLabel(Object wallet) {
    return 'Denarnica: $wallet';
  }

  @override
  String get marketplaceConnectWalletTitle => 'Povežite denarnico';

  @override
  String get marketplaceConnectWalletDescription => 'Povežite Solana denarnico za ogled svojih NFT-jev.';

  @override
  String get marketplaceEmptyCollectionTitle => 'V vaši zbirki ni NFT-jev';

  @override
  String get marketplaceEmptyCollectionDescription => 'Izdajte NFT-je iz AR umetnin in jih zbirajte tukaj.';

  @override
  String get marketplaceExploreArArtButton => 'Raziščite AR umetnost';

  @override
  String get marketplaceListForSaleButton => 'Objavi za prodajo';

  @override
  String get marketplaceListForSaleSuccessToast => 'NFT je uspešno objavljen za prodajo!';

  @override
  String get marketplaceListForSaleFailedToast => 'NFT trenutno ni mogoče objaviti za prodajo.';

  @override
  String get marketplaceRemoveFromSaleTitle => 'Odstrani iz prodaje';

  @override
  String get marketplaceRemoveFromSaleConfirmBody => 'Želite odstraniti ta NFT s tržnice?';

  @override
  String get marketplaceRemoveFromSaleSuccessToast => 'NFT je odstranjen iz prodaje.';

  @override
  String get marketplaceMintConnectWalletTitle => 'Potrebna je denarnica';

  @override
  String get marketplaceMintConnectWalletDescription => 'Povežite denarnico za izdajo NFT-jev iz AR umetnin.';

  @override
  String get marketplaceMintSuccessTitle => 'Izdaja je uspela!';

  @override
  String get marketplaceMintSuccessDescription => 'NFT je uspešno izdan! Ogledate si ga lahko v svoji denarnici.';

  @override
  String get marketplaceViewInWalletButton => 'Ogled v denarnici';

  @override
  String get marketplaceMintFailedTitle => 'Izdaja ni uspela';

  @override
  String get marketplaceMintFailedDescription => 'NFT-ja trenutno ni mogoče izdati. Poskusite znova.';

  @override
  String get daoModerationApproveLabel => 'Odobri';

  @override
  String get daoModerationRejectLabel => 'Zavrni';

  @override
  String get daoModerationSetPendingLabel => 'Nastavi kot čakajoče';

  @override
  String daoModerationDecisionDialogTitle(Object decision) {
    return '$decision prijavo?';
  }

  @override
  String get daoModerationDecisionDialogDescription => 'Po želji dodajte opombe pregledovalca za prijavitelja.';

  @override
  String get daoModerationReviewerNotesLabel => 'Opombe pregledovalca (neobvezno)';

  @override
  String get daoModerationDisabledToast => 'Moderacija pregledov je onemogočena.';

  @override
  String get daoModerationWalletRequiredToast => 'Za moderiranje prijav povežite denarnico.';

  @override
  String get daoModerationSelfNotAllowedToast => 'Svoje prijave ne morete moderirati.';

  @override
  String get daoModerationSubmissionApprovedToast => 'Prijava odobrena';

  @override
  String get daoModerationSubmissionUpdatedToast => 'Prijava posodobljena';

  @override
  String get daoModerationNoChangesSavedToast => 'Spremembe niso shranjene';

  @override
  String get daoModerationUpdateFailedToast => 'Pregleda trenutno ni mogoče posodobiti.';

  @override
  String get daoReviewDetailsVotingDisabledForApplicant => 'Glasovanje za profil prijavitelja je onemogočeno.';

  @override
  String get daoReviewDetailsVotingDisabledForSubmission => 'Glasovanje za to prijavo je onemogočeno.';

  @override
  String get daoReviewDetailsVotingManagedByDao => 'Odločitve o pregledu upravlja DAO postopek.';

  @override
  String get daoReviewQueueTitle => 'Čakalna vrsta za pregled DAO';

  @override
  String get daoReviewVotingHandledByDaoHelper => 'Glasovanje poteka neposredno prek DAO; za odločanje uporabite predloge.';

  @override
  String get daoReviewCannotVoteOwnSubmissionHelper => 'O svoji prijavi ne morete glasovati';

  @override
  String get daoReviewVotingDisabledSubmissionHelper => 'Glasovanje za to prijavo je onemogočeno';

  @override
  String get daoReviewVotingOpensAfterReviewHelper => 'Glasovanje se odpre po pregledu';

  @override
  String daoReviewDecisionRecordedHelper(Object status) {
    return 'Odločitev zabeležena: $status';
  }

  @override
  String get daoReviewMediumNotProvided => 'Medij ni naveden';

  @override
  String get daoReviewViewDetailsButton => 'Ogled podrobnosti';

  @override
  String get daoReviewDetailsDialogTitle => 'Pregled prijave';

  @override
  String daoReviewDetailsPortfolioLabel(Object url) {
    return 'Portfelj: $url';
  }

  @override
  String daoReviewDetailsMediumLabel(Object medium) {
    return 'Medij: $medium';
  }

  @override
  String daoReviewDetailsStatusLabel(Object status) {
    return 'Status: $status';
  }

  @override
  String get daoReviewDetailsReviewerNotesLabel => 'Opombe pregledovalca:';

  @override
  String get daoProposalCategoryLabel => 'Kategorija';

  @override
  String get daoCategoryPlatformUpdate => 'Posodobitev platforme';

  @override
  String get daoCategoryNewFeature => 'Nova funkcija';

  @override
  String get daoCategoryPolicyChange => 'Sprememba pravil';

  @override
  String get daoCategoryTreasuryAllocation => 'Dodelitev zakladnice';

  @override
  String get daoCategoryCommunityInitiative => 'Pobuda skupnosti';

  @override
  String get daoCategoryTechnicalImprovement => 'Tehnična izboljšava';

  @override
  String get daoProposalRequirementsTitle => 'Zahteve za predlog';

  @override
  String get daoProposalRequirementWalletConnected => 'Za oddajo je potrebna povezava denarnice';

  @override
  String get daoProposalRequirementClearlyDefined => 'Predlog mora biti jasno opredeljen';

  @override
  String get daoProposalRequirementVotingPeriod => 'Obdobje glasovanja: 3–14 dni';

  @override
  String get daoProposalRequirementQuorumTargets => 'Cilji kvoruma so določeni z nastavitvami DAO';

  @override
  String get daoProposalFillRequiredFieldsToast => 'Prosimo, izpolnite vsa obvezna polja';

  @override
  String get daoProposalWalletRequiredToast => 'Za oddajo predlogov povežite denarnico.';

  @override
  String get daoProposalSubmittedToast => 'Predlog je oddan v DAO';

  @override
  String get daoProposalSubmitFailedToast => 'Predloga trenutno ni mogoče oddati.';

  @override
  String get daoQuorumReached => 'Kvorum dosežen';

  @override
  String get daoQuorumPending => 'Kvorum ni dosežen';

  @override
  String get daoVoteWalletRequiredToast => 'Pred glasovanjem povežite denarnico';

  @override
  String get daoVoteSubmittedYesToast => 'Glas ZA oddan';

  @override
  String get daoVoteSubmittedNoToast => 'Glas PROTI oddan';

  @override
  String get daoVoteSubmitFailedToast => 'Glasu trenutno ni mogoče oddati.';

  @override
  String get daoVoteYesButton => 'Glasuj ZA';

  @override
  String get daoVoteNoButton => 'Glasuj PROTI';

  @override
  String daoProposalVotesYesLabel(Object count) {
    return 'Za: $count';
  }

  @override
  String daoProposalVotesNoLabel(Object count) {
    return 'Proti: $count';
  }

  @override
  String daoProposalVotesAbstainLabel(Object count) {
    return 'Vzdržan: $count';
  }

  @override
  String get daoVotingHistoryUnknownProposal => 'Neznan predlog';

  @override
  String get daoVoteChoiceYes => 'Za';

  @override
  String get daoVoteChoiceNo => 'Proti';

  @override
  String get daoVoteChoiceAbstain => 'Vzdržan';

  @override
  String get daoVotingResultPassing => 'Sprejet';

  @override
  String get daoVotingResultNotPassing => 'Ni sprejet';

  @override
  String daoVotingHistoryYourPowerLabel(Object power) {
    return 'Vaša moč: $power';
  }

  @override
  String get daoVotingHistoryEmptyTitle => 'Zaenkrat še ni zgodovine glasovanja';

  @override
  String get daoVotingHistoryEmptyDescription => 'Oddajte svoj prvi glas pri aktivnem predlogu';

  @override
  String get daoActiveProposalsEmptyTitle => 'Ni aktivnih predlogov';

  @override
  String get daoActiveProposalsEmptyDescription => 'Oddajte predlog ali pregled, da se upravljanje premakne naprej.';

  @override
  String get daoTreasuryTitle => 'Zakladnica DAO';

  @override
  String get daoTreasurySubtitle => 'Sredstva skupnosti za razvoj platforme';

  @override
  String get daoTreasuryInflowLabel => 'Priliv';

  @override
  String get daoTreasuryOutflowLabel => 'Odliv';

  @override
  String get daoTreasuryProposalsLabel => 'Predlogi';

  @override
  String get daoRecentTransactionsTitle => 'Nedavne transakcije';

  @override
  String get daoRecentTransactionsEmptyTitle => 'Ni nedavnih transakcij';

  @override
  String get daoRecentTransactionsEmptyDescription => '';

  @override
  String commonTimeAgoDays(Object count) {
    return 'pred $count d';
  }

  @override
  String commonTimeAgoHours(Object count) {
    return 'pred $count h';
  }

  @override
  String commonTimeAgoMinutes(Object count) {
    return 'pred $count min';
  }

  @override
  String get daoTreasuryProposalsEmptyTitle => 'Zaenkrat še ni predlogov zakladnice';

  @override
  String get daoTreasuryProposalsEmptyDescription => 'Ustvarite zahtevek zakladnice za dodelitev KUB8 pobudam.';

  @override
  String get daoTreasuryProposalsTitle => 'Predlogi zakladnice';

  @override
  String get daoCreateProposalButton => 'Ustvari predlog';

  @override
  String get daoVoteDelegationTitle => 'Delegiranje glasovanja';

  @override
  String get daoVoteDelegationSubtitle => 'Delegirajte svojo glasovalno moč zaupanja vrednim članom skupnosti';

  @override
  String get daoTopDelegatesTitle => 'Najboljši delegati';

  @override
  String get daoTopDelegatesEmptyTitle => 'Zaenkrat ni delegatov';

  @override
  String get daoTopDelegatesEmptyDescription => 'Zaenkrat ni registriranih delegatov.';

  @override
  String get daoDelegateActiveLabel => 'Aktiven';

  @override
  String get daoTapToDelegateHint => 'Tapnite za delegiranje';

  @override
  String get daoDelegationActionsTitle => 'Dejanja delegiranja';

  @override
  String get daoDelegationActionsSubtitle => 'Izberite, kako uporabiti svojo glasovalno moč';

  @override
  String get daoDelegateToTrustedMembersButton => 'Delegiraj zaupanja vrednim članom';

  @override
  String get daoSelfDelegateButton => 'Samodelegiraj';

  @override
  String get daoRevokeButton => 'Prekliči';

  @override
  String get daoDelegateVotingPowerDialogTitle => 'Delegiraj glasovalno moč';

  @override
  String daoDelegateVotingPowerDialogBody(Object votingPower, Object delegateName) {
    return 'Ali res želite delegirati svojo glasovalno moč $votingPower delegatu $delegateName?';
  }

  @override
  String get daoDelegationBenefitsTitle => 'Prednosti delegiranja';

  @override
  String get daoDelegationBenefitsBody => '• Delegat bo glasoval v vašem imenu\n• Delegiranje lahko kadarkoli prekličete\n• Vaša glasovalna moč ostane vaša';

  @override
  String get daoConfirmDelegationButton => 'Potrdi delegiranje';

  @override
  String daoDelegationSuccessToast(Object delegateName) {
    return 'Glasovalna moč je uspešno delegirana delegatu $delegateName';
  }

  @override
  String get daoViewDelegationDetailsAction => 'Ogled podrobnosti';

  @override
  String get daoDelegationActiveTitle => 'Delegiranje je aktivno';

  @override
  String get daoDelegationDetailDelegateLabel => 'Delegat';

  @override
  String get daoDelegationDetailVotingPowerLabel => 'Glasovalna moč';

  @override
  String get daoDelegationDetailStatusLabel => 'Status';

  @override
  String get daoDelegationDetailStartedLabel => 'Začetek';

  @override
  String get daoDelegationStatusActive => 'Aktivno';

  @override
  String get daoDelegationStartedJustNow => 'Pravkar';

  @override
  String get daoRevokeDelegationButton => 'Prekliči delegiranje';

  @override
  String get daoDelegationRevokedToast => 'Delegiranje je uspešno preklicano';

  @override
  String get daoSelfDelegationEnabledToast => 'Samodelegiranje omogočeno';

  @override
  String get commonPost => 'Objava';

  @override
  String get commonComments => 'Komentarji';

  @override
  String get commonLikes => 'Všečki';

  @override
  String get commonReply => 'Odgovori';

  @override
  String get commonSend => 'Pošlji';

  @override
  String get commonYou => 'Ti';

  @override
  String get commonUnknown => 'Neznano';

  @override
  String get commonUnnamed => 'Brez imena';

  @override
  String get commonOwner => 'Lastnik';

  @override
  String get commonJoined => 'Pridružen';

  @override
  String get commonJoin => 'Pridruži se';

  @override
  String get commonPublic => 'Javno';

  @override
  String get commonPrivate => 'Zasebno';

  @override
  String get commonRefresh => 'Osveži';

  @override
  String commonMembersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count članov',
      few: '$count člani',
      two: '$count člana',
      one: '$count član',
    );
    return '$_temp0';
  }

  @override
  String commonCommentsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count komentarjev',
      few: '$count komentarji',
      two: '$count komentarja',
      one: '$count komentar',
    );
    return '$_temp0';
  }

  @override
  String commonDistanceKmAway(Object value) {
    return '$value km stran';
  }

  @override
  String commonTimeAgoWeeks(Object count) {
    return 'pred $count ted.';
  }

  @override
  String get commonTimeAgoJustNow => 'Pravkar';

  @override
  String get postDetailLoadPostFailedMessage => 'Objave ni bilo mogoče naložiti.';

  @override
  String get postDetailPostLikedToast => 'Objava je všečkana';

  @override
  String get postDetailLikeRemovedToast => 'Všeček odstranjen';

  @override
  String get postDetailUndoLikeFailedToast => 'Všečka ni bilo mogoče razveljaviti.';

  @override
  String get postDetailUpdateLikeFailedToast => 'Všečka ni bilo mogoče posodobiti.';

  @override
  String get postDetailRetryLikeFailedToast => 'Ponovni poskus ni uspel.';

  @override
  String get postDetailCommentAddedToast => 'Komentar dodan';

  @override
  String get postDetailAddCommentFailedToast => 'Komentarja ni bilo mogoče dodati.';

  @override
  String get postDetailUpdateCommentLikeFailedToast => 'Všečka ni bilo mogoče posodobiti.';

  @override
  String get postDetailLoadLikesFailedMessage => 'Všečkov ni bilo mogoče naložiti.';

  @override
  String get postDetailNoLikesTitle => 'Še ni všečkov';

  @override
  String get postDetailNoLikesDescription => 'Bodi prvi, ki všečka to';

  @override
  String get postDetailSharePostTitle => 'Deli objavo';

  @override
  String get postDetailSearchProfilesHint => 'Išči profile…';

  @override
  String get postDetailCopyLink => 'Kopiraj povezavo';

  @override
  String get postDetailLinkCopiedToast => 'Povezava kopirana v odložišče';

  @override
  String get postDetailShareViaEllipsis => 'Deli prek…';

  @override
  String get postDetailNoProfilesFoundTitle => 'Profilov ni bilo mogoče najti';

  @override
  String get postDetailNoProfilesFoundDescription => 'Poskusi z drugim iskalnim izrazom';

  @override
  String get postDetailShareDmDefaultMessage => 'Oglej si to objavo!';

  @override
  String postDetailShareSuccessToast(Object username) {
    return 'Objava deljena z @$username';
  }

  @override
  String get postDetailShareFailedToast => 'Deljenje ni uspelo.';

  @override
  String get postDetailRepostTitle => 'Ponovno objavi';

  @override
  String get postDetailRepostButton => 'Ponovno objavi';

  @override
  String get postDetailRepostSuccessToast => 'Ponovno objavljeno!';

  @override
  String get postDetailRepostWithCommentSuccessToast => 'Ponovno objavljeno s komentarjem!';

  @override
  String get postDetailRepostFailedToast => 'Ponovna objava ni uspela.';

  @override
  String get postDetailRepostThoughtsHint => 'Dodaj svoje misli (neobvezno)…';

  @override
  String get postDetailRepostingLabel => 'Ponovno objavljaš:';

  @override
  String get postDetailNoCommentsTitle => 'Še ni komentarjev';

  @override
  String get postDetailNoCommentsDescription => 'Bodi prvi, ki začne pogovor';

  @override
  String postDetailReplyingToLabel(Object author) {
    return 'Odgovarjaš uporabniku $author';
  }

  @override
  String get postDetailWriteCommentHint => 'Napiši komentar…';

  @override
  String get communityGroupsRefreshFailedToast => 'Skupin ni bilo mogoče osvežiti.';

  @override
  String get communityGroupMembershipUpdateFailedToast => 'Članstva ni bilo mogoče posodobiti.';

  @override
  String get communityGroupNoDescription => 'Opis ni na voljo.';

  @override
  String get communityGroupLatestPostLabel => 'Zadnja objava';

  @override
  String get communityOpenGroupFeedButton => 'Odpri vir skupine';

  @override
  String get communityLocationEnableServicesToast => 'Vključite lokacijske storitve, da lahko priložite lokacijo.';

  @override
  String get communityLocationPermissionRequiredToast => 'Za to dejanje je potrebno dovoljenje za lokacijo.';

  @override
  String get communityLocationUnableToDetermineToast => 'Lokacije ni mogoče določiti.';

  @override
  String get communityLocationUnableToAccessToast => 'Do lokacije ni mogoče dostopati.';

  @override
  String get communityArtFeedLocationPermissionRequiredError => 'Za umetniški vir je potrebno dovoljenje za lokacijo.';

  @override
  String get communityArtFeedLoadFailedError => 'Umetniškega vira ni mogoče naložiti.';

  @override
  String get communityArtFeedLoadFailedToast => 'Umetniškega vira trenutno ni mogoče naložiti.';

  @override
  String get communityFollowingFeedUnavailableToast => 'Vir Spremljam ni na voljo. Poskusite znova pozneje.';

  @override
  String get communityDiscoverFeedUnavailableToast => 'Vir Odkrij ni na voljo. Poskusite znova pozneje.';

  @override
  String get communityScreenTitle => 'Poveži se';

  @override
  String get communityFollowingTab => 'Spremljam';

  @override
  String get communityDiscoverTab => 'Odkrij';

  @override
  String get communityGroupsTab => 'Skupine';

  @override
  String get communityArtTab => 'Umetnost';

  @override
  String get communityFeedEmptyTitle => 'Še ni objav';

  @override
  String get communityFeedEmptyDescription => 'Spremljajte ustvarjalce, da boste tukaj videli njihove objave.';

  @override
  String get communityDiscoverEmptyTitle => 'Za zdaj ni nič za odkriti';

  @override
  String get communityDiscoverEmptyDescription => 'Kmalu preverite znova za nove objave.';

  @override
  String communityNewPostsBanner(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count novih objav',
      one: '1 novo objavo',
    );
    return 'Pokaži $_temp0';
  }

  @override
  String get communityGroupsEmptyTitle => 'Še ni skupin';

  @override
  String get communityGroupsEmptyDescription => 'Ustvarite skupino ali se pridružite obstoječi, da začnete sodelovati.';

  @override
  String communityGroupsEmptySearchDescription(Object query) {
    return 'Ni skupin za \"$query\".';
  }

  @override
  String get communityGroupsEndOfDirectory => 'Konec imenika';

  @override
  String get communityGroupsSearchHint => 'Išči skupine';

  @override
  String get communityClearSearchTooltip => 'Počisti iskanje';

  @override
  String get communityFabNewPost => 'Nova objava';

  @override
  String get communityFabCreateGroup => 'Ustvari skupino';

  @override
  String get communityFabGroupPost => 'Objava v skupini';

  @override
  String get communityFabArtDrop => 'Art drop';

  @override
  String get communityFabPostReview => 'Ocena umetnine';

  @override
  String get communityCreateGroupTitle => 'Ustvari skupino';

  @override
  String get communityCreateGroupNameLabel => 'Ime skupine';

  @override
  String get communityCreateGroupNameHint => 'npr. Ljubljana creators';

  @override
  String get communityCreateGroupDescriptionLabel => 'Opis';

  @override
  String get communityCreateGroupDescriptionHint => 'O čem je ta skupina?';

  @override
  String get communityCreateGroupPublicLabel => 'Javna skupina';

  @override
  String get communityCreateGroupPublicHint => 'Vsak se lahko pridruži in vidi objave.';

  @override
  String get communityCreateGroupPrivateHint => 'Člani se pridružijo z vabilom.';

  @override
  String get communityCreateGroupButton => 'Ustvari skupino';

  @override
  String get communityCreateGroupFailedToast => 'Skupine trenutno ni mogoče ustvariti.';

  @override
  String communityGroupCreatedToast(Object name) {
    return 'Skupina \"$name\" je ustvarjena.';
  }

  @override
  String get communityViewPostButton => 'Odpri objavo';

  @override
  String get communitySearchTypeProfiles => 'Profili';

  @override
  String get communitySearchTypeArtworks => 'Umetnine';

  @override
  String get communitySearchTypeInstitutions => 'Institucije';

  @override
  String get communitySearchTypeScreens => 'Zasloni';

  @override
  String get communitySearchTypePosts => 'Objave';

  @override
  String get communitySearchHintProfiles => 'Išči ljudi…';

  @override
  String get communitySearchHintArtworks => 'Išči umetnine…';

  @override
  String get communitySearchHintInstitutions => 'Išči institucije…';

  @override
  String get communitySearchHintScreens => 'Išči zaslone…';

  @override
  String get communitySearchHintPosts => 'Išči objave…';

  @override
  String get communitySearchEmptyStartTyping => 'Začnite tipkati za iskanje';

  @override
  String get communitySearchEmptyNoResults => 'Ni rezultatov';

  @override
  String get communitySearchSheetHintTags => 'Išči oznake…';

  @override
  String get communitySearchSheetHintProfiles => 'Išči uporabnike po imenu ali @uporabniškem…';

  @override
  String get communitySearchSheetHintArtworks => 'Išči umetnine…';

  @override
  String get communitySearchSheetHintDefault => 'Išči…';

  @override
  String get communityComposerTitle => 'Sestavi';

  @override
  String get communityComposerTextHint => 'Deli, kaj ustvarjaš, odkrivaš ali aktiviraš…';

  @override
  String get communityComposerTargetGroupLabel => 'Ciljna skupina';

  @override
  String get communityComposerGroupOptionalHelper => 'Neobvezno • Pridruži se skupini za dostop do kuratorskih klepetov.';

  @override
  String communityComposerPostingInGroupHelper(Object groupName) {
    return 'Objavljaš v $groupName. Tapni za spremembo ali odstranitev.';
  }

  @override
  String get communityComposerRemoveGroupTooltip => 'Odstrani skupino';

  @override
  String get communityComposerLinkArtworkTitle => 'Poveži umetnino';

  @override
  String get communityComposerLinkArtworkDescription => 'Izberi umetnino, ki jo želiš priložiti objavi.';

  @override
  String communityComposerArtworkAttachedDescription(Object title) {
    return 'Priložena umetnina: $title';
  }

  @override
  String get communityComposerRemoveArtworkTooltip => 'Odstrani umetnino';

  @override
  String get communityComposerAttachCurrentLocationButton => 'Priloži trenutno lokacijo';

  @override
  String get communityComposerAttachedLocationLabel => 'Priložena lokacija';

  @override
  String get communityComposerRemoveLocationTooltip => 'Odstrani lokacijo';

  @override
  String get communityBookmarkAddedToast => 'Objava shranjena!';

  @override
  String get communityBookmarkRemovedToast => 'Zaznamek odstranjen!';

  @override
  String get communityBookmarkUpdateFailedToast => 'Zaznamka ni bilo mogoče posodobiti.';

  @override
  String get communityComposerCategoryPostLabel => 'Objava';

  @override
  String get communityComposerCategoryPostDescription => 'Deli posodobitev s skupnostjo';

  @override
  String get communityComposerCategoryArtDropLabel => 'Art drop';

  @override
  String get communityComposerCategoryArtDropDescription => 'Deli novo umetnino ali kolekcijo';

  @override
  String get communityComposerCategoryArtReviewLabel => 'Ocena umetnine';

  @override
  String get communityComposerCategoryArtReviewDescription => 'Deli oceno ali kritiko';

  @override
  String get communityComposerCategoryEventLabel => 'Dogodek';

  @override
  String get communityComposerCategoryEventDescription => 'Napovej dogodek ali srečanje';

  @override
  String get communityComposerCategoryQuestionLabel => 'Vprašanje';

  @override
  String get communityComposerCategoryQuestionDescription => 'Vprašaj skupnost';

  @override
  String get communityGroupFeedEmptyTitle => 'Še ni objav v tej skupini';

  @override
  String get communityGroupFeedEmptyDescription => 'Bodi prvi, ki začne pogovor.';

  @override
  String communityGroupFeedShareText(Object authorName, Object groupName) {
    return 'Oglej si objavo uporabnika $authorName v skupini $groupName na art.kubus.';
  }

  @override
  String get communityArtFeedHeaderTitle => 'Umetniški vir';

  @override
  String communityArtFeedRadiusSubtitle(Object radius) {
    return 'Radij: $radius';
  }

  @override
  String communityArtFeedCenterSubtitle(Object lat, Object lng) {
    return 'Središče: $lat, $lng';
  }

  @override
  String get communityArtFeedEnablePreciseLocationHint => 'Omogočite natančno lokacijo za boljše rezultate.';

  @override
  String get communityArtFeedLocationNeededTitle => 'Potrebna je lokacija';

  @override
  String get communityArtFeedLocationNeededDescription => 'Omogočite lokacijo za ogled aktivacij v bližini.';

  @override
  String get communityArtFeedNoNearbyActivationsTitle => 'Ni aktivacij v bližini';

  @override
  String get communityArtFeedNoNearbyActivationsDescription => 'Poskusite osvežiti lokacijo ali povečati radij.';

  @override
  String get communityArtFeedRefreshLocationButton => 'Osveži lokacijo';

  @override
  String get communityArtFeedAboutTitle => 'O umetniškem viru';

  @override
  String get communityArtFeedAboutBody => 'Umetniški vir prikazuje lokacijske aktivacije, ki jih delijo člani skupnosti v vaši bližini.';

  @override
  String get communityArtFeedAboutButton => 'O tem';

  @override
  String communityArtFeedShareText(Object authorName) {
    return 'Oglejte si aktivacijo uporabnika $authorName na art.kubus.';
  }

  @override
  String get communityNameThisPlaceTitle => 'Poimenuj ta kraj';

  @override
  String get communityNamePlaceHint => 'npr. Mestni park';

  @override
  String get communityConnectWalletFirstToast => 'Najprej povežite denarnico.';

  @override
  String get communityUnableToAuthenticateToast => 'Overitev ni uspela. Poskusite znova.';

  @override
  String get communityComposerAddContentToast => 'Dodajte besedilo, sliko ali video.';

  @override
  String communityComposerSharedInGroupToast(Object groupName) {
    return 'Objavljeno v $groupName';
  }

  @override
  String get communityGroupFallbackName => 'tej skupini';

  @override
  String get communityComposerPostCreatedToast => 'Objava ustvarjena';

  @override
  String get communityComposerCreatePostFailedToast => 'Objave ni bilo mogoče ustvariti.';

  @override
  String get communityToggleLikeFailedToast => 'Všečka ni bilo mogoče posodobiti.';

  @override
  String get communityPostLikesTitle => 'Všečki objave';

  @override
  String get communityCommentLikesTitle => 'Všečki komentarja';

  @override
  String get communityReplyingToCommentLabel => 'Odgovarjate…';

  @override
  String get communityCommentAuthRequiredToast => 'Za komentiranje se prijavite.';

  @override
  String get communityRepostsLoadFailedMessage => 'Ponovnih objav ni bilo mogoče naložiti.';

  @override
  String get communityNoRepostsTitle => 'Še ni ponovnih objav';

  @override
  String get communityNoRepostsDescription => 'Bodi prvi, ki ponovno objavi to';

  @override
  String get communityUnrepostAction => 'Prekliči ponovno objavo';

  @override
  String get communityUnrepostTitle => 'Odstranim ponovno objavo?';

  @override
  String get communityUnrepostConfirmBody => 'Želite odstraniti svojo ponovno objavo te objave?';

  @override
  String get communityRepostRemovedToast => 'Ponovna objava odstranjena';

  @override
  String get communityUnrepostFailedToast => 'Ponovne objave ni bilo mogoče odstraniti.';

  @override
  String get commonSomethingWentWrong => 'Nekaj je šlo narobe.';

  @override
  String get commonGreetingMorning => 'Dobro jutro';

  @override
  String get commonGreetingAfternoon => 'Dober dan';

  @override
  String get commonGreetingEvening => 'Dober večer';

  @override
  String get commonWeekdayMonShort => 'Pon';

  @override
  String get commonWeekdayTueShort => 'Tor';

  @override
  String get commonWeekdayWedShort => 'Sre';

  @override
  String get commonWeekdayThuShort => 'Čet';

  @override
  String get commonWeekdayFriShort => 'Pet';

  @override
  String get commonWeekdaySatShort => 'Sob';

  @override
  String get commonWeekdaySunShort => 'Ned';

  @override
  String get commonIosLabel => 'iOS';

  @override
  String get commonAndroidLabel => 'Android';

  @override
  String downloadAppCouldNotOpenStoreToast(Object url) {
    return 'Trgovine ni bilo mogoče odpreti. Obiščite: $url';
  }

  @override
  String get downloadAppDefaultFeatureName => 'AR funkcije';

  @override
  String downloadAppExperienceInArTitle(Object featureName) {
    return 'Doživite $featureName v AR';
  }

  @override
  String get downloadAppDefaultDescription => 'Za najboljšo AR izkušnjo uporabite mobilno aplikacijo.';

  @override
  String get downloadAppFeatureViewInAr => 'Ogled umetnin v AR';

  @override
  String get downloadAppFeatureScanArtworks => 'Skenirajte umetnine';

  @override
  String get downloadAppFeatureInteractive3d => 'Interaktivni 3D modeli';

  @override
  String get downloadAppFeatureLocationDiscovery => 'Odkrijte glede na lokacijo';

  @override
  String get downloadAppDownloadForLabel => 'Prenesi za:';

  @override
  String get downloadAppScanQrTitle => 'Skenirajte QR kodo';

  @override
  String get downloadAppScanQrSubtitle => 'Odprite to stran na telefonu za prenos aplikacije.';

  @override
  String get downloadAppContinueBrowsingButton => 'Nadaljuj brskanje';

  @override
  String get homeDefaultDisplayName => 'prijatelj';

  @override
  String get homeWelcomeSubtitle => 'Ste pripravljeni danes odkriti novo umetnost?';

  @override
  String get homeExploreWeb3Button => 'Razišči Web3';

  @override
  String get homeQuickActionsTitle => 'Hitra dejanja';

  @override
  String get homeRecentlyUsedLabel => 'Nedavno uporabljeno';

  @override
  String get homeQuickActionsEmptyDescription => 'Bližnjice se bodo prikazale tukaj, ko boste uporabljali aplikacijo.';

  @override
  String get homeYourStatsTitle => 'Vaša statistika';

  @override
  String get homeNoStatsAvailableTitle => 'Še ni statistike';

  @override
  String get homeNoStatsAvailableDescription => 'Pozneje preverite svojo statistiko aktivnosti.';

  @override
  String get homeStatArtworks => 'Umetnine';

  @override
  String get homeStatFollowers => 'Sledilci';

  @override
  String get homeStatViews => 'Ogledi';

  @override
  String homeStatsDialogTitle(Object statName) {
    return 'Podrobnosti za $statName';
  }

  @override
  String homeStatsTrendTitle(Object statName) {
    return 'Trend za $statName';
  }

  @override
  String get homeViewAdvancedButton => 'Napredno';

  @override
  String get homeRecentMilestonesTitle => 'Nedavni mejniki';

  @override
  String get homeStatsNoMilestonesYet => 'Še ni mejnikov';

  @override
  String get homeStatsMilestoneArtworks1 => 'Prva ustvarjena umetnina';

  @override
  String get homeStatsMilestoneArtworks2 => '5 ustvarjenih umetnin';

  @override
  String get homeStatsMilestoneArtworks3 => '10 ustvarjenih umetnin';

  @override
  String get homeStatsMilestoneFollowers1 => 'Prvi sledilec';

  @override
  String get homeStatsMilestoneFollowers2 => '10 sledilcev';

  @override
  String get homeStatsMilestoneFollowers3 => '50 sledilcev';

  @override
  String get homeStatsMilestoneViews1 => '100 ogledov';

  @override
  String get homeStatsMilestoneViews2 => '500 ogledov';

  @override
  String get homeStatsMilestoneViews3 => '1.000 ogledov';

  @override
  String get homeRecentActivityTitle => 'Nedavna aktivnost';

  @override
  String get homeNoRecentActivityTitle => 'Ni nedavne aktivnosti';

  @override
  String get homeNoRecentActivityDescription => 'Vaša nedavna dejanja se bodo prikazala tukaj.';

  @override
  String get homeUnableToLoadActivityTitle => 'Aktivnosti ni mogoče naložiti';

  @override
  String get homeFeaturedArtworksTitle => 'Izbrane umetnine';

  @override
  String get homeNoFeaturedArtworksTitle => 'Ni izbranih umetnin';

  @override
  String get homeNoFeaturedArtworksDescription => 'Kmalu se vrnite po skrbno izbrane predloge.';

  @override
  String get homeActivityTitle => 'Aktivnost';

  @override
  String get homeMarkAllReadButton => 'Označi vse kot prebrano';

  @override
  String get homeUnableToLoadNotificationsTitle => 'Obvestil ni mogoče naložiti';

  @override
  String get homeNoNotificationsTitle => 'Ni obvestil';

  @override
  String get homeAllCaughtUpDescription => 'Vse je pregledano.';

  @override
  String get homeMockNotificationNewArtworkTitle => 'Dodana nova umetnina';

  @override
  String get homeMockNotificationNewArtworkBody => 'V galerijo je bila dodana nova umetnina.';

  @override
  String get homeMockNotificationCommunityTitle => 'Posodobitev skupnosti';

  @override
  String get homeMockNotificationCommunityBody => 'V skupnosti vas čakajo nove objave.';

  @override
  String get homeMockNotificationRewardsTitle => 'Na voljo so nagrade';

  @override
  String get homeMockNotificationRewardsBody => 'Na voljo imate nove nagrade za prevzem.';

  @override
  String get commonExplore => 'Razišči';

  @override
  String get commonNoSuggestions => 'Ni predlogov';

  @override
  String get commonArShort => 'AR';

  @override
  String get desktopHomeWelcomeFallbackName => 'Dobrodošli v art.kubus';

  @override
  String get desktopHomeDiscoverArtTitle => 'Odkrijte umetnost okoli sebe';

  @override
  String get desktopHomeDiscoverArtDescription => 'Raziskujte poglobljena dela v obogateni resničnosti, povežite se z ustvarjalci in zaslužite žetone KUB8 za odkrivanje umetnosti.';

  @override
  String get desktopHomeYourActivityTitle => 'Vaša aktivnost';

  @override
  String get desktopHomeYourActivitySubtitle => 'Spremljajte svoj napredek in sodelovanje';

  @override
  String get desktopHomeStatArtworksDiscovered => 'Odkrita dela';

  @override
  String get desktopHomeStatArSessions => 'AR seje';

  @override
  String get desktopHomeStatNftsCollected => 'Zbrani NFT-ji';

  @override
  String get desktopHomeStatKub8Earned => 'Prisluženi KUB8';

  @override
  String get desktopHomeQuickActionsSubtitle => 'Na podlagi vaših nedavnih obiskov';

  @override
  String get desktopHomeQuickActionsEmptySubtitle => 'Začnite raziskovati, da se tu prikažejo nedavni zasloni';

  @override
  String get desktopHomeQuickActionsEmptyTitle => 'Za zdaj ni nedavnih obiskov';

  @override
  String get desktopHomeQuickActionsEmptyDescription => 'Pojdite na različne zaslone in prikazali se bodo tukaj za hiter dostop. Kartice izginejo po 24 urah neaktivnosti.';

  @override
  String get desktopHomeFeaturedArtworksSubtitle => 'Odkrijte priljubljeno AR umetnost';

  @override
  String get desktopHomeWeb3HubTitle => 'Web3 središče';

  @override
  String get desktopHomeWeb3HubSubtitle => 'Dostop do decentraliziranih funkcij';

  @override
  String get desktopHomeTrendingArtTitle => 'Priljubljena umetnost';

  @override
  String get desktopHomeTrendingArtLoadFailed => 'Priljubljene umetnosti ni mogoče naložiti.';

  @override
  String get desktopHomeTrendingArtEmpty => 'Priljubljena dela se bodo prikazala tukaj';

  @override
  String get desktopHomeTopCreatorsTitle => 'Naj ustvarjalci';

  @override
  String get desktopHomeTopCreatorsLoadFailed => 'Ustvarjalcev ni mogoče naložiti.';

  @override
  String get desktopHomeTopCreatorsEmpty => 'Naj ustvarjalci se bodo prikazali tukaj';

  @override
  String get desktopHomeCreatorFallbackName => 'Ustvarjalec';

  @override
  String desktopHomePostsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count objav',
      few: '$count objave',
      two: '2 objavi',
      one: '1 objava',
    );
    return '$_temp0';
  }

  @override
  String get desktopHomePlatformStatsTitle => 'Statistika platforme';

  @override
  String get desktopHomePlatformStatsLoadFailed => 'Statistike skupnosti ni mogoče naložiti.';

  @override
  String get desktopHomePlatformStatsTotalArtworks => 'Skupaj del';

  @override
  String get desktopHomePlatformStatsArEnabled => 'AR omogočeno';

  @override
  String get desktopHomePlatformStatsCommunityPosts => 'Objave skupnosti';

  @override
  String get desktopHomePlatformStatsActiveGroups => 'Aktivne skupine';

  @override
  String get desktopHomeUnreadNotificationsLabel => 'neprebrana obvestila';

  @override
  String get homeWeb3SectionTitle => 'Web3';

  @override
  String get homeAccountRequiredLabel => 'Potrebna denarnica';

  @override
  String get homeWeb3DaoTitle => 'DAO';

  @override
  String get homeWeb3DaoSubtitle => 'Upravljanje in glasovanje';

  @override
  String get homeWeb3ArtistTitle => 'Umetniški studio';

  @override
  String get homeWeb3ArtistSubtitle => 'Mintanje in upravljanje';

  @override
  String get homeWeb3InstitutionTitle => 'Institucije';

  @override
  String get homeWeb3InstitutionSubtitle => 'Dogodki in zbirke';

  @override
  String get homeWeb3MarketplaceTitle => 'Tržnica';

  @override
  String get homeWeb3MarketplaceSubtitle => 'Odkrij in trguj';

  @override
  String get homeMockNotificationFriendRequestTitle => 'Nova prošnja za prijateljstvo';

  @override
  String get homeMockNotificationFriendRequestBody => 'Nekdo vam je poslal prošnjo za prijateljstvo.';

  @override
  String get homeMockNotificationFeaturedTitle => 'Danes izpostavljeno';

  @override
  String get homeMockNotificationFeaturedBody => 'Oglejte si današnjo izbrano umetnino.';

  @override
  String get commonReset => 'Ponastavi';

  @override
  String get onboardingResetToolTitle => 'Orodje za ponastavitev uvajanja';

  @override
  String get onboardingResetDialogTitle => 'Ponastavi uvajanje';

  @override
  String get onboardingResetDialogBody => 'To bo ponastavilo vse zastavice uvajanja. Aplikacija bo ob naslednjem zagonu prikazala uvajalne zaslone.\n\nNadaljujem?';

  @override
  String get onboardingResetSnackBarMessage => 'Stanje uvajanja je ponastavljeno! Znova zaženite aplikacijo, da se prikaže uvajanje.';

  @override
  String get onboardingResetDeveloperToolTitle => 'Razvijalsko orodje';

  @override
  String get onboardingResetDeveloperToolDescription => 'To orodje prikazuje trenutno stanje uvajanja in omogoča ponastavitev za testiranje.';

  @override
  String get onboardingResetCurrentStateTitle => 'Trenutno stanje uvajanja';

  @override
  String get onboardingResetConfigSettingsTitle => 'Nastavitve konfiguracije';

  @override
  String get onboardingResetButtonLabel => 'Ponastavi stanje uvajanja';

  @override
  String get onboardingResetHowToTestTitle => 'Kako testirati';

  @override
  String get onboardingResetHowToTestSteps => '1. Tapnite »Ponastavi stanje uvajanja«\n2. Znova zaženite aplikacijo (zaprite in ponovno odprite)\n3. Uvajanje se mora prikazati ob zagonu';

  @override
  String get season0BannerTitle => 'Sezona 0, Ljubljana (beta)';

  @override
  String get season0BannerTap => 'Več o programu lansiranja';

  @override
  String get season0ScreenTitle => 'Sezona 0';

  @override
  String get season0ScreenSubtitle => 'Beta zagon v Ljubljani';

  @override
  String get season0ScreenDescription => 'Pridružite se ustanovnemu programu art.kubus v Ljubljani. Prijavite se kot umetnik ali institucija in soustvarjajte prvo sezono platforme.';

  @override
  String get season0ApplyArtistCta => 'Prijava kot umetnik';

  @override
  String get season0ApplyArtistSubtitle => 'Pridruži se kot ustvarjalec ali kolektiv';

  @override
  String get season0ApplyInstitutionCta => 'Prijava kot institucija';

  @override
  String get season0ApplyInstitutionSubtitle => 'Registriraj svojo galerijo ali prostor';

  @override
  String get season0NewsletterCta => 'Naroči se na novice';

  @override
  String get season0NewsletterSubtitle => 'Prejemaj novice o napredku in dogodkih';

  @override
  String get season0PointsLabel => 'KUB8 točke';

  @override
  String get season0PointsTooltip => 'Izvenveržni žetoni napredka';

  @override
  String get season0OnChainNote => 'Veržne funkcije so na voljo v Labs';
}
