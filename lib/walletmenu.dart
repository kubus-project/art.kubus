import 'package:art_kubus/profile/userprofile.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'nftcollectionpage.dart';
import 'wallet.dart'; // Import the Wallet page

class ProfileMenu extends StatelessWidget {
  const ProfileMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Menu'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),

              Expanded(flex: 8, child: buildMenuItem(
                context,
                title: 'Collection',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NFTCollectionPage()),
                  );
                },
                icon: Icons.collections,
              )),

              const Spacer(flex: 1),

              Expanded(flex: 8, child: buildMenuItem(
                context,
                title: 'Community',
                onPressed: () {
                  showSnackbar(context, 'Community feature is not yet available.');
                },
                icon: Icons.people,
              )),

              const Spacer(flex: 1),

              Expanded(flex: 8, child: buildMenuItem(
                context,
                title: 'Profile',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) =>  const UserProfile()),
                  );
                },
                icon: Icons.person,
              )),

              const Spacer(flex: 1),

              Expanded(flex: 8, child: buildMenuItem(
                context,
                title: 'Wallet',
                onPressed: () async {
                  {
                   Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const Wallet()),
                    );
                  }
                },
                icon: Icons.account_balance_wallet,
              )),

              const Spacer(flex: 1),

              Expanded(flex: 8, child: buildMenuItem(
                context,
                title: 'Support',
                onPressed: () {
                  launchEmail(context, 'info@kubus.site');
                },
                icon: Icons.contact_support,
              )),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
  void showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.grey.shade800,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget buildMenuItem(BuildContext context, {required String title, VoidCallback? onPressed, required IconData icon}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.all(15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Colors.black),
          const SizedBox(height: 10), 
          Text(title, style: const TextStyle(fontSize: 22,   color: Colors.black)),
        ],
      ),
    );
  }

void launchEmail(BuildContext context, String email) async {
  final Uri emailLaunchUri = Uri(
    scheme: 'mailto',
    path: email,
  );

  final scaffoldMessenger = ScaffoldMessenger.of(context);

  try {
    await launchUrl(emailLaunchUri);
  } catch (e) {
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Could not launch email.')),
    );
  }
}
}