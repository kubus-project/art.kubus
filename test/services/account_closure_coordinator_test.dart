import 'dart:async';

import 'package:art_kubus/models/account_closure.dart';
import 'package:art_kubus/services/account_closure_coordinator.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake account. It never touches the network, the credential store, or a
/// real account. [run] scripts one closure attempt.
class _FakeAccount implements AccountClosureApi {
  _FakeAccount({required this.run, this.hasWallet = false});

  final bool hasWallet;
  final Future<int> Function(
      _FakeAccount self, AccountClosureStageListener? onStage) run;

  int epoch = 7;
  int calls = 0;

  /// True once the scripted "server" has committed the deletion.
  bool serverDeleted = false;

  @override
  int get authSessionEpoch => epoch;

  @override
  Future<int> deleteMyAccount({AccountClosureStageListener? onStage}) {
    calls += 1;
    return run(this, onStage);
  }
}

/// Prepare, DELETE, and local sign-out all succeed.
Future<int> _closes(
    _FakeAccount account, AccountClosureStageListener? onStage) async {
  onStage?.call(AccountClosureStage.preparing, account.epoch);
  onStage?.call(AccountClosureStage.deleting, account.epoch);
  account.serverDeleted = true;
  final cleared = ++account.epoch;
  onStage?.call(AccountClosureStage.committed, cleared);
  return cleared;
}

/// Prepare fails before the receipt is stored. DELETE is never sent.
Future<int> _prepareRejected(
    _FakeAccount account, AccountClosureStageListener? onStage) async {
  onStage?.call(AccountClosureStage.preparing, account.epoch);
  throw BackendApiRequestException(
    statusCode: 503,
    path: '/api/auth/account-closure/prepare',
  );
}

