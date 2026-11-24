import 'dart:async';

import 'package:PiliPlus/models/common/rank_type.dart';
import 'package:PiliPlus/pages/common/common_controller.dart';
import 'package:PiliPlus/pages/rank/zone/controller.dart';
import 'package:PiliPlus/utils/zone_tab_utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class RankController extends GetxController
    with GetSingleTickerProviderStateMixin, ScrollOrRefreshMixin {
  RxInt tabIndex = 0.obs;
  late TabController tabController;

  /// 当前显示的分区（受「隐藏指定分区」配置影响，未配置时使用默认分区及顺序）
  late final List<RankType> types = ZoneTabUtils.visibleTypes;

  ZoneController get controller {
    final item = types[tabController.index];
    return Get.find<ZoneController>(tag: '${item.rid}${item.seasonType}');
  }

  @override
  ScrollController get scrollController => controller.scrollController;

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: types.length, vsync: this);
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }

  @override
  Future<void> onRefresh() => controller.onRefresh();

  @override
  Future<void> showRefresh() => controller.showRefresh();
}
