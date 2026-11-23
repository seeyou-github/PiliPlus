import 'package:PiliPlus/models/local/local_follow_item.dart';
import 'package:PiliPlus/utils/local_library.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// 未登录状态下的关注 / 取关动作
///
/// 已登录时 [handle] 直接返回 false，调用方继续走原有在线逻辑；
/// 未登录时把关注关系写入本地，不发起任何网络请求。
abstract final class LocalFollowAction {
  /// 返回 true 表示已在本地处理，调用方应直接 return
  static bool handle({
    required Object? mid,
    String? name,
    String? face,
    String? sign,
    required bool isFollow,
    void Function(int attribute)? onChanged,
  }) {
    if (!LocalLibrary.isGuest) return false;
    final id = mid is int ? mid : int.tryParse('$mid');
    if (id == null || id <= 0) return false;
    if (isFollow) {
      LocalLibrary.unfollow(id);
      SmartDialog.showToast('已取消本地关注');
      onChanged?.call(0);
    } else {
      LocalLibrary.follow(
        LocalFollowItem(
          mid: id,
          name: (name?.isNotEmpty ?? false) ? name! : '$id',
          face: face,
          sign: sign,
          addTime: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      SmartDialog.showToast('已本地关注');
      onChanged?.call(1);
    }
    return true;
  }

  /// 本地关注状态对应的 attribute 值（0 未关注 / 1 已关注），未登录且已本地关注时使用
  static int localAttribute(int? mid) => LocalLibrary.isFollowing(mid) ? 1 : 0;

  /// 补全已存在条目的昵称/头像（例如先只拿到 mid 的情况）
  static void touch(int? mid, {String? name, String? face, String? sign}) {
    final item = LocalLibrary.followItemOf(mid);
    if (item == null) return;
    if (name == null && face == null && sign == null) return;
    LocalLibrary.follow(item.copyWith(name: name, face: face, sign: sign));
  }
}
