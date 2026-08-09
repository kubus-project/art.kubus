import 'package:art_kubus/services/diagnostics/flutter_error_context.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [DiagnosticsNode] whose description throws, standing in for a widget
/// whose `debugFillProperties` misbehaves while an error is being described.
class _ThrowingDiagnostics extends DiagnosticsProperty<String> {
  _ThrowingDiagnostics() : super('bad', 'bad');

  @override
  String toDescription({TextTreeConfiguration? parentConfiguration}) {
    throw StateError('diagnostics description failed');
  }
}

/// An object whose `runtimeType` cannot be rendered.
class _HostileError {
  @override
  String toString() => throw StateError('toString failed');
}

void main() {
  group('buildFlutterErrorContext', () {
    test('records the exception type when there are no Flutter details', () {
      final context = buildFlutterErrorContext(ArgumentError('boom'), null);

      expect(context, isNotNull);
      expect(context!['exception_type'], 'ArgumentError');
      expect(context['is_web'], kIsWeb);
      // Nothing framework-specific is invented when details are absent.
      expect(context.containsKey('flutter_library'), isFalse);
      expect(context.containsKey('flutter_context'), isFalse);
    });

    test(
      'preserves the library and the building context that name the subtree',
      () {
        final details = FlutterErrorDetails(
          exception: TypeError(),
          library: 'widgets library',
          context: ErrorDescription('while building KubusNearbyArtPanel'),
        );

        final context = buildFlutterErrorContext(details.exception, details);

        expect(context, isNotNull);
        expect(context!['flutter_library'], 'widgets library');
        expect(
          context['flutter_context'],
          contains('while building KubusNearbyArtPanel'),
        );
      },
    );

    test('bounds every free-form string', () {
      final details = FlutterErrorDetails(
        exception: Exception('boom'),
        library: 'x' * 5000,
        context: ErrorDescription('y' * 5000),
      );

      final context = buildFlutterErrorContext(details.exception, details)!;

      expect(
        (context['flutter_library'] as String).length,
        kMaxDiagnosticFieldLength,
      );
      expect(
        (context['flutter_context'] as String).length,
        kMaxDiagnosticFieldLength,
      );
    });

    test('marks silent errors so triage can filter them', () {
      final details = FlutterErrorDetails(
        exception: Exception('boom'),
        library: 'widgets library',
        silent: true,
      );

      final context = buildFlutterErrorContext(details.exception, details)!;

      expect(context['flutter_silent'], isTrue);
    });

    test('omits the silent marker for ordinary errors', () {
      final details = FlutterErrorDetails(
        exception: Exception('boom'),
        library: 'widgets library',
      );

      final context = buildFlutterErrorContext(details.exception, details)!;

      expect(context.containsKey('flutter_silent'), isFalse);
    });

    // The collector runs *inside* the error handler. If it throws it destroys
    // the report it was meant to enrich, so failures of any single source must
    // degrade to a partial result rather than propagate.
    test('never throws when the diagnostics description throws', () {
      final details = FlutterErrorDetails(
        exception: Exception('boom'),
        library: 'widgets library',
        context: _ThrowingDiagnostics(),
      );

      Map<String, dynamic>? collected;
      expect(
        () => collected = buildFlutterErrorContext(details.exception, details),
        returnsNormally,
      );
      // The salvageable fields still survive.
      final context = collected!;
      expect(context['flutter_library'], 'widgets library');
      expect(context.containsKey('flutter_context'), isFalse);
    });

    test('never throws when the error itself is hostile', () {
      expect(
        () => buildFlutterErrorContext(_HostileError(), null),
        returnsNormally,
      );
    });

    test('carries no user-identifying keys', () {
      final details = FlutterErrorDetails(
        exception: TypeError(),
        library: 'widgets library',
        context: ErrorDescription('while building KubusNearbyArtPanel'),
      );

      final context = buildFlutterErrorContext(details.exception, details)!;

      const forbidden = <String>[
        'email',
        'name',
        'wallet',
        'address',
        'token',
        'latitude',
        'longitude',
        'location',
        'body',
      ];
      for (final key in context.keys) {
        for (final term in forbidden) {
          expect(
            key.toLowerCase(),
            isNot(contains(term)),
            reason: 'diagnostic key "$key" must not carry $term data',
          );
        }
      }
    });
  });
}
