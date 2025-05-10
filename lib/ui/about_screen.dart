import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  AboutScreenState createState() => AboutScreenState();
}

class AboutScreenState extends State<AboutScreen> {
  late final WebViewController _controller;
  int _stackToView = 1;

  @override
  void initState() {
    super.initState();
    // Required for Android: initialize the platform.
    // (No-op on iOS, safe to call on all platforms.)
    // See: https://pub.dev/packages/webview_flutter#platform-initialization
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (!mounted) return;
            setState(() {
              _stackToView = 0;
            });
          },
          onWebResourceError: (WebResourceError error) {
            if (!mounted) return;
            debugPrint('WebView error: ${error.description}');
            // Optionally, display an error message to the user here.
          },
        ),
      )
      ..loadRequest(
          Uri.parse('https://retrosharedocs.readthedocs.io/en/latest/'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: IndexedStack(
        index: _stackToView,
        children: [
          WebViewWidget(controller: _controller),
          const ColoredBox(
            color: Colors.white,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      ),
    );
  }
}
