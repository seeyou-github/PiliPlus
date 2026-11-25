import 'package:PiliPlus/common/skeleton/video_card_h.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_h.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v_compact.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/pages/rank/zone/controller.dart';
import 'package:PiliPlus/pages/rank/zone/widget/pgc_rank_item.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class ZonePage extends StatefulWidget {
  const ZonePage({super.key, this.rid, this.seasonType});

  final int? rid;
  final int? seasonType;

  @override
  State<ZonePage> createState() => _ZonePageState();
}

class _ZonePageState extends State<ZonePage>
    with AutomaticKeepAliveClientMixin, VideoCardVCompactGridMixin {
  late final ZoneController controller;

  /// 移动端沿用分区页原来的横向卡片布局，桌面端保持垂直紧凑卡片
  final bool _useHCard = PlatformUtils.isMobile;

  /// PGC 排行(以及移动端分区列表)沿用原有水平卡片布局
  late final pgcGridDelegate = Grid.videoCardHDelegate();

  Widget get _pgcGridSkeleton => SliverGrid(
    gridDelegate: pgcGridDelegate,
    delegate: const SliverSingleChildDelegate(
      count: 10,
      child: VideoCardHSkeleton(),
    ),
  );

  @override
  void initState() {
    controller = Get.put(
      ZoneController(rid: widget.rid, seasonType: widget.seasonType),
      tag: '${widget.rid}${widget.seasonType}',
    );
    super.initState();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return refreshIndicator(
      key: controller.refreshKey,
      onRefresh: controller.onRefresh,
      child: CustomScrollView(
        controller: controller.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            // 横向卡片自带左右内边距
            padding: _useHCard
                ? const EdgeInsets.only(top: 7, bottom: 100)
                : const EdgeInsets.only(
                    left: Style.safeSpace,
                    top: Style.cardSpace,
                    right: Style.safeSpace,
                    bottom: 100,
                  ),
            sliver: Obx(() => _buildBody(controller.loadingState.value)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(LoadingState<List<dynamic>?> loadingState) {
    return switch (loadingState) {
      Loading() =>
        _useHCard || widget.rid == null ? _pgcGridSkeleton : gridSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: _useHCard || response.first is! HotVideoItemModel
                    ? pgcGridDelegate
                    : gridDelegate,
                itemBuilder: (context, index) {
                  final item = response[index];
                  if (item is! HotVideoItemModel) {
                    return PgcRankItem(item: item);
                  }
                  void onRemove() => controller.loadingState
                    ..value.data!.removeAt(index)
                    ..refresh();
                  return _useHCard
                      ? VideoCardH(videoItem: item, onRemove: onRemove)
                      : VideoCardVCompact(videoItem: item, onRemove: onRemove);
                },
                itemCount: response.length,
              )
            : HttpError(onReload: controller.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: controller.onReload,
      ),
    };
  }
}
