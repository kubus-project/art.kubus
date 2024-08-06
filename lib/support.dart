import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class Support extends StatelessWidget {
  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                icon: Icon(Icons.code, color: Colors.white),
                onPressed: () {
                  _launchURL('https://github.com/kubus-project');
                },
                tooltip: 'GitHub',
                iconSize: 40.0,
              ),
              SizedBox(width: 20),
              IconButton(
                icon: Icon(Icons.web_asset_sharp, color: Colors.white),
                onPressed: () {
                  _launchURL('https://kubus.site');
                },
                tooltip: 'Website',
                iconSize: 40.0,
              ),
            ],
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              // Add your live chat functionality here
            },
            icon: Icon(Icons.support_agent_outlined, color: Colors.black, size: 40.0),
            label: Text(
              'Live Chat',
              style: TextStyle(fontSize: 20.0), // Adjust font size as needed
            ), 
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0), // Adjust padding as needed
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}