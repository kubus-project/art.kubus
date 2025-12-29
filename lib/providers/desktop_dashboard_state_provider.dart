import 'package:flutter/foundation.dart';

enum DesktopArtistStudioSection {
  gallery,
  create,
  exhibitions,
  analytics,
}

enum DesktopInstitutionSection {
  events,
  exhibitions,
  create,
  analytics,
}

class DesktopDashboardStateProvider extends ChangeNotifier {
  DesktopArtistStudioSection _artistStudioSection = DesktopArtistStudioSection.gallery;
  DesktopInstitutionSection _institutionSection = DesktopInstitutionSection.events;

  DesktopArtistStudioSection get artistStudioSection => _artistStudioSection;
  DesktopInstitutionSection get institutionSection => _institutionSection;

  void setArtistStudioSection(DesktopArtistStudioSection section) {
    if (_artistStudioSection == section) return;
    _artistStudioSection = section;
    notifyListeners();
  }

  void setInstitutionSection(DesktopInstitutionSection section) {
    if (_institutionSection == section) return;
    _institutionSection = section;
    notifyListeners();
  }

  void updateArtistStudioSectionFromTabIndex({
    required int tabIndex,
    required bool exhibitionsEnabled,
  }) {
    final section = _artistStudioSectionFromTabIndex(
      tabIndex: tabIndex,
      exhibitionsEnabled: exhibitionsEnabled,
    );
    if (section == null) return;
    setArtistStudioSection(section);
  }

  void updateInstitutionSectionFromTabIndex({
    required int tabIndex,
    required bool exhibitionsEnabled,
  }) {
    final section = _institutionSectionFromTabIndex(
      tabIndex: tabIndex,
      exhibitionsEnabled: exhibitionsEnabled,
    );
    if (section == null) return;
    setInstitutionSection(section);
  }

  DesktopArtistStudioSection? _artistStudioSectionFromTabIndex({
    required int tabIndex,
    required bool exhibitionsEnabled,
  }) {
    if (tabIndex == 0) return DesktopArtistStudioSection.gallery;
    if (tabIndex == 1) return DesktopArtistStudioSection.create;
    if (exhibitionsEnabled) {
      if (tabIndex == 2) return DesktopArtistStudioSection.exhibitions;
      if (tabIndex == 3) return DesktopArtistStudioSection.analytics;
      return null;
    }
    if (tabIndex == 2) return DesktopArtistStudioSection.analytics;
    return null;
  }

  DesktopInstitutionSection? _institutionSectionFromTabIndex({
    required int tabIndex,
    required bool exhibitionsEnabled,
  }) {
    if (tabIndex == 0) return DesktopInstitutionSection.events;
    if (exhibitionsEnabled) {
      if (tabIndex == 1) return DesktopInstitutionSection.exhibitions;
      if (tabIndex == 2) return DesktopInstitutionSection.create;
      if (tabIndex == 3) return DesktopInstitutionSection.analytics;
      return null;
    }
    if (tabIndex == 1) return DesktopInstitutionSection.create;
    if (tabIndex == 2) return DesktopInstitutionSection.analytics;
    return null;
  }
}

