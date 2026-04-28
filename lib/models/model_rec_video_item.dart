import 'package:PiliPlus/models/model_owner.dart';
import 'package:PiliPlus/models/model_video.dart';

abstract class BaseRcmdVideoItemModel extends BaseVideoItemModel {
  String? goto;
  String? uri;
  String? rcmdReason;
  bool isUpowerExclusive = false;

  // app推荐专属
  int? param;
  String? pgcBadge;
}

bool isUpowerExclusiveFromJson(Map<String, dynamic> json) {
  bool isTrue(Object? value) => value == true || value == 1 || value == '1';

  bool hasBadgeText(Object? value) {
    if (value is String) {
      return value.contains('充电专属');
    }
    if (value is Map) {
      return value.values.any(hasBadgeText);
    }
    if (value is Iterable) {
      return value.any(hasBadgeText);
    }
    return false;
  }

  final chargingPay = json['charging_pay'];
  return isTrue(json['is_upower_exclusive']) ||
      isTrue(json['is_upower_exclusive_video']) ||
      (chargingPay is Map && chargingPay['level'] != null) ||
      hasBadgeText(json['badge']) ||
      hasBadgeText(json['badges']) ||
      hasBadgeText(json['badge_info']) ||
      hasBadgeText(json['badge_text']) ||
      hasBadgeText(json['cover_badge']) ||
      hasBadgeText(json['cover_left_text_3']) ||
      hasBadgeText(json['cover_right_text']) ||
      hasBadgeText(json['label']) ||
      hasBadgeText(json['styles']);
}

class RcmdVideoItemModel extends BaseRcmdVideoItemModel {
  RcmdVideoItemModel.fromJson(Map<String, dynamic> json) {
    aid = json["id"];
    bvid = json["bvid"];
    cid = json["cid"];
    goto = json["goto"];
    uri = json["uri"];
    cover = json["pic"];
    title = json["title"];
    duration = json["duration"];
    pubdate = json["pubdate"];
    owner = Owner.fromJson(json["owner"]);
    stat = Stat.fromJson(json["stat"]);
    isFollowed = json["is_followed"] == 1;
    isUpowerExclusive = isUpowerExclusiveFromJson(json);
    // rcmdReason = json["rcmd_reason"] != null
    //     ? RcmdReason.fromJson(json["rcmd_reason"])
    //     : RcmdReason(content: '');
    rcmdReason = json["rcmd_reason"]?['content'];
  }

  // @override
  // String? get desc => null;
}

// @HiveType(typeId: 2)
// class RcmdReason {
//   RcmdReason({
//     this.reasonType,
//     this.content,
//   });
// //   int? reasonType;
// //   String? content;
//
//   RcmdReason.fromJson(Map<String, dynamic> json) {
//     reasonType = json["reason_type"];
//     content = json["content"] ?? '';
//   }
// }
