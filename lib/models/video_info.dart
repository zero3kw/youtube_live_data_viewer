class VideoInfo {
  final String title;
  final String description;
  final String channelName;
  final String channelUrl;
  final String channelId;
  final String videoId;
  final String viewCount;
  final bool isLive;
  final bool isLiveNow;
  final String startTimestamp;
  final String endTimestamp;
  final String category;
  final String maxQuality;
  final String maxBitrate;
  final int fps;
  final bool isLiveDvrEnabled;

  VideoInfo({
    required this.title,
    required this.description,
    required this.channelName,
    required this.channelUrl,
    required this.channelId,
    required this.videoId,
    required this.viewCount,
    required this.isLive,
    required this.isLiveNow,
    required this.startTimestamp,
    required this.endTimestamp,
    required this.category,
    required this.maxQuality,
    required this.maxBitrate,
    required this.fps,
    required this.isLiveDvrEnabled,
  });

  factory VideoInfo.fromJson(Map<String, dynamic> json) {
    final videoDetails = json['videoDetails'] ?? {};
    final microformat = json['microformat']?['playerMicroformatRenderer'] ?? {};
    final streamingData = json['streamingData'] ?? {};

    final videoFormats = (streamingData['adaptiveFormats'] as List<dynamic>?)
            ?.where(
                (format) => format['mimeType'].toString().startsWith('video/'))
            .toList() ??
        [];

    final highestQualityFormat = videoFormats.isNotEmpty
        ? videoFormats.reduce((prev, current) =>
            (prev['bitrate'] > current['bitrate']) ? prev : current)
        : {};

    final channelId = videoDetails['channelId'] ?? '';
    final videoId = videoDetails['videoId'] ?? '';

    return VideoInfo(
      title: videoDetails['title'] ?? '',
      description: videoDetails['shortDescription'] ?? '',
      channelName: videoDetails['author'] ?? '',
      channelUrl: 'https://www.youtube.com/channel/$channelId',
      channelId: channelId,
      videoId: videoId,
      viewCount: videoDetails['viewCount']?.toString() ?? '0',
      isLive: videoDetails['isLive'] ?? false,
      isLiveNow: microformat['liveBroadcastDetails']?['isLiveNow'] ?? false,
      startTimestamp:
          microformat['liveBroadcastDetails']?['startTimestamp'] ?? '',
      endTimestamp: microformat['liveBroadcastDetails']?['endTimestamp'] ?? '',
      category: microformat['category'] ?? '',
      maxQuality: highestQualityFormat['qualityLabel'] ?? '',
      maxBitrate: highestQualityFormat['bitrate']?.toString() ?? '',
      fps: highestQualityFormat['fps'] ?? 0,
      isLiveDvrEnabled: videoDetails['isLiveDvrEnabled'] ?? false,
    );
  }
}
