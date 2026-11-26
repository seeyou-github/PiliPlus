import 'dart:convert';
import 'dart:typed_data';

import 'package:PiliPlus/models/model_owner.dart';
import 'package:PiliPlus/models/user/danmaku_rule_adapter.dart';
import 'package:PiliPlus/models/user/info.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account_adapter.dart';
import 'package:PiliPlus/utils/accounts/account_type_adapter.dart';
import 'package:PiliPlus/utils/accounts/cookie_jar_adapter.dart';
import 'package:PiliPlus/utils/filter_settings_merge.dart';
import 'package:PiliPlus/utils/local_field_codec.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/set_int_adapter.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as path;

abstract final class GStorage {
  static late final Box<UserInfoData> userInfo;
  static late final Box<dynamic> historyWord;
  static late final Box<dynamic> localCache;
  static late final Box<dynamic> setting;
  static late final Box<dynamic> video;
  static late final Box<int> watchProgress;
  static late final Box<Uint8List>? reply;

  /// 本地关注（未登录时使用），key = mid
  static late final Box<dynamic> localFollow;

  /// 本地收藏（未登录时使用），key = "type:oid"
  static late final Box<dynamic> localFav;

  /// 本地关注投稿缓存（未登录时使用）
  static late final Box<dynamic> localFeed;

  /// 本地观看记录（未登录时使用），**不参与备份 / 同步 / 导出**
  static late final Box<dynamic> localHistory;

  /// 本地稍后再看（未登录时使用），**不参与备份 / 同步 / 导出**
  static late final Box<dynamic> localLater;

  static Future<void> init() async {
    Hive.init(path.join(appSupportDirPath, 'hive'));
    regAdapter();

    await Future.wait([
      // 登录用户信息
      Hive.openBox<UserInfoData>(
        'userInfo',
        compactionStrategy: (int entries, int deletedEntries) {
          return deletedEntries > 2;
        },
      ).then((res) => userInfo = res),
      // 本地缓存
      Hive.openBox(
        'localCache',
        compactionStrategy: (int entries, int deletedEntries) {
          return deletedEntries > 4;
        },
      ).then((res) => localCache = res),
      // 设置
      Hive.openBox('setting').then((res) => setting = res),
      // 搜索历史
      Hive.openBox(
        'historyWord',
        compactionStrategy: (int entries, int deletedEntries) {
          return deletedEntries > 10;
        },
      ).then((res) => historyWord = res),
      // 视频设置
      Hive.openBox('video').then((res) => video = res),
      // 本地关注 / 本地收藏（未登录）
      Hive.openBox(
        'localFollow',
        compactionStrategy: (int entries, int deletedEntries) =>
            deletedEntries > 10,
      ).then((res) => localFollow = res),
      Hive.openBox(
        'localFav',
        compactionStrategy: (int entries, int deletedEntries) =>
            deletedEntries > 10,
      ).then((res) => localFav = res),
      // 本地关注投稿缓存（未登录）
      Hive.openBox(
        'localFeed',
        compactionStrategy: (int entries, int deletedEntries) =>
            deletedEntries > 20,
      ).then((res) => localFeed = res),
      // 本地观看记录（未登录）：只存本机，不进设置、不参与备份
      Hive.openBox(
        'localHistory',
        compactionStrategy: (int entries, int deletedEntries) =>
            deletedEntries > 10,
      ).then((res) => localHistory = res),
      // 本地稍后再看（未登录）：只存本机，不进设置、不参与备份
      Hive.openBox(
        'localLater',
        compactionStrategy: (int entries, int deletedEntries) =>
            deletedEntries > 10,
      ).then((res) => localLater = res),
      Accounts.init(),
      Hive.openBox<int>(
        'watchProgress',
        keyComparator: _intStrDescKeyComparator,
        compactionStrategy: (entries, deletedEntries) {
          return deletedEntries > 4;
        },
      ).then((res) => watchProgress = res),
    ]);

    if (Pref.saveReply) {
      reply = await Hive.openBox<Uint8List>(
        'reply',
        keyComparator: _intStrDescKeyComparator,
        compactionStrategy: (entries, deletedEntries) {
          return deletedEntries > 10;
        },
      );
    } else {
      reply = null;
    }
  }

