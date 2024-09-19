import 'package:flutter/material.dart';
import 'artvote.dart';
import '/web3/wallet.dart';
import '/profile/userprofile.dart';
import 'platformvote.dart';

class DAOMenu extends StatelessWidget {
  const DAOMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final ArtDAO artDAO = ArtDAO();
    artDAO.populateArtPiecesWithRandomImages(10); // Populate with 10 random art pieces

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 20,
              left: MediaQuery.of(context).size.width * 0.04,
              right: MediaQuery.of(context).size.width * 0.04,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FloatingActionButton(
                    heroTag: 'UserProfileFAB',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const UserProfile()),
                      );
                    },
                    child: const Icon(Icons.person, size: 30),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.3,
                    child: FloatingActionButton(
                      heroTag: 'WalletFAB',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const Wallet()),
                        );
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '1000', // Replace '1000' with the actual token amount
                              style: TextStyle(fontSize: 18),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 5),
                          Icon(Icons.account_balance_wallet, size: 30),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 2),
                    buildMenuItem(
                      context,
                      title: 'Vote on Art',
                      onPressed: () {
                        final artPieces = artDAO.listAllArtPieces();
                        if (artPieces.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ArtVoteWidget(
                                artPieces: artPieces,
                                artDAO: ArtDAO(), // Pass a valid ArtDAO instance here
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No art pieces available to vote on.')),
                          );
                        }
                      },
                      icon: Icons.how_to_vote,
                      heroTag: 'VoteButton',
                    ),
                    const Spacer(flex: 1),
                    buildMenuItem(
                      context,
                      title: 'Platform Vote',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PlatformVote()),
                        );
                      },
                      icon: Icons.add_box,
                      heroTag: 'PlatformVoteButton',
                    ),
                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMenuItem(BuildContext context, {required String title, VoidCallback? onPressed, required IconData icon, required String heroTag}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Hero(
            tag: heroTag,
            child: Icon(icon, size: 40),
          ),
          const SizedBox(height: 5),
          Text(title),
        ],
      ),
    );
  }
}