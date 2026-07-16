import 'package:art_kubus/features/map/navigation/walking_navigation_models.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/walking_navigation_provider.dart';
import 'package:art_kubus/services/walking_directions_service.dart';
import 'package:art_kubus/widgets/map/navigation/kubus_walking_navigation_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const _intent = WalkingNavigationIntent(
  destinationId: 'artwork-1',
  destinationLabel: 'Artwork',
  destination: LatLng(46.05, 14.5),
);

void main() {
  testWidgets('permanently denied permission offers app settings',
      (tester) async {
    final provider = _providerWithLocationFailure(
      WalkingLocationAccessStatus.permissionDeniedPermanently,
    );
    addTearDown(provider.dispose);

    await _pumpPanel(tester, provider);

    expect(find.text('Open app settings'), findsOneWidget);
    expect(find.text('Open location settings'), findsNothing);
  });

  testWidgets('disabled services offer location settings', (tester) async {
    final provider = _providerWithLocationFailure(
      WalkingLocationAccessStatus.serviceDisabled,
    );
    addTearDown(provider.dispose);

    await _pumpPanel(tester, provider);

    expect(find.text('Open location settings'), findsOneWidget);
    expect(find.text('Open app settings'), findsNothing);
  });

  testWidgets('routing failures show distinct localized messages',
      (tester) async {
    final cases = <WalkingDirectionsErrorType, String>{
      WalkingDirectionsErrorType.noRoute:
          'No connected pedestrian route was found.',
      WalkingDirectionsErrorType.routeTooLong:
          'outside the supported walking-navigation distance',
      WalkingDirectionsErrorType.sourceTimeout: 'route source timed out',
      WalkingDirectionsErrorType.sourceTransport:
          'route source could not be reached',
      WalkingDirectionsErrorType.sourceInvalidResponse:
          'returned an invalid response',
    };
    for (final entry in cases.entries) {
      final provider = WalkingNavigationProvider(
        directionsApi: _ThrowingApi(entry.key),
      );
      provider.start(_intent);
      await provider.updatePosition(const LatLng(46.04, 14.49));
      await _pumpPanel(tester, provider);
      expect(find.textContaining(entry.value), findsOneWidget);
      expect(find.text('internal routing detail'), findsNothing);
      provider.dispose();
    }
  });
}

WalkingNavigationProvider _providerWithLocationFailure(
  WalkingLocationAccessStatus status,
) {
  final provider = WalkingNavigationProvider(directionsApi: _UnusedApi());
  final lease = provider.start(_intent);
  provider.reportLocationAccess(status, lease: lease);
  return provider;
}

Future<void> _pumpPanel(
  WidgetTester tester,
  WalkingNavigationProvider provider,
) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: KubusWalkingNavigationPanel(
            navigation: provider,
            onEnd: () {},
            onResume: () {},
            onRetry: () {},
            onAllowLocation: () {},
            onOpenAppSettings: () {},
            onOpenLocationSettings: () {},
            onUseExternalMaps: () {},
            onViewDestination: () {},
          ),
        ),
      ),
    );

class _UnusedApi implements WalkingDirectionsApi {
  @override
  Future<WalkingRoute> route({
    required LatLng origin,
    required LatLng destination,
  }) =>
      throw StateError('unused');

  @override
  void dispose() {}
}

class _ThrowingApi implements WalkingDirectionsApi {
  _ThrowingApi(this.type);

  final WalkingDirectionsErrorType type;

  @override
  Future<WalkingRoute> route({
    required LatLng origin,
    required LatLng destination,
  }) =>
      Future<WalkingRoute>.error(
        WalkingDirectionsException('internal routing detail', type: type),
      );

  @override
  void dispose() {}
}
