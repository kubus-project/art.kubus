import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late WebViewController _controller;
  bool _webViewReady = false;  // This should not be final

  @override
  void initState() {
    super.initState();
    // Don't call _prepareLocalHtml here, wait until WebView is ready
  }

  Future<void> _prepareLocalHtml() async {
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/map.html';

    // Load the HTML file from assets
    final htmlBytes = await rootBundle.load('assets/html/map.html');
    final htmlString = String.fromCharCodes(htmlBytes.buffer.asUint8List());

    // Write the file to the file system
    final file = File(filePath);
    await file.writeAsString(htmlString);

    // Only try to load the file if the WebView is ready
    if (_webViewReady) {
      _controller.loadUrl('file://$filePath');  // Use loadUrl
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map View'),
      ),
      body: WebView(
        initialUrl: 'about:blank',
        javascriptMode: JavascriptMode.unrestricted,
        onWebViewCreated: (WebViewController webViewController) {
          _controller = webViewController;
          _webViewReady = true;  // Set to true when WebView is created
          _prepareLocalHtml();  // Now call to prepare and load HTML
        },
        onPageFinished: (url) {
          // Use this if needed to handle additional logic once the page loads
        },
      ),
    );
  }
}
