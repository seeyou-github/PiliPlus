import 'package:PiliPlus/models/common/enum_with_label.dart';

/// 本地收藏的类型（未登录时使用）
enum LocalFavType implements EnumWithLabel {
  video('视频'),
  pgc('番剧'),
  article('专栏'),
  topic('话题'),
  season('合辑'),
  favFolder('播放列表'),
  audio('音频');

  @override
  final String label;

  const LocalFavType(this.label);
}

/// 本地收藏项（未登录时使用）
///
/// 与在线收藏完全隔离：只存本地，不调用任何收藏接口。
class LocalFavItem {
  final LocalFavType type;

  /// 资源主 id：aid / epId / cvid / topicId / seasonId / mediaId / auId
  final int oid;

  /// 附加 id：如视频 cid、番剧 seasonId
  final int? subId;

  final String title;
  final String? cover;
  final String? author;

  /// 时长（秒）
  final int? duration;

  /// 收藏时间（毫秒时间戳）
  final int addTime;

  const LocalFavItem({
    required this.type,
    required this.oid,
    this.subId,
    required this.title,
    this.cover,
    this.author,
    this.duration,
    required this.addTime,
  });

  String get key => '${type.name}:$oid';

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'oid': oid,
    'subId': subId,
    'title': title,
    'cover': cover,
    'author': author,
    'duration': duration,
    'addTime': addTime,
  };

  factory LocalFavItem.fromMap(Object? key, Object? value) {
    final map = value is Map ? value : const <String, dynamic>{};
    final typeName = map['type'] as String? ?? '';
    return LocalFavItem(
      type: LocalFavType.values.firstWhere(
        (e) => e.name == typeName,
        orElse: () => LocalFavType.video,
      ),
      oid: (map['oid'] as num?)?.toInt() ?? 0,
      subId: (map['subId'] as num?)?.toInt(),
      title: map['title'] as String? ?? '',
      cover: map['cover'] as String?,
      author: map['author'] as String?,
      duration: (map['duration'] as num?)?.toInt(),
      addTime: (map['addTime'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 收藏时所需的元信息（由各页面控制器提供）
class LocalFavMeta {
  final LocalFavType type;
  final int oid;
  final int? subId;
  final String title;
  final String? cover;
  final String? author;
  final int? duration;

  const LocalFavMeta({
    required this.type,
    required this.oid,
    this.subId,
    required this.title,
    this.cover,
    this.author,
    this.duration,
  });

  LocalFavItem toItem() => LocalFavItem(
    type: type,
    oid: oid,
    subId: subId,
    title: title,
    cover: cover,
    author: author,
    duration: duration,
    addTime: DateTime.now().millisecondsSinceEpoch,
  );
}
