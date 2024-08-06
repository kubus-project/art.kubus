import 'package:art_kubus/profile/userprofile.dart';
import 'package:flutter/material.dart';
import 'web3/nftcollectionpage.dart';
import '/community/community.dart';
import 'web3/wallet.dart';
import 'support.dart';

class Menu extends StatelessWidget {
  const Menu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 15),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                            isWide: isWide,
                          ),
                          const SizedBox(height: 15),
                          buildMenuItem(
                            context,
                            title: 'Community',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => InfiniteScrollFeed()),
                              );
                            },
                            icon: Icons.people,
                            isWide: isWide,
                          ),
                          const SizedBox(height: 15),
                          buildMenuItem(
                            context,
                            title: 'Profile',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const UserProfile()),
                              );
                            },
                            icon: Icons.person,
                            isWide: isWide,
                          ),
                          const SizedBox(height: 15),
                          buildMenuItem(
                            context,
                            title: 'Wallet',
                            onPressed: () async {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const Wallet()),
                              );
                            },
                            icon: Icons.account_balance_wallet,
                            isWide: isWide,
                          ),
                          const SizedBox(height: 15),
                          buildMenuItem(
                            context,
                            title: 'Support',
                            onPressed: () {
                          Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => Support()), // Use SupportWidget
                              );
                            },
                            icon: Icons.contact_support,
                            isWide: isWide,
                          ),
                          const SizedBox(height: 15),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget buildMenuItem(BuildContext context, {required String title, VoidCallback? onPressed, required IconData icon, required bool isWide}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      child: isWide
        ? Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(icon, size: 40, color: Colors.black),
              const SizedBox(width: 10), 
              Text(title, style: const TextStyle(fontSize: 22, color: Colors.black)),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: Colors.black),
              const SizedBox(height: 10), 
              Text(title, style: const TextStyle(fontSize: 22, color: Colors.black)),
            ],
          ),
    );
  }
}