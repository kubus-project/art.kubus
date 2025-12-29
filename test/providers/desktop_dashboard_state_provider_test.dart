import 'package:art_kubus/providers/desktop_dashboard_state_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DesktopDashboardStateProvider defaults are stable', () {
    final provider = DesktopDashboardStateProvider();
    expect(provider.artistStudioSection, DesktopArtistStudioSection.gallery);
    expect(provider.institutionSection, DesktopInstitutionSection.events);
  });

  test('DesktopDashboardStateProvider maps artist studio tabs with exhibitions enabled', () {
    final provider = DesktopDashboardStateProvider();
    provider.updateArtistStudioSectionFromTabIndex(tabIndex: 0, exhibitionsEnabled: true);
    expect(provider.artistStudioSection, DesktopArtistStudioSection.gallery);

    provider.updateArtistStudioSectionFromTabIndex(tabIndex: 1, exhibitionsEnabled: true);
    expect(provider.artistStudioSection, DesktopArtistStudioSection.create);

    provider.updateArtistStudioSectionFromTabIndex(tabIndex: 2, exhibitionsEnabled: true);
    expect(provider.artistStudioSection, DesktopArtistStudioSection.exhibitions);

    provider.updateArtistStudioSectionFromTabIndex(tabIndex: 3, exhibitionsEnabled: true);
    expect(provider.artistStudioSection, DesktopArtistStudioSection.analytics);
  });

  test('DesktopDashboardStateProvider maps artist studio tabs without exhibitions', () {
    final provider = DesktopDashboardStateProvider();
    provider.updateArtistStudioSectionFromTabIndex(tabIndex: 2, exhibitionsEnabled: false);
    expect(provider.artistStudioSection, DesktopArtistStudioSection.analytics);
  });

  test('DesktopDashboardStateProvider maps institution tabs with exhibitions enabled', () {
    final provider = DesktopDashboardStateProvider();
    provider.updateInstitutionSectionFromTabIndex(tabIndex: 0, exhibitionsEnabled: true);
    expect(provider.institutionSection, DesktopInstitutionSection.events);

    provider.updateInstitutionSectionFromTabIndex(tabIndex: 1, exhibitionsEnabled: true);
    expect(provider.institutionSection, DesktopInstitutionSection.exhibitions);

    provider.updateInstitutionSectionFromTabIndex(tabIndex: 2, exhibitionsEnabled: true);
    expect(provider.institutionSection, DesktopInstitutionSection.create);

    provider.updateInstitutionSectionFromTabIndex(tabIndex: 3, exhibitionsEnabled: true);
    expect(provider.institutionSection, DesktopInstitutionSection.analytics);
  });

  test('DesktopDashboardStateProvider ignores unknown tab indexes', () {
    final provider = DesktopDashboardStateProvider();
    provider.setArtistStudioSection(DesktopArtistStudioSection.create);

    var notifications = 0;
    provider.addListener(() => notifications += 1);

    provider.updateArtistStudioSectionFromTabIndex(tabIndex: 99, exhibitionsEnabled: true);
    expect(provider.artistStudioSection, DesktopArtistStudioSection.create);
    expect(notifications, 0);
  });
}

