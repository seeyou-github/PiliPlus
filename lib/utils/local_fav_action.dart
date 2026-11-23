import 'package:PiliPlus/models/local/local_fav_item.dart';
import 'package:PiliPlus/utils/local_library.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// 未登录状态下的收藏 / 取消收藏
///
/// 已登录时返回 false，调用方继续走原有在线逻辑；
/// 未登录时写入本地收藏，不发起任何网络请求。
abstract final class LocalFavAction {
  /// [fav] 为 null 时按当前状态切换，否则按指定值设置。
  /// 返回 true 表示已在本地处理。
  static bool toggle({
    required LocalFavMeta meta,
    bool? fav,
    void Function(bool isFav)? onChanged,
  }) {
    if (!LocalLibrary.isGuest) return false;
    final current = LocalLibrary.isFaved(meta.type, meta.oid);
    final target = fav ?? !current;
    if (target == current) {
      onChanged?.call(target);
      return true;
    }
    if (target) {
      LocalLibrary.addFav(meta.toItem());
      SmartDialog.showToast('已收藏到本地');
    } else {
      LocalLibrary.removeFav(meta.type, meta.oid);
      SmartDialog.showToast('已取消本地收藏');
    }
    onChanged?.call(target);
    return true;
  }

  /// 仅删除
  static bool remove(LocalFavType type, int oid) =>
      LocalLibrary.isGuest && LocalLibrary.removeFav(type, oid);

  /// 本地是否已收藏
  static bool isFaved(LocalFavType type, int? oid) =>
      LocalLibrary.isFaved(type, oid);
}
