import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/public_entity_takeover_provider.dart';
import '../services/share/share_types.dart';

/// Marks a loaded public entity as takeover-ready after [child] has painted.
///
/// Detail screens must only include this wrapper around a meaningful view for
/// the exact requested record. Loading, placeholder, not-found, and error
/// branches must remain unwrapped so the server-rendered fallback stays active.
class PublicEntityTakeoverReady extends StatefulWidget {
  const PublicEntityTakeoverReady({
    super.key,
    required this.type,
    required this.entityId,
    required this.child,
  });

  final ShareEntityType type;
  final String entityId;
  final Widget child;

  @override
  State<PublicEntityTakeoverReady> createState() =>
      _PublicEntityTakeoverReadyState();
}

class _PublicEntityTakeoverReadyState extends State<PublicEntityTakeoverReady> {
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleReadySignal();
  }

  @override
  void didUpdateWidget(covariant PublicEntityTakeoverReady oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type ||
        oldWidget.entityId != widget.entityId) {
      _scheduled = false;
      _scheduleReadySignal();
    }
  }

  void _scheduleReadySignal() {
    if (_scheduled) return;
    _scheduled = true;
    // This widget is mounted while the exact entity frame is being built.
    // Dispatch at the end of that same frame so a responsive shell rebuild on
    // the following frame cannot dispose the meaningful view first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        unawaited(
          context.read<PublicEntityTakeoverProvider>().markEntityReady(
                widget.type,
                widget.entityId,
              ),
        );
      } catch (_) {
        // Ordinary in-app detail routes may be rendered in isolated tests or
        // embeds without the takeover provider.
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
