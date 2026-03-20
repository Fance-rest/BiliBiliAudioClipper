class PageInfo {
  final int cid;
  final String title;
  final Duration duration;

  const PageInfo({
    required this.cid,
    required this.title,
    required this.duration,
  });
}

class VideoInfo {
  final String bvid;
  final int aid;
  final String title;
  final String coverUrl;
  final Duration duration;
  final int cid;
  final List<PageInfo> pages;

  const VideoInfo({
    required this.bvid,
    required this.aid,
    required this.title,
    required this.coverUrl,
    required this.duration,
    required this.cid,
    this.pages = const [],
  });

  bool get hasMultiplePages => pages.length > 1;

  factory VideoInfo.fromBiliResponse(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final rawPages = data['pages'] as List<dynamic>;
    final pages = rawPages.map((p) {
      final page = p as Map<String, dynamic>;
      return PageInfo(
        cid: page['cid'] as int,
        title: page['part'] as String? ?? '',
        duration: Duration(seconds: page['duration'] as int? ?? 0),
      );
    }).toList();
    final firstPage = pages[0];
    return VideoInfo(
      bvid: data['bvid'] as String,
      aid: data['aid'] as int,
      title: data['title'] as String,
      coverUrl: data['pic'] as String,
      duration: Duration(seconds: data['duration'] as int),
      cid: firstPage.cid,
      pages: pages,
    );
  }

  String get durationText {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
