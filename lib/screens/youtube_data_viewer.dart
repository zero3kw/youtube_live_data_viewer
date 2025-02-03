import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/video_info.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_json_view/flutter_json_view.dart';

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
  dynamic _rawPlayerData;
  bool _isJsonExpanded = false;

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
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: const Text(
          'YouTube Live Data Viewer',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 8,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            labelText: 'YouTube URL',
                            hintText: 'https://www.youtube.com/watch?v=...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.link),
                          ),
                          onSubmitted: (value) => _fetchData(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _fetchData,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.search),
                        label: const Text('取得'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_playerController != null) _buildVideoPlayer(),
              if (_videoInfo != null) ...[
                const SizedBox(height: 16),
                _buildVideoInfo(),
                const SizedBox(height: 16),
                _buildRawData(),
              ],
            ],
          ),
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

  Widget _buildVideoInfo() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  'Video Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SelectableText(
              _videoInfo!.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
                Icons.account_circle, 'チャンネル', _videoInfo!.channelName),
            _buildInfoRow(Icons.numbers, 'チャンネルID', _videoInfo!.channelId),
            _buildInfoRow(Icons.video_library, '動画ID', _videoInfo!.videoId),
            _buildInfoRow(Icons.visibility, '視聴回数',
                '${_formatNumber(_videoInfo!.viewCount)}回'),
            if (_videoInfo!.isLive) _buildInfoRow(Icons.live_tv, 'ライブ配信', 'はい'),
            if (_videoInfo!.isLiveNow) _buildInfoRow(Icons.stream, '配信中', 'はい'),
            if (_videoInfo!.isLiveDvrEnabled)
              _buildInfoRow(Icons.replay_circle_filled, 'DVR', '有効'),
            if (_videoInfo!.startTimestamp.isNotEmpty)
              _buildInfoRow(Icons.play_circle, '開始時刻',
                  _formatDate(_videoInfo!.startTimestamp)),
            if (_videoInfo!.endTimestamp.isNotEmpty)
              _buildInfoRow(Icons.stop_circle, '終了時刻',
                  _formatDate(_videoInfo!.endTimestamp)),
            if (_videoInfo!.category.isNotEmpty)
              _buildInfoRow(Icons.category, 'カテゴリ', _videoInfo!.category),
            if (_videoInfo!.maxQuality.isNotEmpty)
              _buildInfoRow(Icons.high_quality, '最高画質', _videoInfo!.maxQuality),
            if (_videoInfo!.maxBitrate.isNotEmpty)
              _buildInfoRow(Icons.speed, 'ビットレート',
                  _formatBitrate(_videoInfo!.maxBitrate)),
            if (_videoInfo!.fps > 0)
              _buildInfoRow(Icons.timer, 'FPS', '${_videoInfo!.fps}'),
            if (_videoInfo!.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '説明',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
              ),
              const SizedBox(height: 8),
              SelectableText(_videoInfo!.description),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawData() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.code, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Raw Data',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    final data = const JsonEncoder.withIndent('  ')
                        .convert(_rawPlayerData);
                    // TODO: クリップボードへのコピー機能を実装
                  },
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy JSON',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: JsonView.map(
                _rawPlayerData,
                theme: JsonViewTheme(
                  backgroundColor: const Color(0xFF1E1E1E),
                  defaultTextStyle: const TextStyle(
                    color: Color(0xFFCE9178),
                    fontSize: 14,
                    fontFamily: 'Fira Code',
                  ),
                  keyStyle: const TextStyle(
                    color: Color(0xFF9CDCFE),
                    fontSize: 14,
                    fontFamily: 'Fira Code',
                  ),
                  closeIcon:
                      const Icon(Icons.arrow_drop_down, color: Colors.white),
                  openIcon: const Icon(Icons.arrow_right, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
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
        _rawPlayerData = playerData;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }
}
