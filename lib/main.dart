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
          brightness: Brightness.dark,
          primary: const Color(0xFFFF0000),
          secondary: const Color(0xFFFF4444),
          background: const Color(0xFF121212),
          surface: const Color(0xFF1E1E1E),
        ),
        cardTheme: const CardTheme(
          color: Color(0xFF242424),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white70),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: Colors.white),
        ),
        useMaterial3: true,
      ),
      home: YouTubeDataViewer(initialUrl: initialUrl),
    );
  }
}
