import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:flutter/material.dart';

class ShareSheet extends StatelessWidget {
  const ShareSheet({
    super.key,
    required this.target,
    required this.onActionSelected,
  });

  final ShareTarget target;
  final Future<void> Function(ShareAction action) onActionSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    Widget tile({
      required IconData icon,
      required String title,
      required ShareAction action,
    }) {
      return ListTile(
        leading: Icon(icon, color: scheme.primary),
        title: Text(title),
        onTap: () => onActionSelected(action),
      );
    }

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: scheme.outline.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.commonShare,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              tile(
                icon: Icons.post_add,
                title: l10n.shareOptionCreatePost,
                action: ShareAction.createPost,
              ),
              if (AppConfig.isFeatureEnabled('messaging'))
                tile(
                  icon: Icons.send_outlined,
                  title: l10n.shareOptionSendMessage,
                  action: ShareAction.sendMessage,
                ),
              tile(
                icon: Icons.share_outlined,
                title: l10n.shareOptionShareExternal,
                action: ShareAction.shareExternal,
              ),
              tile(
                icon: Icons.link,
                title: l10n.postDetailCopyLink,
                action: ShareAction.copyLink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

