import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ThreeDSScreen extends StatelessWidget {
  final String url;
  const ThreeDSScreen({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161925),
        title: const Text('Secure Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(url)),
            onLoadStop: (controller, url) {
              if (url != null) {
                final urlStr = url.toString();
                if (urlStr.contains('/payment/success')) {
                  Navigator.pop(context, true);
                } else if (urlStr.contains('/payment/failure')) {
                  Navigator.pop(context, false);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
