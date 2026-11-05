import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../services/account_identity.dart';
import '../../services/backend_api_service.dart';
import '../../utils/design_tokens.dart';
import '../inline_loading.dart';

/// Both phone and desktop conversations use this authenticated delivery path.
/// Bytes are not put in a URL, a public proxy, or a persistent application cache.
class PrivateMessageAttachment extends StatefulWidget {
  const PrivateMessageAttachment(
      {super.key,
      required this.url,
      required this.filename,
      required this.mimeType});
  final String url;
  final String filename;
  final String mimeType;

  @override
  State<PrivateMessageAttachment> createState() =>
      _PrivateMessageAttachmentState();
}

class _PrivateMessageAttachmentState extends State<PrivateMessageAttachment> {
  late Future<Uint8List> _content;
  MemoryImage? _image;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _content = BackendApiService().fetchPrivateMessageAttachment(widget.url);
    AccountIdentity.addListener(_endSession);
  }

  void _endSession() {
    _image?.evict();
    _image = null;
    _content = Future<Uint8List>.value(Uint8List(0));
    if (mounted) setState(() => _ended = true);
  }

  @override
  void dispose() {
    AccountIdentity.removeListener(_endSession);
    _image?.evict();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_ended) return Text(l10n.messagesAttachmentUnavailable);
    return FutureBuilder<Uint8List>(
      future: _content,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(l10n.messagesAttachmentUnavailable);
        }
        if (!snapshot.hasData) {
          return const SizedBox(
              height: 80, child: Center(child: InlineLoading(tileSize: 4)));
        }
        final bytes = snapshot.data!;
        if (widget.mimeType.startsWith('image/')) _image ??= MemoryImage(bytes);
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300, maxHeight: 440),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_image != null)
              Flexible(
                  child: Image(
                      image: _image!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image))),
            Text(widget.filename, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: KubusSpacing.xs),
            TextButton.icon(
              icon: const Icon(Icons.download),
              label: Text(l10n.messagesAttachmentDownloadButton),
              onPressed: () async {
                // Reauthorize at the action, rather than sharing old preview
                // bytes after removal from a conversation or message deletion.
                final epoch = BackendApiService().authSessionEpoch;
                try {
                  final fresh = await BackendApiService()
                      .fetchPrivateMessageAttachment(widget.url);
                  if (!context.mounted ||
                      _ended ||
                      epoch != BackendApiService().authSessionEpoch) {
                    return;
                  }
                  final box = context.findRenderObject() as RenderBox?;
                  await SharePlus.instance.share(ShareParams(
                    files: [
                      XFile.fromData(fresh,
                          mimeType: widget.mimeType, name: widget.filename)
                    ],
                    fileNameOverrides: [widget.filename],
                    sharePositionOrigin: box == null
                        ? null
                        : box.localToGlobal(Offset.zero) & box.size,
                  ));
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(l10n.messagesAttachmentUnavailable)));
                  }
                }
              },
            ),
          ]),
        );
      },
    );
  }
}
