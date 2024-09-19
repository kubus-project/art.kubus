import 'package:flutter/material.dart';
import 'communityfeed.dart';
import '/web3/wallet.dart';
import '/profile/userprofile.dart';

class CommunityFeedMenu extends StatelessWidget {
  const CommunityFeedMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
                    backgroundColor: Colors.transparent,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const UserProfile()),
                      );
                    },
                    child: const Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.2,
                    child: FloatingActionButton(
                      heroTag: 'WalletFAB',
                      backgroundColor: Colors.transparent,
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
                              style: TextStyle(color: Colors.white, fontSize: 18),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 5),
                          Icon(Icons.account_balance_wallet, color: Colors.white, size: 30),
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
                      title: 'Community Feed',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const InfiniteScrollFeed()),
                        );
                      },
                      icon: Icons.feed,
                      heroTag: 'CommunityFeedButton',
                    ),
                    const Spacer(flex: 1),
                    buildMenuItem(
                      context,
                      title: 'Post to Feed',
                      onPressed: () {
                        // Add navigation to post to feed page
                      },
                      icon: Icons.post_add,
                      heroTag: 'PostFeedButton',
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
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Hero(
            tag: heroTag,
            child: Icon(icon, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}