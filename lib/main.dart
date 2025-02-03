import 'package:flutter/material.dart';
import 'package:youtube_live_data_viewer/screens/youtube_data_viewer.dart';
import 'package:universal_html/html.dart' as html;

void main() {
  final uri = Uri.parse(html.window.location.href);
  final url = uri.queryParameters['url'];

  runApp(MyApp(initialUrl: url));
}

class MyApp extends StatelessWidget {
  final String? initialUrl;

  const MyApp({super.key, this.initialUrl});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YouTube Live Data Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF0000),
          brightness: Brightness.light,
          primary: const Color(0xFFFF0000),
          secondary: const Color(0xFFFF4444),
        ),
        useMaterial3: true,
      ),
      home: YouTubeDataViewer(initialUrl: initialUrl),
    );
  }
}
