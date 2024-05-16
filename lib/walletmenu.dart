import 'package:art_kubus/profile/userprofile.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'nftcollectionpage.dart';
import 'providers/connection_provider.dart';

class ProfileMenu extends StatelessWidget {
  const ProfileMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final connectionProvider = Provider.of<ConnectionProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Container(
          color: Colors.black,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buildMenuItem(
                    context,
                    title: 'Collection',
                    onPressed: connectionProvider.isConnected ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NFTCollectionPage()),
                      );
                    } : null, // Disable if not connected
                    isEnabled: connectionProvider.isConnected,
                  ),
                  const SizedBox(height: 30),
                  buildMenuItem(
                    context,
                    title: 'Community',
                    onPressed: connectionProvider.isConnected ? () {
                      showSnackbar(context, 'Community feature is not yet available.');
                    } : null, // Disable if not connected
                    isEnabled: connectionProvider.isConnected,
                  ),
                  const SizedBox(height: 30),
                  buildMenuItem(
                    context,
                    title: 'Profile',
                    onPressed: connectionProvider.isConnected ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) =>  const UserProfile()),
                      );
                    } : null, // Disable if not connected
                    isEnabled: connectionProvider.isConnected,
                  ),
                  const SizedBox(height: 30),
                  buildMenuItem(
                    context,
                    title: 'Support',
                    onPressed: () {
                      launchEmail(context, 'info@kubus.site');
                    },
                    isEnabled: true, // Always enabled
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () async {
                      if (connectionProvider.isConnected) {
                        connectionProvider.disconnectWallet();
                        showSnackbar(context, 'Wallet disconnected successfully.');
                      } else {
                        try {
                          connectionProvider.connectWallet();
                          showSnackbar(context, 'Wallet connected successfully.');
                        } catch (e) {
                          showSnackbar(context, 'Failed to connect wallet.');
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      backgroundColor: Colors.white,
                    ),
                    child: Text(
                      connectionProvider.isConnected ? 'Disconnect Wallet' : 'Connect Wallet',
                      style: const TextStyle(color: Colors.black, fontFamily: 'Sofia Sans'),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

Widget buildMenuItem(BuildContext context, {required String title, VoidCallback? onPressed, required bool isEnabled}) {
  return GestureDetector(
    onTap: () {
      if (isEnabled) {
        if (onPressed != null) {
          onPressed();
        }
      } else {
        showSnackbar(context, 'Please connect your wallet to access this feature.');
      }
    },
    child: Container(
      height: 115,
      decoration: BoxDecoration(
        color: isEnabled ? const Color(0xFFD9D9D9) : Colors.grey.shade800, // Grey out if disabled
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            color: isEnabled ? Colors.black : Colors.white.withOpacity(0.7), // Semi-visible text if disabled
            fontSize: 32,
            fontFamily: 'Sofia Sans',
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    ),
  );
}

  

 void launchEmail(BuildContext context, String email) async {
  final Uri emailLaunchUri = Uri(
    scheme: 'mailto',
    path: email,
  );

  // Store the ScaffoldMessenger instance before the async gap
  final scaffoldMessenger = ScaffoldMessenger.of(context);

  try {
    await launchUrl(emailLaunchUri);
  } catch (e) {
    // Use the stored ScaffoldMessenger instance
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Could not launch email.')),
    );
  }
}

}
