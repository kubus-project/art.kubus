import 'dart:async';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/config_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/share_create_post_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../widgets/share/share_message_sheet.dart';
import '../../widgets/share/share_sheet.dart';
import 'share_link_builder.dart';
import 'share_types.dart';

class ShareService {
  ShareService({
    BackendApiService? api,
    ShareLinkBuilder? linkBuilder,
  })  : _api = api ?? BackendApiService(),
        _linkBuilder = linkBuilder ?? ShareLinkBuilder(baseUri: Uri.parse(AppConfig.appBaseUrl));

  final BackendApiService _api;
  final ShareLinkBuilder _linkBuilder;

  bool _analyticsEnabled(BuildContext context) {
    if (!AppConfig.isFeatureEnabled('analytics')) return false;
    try {
      return context.read<ConfigProvider>().enableAnalytics;
    } catch (_) {
      return true;
    }
  }

  bool _looksLikeUuid(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$')
        .hasMatch(v);
  }

  Future<void> _trackShareEventIfEnabled(
    bool analyticsEnabled, {
    required String eventType,
    required ShareTarget target,
    required String channel,
    required String sourceScreen,
  }) async {
    if (!analyticsEnabled) return;
    try {
      final rawId = target.shareId;
      await _api.trackAnalyticsEvent(
        eventType: eventType,
        targetType: target.type.analyticsTargetType,
        targetId: _looksLikeUuid(rawId) ? rawId : null,
        eventCategory: 'share',
        metadata: <String, dynamic>{
          'entityType': target.type.analyticsTargetType,
          'entityId': rawId,
          'channel': channel,
          'sourceScreen': sourceScreen,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (_) {
      // Best-effort only.
    }
  }

  Uri buildShareUrl(ShareTarget target) => _linkBuilder.build(target);

  Future<void> showShareSheet(
    BuildContext context, {
    required ShareTarget target,
    required String sourceScreen,
    Future<void> Function()? onCreatePostRequested,
  }) async {
    if (!AppConfig.isFeatureEnabled('sharing')) return;
    final analyticsEnabled = _analyticsEnabled(context);
    unawaited(_trackShareEventIfEnabled(
      analyticsEnabled,
      eventType: 'share_modal_opened',
      target: target,
      channel: 'modal',
      sourceScreen: sourceScreen,
    ));

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => ShareSheet(
        target: target,
        onActionSelected: (action) async {
          final sheetNavigator = Navigator.of(sheetContext);
          final l10n = AppLocalizations.of(context)!;
          final messenger = ScaffoldMessenger.of(context);

          final shareUrl = buildShareUrl(target).toString();

          Future<void> bumpPostShareCountIfNeeded() async {
            if (target.type != ShareEntityType.post) return;
            try {
              await _api.sharePost(target.shareId);
            } catch (_) {}
          }

          switch (action) {
            case ShareAction.copyLink:
              await Clipboard.setData(ClipboardData(text: shareUrl));
              if (!context.mounted) return;
              sheetNavigator.pop();
              messenger.showSnackBar(SnackBar(content: Text(l10n.shareLinkCopiedToast)));
              unawaited(bumpPostShareCountIfNeeded());
              unawaited(_trackShareEventIfEnabled(
                analyticsEnabled,
                eventType: 'share_copy_link',
                target: target,
                channel: 'copy_link',
                sourceScreen: sourceScreen,
              ));
              return;
            case ShareAction.shareExternal:
              sheetNavigator.pop();
              await SharePlus.instance.share(ShareParams(text: shareUrl));
              if (!context.mounted) return;
              unawaited(bumpPostShareCountIfNeeded());
              unawaited(_trackShareEventIfEnabled(
                analyticsEnabled,
                eventType: 'share_external',
                target: target,
                channel: 'platform_share',
                sourceScreen: sourceScreen,
              ));
              return;
            case ShareAction.sendMessage:
              sheetNavigator.pop();
              if (!context.mounted) return;
              final outerMessenger = messenger;
              final outerNavigator = Navigator.of(context);
              final outerL10n = l10n;
              await showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => ShareMessageSheet(
                  target: target,
                  initialMessage: outerL10n.shareDmDefaultMessage,
                  onSend: ({required recipientWallet, required message}) async {
                    try {
                      await _api.shareEntityViaDM(
                        recipientWallet: recipientWallet,
                        message: message,
                        target: target,
                        url: shareUrl,
                      );
                      unawaited(bumpPostShareCountIfNeeded());
                      unawaited(_trackShareEventIfEnabled(
                        analyticsEnabled,
                        eventType: 'share_message',
                        target: target,
                        channel: 'dm',
                        sourceScreen: sourceScreen,
                      ));
                      if (!outerNavigator.mounted) return;
                      outerMessenger.showSnackBar(
                        SnackBar(content: Text(outerL10n.shareMessageSentToast(recipientWallet))),
                      );
                    } catch (_) {
                      if (!outerNavigator.mounted) return;
                      outerMessenger.showSnackBar(
                        SnackBar(content: Text(outerL10n.shareMessageFailedToast)),
                      );
                      rethrow;
                    }
                  },
                ),
              );
              return;
            case ShareAction.createPost:
              sheetNavigator.pop();
              unawaited(_trackShareEventIfEnabled(
                analyticsEnabled,
                eventType: 'share_create_post',
                target: target,
                channel: 'create_post',
                sourceScreen: sourceScreen,
              ));
              if (onCreatePostRequested != null) {
                await onCreatePostRequested();
                return;
              }
              await ShareCreatePostLauncher.openComposerForShare(context, target);
              return;
          }
        },
      ),
    );
  }
}
