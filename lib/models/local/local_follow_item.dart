/// 本地关注项（未登录时使用）
///
/// 与在线关注完全隔离：只存本地，不调用任何关注接口。
class LocalFollowItem {
  /// UP 主 mid
  final int mid;

  /// UP 主昵称
  final String name;

  /// 头像
  final String? face;

  /// 签名（可选，UP 主页获取时才有）
  final String? sign;

  /// 关注时间（毫秒时间戳）
  final int addTime;

  const LocalFollowItem({
    required this.mid,
    required this.name,
    this.face,
    this.sign,
    required this.addTime,
  });

  LocalFollowItem copyWith({String? name, String? face, String? sign}) =>
      LocalFollowItem(
        mid: mid,
        name: name ?? this.name,
        face: face ?? this.face,
        sign: sign ?? this.sign,
        addTime: addTime,
      );

  Map<String, dynamic> toMap() => {
    'mid': mid,
    'name': name,
    'face': face,
    'sign': sign,
    'addTime': addTime,
  };

  factory LocalFollowItem.fromMap(Object? key, Object? value) {
    final map = value is Map ? value : const <String, dynamic>{};
    return LocalFollowItem(
      mid: (map['mid'] as num?)?.toInt() ?? int.tryParse('$key') ?? 0,
      name: map['name'] as String? ?? '',
      face: map['face'] as String?,
      sign: map['sign'] as String?,
      addTime: (map['addTime'] as num?)?.toInt() ?? 0,
    );
  }
}
