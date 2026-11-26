/// 本地稍后再看（未登录时使用）
///
/// 只保存在独立的 `localLater` box 里，
/// 不写入设置、不参与备份 / 同步 / 导出，仅限本设备浏览。
class LocalLaterItem {
  const LocalLaterItem({
    required this.bvid,
    required this.cid,
    required this.title,
    required this.addTime,
    this.cover,
    this.ownerName,
    this.ownerMid,
    this.duration = 0,
  });

  final String bvid;
  final int cid;
  final String title;
  final String? cover;
  final String? ownerName;
  final int? ownerMid;

  /// 视频总时长（秒），0 表示未知
  final int duration;

  /// 加入稍后再看的时间（毫秒时间戳）
  final int addTime;

  /// 同一个视频只保留一条，按 bvid 去重
  String get key => bvid;

  Map<String, dynamic> toMap() => {
    'bvid': bvid,
    'cid': cid,
    'title': title,
    'cover': cover,
    'ownerName': ownerName,
    'ownerMid': ownerMid,
    'duration': duration,
    'addTime': addTime,
  };

  static LocalLaterItem? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final bvid = raw['bvid'];
    if (bvid is! String || bvid.isEmpty) return null;
    return LocalLaterItem(
      bvid: bvid,
      cid: raw['cid'] as int? ?? 0,
      title: raw['title'] as String? ?? '',
      cover: raw['cover'] as String?,
      ownerName: raw['ownerName'] as String?,
      ownerMid: raw['ownerMid'] as int?,
      duration: raw['duration'] as int? ?? 0,
      addTime: raw['addTime'] as int? ?? 0,
    );
  }
}
