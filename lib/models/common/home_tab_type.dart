import 'package:PiliPlus/models/common/enum_with_label.dart';
import 'package:PiliPlus/models/common/rank_type.dart';
import 'package:PiliPlus/pages/common/common_controller.dart';
import 'package:PiliPlus/pages/hot/controller.dart';
import 'package:PiliPlus/pages/hot/view.dart';
import 'package:PiliPlus/pages/live/controller.dart';
import 'package:PiliPlus/pages/live/view.dart';
import 'package:PiliPlus/pages/pgc/controller.dart';
import 'package:PiliPlus/pages/pgc/view.dart';
import 'package:PiliPlus/pages/rank/controller.dart';
import 'package:PiliPlus/pages/rank/view.dart';
import 'package:PiliPlus/pages/rank/zone/controller.dart';
import 'package:PiliPlus/pages/rank/zone/view.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/pages/rcmd/view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum HomeTabType implements EnumWithLabel {
  live('直播'),
  rcmd('推荐'),
  hot('热门'),
  rank('分区'),
  bangumi('番剧'),
  cinema('影视'),
  rankAll('全站', rankType: RankType.all),
  rankAnime('番剧', rankType: RankType.anime),
  rankGuochuang('国创', rankType: RankType.guochuang),
  rankDouga('动画', rankType: RankType.douga),
  rankMusic('音乐', rankType: RankType.music),
  rankDance('舞蹈', rankType: RankType.dance),
  rankGame('游戏', rankType: RankType.game),
  rankKnowledge('知识', rankType: RankType.knowledge),
  rankTech('科技', rankType: RankType.tech),
  rankSports('运动', rankType: RankType.sports),
  rankCar('汽车', rankType: RankType.car),
  rankFood('美食', rankType: RankType.food),
  rankAnimal('动物', rankType: RankType.animal),
  rankKichiku('鬼畜', rankType: RankType.kichiku),
  rankFashion('时尚', rankType: RankType.fashion),
  rankEnt('娱乐', rankType: RankType.ent),
  rankCinephile('影视', rankType: RankType.cinephile),
  rankDocumentary('纪录片', rankType: RankType.documentary),
  rankMovie('电影', rankType: RankType.movie),
  rankTv('剧集', rankType: RankType.tv),
  rankVariety('综艺', rankType: RankType.variety),
  ;

  @override
  final String label;
  final RankType? rankType;
  const HomeTabType(this.label, {this.rankType});

  static const defaultTabs = [live, rcmd, hot, rank, bangumi, cinema];
  static List<HomeTabType> get selectableTabs => values;

  String get _zoneTag => 'home_rank_${rankType!.name}';

  ScrollOrRefreshMixin Function() get ctr {
    if (rankType != null) {
      return () => Get.find<ZoneController>(tag: _zoneTag);
    }
    return switch (this) {
      HomeTabType.live => Get.find<LiveController>,
      HomeTabType.rcmd => Get.find<RcmdController>,
      HomeTabType.hot => Get.find<HotController>,
      HomeTabType.rank => Get.find<RankController>,
      HomeTabType.bangumi ||
      HomeTabType.cinema => () => Get.find<PgcController>(tag: name),
      _ => throw UnimplementedError(),
    };
  }

  Widget get page {
    final rankType = this.rankType;
    if (rankType != null) {
      return ZonePage(
        rid: rankType.rid,
        seasonType: rankType.seasonType,
        tag: _zoneTag,
      );
    }
    return switch (this) {
      HomeTabType.live => const LivePage(),
      HomeTabType.rcmd => const RcmdPage(),
      HomeTabType.hot => const HotPage(),
      HomeTabType.rank => const RankPage(),
      HomeTabType.bangumi => const PgcPage(tabType: HomeTabType.bangumi),
      HomeTabType.cinema => const PgcPage(tabType: HomeTabType.cinema),
      _ => throw UnimplementedError(),
    };
  }
}
