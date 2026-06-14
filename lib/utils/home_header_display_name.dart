import '../models/user_profile.dart';
import 'creator_display_format.dart';
import 'wallet_utils.dart';

String resolveHomeHeaderDisplayName({
  required UserProfile? user,
  required String fallbackLabel,
}) {
  final formatted = CreatorDisplayFormat.format(
    fallbackLabel: fallbackLabel,
    displayName: user?.displayName,
    username: user?.username,
  );
  final primary = formatted.primary.trim();
  return WalletUtils.looksLikeWallet(primary) ? fallbackLabel : primary;
}
