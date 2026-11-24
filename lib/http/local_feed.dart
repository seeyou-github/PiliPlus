import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/member.dart';
import 'package:PiliPlus/models/common/member/archive_order_type_app.dart';
import 'package:PiliPlus/models/common/member/contribute_type.dart';
import 'package:PiliPlus/models_new/member/search_archive/vlist.dart';
import 'package:PiliPlus/models_new/space/space_archive/data.dart';
import 'package:PiliPlus/models_new/space/space_archive/item.dart';

/// 本地关注投稿流的数据源。
///
/// 复用 UP 主页投稿的 App 接口，避免 Web 端 WBI 签名接口在未登录态被风控拒绝。
abstract final class LocalFeedApi {
  static Future<LoadingState<LocalFeedArchiveResult>> archives({
    required int mid,
    int? next,
  }) async {
    final res = await MemberHttp.spaceArchive(
      type: ContributeType.video,
      mid: mid,
      order: ArchiveOrderTypeApp.pubdate,
      aid: next?.toString(),
      includeCursor: next == null ? true : null,
    );
    return switch (res) {
      Success(:final response) => Success(
        LocalFeedArchiveResult(
          (response.item ?? const <SpaceArchiveItem>[])
              .map((e) => e.toVListItemModel(mid))
              .toList(),
          response.hasNext == false
              ? null
              : response.nextCursor ?? response.next,
        ),
      ),
      Error(:final errMsg, :final code) => Error(errMsg, code: code),
      Loading() => LoadingState.loading(),
    };
  }
}

class LocalFeedArchiveResult {
  const LocalFeedArchiveResult(this.items, this.next);

  final List<VListItemModel> items;
  final int? next;
}

extension _SpaceArchiveItemExt on SpaceArchiveItem {
  VListItemModel toVListItemModel(int mid) {
    final item = VListItemModel.fromJson({
      'pic': cover,
      'description': subtitle,
      'title': title,
      'created': pubdate,
      'length': length,
      'aid': int.tryParse(param ?? ''),
      'bvid': bvid,
      'play': stat.view,
      'video_review': stat.danmu,
      'mid': mid,
      'author': owner.name,
      'is_lesson_video': isPugv == true ? 1 : 0,
    });
    if (isUpowerExclusive) {
      item.badge = '充电专属';
    } else if (isCooperation == true) {
      item.badge = '合作';
    }
    return item;
  }
}
