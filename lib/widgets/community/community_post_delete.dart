import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../community/community_interactions.dart';
import '../../providers/community_art_discovery_provider.dart';
import '../../providers/community_interactions_provider.dart';
import '../../services/backend_api_service.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../glass_components.dart';
import '../kubus_button.dart';
import '../kubus_snackbar.dart';

/// Why a post deletion did not complete. Drives the localized, actionable
/// message shown inside the confirmation dialog.
enum CommunityPostDeleteFailure {
  sessionExpired,
  notAllowed,
  conflict,
  network,
  server,
}

/// Maps a thrown error to a [CommunityPostDeleteFailure].
///
/// A 404 is not a failure: the post is already gone, which is exactly what the
/// owner asked for. Callers treat it as a completed deletion.
@visibleForTesting
CommunityPostDeleteFailure? classifyCommunityPostDeleteError(Object error) {
  if (error is BackendApiRequestException) {
    final status = error.statusCode;
    if (status == 404) return null;
    if (status == 401) return CommunityPostDeleteFailure.sessionExpired;
    if (status == 403) return CommunityPostDeleteFailure.notAllowed;
    if (status == 409) return CommunityPostDeleteFailure.conflict;
    return CommunityPostDeleteFailure.server;
  }
  if (error is TimeoutException) return CommunityPostDeleteFailure.network;
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('XMLHttpRequest')) {
    return CommunityPostDeleteFailure.network;
  }
  return CommunityPostDeleteFailure.server;
}

String _failureMessage(
  AppLocalizations l10n,
  CommunityPostDeleteFailure failure,
) {
  switch (failure) {
    case CommunityPostDeleteFailure.sessionExpired:
      return l10n.communityPostDeleteSessionExpired;
    case CommunityPostDeleteFailure.notAllowed:
      return l10n.communityPostDeleteNotAllowed;
    case CommunityPostDeleteFailure.conflict:
      return l10n.communityPostDeleteConflict;
    case CommunityPostDeleteFailure.network:
      return l10n.communityPostDeleteNetwork;
    case CommunityPostDeleteFailure.server:
      return l10n.postDetailDeletePostFailedToast;
  }
}

/// Post ids whose deletion request is currently in flight, across every
/// Community surface (feed, desktop feed, group feed, post detail).
final Set<String> _deleteInFlight = <String>{};

/// Shows the shared delete-post confirmation and performs the deletion.
///
/// One contract for every Community surface:
/// * the server decides: [CommunityInteractionsProvider.deleteCommunityPost]
///   is the only deletion call, and a 404 counts as already deleted;
/// * a pending state disables both actions and blocks dismissal, and a second
///   request for the same post is ignored while one is in flight;
/// * on success the dialog closes first, then [onDeleted] runs for the caller's
///   local UI. [onDeleted] is isolated: an exception while updating local
///   lists can never turn a deletion the server completed into a failure;
/// * on failure the dialog stays open with an actionable message and working
///   Cancel/Delete controls, so the user is never trapped.
///
/// Returns true when the post is gone.
Future<bool> confirmAndDeleteCommunityPost({
  required BuildContext context,
  required CommunityPost post,
  required VoidCallback onDeleted,
}) async {
  if (_deleteInFlight.contains(post.id)) return false;
  final l10n = AppLocalizations.of(context)!;
  final interactions = context.read<CommunityInteractionsProvider>();
  CommunityArtDiscoveryProvider? discovery;
  try {
    discovery = context.read<CommunityArtDiscoveryProvider>();
  } catch (_) {
    discovery = null;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);

  final deleted = await showKubusDialog<bool>(
    context: context,
    builder: (dialogContext) => _DeletePostDialog(
      postId: post.id,
      perform: () => interactions.deleteCommunityPost(post),
    ),
  );
  if (deleted != true) return false;

  // A deleted post must leave the Art discovery feed too, and stay out of it.
  discovery?.removePost(post.id);
  try {
    onDeleted();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('confirmAndDeleteCommunityPost: local cleanup failed: $e');
    }
  }
  messenger?.showKubusSnackBar(
    SnackBar(content: Text(l10n.postDetailPostDeletedToast)),
  );
  return true;
}

class _DeletePostDialog extends StatefulWidget {
  const _DeletePostDialog({required this.postId, required this.perform});

  final String postId;
  final Future<void> Function() perform;

  @override
  State<_DeletePostDialog> createState() => _DeletePostDialogState();
}

class _DeletePostDialogState extends State<_DeletePostDialog> {
  bool _pending = false;
  CommunityPostDeleteFailure? _failure;

  Future<void> _delete() async {
    if (_pending || _deleteInFlight.contains(widget.postId)) return;
    setState(() {
      _pending = true;
      _failure = null;
    });
    _deleteInFlight.add(widget.postId);
    try {
      await widget.perform();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (kDebugMode) debugPrint('delete post failed: $e');
      final failure = classifyCommunityPostDeleteError(e);
      if (failure == null) {
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      if (!mounted) return;
      setState(() {
        _pending = false;
        _failure = failure;
      });
    } finally {
      _deleteInFlight.remove(widget.postId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final failure = _failure;

    return PopScope(
      canPop: !_pending,
      child: KubusAlertDialog(
        size: KubusDialogSize.compact,
        title: Text(l10n.postDetailDeletePostTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.postDetailDeletePostBody),
            if (failure != null) ...[
              const SizedBox(height: KubusSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  _failureMessage(l10n, failure),
                  style: TextStyle(color: roles.destructive),
                ),
              ),
            ],
          ],
        ),
        actions: [
          KubusButton(
            onPressed: _pending ? null : () => Navigator.of(context).pop(false),
            label: l10n.commonCancel,
            variant: KubusButtonVariant.quiet,
          ),
          const SizedBox(width: KubusSpacing.sm),
          KubusButton(
            onPressed: _pending ? null : _delete,
            label: l10n.commonDelete,
            variant: KubusButtonVariant.destructive,
            isLoading: _pending,
          ),
        ],
      ),
    );
  }
}
