import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/pages/rank/zone/controller.dart';
import 'package:PiliPlus/pages/rank/zone/widget/pgc_rank_item.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ZonePage extends StatefulWidget {
  const ZonePage({super.key, this.rid, this.seasonType, this.tag});

  final int? rid;
  final int? seasonType;
  final String? tag;

  @override
  State<ZonePage> createState() => _ZonePageState();
}

class _ZonePageState extends State<ZonePage>
    with AutomaticKeepAliveClientMixin, VideoCardVGridMixin {
  late final ZoneController controller;
  late final pgcGridDelegate = Grid.videoCardHDelegate(context);

  @override
  void initState() {
    controller = Get.putOrFind(
      () => ZoneController(rid: widget.rid, seasonType: widget.seasonType),
      tag: widget.tag ?? '${widget.rid}${widget.seasonType}',
    );
    super.initState();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return refreshIndicator(
      onRefresh: controller.onRefresh,
      child: CustomScrollView(
        controller: controller.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(
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
      Loading() => gridSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: response.first is HotVideoItemModel
                    ? gridDelegate
                    : pgcGridDelegate,
                itemBuilder: (context, index) {
                  final item = response[index];
                  if (item is HotVideoItemModel) {
                    return VideoCardV(
                      videoItem: item,
                      onRemove: () => controller.loadingState
                        ..value.data!.removeAt(index)
                        ..refresh(),
                    );
                  }
                  return PgcRankItem(item: item);
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
