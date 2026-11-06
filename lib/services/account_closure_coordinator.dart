import '../models/account_closure.dart';

/// Reports each closure stage with the session epoch in effect at that point.
typedef AccountClosureStageListener = void Function(
  AccountClosureStage stage,
  int sessionEpoch,
);

/// The account-closure surface the coordinator depends on.
///
/// [BackendApiService] implements it. Tests supply a fake so that no real
/// account is ever touched.
abstract class AccountClosureApi {
  /// Incremented by every sign-in, sign-out, or account switch.
  int get authSessionEpoch;

  /// Closes the authenticated account. Returns the session epoch left behind
  /// by the local sign-out that follows a confirmed deletion.
  Future<int> deleteMyAccount({AccountClosureStageListener? onStage});
}

/// Result of one closure attempt. Both settings screens render these
/// identically; see `confirmAndCloseAccount` in `widgets/account_closure_flow`.
sealed class AccountClosureOutcome {
  const AccountClosureOutcome();
}

/// The server confirmed the closure and this session's local state was cleared.
final class AccountClosureAccepted extends AccountClosureOutcome {
  const AccountClosureAccepted();
}

/// The closure may have committed but its confirmation was lost. The status
/// receipt is durable, so the closure status screen resolves the real state.
final class AccountClosurePending extends AccountClosureOutcome {
  const AccountClosurePending();
}

/// Why an attempt failed without a closure result to show.
enum AccountClosureFailure {
  /// The receipt was never stored and DELETE was never sent. Nothing deleted.
  prepareRejected,

  /// The signed-in account changed while the attempt ran. The result belongs
  /// to a session that no longer exists, so it must not be applied.
  sessionChanged,
}

/// The attempt did not close anything from this session.
final class AccountClosureFailed extends AccountClosureOutcome {
  const AccountClosureFailed(this.reason, {required this.retryable});

  final AccountClosureFailure reason;

  /// Whether the same user can try again from the same screen.
  final bool retryable;
}

/// A closure is already running. The new request was ignored.
final class AccountClosureAlreadyInProgress extends AccountClosureOutcome {
  const AccountClosureAlreadyInProgress();
}

/// Runs account closure once per in-flight request and classifies the result.
///
/// Classification uses the stage the service reached and the session epoch
/// that stage recorded:
///
/// * epoch changed since the last stage -> [AccountClosureFailed]
///   (`sessionChanged`, not retryable, not applied)
/// * failed while still preparing -> [AccountClosureFailed]
///   (`prepareRejected`, retryable; nothing was deleted)
/// * failed once DELETE was about to be sent -> [AccountClosurePending]
///   (the server may have committed; status recovery decides)
/// * succeeded with the epoch unchanged -> [AccountClosureAccepted]
///
/// Wallet presence is never consulted, so walletless and wallet-linked
/// accounts take the same path.
class AccountClosureCoordinator {
  AccountClosureCoordinator({required AccountClosureApi api}) : _api = api;

  final AccountClosureApi _api;
  bool _inFlight = false;

  /// Runs one closure attempt against the current session.
  ///
  /// A call made while another attempt is in flight returns
  /// [AccountClosureAlreadyInProgress] without sending anything.
  Future<AccountClosureOutcome> run() async {
    if (_inFlight) return const AccountClosureAlreadyInProgress();
    _inFlight = true;
    try {
      return await _attempt();
    } finally {
      _inFlight = false;
    }
  }

  Future<AccountClosureOutcome> _attempt() async {
    var baselineEpoch = _api.authSessionEpoch;
    var stage = AccountClosureStage.preparing;
    try {
      final clearedEpoch = await _api.deleteMyAccount(
        onStage: (reached, epoch) {
          stage = reached;
          baselineEpoch = epoch;
        },
      );
      if (_api.authSessionEpoch != clearedEpoch) {
        return const AccountClosureFailed(
          AccountClosureFailure.sessionChanged,
          retryable: false,
        );
      }
      return const AccountClosureAccepted();
    } catch (_) {
      if (_api.authSessionEpoch != baselineEpoch) {
        return const AccountClosureFailed(
          AccountClosureFailure.sessionChanged,
          retryable: false,
        );
      }
      if (stage == AccountClosureStage.preparing) {
        return const AccountClosureFailed(
          AccountClosureFailure.prepareRejected,
          retryable: true,
        );
      }
      return const AccountClosurePending();
    }
  }
}
