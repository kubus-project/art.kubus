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
