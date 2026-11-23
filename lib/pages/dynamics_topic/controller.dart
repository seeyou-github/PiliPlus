import 'package:PiliPlus/http/dynamics.dart';
import 'package:PiliPlus/http/fav.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/dynamic/dyn_topic_feed/item.dart';
import 'package:PiliPlus/models_new/dynamic/dyn_topic_feed/topic_card_list.dart';
import 'package:PiliPlus/models_new/dynamic/dyn_topic_feed/topic_sort_by_conf.dart';
import 'package:PiliPlus/models/local/local_fav_item.dart';
import 'package:PiliPlus/models_new/dynamic/dyn_topic_top/top_details.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/extension/scroll_controller_ext.dart';
import 'package:PiliPlus/utils/local_fav_action.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class DynTopicController
    extends CommonListController<TopicCardList?, TopicCardItem> {
  final topicId = Get.parameters['id']!;
  String topicName = Get.parameters['name'] ?? '';

  int sortBy = 0;
  String? offset;
  final topicSortByConf = Rxn<TopicSortByConf>();

  double? appbarOffset;

  // top
  final isFav = false.obs;
  final isLike = false.obs;
  Rx<LoadingState<TopDetails?>> topState =
      LoadingState<TopDetails?>.loading().obs;

  late final isLogin = Accounts.main.isLogin;

  @override
  void onInit() {
    super.onInit();
    queryTop();
    queryData();
  }

  Future<void> queryTop() async {
    topState.value = await DynamicsHttp.topicTop(topicId: topicId);
    if (topState.value case Success(:final response)) {
      final topicItem = response!.topicItem!;
      topicName = topicItem.name;
      isFav.value = topicItem.isFav ?? false;
      isLike.value = topicItem.isLike ?? false;
      // 未登录：收藏状态以本地收藏为准
      if (!isLogin) {
        isFav.value = LocalFavAction.isFaved(
          LocalFavType.topic,
          int.tryParse(topicId),
        );
      }
    }
  }

  @override
  List<TopicCardItem>? getDataList(TopicCardList? response) {
    if (response != null) {
      offset = response.offset;
      topicSortByConf.value = response.topicSortByConf;
      sortBy = response.topicSortByConf?.showSortBy ?? 0;
      if (response.hasMore == false) {
        isEnd = true;
      }
      return response.items;
    }
    return null;
  }

  @override
  Future<void> onRefresh() {
    offset = '';
    queryTop();
    return super.onRefresh();
  }

  @override
  Future<void> onReload() {
    if (appbarOffset != null) {
      if (scrollController.hasClients &&
          scrollController.offset > appbarOffset!) {
        scrollController.jumpTo(appbarOffset!);
      }
    } else {
      scrollController.jumpToTop();
    }
    return super.onReload();
  }

  @override
  Future<LoadingState<TopicCardList?>> customGetData() =>
      DynamicsHttp.topicFeed(
        topicId: topicId,
        offset: offset,
        sortBy: sortBy,
      );

  void onSort(int sortBy) {
    this.sortBy = sortBy;
    onReload();
  }

  Future<void> onFav() async {
    if (!isLogin) {
      // 未登录：收藏到本地
      LocalFavAction.toggle(
        meta: LocalFavMeta(
          type: LocalFavType.topic,
          oid: int.tryParse(topicId) ?? 0,
          title: topicName,
        ),
        onChanged: (isFav) {
          if (this.isFav.value == isFav) return;
          final topicItem = topState.value.data?.topicItem;
          if (topicItem != null) {
            topicItem.fav += isFav ? 1 : -1;
          }
          this.isFav.value = isFav;
        },
      );
      return;
    }
    final isFav = this.isFav.value;
    final res = isFav
        ? await FavHttp.delFavTopic(topicId)
        : await FavHttp.addFavTopic(topicId);
    if (res.isSuccess) {
      if (isFav) {
        topState.value.data!.topicItem!.fav -= 1;
      } else {
        topState.value.data!.topicItem!.fav += 1;
      }
      this.isFav.toggle();
    } else {
      res.toast();
    }
  }

  Future<void> onLike() async {
    if (!isLogin) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    final isLike = this.isLike.value;
    final res = await FavHttp.likeTopic(topicId, isLike);
    if (res.isSuccess) {
      if (isLike) {
        topState.value.data!.topicItem!.like -= 1;
      } else {
        topState.value.data!.topicItem!.like += 1;
      }
      this.isLike.toggle();
    } else {
      res.toast();
    }
  }

  Future<void> topicFold() async {
    final res = await DynamicsHttp.topicFold(topicId: topicId, sortBy: sortBy);
    if (res case Success(:final response)) {
      if (response?.items case final items? when items.isNotEmpty) {
        loadingState.value.data!
          ..removeLast()
          ..addAll(items);
        loadingState.refresh();
      }
    }
  }
}