void main() {
  group('AccountClosureCoordinator', () {
    test('walletless account closes and is accepted', () async {
      final account = _FakeAccount(run: _closes);
      final outcome = await AccountClosureCoordinator(api: account).run();

      expect(outcome, isA<AccountClosureAccepted>());
      expect(account.serverDeleted, isTrue);
      expect(account.calls, 1);
    });

    test('wallet-linked account takes the same path and is accepted', () async {
      final account = _FakeAccount(run: _closes, hasWallet: true);
      final outcome = await AccountClosureCoordinator(api: account).run();

      expect(outcome, isA<AccountClosureAccepted>());
      expect(account.serverDeleted, isTrue);
      expect(account.calls, 1);
    });

    test('a second submit while in flight is ignored', () async {
      final gate = Completer<void>();
      final account = _FakeAccount(run: (self, onStage) async {
        onStage?.call(AccountClosureStage.preparing, self.epoch);
        await gate.future;
        return _closes(self, onStage);
      });
      final coordinator = AccountClosureCoordinator(api: account);

      final first = coordinator.run();
      await Future<void>.delayed(Duration.zero);
      final second = await coordinator.run();

      expect(second, isA<AccountClosureAlreadyInProgress>());
      expect(account.calls, 1, reason: 'the duplicate must send nothing');

      gate.complete();
      expect(await first, isA<AccountClosureAccepted>());
      expect(account.calls, 1);
    });

    test('the single-flight guard releases after the attempt completes',
        () async {
      var attempt = 0;
      final account = _FakeAccount(run: (self, onStage) async {
        attempt += 1;
        if (attempt == 1) return _prepareRejected(self, onStage);
        return _closes(self, onStage);
      });
      final coordinator = AccountClosureCoordinator(api: account);

      expect(await coordinator.run(), isA<AccountClosureFailed>());
      expect(await coordinator.run(), isA<AccountClosureAccepted>());
      expect(account.calls, 2);
    });

    test('lost DELETE response after commit is pending, not a failure',
        () async {
      final account = _FakeAccount(run: (self, onStage) async {
        onStage?.call(AccountClosureStage.preparing, self.epoch);
        onStage?.call(AccountClosureStage.deleting, self.epoch);
        self.serverDeleted = true; // the server committed
        throw TimeoutException('response lost after commit');
      });

      final outcome = await AccountClosureCoordinator(api: account).run();

      expect(outcome, isA<AccountClosurePending>());
      expect(account.serverDeleted, isTrue);
      expect(account.epoch, 7,
          reason: 'no local sign-out happened, so the session is untouched');
    });

    test('local cleanup failure after confirmed deletion is pending', () async {
      final account = _FakeAccount(run: (self, onStage) async {
        onStage?.call(AccountClosureStage.preparing, self.epoch);
        onStage?.call(AccountClosureStage.deleting, self.epoch);
        self.serverDeleted = true;
        final cleared = ++self.epoch;
        onStage?.call(AccountClosureStage.committed, cleared);
        throw StateError('secure storage cleanup incomplete');
      });

      final outcome = await AccountClosureCoordinator(api: account).run();

      expect(outcome, isA<AccountClosurePending>());
      expect(account.serverDeleted, isTrue);
    });

    test('prepare failure is a retryable failure and nothing is deleted',
        () async {
      final account = _FakeAccount(run: _prepareRejected);

      final outcome = await AccountClosureCoordinator(api: account).run();

      expect(outcome, isA<AccountClosureFailed>());
      final failed = outcome as AccountClosureFailed;
      expect(failed.reason, AccountClosureFailure.prepareRejected);
      expect(failed.retryable, isTrue);
      expect(account.serverDeleted, isFalse);
      expect(account.epoch, 7);
    });

    test('receipt that cannot be stored fails before DELETE, retryable',
        () async {
      final account = _FakeAccount(run: (self, onStage) async {
        onStage?.call(AccountClosureStage.preparing, self.epoch);
        // Storage refused the receipt. The service throws before DELETE.
        throw StateError('synthetic storage unavailable');
      });

      final outcome = await AccountClosureCoordinator(api: account).run();

      final failed = outcome as AccountClosureFailed;
      expect(failed.reason, AccountClosureFailure.prepareRejected);
      expect(failed.retryable, isTrue);
      expect(account.serverDeleted, isFalse);
    });

    test('account switch while prepare runs is ignored', () async {
      final account = _FakeAccount(run: (self, onStage) async {
        onStage?.call(AccountClosureStage.preparing, self.epoch);
        self.epoch += 1; // a different account signs in
        throw StateError('Account closure session changed');
      });

      final outcome = await AccountClosureCoordinator(api: account).run();

      final failed = outcome as AccountClosureFailed;
      expect(failed.reason, AccountClosureFailure.sessionChanged);
      expect(failed.retryable, isFalse);
      expect(account.serverDeleted, isFalse);
    });

    test('account switch during DELETE is ignored, not reported as pending',
        () async {
      final account = _FakeAccount(run: (self, onStage) async {
        onStage?.call(AccountClosureStage.preparing, self.epoch);
        onStage?.call(AccountClosureStage.deleting, self.epoch);
        self.epoch += 1; // newer account signs in while DELETE is in flight
        throw StateError('Account closure session changed');
      });

      final outcome = await AccountClosureCoordinator(api: account).run();

      final failed = outcome as AccountClosureFailed;
      expect(failed.reason, AccountClosureFailure.sessionChanged);
      expect(failed.retryable, isFalse);
    });

    test(
        'account switch during local cleanup after confirmed deletion is '
        'ignored and does not apply the result to the newer account', () async {
      final account = _FakeAccount(run: (self, onStage) async {
        onStage?.call(AccountClosureStage.preparing, self.epoch);
        onStage?.call(AccountClosureStage.deleting, self.epoch);
        self.serverDeleted = true;
        final cleared = ++self.epoch;
        onStage?.call(AccountClosureStage.committed, cleared);
        self.epoch += 1; // newer account signs in during cleanup
        return cleared;
      });

      final outcome = await AccountClosureCoordinator(api: account).run();

      final failed = outcome as AccountClosureFailed;
      expect(failed.reason, AccountClosureFailure.sessionChanged);
      expect(failed.retryable, isFalse);
      expect(account.serverDeleted, isTrue,
          reason: 'the old account was deleted; only the result is ignored');
    });
  });

  group('AccountClosureCoordinator classification', () {
    test('a lost DELETE response after the receipt is pending, not failed',
        () async {
      final account = _FakeAccount(run: (self, onStage) async {
        onStage?.call(AccountClosureStage.preparing, self.epoch);
        onStage?.call(AccountClosureStage.deleting, self.epoch);
        throw TimeoutException('synthetic lost response');
      });

      final outcome = await AccountClosureCoordinator(api: account).run();

      expect(outcome, isA<AccountClosurePending>());
      expect(account.calls, 1,
          reason: 'the coordinator never re-issues DELETE');
      expect(account.serverDeleted, isFalse);
    });

    test('an ambiguous HTTP answer after the receipt is pending, not refused',
        () async {
      final account = _FakeAccount(run: (self, onStage) async {
        onStage?.call(AccountClosureStage.preparing, self.epoch);
        onStage?.call(AccountClosureStage.deleting, self.epoch);
        throw BackendApiRequestException(
          statusCode: 401,
          path: '/api/auth/me',
        );
      });

      final outcome = await AccountClosureCoordinator(api: account).run();

      expect(outcome, isA<AccountClosurePending>());
      expect(account.calls, 1);
    });

    test(
        'a definitive refusal is failed as refused, retryable, and the '
        'session is not treated as closed', () async {
      final account = _FakeAccount(run: (self, onStage) async {
        onStage?.call(AccountClosureStage.preparing, self.epoch);
        onStage?.call(AccountClosureStage.deleting, self.epoch);
        onStage?.call(AccountClosureStage.refused, self.epoch);
        throw BackendApiRequestException(
          statusCode: 403,
          path: '/api/auth/me',
        );
      });

      final outcome = await AccountClosureCoordinator(api: account).run();

      final failed = outcome as AccountClosureFailed;
      expect(failed.reason, AccountClosureFailure.refused);
      expect(failed.retryable, isTrue);
      expect(account.serverDeleted, isFalse);
    });

    test('a refusal after an account switch is not applied', () async {
      final account = _FakeAccount(run: (self, onStage) async {
        onStage?.call(AccountClosureStage.preparing, self.epoch);
        onStage?.call(AccountClosureStage.deleting, self.epoch);
        onStage?.call(AccountClosureStage.refused, self.epoch);
        self.epoch += 1; // a different account signs in
        throw BackendApiRequestException(
          statusCode: 403,
          path: '/api/auth/me',
        );
      });

      final outcome = await AccountClosureCoordinator(api: account).run();

      final failed = outcome as AccountClosureFailed;
      expect(failed.reason, AccountClosureFailure.sessionChanged);
      expect(failed.retryable, isFalse);
    });
  });
}
