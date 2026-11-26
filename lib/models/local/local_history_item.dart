/// 本地观看记录（未登录时使用）
///
/// 只保存在独立的 `localHistory` box 里，
/// 不写入设置、不参与备份 / 同步 / 导出，仅限本设备浏览。
class LocalHistoryItem {
  const LocalHistoryItem({
    required this.bvid,
    required this.cid,
    required this.title,
    required this.watchTime,
    this.cover,
    this.ownerName,
    this.ownerMid,
    this.duration = 0,
    this.progress = 0,
  });

  final String bvid;
  final int cid;
  final String title;
  final String? cover;
  final String? ownerName;
  final int? ownerMid;

  /// 视频总时长（秒），0 表示未知
  final int duration;

  /// 最近观看时间（毫秒时间戳）
  final int watchTime;

  /// 上次播放进度（毫秒），0 表示从头开始
  final int progress;

  /// 同一视频的不同分P分开记录
  String get key => '$bvid:$cid';

  LocalHistoryItem copyWith({int? watchTime, int? progress}) {
    return LocalHistoryItem(
      bvid: bvid,
      cid: cid,
      title: title,
      cover: cover,
      ownerName: ownerName,
      ownerMid: ownerMid,
      duration: duration,
      watchTime: watchTime ?? this.watchTime,
      progress: progress ?? this.progress,
    );
  }

  Map<String, dynamic> toMap() => {
    'bvid': bvid,
    'cid': cid,
    'title': title,
    'cover': cover,
    'ownerName': ownerName,
    'ownerMid': ownerMid,
    'duration': duration,
    'watchTime': watchTime,
    'progress': progress,
  };

  static LocalHistoryItem? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final bvid = raw['bvid'];
    final cid = raw['cid'];
    if (bvid is! String || bvid.isEmpty || cid is! int || cid <= 0) {
      return null;
    }
    return LocalHistoryItem(
      bvid: bvid,
      cid: cid,
      title: raw['title'] as String? ?? '',
      cover: raw['cover'] as String?,
      ownerName: raw['ownerName'] as String?,
      ownerMid: raw['ownerMid'] as int?,
      duration: raw['duration'] as int? ?? 0,
      watchTime: raw['watchTime'] as int? ?? 0,
      progress: raw['progress'] as int? ?? 0,
    );
  }
}
