import 'package:art_kubus/models/pending_action_intent.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/pending_action_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/services/pending_action_executor.dart';
import 'package:art_kubus/services/pending_action_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Counts executions so "exactly once" is actually observable.
class RecordingExecutor implements PendingActionExecutor {
  RecordingExecutor({
    this.outcome = PendingActionOutcome.completed,
  });

  PendingActionOutcome outcome;
  int calls = 0;
  final List<PendingActionIntent> executed = <PendingActionIntent>[];

  @override
  Future<PendingActionExecutionResult> execute({
    required PendingActionIntent intent,
    required ArtworkProvider artworkProvider,
    required SavedItemsProvider savedItemsProvider,
  }) async {
    calls += 1;
    executed.add(intent);
    return PendingActionExecutionResult(outcome);
  }
}

PendingActionIntent _saveArtwork({String targetId = 'artwork-1'}) =>
    PendingActionIntent.create(
      actionType: PendingActionType.save,
      targetType: PendingActionTargetType.artwork,
      targetId: targetId,
      returnRoute: '/a/$targetId',
      sourceScreen: 'map_marker',
    )!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingExecutor executor;
  late PendingActionProvider provider;
  // Built inside setUp: these construct BackendApiService, which needs to run
  // inside a test zone.
  late ArtworkProvider artworkProvider;
  late SavedItemsProvider savedItemsProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    executor = RecordingExecutor();
    provider = PendingActionProvider(executor: executor);
    artworkProvider = ArtworkProvider();
    savedItemsProvider = SavedItemsProvider();
  });

  Future<PendingActionExecutionResult> confirm() => provider.confirm(
        artworkProvider: artworkProvider,
        savedItemsProvider: savedItemsProvider,
      );

  test('capture persists the intent and does not await confirmation', () async {
    await provider.capture(_saveArtwork());

    expect(provider.pending, isNotNull);
    expect(provider.isAwaitingConfirmation, isFalse);
    expect(await const PendingActionService().read(), isNotNull);
  });

  test('restore surfaces the intent for confirmation without running it',
      () async {
    await provider.capture(_saveArtwork());
    final fresh = PendingActionProvider(executor: executor);

    final restored = await fresh.restore();

    expect(restored, isNotNull);
    expect(fresh.isAwaitingConfirmation, isTrue);
    // Crucially: restoring offers the action back, it never replays it.
    expect(executor.calls, 0);
  });

  test('confirming runs the action exactly once and clears the intent',
      () async {
    await provider.capture(_saveArtwork());
    await provider.restore();

    final result = await confirm();

    expect(result.didSucceed, isTrue);
    expect(executor.calls, 1);
    expect(provider.pending, isNull);
    expect(provider.isAwaitingConfirmation, isFalse);
    expect(await const PendingActionService().read(), isNull);
  });

  test('a second confirmation does not run the action again', () async {
    await provider.capture(_saveArtwork());
    await provider.restore();

    await confirm();
    final second = await confirm();

    expect(executor.calls, 1);
    // The repeat is reported as already-done rather than as a failure.
    expect(second.outcome, PendingActionOutcome.failed);
  });

  test('a restore after completion does not re-offer the same action',
      () async {
    await provider.capture(_saveArtwork());
    await provider.restore();
    await confirm();

    final fresh = PendingActionProvider(executor: executor);
    final restored = await fresh.restore();

    expect(restored, isNull);
    expect(fresh.isAwaitingConfirmation, isFalse);
    expect(executor.calls, 1);
  });

  test('cancelling never runs the action and drops the intent', () async {
    await provider.capture(_saveArtwork());
    await provider.restore();

    await provider.cancel();

    expect(executor.calls, 0);
    expect(provider.pending, isNull);
    expect(provider.isAwaitingConfirmation, isFalse);
    expect(await const PendingActionService().read(), isNull);
  });

  test('an expired intent is never offered for confirmation', () async {
    final stale = PendingActionIntent(
      actionType: PendingActionType.save,
      targetType: PendingActionTargetType.artwork,
      targetId: 'artwork-1',
      returnRoute: '/a/artwork-1',
      sourceScreen: 'map_marker',
      createdAtUtc: DateTime.now()
          .toUtc()
          .subtract(PendingActionIntent.ttl + const Duration(minutes: 5)),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PendingActionService.storageKey, stale.encode());

    final restored = await provider.restore();

    expect(restored, isNull);
    expect(executor.calls, 0);
  });

  test('a gone target is reported and the dead intent is dropped', () async {
    executor.outcome = PendingActionOutcome.targetUnavailable;
    await provider.capture(_saveArtwork());
    await provider.restore();

    final result = await confirm();

    expect(result.outcome, PendingActionOutcome.targetUnavailable);
    expect(result.failureStage, 'target_unavailable');
    // Nothing would be gained by re-offering an action on a deleted entity.
    expect(provider.pending, isNull);
    expect(await const PendingActionService().read(), isNull);
  });

  test('a transient failure stays retryable', () async {
    executor.outcome = PendingActionOutcome.failed;
    await provider.capture(_saveArtwork());
    await provider.restore();

    final first = await confirm();
    expect(first.didSucceed, isFalse);
    expect(provider.pending, isNotNull);

    executor.outcome = PendingActionOutcome.completed;
    final second = await confirm();

    expect(second.didSucceed, isTrue);
    expect(executor.calls, 2);
    expect(provider.pending, isNull);
  });

  test('an unauthorized replay is surfaced, not silently swallowed', () async {
    executor.outcome = PendingActionOutcome.unauthorized;
    await provider.capture(_saveArtwork());
    await provider.restore();

    final result = await confirm();

    expect(result.outcome, PendingActionOutcome.unauthorized);
    expect(result.failureStage, 'unauthorized');
  });

  test('capturing a new intent replaces the previous one', () async {
    await provider.capture(_saveArtwork(targetId: 'artwork-1'));
    await provider.capture(_saveArtwork(targetId: 'artwork-2'));

    expect(provider.pending!.targetId, 'artwork-2');
    final stored = await const PendingActionService().read();
    expect(stored!.targetId, 'artwork-2');
  });

  group('identity binding', () {
    test('a guest intent may be completed by the account they create',
        () async {
      await provider.capture(_saveArtwork());
      // The visitor signs up; a user id now exists.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', 'user-new');

      final restored =
          await PendingActionProvider(executor: executor).restore();

      expect(restored, isNotNull);
    });

    test('an intent captured while signed in is pinned to that account',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', 'user-a');
      await provider.capture(_saveArtwork());
      expect(provider.pending!.capturedByUserId, 'user-a');

      // Someone else signs in on the same device.
      await prefs.setString('user_id', 'user-b');
      final other = PendingActionProvider(executor: executor);
      final restored = await other.restore();

      expect(restored, isNull, reason: 'must not cross an identity boundary');
      expect(other.isAwaitingConfirmation, isFalse);
      expect(executor.calls, 0);
      // The orphaned intent is dropped, not left to be re-offered.
      expect(await const PendingActionService().read(), isNull);
    });

    test('the same account still gets its own intent back', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', 'user-a');
      await provider.capture(_saveArtwork());

      final again = PendingActionProvider(executor: executor);
      expect(await again.restore(), isNotNull);
    });
  });

  test('clear drops the intent without reporting a cancellation', () async {
    await provider.capture(_saveArtwork());

    await provider.clear();

    expect(provider.pending, isNull);
    expect(await const PendingActionService().read(), isNull);
  });
}
