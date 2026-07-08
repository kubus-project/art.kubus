import '../providers/chat_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/wallet_provider.dart';

class WalletSessionSyncProvidersPayload {
  const WalletSessionSyncProvidersPayload({
    required this.walletProvider,
    required this.profileProvider,
    required this.chatProvider,
  });

  final WalletProvider walletProvider;
  final ProfileProvider profileProvider;
  final ChatProvider chatProvider;
}
