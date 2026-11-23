import 'package:PiliPlus/utils/local_blacklist.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

class GlobalData {
  int imgQuality = Pref.picQuality;

  num? coins;

  void afterCoin(num coin) {
    if (coins != null) {
      coins = coins! - coin;
    }
  }

  Set<int> blackMids = Pref.blackMids;

  bool dynamicsWaterfallFlow = Pref.dynamicsWaterfallFlow;

  bool showMedal = Pref.showMedal;

  // 私有构造函数
  GlobalData._();

  // 单例实例
  static final GlobalData _instance = GlobalData._();

  // 获取全局实例
  factory GlobalData() => _instance;
}

extension IterableExt<E> on Iterable<E> {
  /// 过滤本地黑名单（UID 或昵称，昵称支持通配符）
  Iterable<E> whereNotBlocked(
    Object? /* mid */ Function(E element) test, [
    Object? /* name */ Function(E element)? name,
  ]) => where(
    (e) => !LocalBlacklist.blocked(mid: test(e), name: name?.call(e)),
  );
}
