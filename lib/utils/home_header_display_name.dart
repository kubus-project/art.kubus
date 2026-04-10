import '../models/user_profile.dart';
import 'creator_display_format.dart';

String resolveHomeHeaderDisplayName({
  required UserProfile? user,
  required String fallbackLabel,
}) {
  final formatted = CreatorDisplayFormat.format(
    fallbackLabel: fallbackLabel,
    displayName: user?.displayName,
    username: user?.username,
    wallet: user?.walletAddress,
  );
  return formatted.primary;
}
