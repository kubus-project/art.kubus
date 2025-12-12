import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../config/config.dart';
import '../../../models/collectible.dart';
import '../../../providers/collectibles_provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/web3provider.dart';
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
    if (!provider.isLoading && provider.allSeries.isEmpty && provider.allCollectibles.isEmpty) {
      unawaited(provider.initialize(loadMockIfEmpty: AppConfig.isDevelopment));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'NFT Gallery',
          style: GoogleFonts.inter(
            fontSize: 24,
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
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final provider = Provider.of<CollectiblesProvider>(context, listen: false);
              unawaited(provider.initialize(loadMockIfEmpty: AppConfig.isDevelopment));
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer2<Web3Provider, CollectiblesProvider>(
        builder: (context, web3Provider, collectiblesProvider, _) {
          final walletAddress = web3Provider.walletAddress.trim();
          if (walletAddress.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: EmptyStateCard(
                  icon: Icons.account_balance_wallet,
                  title: 'Connect your wallet',
                  description: 'Connect a wallet to view your collectibles.',
                  showAction: true,
                  actionLabel: 'Connect Wallet',
                  onAction: () => Navigator.of(context).pushNamed('/connect-wallet'),
                ),
              ),
            );
          }

          if (collectiblesProvider.isLoading &&
              collectiblesProvider.allSeries.isEmpty &&
              collectiblesProvider.allCollectibles.isEmpty) {
            return const AppLoading();
          }

          final owned = collectiblesProvider.getCollectiblesByOwner(walletAddress);
          if (owned.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: EmptyStateCard(
                  icon: Icons.diamond_outlined,
                  title: 'No collectibles yet',
                  description: 'Mint NFTs from artworks to see them here.',
                  showAction: false,
                ),
              ),
            );
          }

          final seriesById = <String, CollectibleSeries>{
            for (final series in collectiblesProvider.allSeries) series.id: series,
          };

          return LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 600;
              final crossAxisCount = isSmallScreen ? 2 : 3;
              final childAspectRatio = isSmallScreen ? 0.75 : 0.82;

              return GridView.builder(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
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
                  return _buildCollectibleCard(context, collectible, series, isSmallScreen);
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
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final scheme = Theme.of(context).colorScheme;
    final title = series?.name ?? 'Collectible';
    final rawImage = series?.imageUrl ?? series?.animationUrl;
    final resolvedImage = rawImage == null ? null : (MediaUrlResolver.resolve(rawImage) ?? rawImage);
    final rarityColor = series != null
        ? RarityUi.collectibleColor(context, series.rarity)
        : themeProvider.accentColor;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (resolvedImage != null && resolvedImage.isNotEmpty)
                    Image.network(
                      resolvedImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imageFallback(themeProvider, rarityColor),
                    )
                  else
                    _imageFallback(themeProvider, rarityColor),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        collectible.status.name.toUpperCase(),
                        style: GoogleFonts.inter(
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
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 13 : 15,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
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
                          style: GoogleFonts.inter(
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
                    style: GoogleFonts.inter(
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

  Widget _imageFallback(ThemeProvider themeProvider, Color rarityColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            rarityColor.withValues(alpha: 0.25),
            themeProvider.accentColor.withValues(alpha: 0.10),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.diamond_outlined,
          size: 42,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
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
