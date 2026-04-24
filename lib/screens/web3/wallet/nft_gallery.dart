import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/design_tokens.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/collectible.dart';
import '../../../providers/collectibles_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/media_url_resolver.dart';
import '../../../utils/rarity_ui.dart';
import '../../../widgets/app_loading.dart';
import '../../../widgets/empty_state_card.dart';

class NFTGallery extends StatefulWidget {
  const NFTGallery({super.key});

  @override
  State<NFTGallery> createState() => _NFTGalleryState();
}

class _NFTGalleryState extends State<NFTGallery> {
  bool _requestedInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedInit) return;
    _requestedInit = true;

    final provider = Provider.of<CollectiblesProvider>(context, listen: false);
    if (!provider.isLoading &&
        provider.allSeries.isEmpty &&
        provider.allCollectibles.isEmpty) {
      unawaited(
        provider.initialize(),
      );
    }

    final walletAddress =
        (Provider.of<WalletProvider>(context, listen: false).currentWalletAddress ?? '')
            .trim();
    if (walletAddress.isNotEmpty) {
      unawaited(
        provider.refreshWalletCollectibleIndex(walletAddress),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.walletHomeActionNfts,
          style: KubusTypography.inter(
            fontSize: KubusHeaderMetrics.screenTitle,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: scheme.onSurface),
            onPressed: () {
              final provider =
                  Provider.of<CollectiblesProvider>(context, listen: false);
              unawaited(
                provider.initialize(),
              );
              final walletAddress =
                  (Provider.of<WalletProvider>(context, listen: false).currentWalletAddress ?? '')
                      .trim();
              if (walletAddress.isNotEmpty) {
                unawaited(
                  provider.refreshWalletCollectibleIndex(walletAddress, force: true),
                );
              }
            },
            tooltip: l10n.commonRefresh,
          ),
        ],
      ),
      body: Consumer2<WalletProvider, CollectiblesProvider>(
        builder: (context, walletProvider, collectiblesProvider, _) {
          final walletAddress =
              (walletProvider.currentWalletAddress ?? '').trim();
          if (walletAddress.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.md,
                  vertical: KubusSpacing.lg,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: EmptyStateCard(
                    icon: Icons.account_balance_wallet,
                    title: 'Connect your wallet',
                    description: 'Connect a wallet to view your collectibles.',
                    showAction: true,
                    actionLabel: 'Connect Wallet',
                    onAction: () =>
                        Navigator.of(context).pushNamed('/connect-wallet'),
                  ),
                ),
              ),
            );
          }

          if (collectiblesProvider.isLoading &&
              collectiblesProvider.allSeries.isEmpty &&
              collectiblesProvider.allCollectibles.isEmpty) {
            return const AppLoading();
          }

          final owned =
              collectiblesProvider.getCollectiblesByOwner(walletAddress);
          if (owned.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.md,
                  vertical: KubusSpacing.lg,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: EmptyStateCard(
                    icon: Icons.diamond_outlined,
                    title: 'No collectibles yet',
                    description: 'Mint NFTs from artworks to see them here.',
                    showAction: false,
                  ),
                ),
              ),
            );
          }

          final seriesById = <String, CollectibleSeries>{
            for (final series in collectiblesProvider.allSeries)
              series.id: series,
          };

          return LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 600;
              final crossAxisCount = isSmallScreen ? 2 : 3;
              final childAspectRatio = isSmallScreen ? 0.75 : 0.82;

              return GridView.builder(
                padding: EdgeInsets.fromLTRB(
                  isSmallScreen ? 16 : 24,
                  (isSmallScreen ? 16 : 24) + kToolbarHeight,
                  isSmallScreen ? 16 : 24,
                  isSmallScreen ? 16 : 24,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: owned.length,
                itemBuilder: (context, index) {
                  final collectible = owned[index];
                  final series = seriesById[collectible.seriesId];
                  return _buildCollectibleCard(
                      context, collectible, series, isSmallScreen);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCollectibleCard(
    BuildContext context,
    Collectible collectible,
    CollectibleSeries? series,
    bool isSmallScreen,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final title = series?.name ?? 'Collectible';
    final rawImage = series?.imageUrl ?? series?.animationUrl;
    final resolvedImage = rawImage == null
        ? null
        : (MediaUrlResolver.resolve(rawImage) ?? rawImage);
    final rarityColor = series != null
        ? RarityUi.collectibleColor(context, series.rarity)
        : AppColorUtils.tealAccent;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(KubusRadius.lg)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (resolvedImage != null && resolvedImage.isNotEmpty)
                    Image.network(
                      resolvedImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _imageFallback(rarityColor, scheme),
                    )
                  else
                    _imageFallback(rarityColor, scheme),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KubusSpacing.sm,
                        vertical: KubusSpacing.xxs * 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(KubusRadius.sm),
                        border: Border.all(
                            color: scheme.outline.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        collectible.status.name.toUpperCase(),
                        style: KubusTypography.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.all(
                isSmallScreen
                    ? KubusSpacing.md - KubusSpacing.xxs
                    : KubusSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: KubusTypography.inter(
                      fontSize: isSmallScreen
                          ? KubusHeaderMetrics.sectionSubtitle
                          : KubusHeaderMetrics.sectionTitle,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: KubusSpacing.xs + KubusSpacing.xxs),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: rarityColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Token #${collectible.tokenId}',
                          style: KubusTypography.inter(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.7),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    (collectible.transactionHash ?? '').isNotEmpty
                        ? 'Tx: ${_shortenHash(collectible.transactionHash ?? '')}'
                        : 'Tx: —',
                    style: KubusTypography.inter(
                      fontSize: 11,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback(Color rarityColor, ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            rarityColor.withValues(alpha: 0.25),
            scheme.tertiary.withValues(alpha: 0.10),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.diamond_outlined,
          size: 42,
          color: scheme.onSurface.withValues(alpha: 0.65),
        ),
      ),
    );
  }

  String _shortenHash(String hash) {
    final value = hash.trim();
    if (value.length <= 14) return value;
    return '${value.substring(0, 6)}…${value.substring(value.length - 6)}';
  }
}
