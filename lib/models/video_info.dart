class VideoInfo {
  final String bvid;
  final int aid;
  final String title;
  final String coverUrl;
  final Duration duration;
  final int cid;

  const VideoInfo({
    required this.bvid,
    required this.aid,
    required this.title,
    required this.coverUrl,
    required this.duration,
    required this.cid,
  });

  factory VideoInfo.fromBiliResponse(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final pages = data['pages'] as List<dynamic>;
    final firstPage = pages[0] as Map<String, dynamic>;
    return VideoInfo(
      bvid: data['bvid'] as String,
      aid: data['aid'] as int,
      title: data['title'] as String,
      coverUrl: data['pic'] as String,
      duration: Duration(seconds: data['duration'] as int),
      cid: firstPage['cid'] as int,
    );
  }

  String get durationText {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