  static String exportAllSettings() {
    return Utils.jsonEncoder.convert({
      // 窗口位置 / 最大化状态不参与导出：和设备绑定，换设备后没有意义
      setting.name: setting.toMap()
        ..remove(SettingBoxKey.windowPosition)
        ..remove(SettingBoxKey.isWindowMaximized),
      video.name: video.toMap(),
    });
  }

  static Future<void> importAllSettings(String data) =>
      importAllJsonSettings(jsonDecode(data));

  static Future<List<void>> importAllJsonSettings(
    Map<String, dynamic> map,
  ) {
    final settingData = map[setting.name];
    // 屏蔽过滤设置（标题/分区/评论/动态关键词）按并集合并，避免覆盖本机已有内容
    final mergedSetting = settingData is Map
        ? FilterSettingsMerge.mergeSettings(settingData, setting.toMap())
        : settingData;
    if (mergedSetting is Map) {
      // 窗口位置 / 最大化状态不参与导入：不把其它设备的状态写回本机配置
      mergedSetting.remove(SettingBoxKey.windowPosition);
      mergedSetting.remove(SettingBoxKey.isWindowMaximized);
      // 旧备份 / 外部导入可能带明文 WebDAV 配置，落盘前统一加密
      _sealWebDavSecrets(mergedSetting);
    }
    return Future.wait([
      setting.clear().then((_) => setting.putAll(mergedSetting)),
      video.clear().then((_) => video.putAll(map[video.name])),
    ]);
  }

  static void _sealWebDavSecrets(Map<dynamic, dynamic> settings) {
    for (final key in const [
      SettingBoxKey.webdavUri,
      SettingBoxKey.webdavUsername,
      SettingBoxKey.webdavPassword,
    ]) {
      final value = settings[key];
      if (value is String &&
          value.isNotEmpty &&
          !LocalFieldCodec.isSealed(value)) {
        settings[key] = LocalFieldCodec.seal(value);
      }
    }
  }

  static void regAdapter() {
    Hive
      ..registerAdapter(OwnerAdapter())
      ..registerAdapter(UserInfoDataAdapter())
      ..registerAdapter(LevelInfoAdapter())
      ..registerAdapter(BiliCookieJarAdapter())
      ..registerAdapter(LoginAccountAdapter())
      ..registerAdapter(AccountTypeAdapter())
      ..registerAdapter(SetIntAdapter())
      ..registerAdapter(RuleFilterAdapter());
  }

  static Future<List<void>> compact() {
    return Future.wait([
      userInfo.compact(),
      historyWord.compact(),
      localCache.compact(),
      setting.compact(),
      video.compact(),
      Accounts.account.compact(),
      watchProgress.compact(),
      ?reply?.compact(),
      localFollow.compact(),
      localFav.compact(),
      localFeed.compact(),
      localHistory.compact(),
      localLater.compact(),
    ]);
  }

  static Future<List<void>> close() {
    return Future.wait([
      userInfo.close(),
      historyWord.close(),
      localCache.close(),
      setting.close(),
      video.close(),
      Accounts.account.close(),
      watchProgress.close(),
      ?reply?.close(),
      localFollow.close(),
      localFav.close(),
      localFeed.close(),
      localHistory.close(),
      localLater.close(),
    ]);
  }

  static Future<List<void>> clear() {
    return Future.wait([
      userInfo.clear(),
      historyWord.clear(),
      localCache.clear(),
      setting.clear(),
      video.clear(),
      Accounts.clear(),
      watchProgress.clear(),
      ?reply?.clear(),
      localFollow.clear(),
      localFav.clear(),
      localFeed.clear(),
      localHistory.clear(),
      localLater.clear(),
    ]);
  }

  static int _intStrDescKeyComparator(dynamic k1, dynamic k2) {
    if (k1 is int) {
      if (k2 is int) {
        return k2.compareTo(k1);
      } else {
        return -1;
      }
    } else if (k2 is String) {
      final lenCompare = k2.length.compareTo((k1 as String).length);
      if (lenCompare == 0) {
        return k2.compareTo(k1);
      } else {
        return lenCompare;
      }
    } else {
      return 1;
    }
  }
}
