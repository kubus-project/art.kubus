import 'package:art_kubus/profile/userprofile.dart';
import 'package:flutter/material.dart';
import 'web3/nftcollectionpage.dart';
import 'community/communitymenu.dart';
import 'web3/wallet.dart';
import 'settings.dart';

class Menu extends StatelessWidget {
  const Menu({super.key});

  @override
  Widget build(BuildContext context) {
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
                    width: MediaQuery.of(context).size.width * 0.3, // Adjust the width as needed
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
                      title: 'Collection',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const NFTCollectionPage()),
                        );
                      },
                      icon: Icons.collections,
                      heroTag: 'CollectionButton',
                    ),
                    const Spacer(flex: 1),
                    buildMenuItem(
                      context,
                      title: 'Community',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CommunityMenu()),
                        );
                      },
                      icon: Icons.people,
                      heroTag: 'CommunityButton',
                    ),
                    const Spacer(flex: 1),
                    buildMenuItem(
                      context,
                      title: 'Settings',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AppSettings()),
                        );
                      },
                      icon: Icons.settings,
                      heroTag: 'SettingsButton',
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