import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/video_info.dart';

class YouTubeDataViewer extends StatefulWidget {
  final String? initialUrl;
  const YouTubeDataViewer({super.key, this.initialUrl});

  @override
  State<YouTubeDataViewer> createState() => _YouTubeDataViewerState();
}

class _YouTubeDataViewerState extends State<YouTubeDataViewer> {
  final _urlController = TextEditingController();
  YoutubePlayerController? _playerController;
  VideoInfo? _videoInfo;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      _fetchData();
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _playerController?.close();
    super.dispose();
  }

  String _formatNumber(String number) {
    final formatter = NumberFormat('#,###');
    return formatter.format(int.parse(number));
  }

  String _formatBitrate(String bitrate) {
    final value = int.parse(bitrate);
    if (value > 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)} Mbps';
    } else if (value > 1000) {
      return '${(value / 1000).toStringAsFixed(1)} Kbps';
    }
    return '$value bps';
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '';
    final date = DateTime.parse(dateString);
    return DateFormat('yyyy/MM/dd HH:mm:ss').format(date);
  }

  String _extractVideoId(String url) {
    final regExp = RegExp(
      r'^.*((youtu.be\/)|(v\/)|(\/u\/\w\/)|(embed\/)|(watch\?))\??v?=?([^#&?]*)',
    );
    final match = regExp.firstMatch(url);
    return (match != null && match.group(7)!.length == 11)
        ? match.group(7)!
        : '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube Live Data Viewer'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          hintText: 'Enter YouTube Live URL',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _fetchData,
                      child: const Text('Fetch Data'),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null)
              Card(
                color: Colors.red.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              ),
            if (_videoInfo != null) ...[
              _buildVideoPlayer(),
              _buildVideoInfo(),
              _buildStreamInfo(),
              _buildDescription(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Card(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: _playerController != null
            ? YoutubePlayer(
                controller: _playerController!,
                aspectRatio: 16 / 9,
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _fetchData() async {
    setState(() {
      _error = null;
      _videoInfo = null;
      _playerController?.close();
      _playerController = null;
    });

    final url = _urlController.text;
    if (url.isEmpty) {
      setState(() {
        _error = 'URLを入力してください';
      });
      return;
    }

    final videoId = _extractVideoId(url);
    if (videoId.isEmpty) {
      setState(() {
        _error = '無効なYouTube URLです';
      });
      return;
    }

    try {
      // CORSプロキシを使用して動画情報を取得
      final response = await http.get(
        Uri.parse(
            'https://corsproxy.io/?https://www.youtube.com/watch?v=$videoId'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'ja,en-US;q=0.7,en;q=0.3',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('データの取得に失敗しました (${response.statusCode})');
      }

      final html = response.body;
      final startTag = 'ytInitialPlayerResponse = ';
      final startIndex = html.indexOf(startTag);

      if (startIndex == -1) {
        throw Exception('動画データが見つかりません');
      }

      var endIndex = startIndex + startTag.length;
      var bracketCount = 0;
      var found = false;

      while (endIndex < html.length) {
        if (html[endIndex] == '{') bracketCount++;
        if (html[endIndex] == '}') {
          bracketCount--;
          if (bracketCount == 0) {
            found = true;
            break;
          }
        }
        endIndex++;
      }

      if (!found) {
        throw Exception('動画データの解析に失敗しました');
      }

      final jsonStr =
          html.substring(startIndex + startTag.length, endIndex + 1);
      final playerData = json.decode(jsonStr);

      // プレーヤーを初期化
      setState(() {
        _videoInfo = VideoInfo.fromJson(playerData);
        _playerController = YoutubePlayerController.fromVideoId(
          videoId: videoId,
          params: const YoutubePlayerParams(
            showControls: true,
            mute: false,
            showFullscreenButton: true,
            enableJavaScript: true,
          ),
        );
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  Widget _buildVideoInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _videoInfo!.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final url = Uri.parse(_videoInfo!.channelUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              child: Text(
                _videoInfo!.channelName,
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('視聴回数: ${_formatNumber(_videoInfo!.viewCount)}回'),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamInfo() {
    if (!_videoInfo!.isLive) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ライブ配信情報',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('配信中: ${_videoInfo!.isLiveNow ? "はい" : "いいえ"}'),
            Text('開始時刻: ${_formatDate(_videoInfo!.startTimestamp)}'),
            if (_videoInfo!.endTimestamp.isNotEmpty)
              Text('終了時刻: ${_formatDate(_videoInfo!.endTimestamp)}'),
            Text('最高画質: ${_videoInfo!.maxQuality}'),
            Text('最大ビットレート: ${_formatBitrate(_videoInfo!.maxBitrate)}'),
            Text('FPS: ${_videoInfo!.fps}'),
            Text('DVR: ${_videoInfo!.isLiveDvrEnabled ? "有効" : "無効"}'),
          ],
        ),
      ),
    );
  }

  Widget _buildDescription() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '説明',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(_videoInfo!.description),
          ],
        ),
      ),
    );
  }
}
