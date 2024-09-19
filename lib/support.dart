import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class Support extends StatelessWidget {
  const Support({super.key});

  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.code),
                onPressed: () {
                  _launchURL('https://github.com/kubus-project');
                },
                tooltip: 'GitHub',
                iconSize: 40.0,
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: const Icon(Icons.web_asset_sharp),
                onPressed: () {
                  _launchURL('https://kubus.site');
                },
                tooltip: 'Website',
                iconSize: 40.0,
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              // Add your live chat functionality here
            },
            icon: const Icon(
              Icons.support_agent_outlined,
              size: 40.0,
            ),
            label: const Text(
              'Live Chat',
              style: TextStyle(fontSize: 20.0),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: 16.0,
                horizontal: 24.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}