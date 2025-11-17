import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import '../../widgets/app_loading.dart';
import '../../services/backend_api_service.dart';

class NFTGallery extends StatefulWidget {
  const NFTGallery({super.key});

  @override
  State<NFTGallery> createState() => _NFTGalleryState();
}

class _NFTGalleryState extends State<NFTGallery> {
  final BackendApiService _backendApi = BackendApiService();
  List<Map<String, dynamic>> _nfts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNFTs();
  }

  Future<void> _loadNFTs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) {
        setState(() {
          _error = 'Please connect your wallet first';
          _isLoading = false;
        });
        return;
      }

      final nfts = await _backendApi.getUserNFTs(userId: userId);
      
      setState(() {
        _nfts = nfts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading NFTs: $e');
      setState(() {
        _error = 'Failed to load NFTs';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNFTs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoading();
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadNFTs,
              icon: const Icon(Icons.refresh),
              label: Text('Retry', style: GoogleFonts.inter()),
            ),
          ],
        ),
      );
    }

    if (_nfts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.diamond_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No NFTs yet',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mint some NFTs from artworks\nto see them here',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth < 600 ? 2 : 3;
        double childAspectRatio = constraints.maxWidth < 600 ? 0.75 : 0.8;
        
        return GridView.builder(
          padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: _nfts.length,
          itemBuilder: (context, index) {
            return _buildNFTCard(context, _nfts[index], constraints.maxWidth < 600);
          },
        );
      },
    );
  }

  Widget _buildNFTCard(BuildContext context, Map<String, dynamic> nft, bool isSmallScreen) {
    final tokenId = nft['token_id'] ?? nft['tokenId'] ?? 'Unknown';
    final status = nft['status'] ?? 'minted';
    final transactionHash = nft['transaction_hash'] ?? nft['transactionHash'];
    final properties = nft['properties'] as Map<String, dynamic>? ?? {};
    final edition = properties['edition'] ?? '?';
    final maxEdition = properties['maxEdition'] ?? '?';
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.4),
                    Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.9).withValues(alpha: 0.4),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.diamond,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 48,
                    ),
                  ),
                  if (status == 'listed')
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'LISTED',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
              padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NFT #$tokenId',
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 12 : 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Edition $edition/$maxEdition',
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 10 : 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          status.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 10 : 12,
                            fontWeight: FontWeight.w600,
                            color: Provider.of<ThemeProvider>(context).accentColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (transactionHash != null)
                        Icon(
                          Icons.verified,
                          color: Colors.green,
                          size: 16,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}





