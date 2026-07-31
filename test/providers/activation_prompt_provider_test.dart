import 'package:art_kubus/providers/activation_prompt_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  ActivationPromptProvider guestProvider() =>
      ActivationPromptProvider(hasAuthSession: () => false);

  test('stays quiet on landing and until enough interest is shown', () async {
    final provider = guestProvider();
    expect(provider.shouldPrompt, isFalse);

    for (var i = 1; i < ActivationPromptProvider.viewsBeforePrompt; i++) {
      await provider.recordEntityView();
      expect(
        provider.shouldPrompt,
        isFalse,
        reason: 'must not prompt after only $i view(s)',
      );
    }

    await provider.recordEntityView();
    expect(provider.shouldPrompt, isTrue);
  });

  test('never prompts an authenticated visitor', () async {
    final provider = ActivationPromptProvider(hasAuthSession: () => true);

    for (var i = 0; i < 10; i++) {
      await provider.recordEntityView();
    }

    expect(provider.shouldPrompt, isFalse);
    expect(provider.entityViews, 0);
  });

  test('dismissal sticks for the rest of the session', () async {
    final provider = guestProvider();
    for (var i = 0; i < ActivationPromptProvider.viewsBeforePrompt; i++) {
      await provider.recordEntityView();
    }
    expect(provider.shouldPrompt, isTrue);

    await provider.dismiss();
    expect(provider.shouldPrompt, isFalse);

    for (var i = 0; i < 10; i++) {
      await provider.recordEntityView();
    }
    expect(provider.shouldPrompt, isFalse);
  });

  test('accepting also closes the prompt for the session', () async {
    final provider = guestProvider();
    for (var i = 0; i < ActivationPromptProvider.viewsBeforePrompt; i++) {
      await provider.recordEntityView();
    }

    await provider.accept();

    expect(provider.shouldPrompt, isFalse);
  });

  test('is capped to once per interval across sessions', () async {
    final first = guestProvider();
    for (var i = 0; i < ActivationPromptProvider.viewsBeforePrompt; i++) {
      await first.recordEntityView();
    }
    await first.dismiss();

    // New session, same device, inside the interval.
    final second = guestProvider();
    for (var i = 0; i < ActivationPromptProvider.viewsBeforePrompt; i++) {
      await second.recordEntityView();
    }

    expect(second.shouldPrompt, isFalse);
  });

  test('prompts again once the interval has elapsed', () async {
    final elapsed = DateTime.now()
        .toUtc()
        .subtract(ActivationPromptProvider.promptInterval)
        .subtract(const Duration(minutes: 1))
        .millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues(<String, Object>{
      ActivationPromptProvider.lastShownPrefsKey: elapsed,
    });

    final provider = guestProvider();
    for (var i = 0; i < ActivationPromptProvider.viewsBeforePrompt; i++) {
      await provider.recordEntityView();
    }

    expect(provider.shouldPrompt, isTrue);
  });

  test('reset clears the session counters', () async {
    final provider = guestProvider();
    for (var i = 0; i < ActivationPromptProvider.viewsBeforePrompt; i++) {
      await provider.recordEntityView();
    }
    expect(provider.shouldPrompt, isTrue);

    provider.reset();

    expect(provider.shouldPrompt, isFalse);
    expect(provider.entityViews, 0);
  });

  test('notifies listeners exactly once when it arms', () async {
    final provider = guestProvider();
    var notifications = 0;
    provider.addListener(() => notifications += 1);

    for (var i = 0; i < ActivationPromptProvider.viewsBeforePrompt + 3; i++) {
      await provider.recordEntityView();
    }

    expect(notifications, 1);
  });
}
