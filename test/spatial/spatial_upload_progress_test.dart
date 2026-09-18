import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/node/kubus_node_transport.dart';
import 'package:art_kubus/services/spatial_node_upload.dart';
import 'package:art_kubus/widgets/spatial/spatial_upload_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(
  WidgetTester tester,
  SpatialTransferProgress progress, {
  Size size = const Size(320, 640),
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SpatialUploadProgress(progress: progress),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

const mid = SpatialTransferProgress(
  phase: SpatialTransferPhase.uploading,
  uploadedFiles: 84,
  totalFiles: 126,
  confirmedBytes: 328 * 1000 * 1000,
  totalBytes: 489 * 1000 * 1000,
  bytesPerSecond: 8.6 * 1000 * 1000,
  eta: Duration(seconds: 19),
  route: KubusNodeTransportKind.localDirect,
);

void main() {
  testWidgets('shows the measured state of the transfer', (tester) async {
    await pump(tester, mid);

    expect(find.textContaining('67%'), findsOneWidget);
    // Byte sizes are binary-prefixed by the shared formatter; what matters
    // here is that both halves of the ratio are shown.
    expect(find.textContaining(RegExp(r'MB / .* MB')), findsOneWidget);
    expect(find.textContaining('19 sec'), findsOneWidget);
    expect(find.textContaining('84 / 126 files'), findsOneWidget);
    expect(find.textContaining('Local network'), findsOneWidget);
  });

  testWidgets('says nothing when nothing is being transferred', (tester) async {
    await pump(tester, const SpatialTransferProgress());

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a stalled transfer is stated, not counted down', (tester) async {
    await pump(
      tester,
      const SpatialTransferProgress(
        phase: SpatialTransferPhase.uploading,
        uploadedFiles: 40,
        totalFiles: 126,
        confirmedBytes: 100 * 1000 * 1000,
        totalBytes: 489 * 1000 * 1000,
        stalled: true,
      ),
    );

    expect(find.textContaining('Waiting for your node'), findsOneWidget);
    expect(find.textContaining('remaining'), findsNothing);
    // What was delivered is still shown; the user has not lost it.
    expect(find.textContaining('20%'), findsOneWidget);
  });

  testWidgets('progress is exposed as a sentence, not only as a bar',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, mid);

    expect(
      find.bySemanticsLabel(RegExp('67%')),
      findsOneWidget,
      reason: 'a screen reader must get the percentage, not just the bar',
    );
    handle.dispose();
  });

  testWidgets('lays out at large text on a narrow phone without overflowing',
      (tester) async {
    await pump(tester, mid, size: const Size(320, 640), textScale: 2.0);

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders in Slovene', (tester) async {
    await pump(tester, mid, locale: const Locale('sl'));

    expect(find.textContaining('Lokalno omrežje'), findsOneWidget);
    expect(find.textContaining('67%'), findsOneWidget);
  });
}
