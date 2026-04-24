import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:art_kubus/l10n/app_localizations.dart';

import '../../providers/collections_provider.dart';
import '../../utils/design_tokens.dart';
import '../../widgets/inline_loading.dart';
import 'collection_detail_screen.dart';

class CollectionSettingsScreen extends StatelessWidget {
  final int collectionIndex;
  final String collectionName;

  const CollectionSettingsScreen({
    super.key,
    required this.collectionIndex,
    required this.collectionName,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Consumer<CollectionsProvider>(
      builder: (context, provider, _) {
        if (provider.listLoading && provider.collections.isEmpty) {
          return Scaffold(
            backgroundColor: scheme.surface,
            body: const Center(child: InlineLoading()),
          );
        }

        final collection = (collectionIndex >= 0 &&
                collectionIndex < provider.collections.length)
            ? provider.collections[collectionIndex]
            : null;

        if (collection == null) {
          return Scaffold(
            backgroundColor: scheme.surface,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(KubusSpacing.lg),
                child: Text(
                  collectionName.isNotEmpty
                      ? collectionName
                      : l10n.collectionDetailLoadFailedMessage,
                  textAlign: TextAlign.center,
                  style: KubusTypography.inter(
                    color: scheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          );
        }

        return CollectionDetailScreen(collectionId: collection.id);
      },
    );
  }
}
