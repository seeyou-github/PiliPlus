import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:PiliPlus/models/local/local_fav_item.dart';
import 'package:PiliPlus/models/local/local_follow_item.dart';
import 'package:PiliPlus/pages/webdav/webdav.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/local_blacklist.dart';
import 'package:PiliPlus/utils/local_library.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, listEquals, mapEquals, setEquals;

const _syncFileVersion = 1;

/// 墓碑保留时长：超过后不再参与合并，避免文件无限增长
const _tombstoneTtlMs = 180 * 24 * 60 * 60 * 1000;

/// WebDAV 跨设备同步
///
/// 同步本地关注 / 本地收藏 / 本地黑名单到 `<WebDAV 地址>/PiliPlus/Sync_Piliplus.json`，
/// 全平台共用一份数据。按条目合并：修改时间较新者生效，删除以墓碑记录传播。
abstract final class WebDavAutoSync {
  /// 冷启动后延迟同步（非精确定时）
  static const _appStartDelay = Duration(minutes: 1);

  /// 连续修改合并为一次同步
  static const _debounce = Duration(seconds: 30);

  /// 两次同步之间的最小间隔
  static const _minInterval = Duration(minutes: 5);

  /// 同步写回本地后忽略自身引发的变更事件
  static const _ignoreWindow = Duration(seconds: 2);

  static Timer? _timer;
  static bool _running = false;
  static bool _paused = false;
  static bool _applying = false;
  static bool _pendingBeforePause = false;
  static bool _scheduleAfterResume = false;
  static DateTime? _lastSyncAt;
  static DateTime? _ignoreChangesBefore;
  static int? _restoreBasis;
  static final List<StreamSubscription<dynamic>> _subs = [];

  static void init() {
    if (_subs.isNotEmpty) return;
    for (final box in [GStorage.localFollow, GStorage.localFav]) {
      _subs.add(box.watch().listen((_) => schedule()));
    }
    // 黑名单存在 localCache，其它键（WBI、弹幕过滤等）不属于同步内容
    _subs.add(
      GStorage.localCache.watch().listen((event) {
        final key = event.key;
        if (key == LocalCacheKey.blackMids || key == LocalCacheKey.blackNames) {
          schedule();
        }
      }),
    );
    // 每次冷启动后同步一次
    _timer?.cancel();
    _timer = Timer(_appStartDelay, _run);
  }

  static bool get _enabled =>
      Pref.webdavAutoSync && Pref.webdavAutoBackup && WebDav().isConfigured;

  /// 恢复备份期间暂停，避免同步与恢复写回互相覆盖
  static void pause() {
    _pendingBeforePause = _timer != null || _scheduleAfterResume;
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

  static void resume() {
    _paused = false;
    final pending = _pendingBeforePause || _scheduleAfterResume;
    _pendingBeforePause = false;
    _scheduleAfterResume = false;
    if (pending) schedule(force: true);
  }

  /// 记录恢复备份的时间基准：恢复出的旧数据在冲突时不覆盖云端较新记录
  static void markRestored(int basisMillis) {
    _restoreBasis = basisMillis;
    _scheduleAfterResume = true;
  }

  static void schedule({bool force = false}) {
    if (_paused || _applying || !_enabled) return;
    final now = DateTime.now();
    final ignoreBefore = _ignoreChangesBefore;
    if (ignoreBefore != null && now.isBefore(ignoreBefore)) return;

    var delay = _debounce;
    final last = _lastSyncAt;
    if (!force && last != null) {
      final earliest = last.add(_minInterval);
      if (earliest.isAfter(now.add(delay))) {
        delay = earliest.difference(now);
      }
    }
    _timer?.cancel();
    _timer = Timer(delay, _run);
  }

  static Future<void> _run() async {
    _timer = null;
    if (_paused || !_enabled) return;
    if (_running) {
      // 上一次同步尚未结束，稍后重试，避免丢弃这次变更
      _timer = Timer(_debounce, _run);
      return;
    }
    _running = true;
    try {
      final baseline = _SyncState.load();

      // 先拉取远端，再读取本机数据，避免下载期间的本机修改被旧快照覆盖
      final bytes = await WebDav().downloadIfExists(WebDav.syncFileName);
      if (_paused || !_enabled) return;
      final remote = bytes == null ? null : _SyncState.decode(bytes);

      final now = DateTime.now().millisecondsSinceEpoch;
      final local = _SyncState.fromLocal(
        baseline,
        now: now,
        restoreBasis: _restoreBasis,
      );
      final merged = _SyncState.merge(local, remote);
      merged.prune(now - _tombstoneTtlMs);

      if (_paused) return;
      _applying = true;
      try {
        merged.applyToLocal();
      } finally {
        _applying = false;
        _ignoreChangesBefore = DateTime.now().add(_ignoreWindow);
      }

      await merged.save();
      _restoreBasis = null;

      if (remote == null || !merged.sameAs(remote)) {
        await WebDav().uploadBackup(merged.encode(), WebDav.syncFileName);
      }
      _lastSyncAt = DateTime.now();
    } catch (e) {
      debugPrint('[WebDavAutoSync] 同步失败: $e');
    } finally {
      _running = false;
    }
  }
}

class _Record {
  const _Record({required this.updatedAt, this.deleted = false, this.data});

  /// 修改时间（毫秒时间戳）
  final int updatedAt;

  /// 墓碑：表示该条目已被删除
  final bool deleted;

  /// 关注 / 收藏的数据；黑名单没有数据
  final Map<String, dynamic>? data;

  bool sameAs(_Record other) =>
      updatedAt == other.updatedAt &&
      deleted == other.deleted &&
      mapEquals(data, other.data);

  Map<String, dynamic> toJson() => {
    'u': updatedAt,
    if (deleted) 'd': true else if (data != null) 'm': data,
  };

  static _Record? fromJson(Object? json) {
    if (json is! Map) return null;
    final updatedAt = (json['u'] as num?)?.toInt() ?? 0;
    final deleted = json['d'] == true;
    final data = json['m'];
    if (data != null && data is! Map) return null;
    return _Record(
      updatedAt: updatedAt,
      deleted: deleted,
      data: data is Map ? Map<String, dynamic>.from(data) : null,
    );
  }
}

class _SyncState {
  _SyncState({
    Map<String, _Record>? follows,
    Map<String, _Record>? favs,
    Map<String, _Record>? blackMids,
    Map<String, _Record>? blackNames,
  }) : follows = follows ?? {},
       favs = favs ?? {},
       blackMids = blackMids ?? {},
       blackNames = blackNames ?? {};

  final Map<String, _Record> follows;
  final Map<String, _Record> favs;
  final Map<String, _Record> blackMids;
  final Map<String, _Record> blackNames;

  static _SyncState? load() {
    final raw = GStorage.localCache.get(LocalCacheKey.webdavSyncState);
    if (raw is! String || raw.isEmpty) return null;
    try {
      return decode(utf8.encode(raw));
    } catch (_) {
      return null;
    }
  }

  static _SyncState decode(List<int> bytes) {
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map) {
      throw const FormatException('同步文件格式不正确');
    }
    final version = (json['version'] as num?)?.toInt() ?? 0;
    if (version != _syncFileVersion) {
      throw FormatException('同步文件版本不支持：$version');
    }
    return _SyncState(
      follows: _decodeMap(json['follows']),
      favs: _decodeMap(json['favs']),
      blackMids: _decodeMap(json['blackMids']),
      blackNames: _decodeMap(json['blackNames']),
    );
  }

  static Map<String, _Record> _decodeMap(Object? value) {
    final result = <String, _Record>{};
    if (value == null) return result;
    if (value is! Map) {
      throw const FormatException('同步文件记录格式不正确');
    }
    for (final entry in value.entries) {
      final record = _Record.fromJson(entry.value);
      if (record == null) {
        throw const FormatException('同步文件记录损坏');
      }
      result['${entry.key}'] = record;
    }
    return result;
  }

  /// 以「本地数据 + 上次同步基线」生成当前记录，识别本地新增、修改与删除
  static _SyncState fromLocal(
    _SyncState? baseline, {
    required int now,
    int? restoreBasis,
  }) {
    final state = _SyncState();

    final follows = {
      for (final item in LocalLibrary.follows) '${item.mid}': item,
    };
    for (final entry in follows.entries) {
      final map = entry.value.toMap();
      final base = baseline?.follows[entry.key];
      if (base != null && !base.deleted && mapEquals(base.data, map)) {
        state.follows[entry.key] = base;
      } else if (base != null) {
        state.follows[entry.key] = _Record(
          updatedAt: restoreBasis ?? now,
          data: map,
        );
      } else {
        state.follows[entry.key] = _Record(
          updatedAt: entry.value.addTime > 0
              ? entry.value.addTime
              : (restoreBasis ?? now),
          data: map,
        );
      }
    }
    _carryTombstones(state.follows, baseline?.follows, follows.keys, now);

    final favs = {for (final item in LocalLibrary.favs) item.key: item};
    for (final entry in favs.entries) {
      final map = entry.value.toMap();
      final base = baseline?.favs[entry.key];
      if (base != null && !base.deleted && mapEquals(base.data, map)) {
        state.favs[entry.key] = base;
      } else if (base != null) {
        state.favs[entry.key] = _Record(
          updatedAt: restoreBasis ?? now,
          data: map,
        );
      } else {
        state.favs[entry.key] = _Record(
          updatedAt: entry.value.addTime > 0
              ? entry.value.addTime
              : (restoreBasis ?? now),
          data: map,
        );
      }
    }
    _carryTombstones(state.favs, baseline?.favs, favs.keys, now);

    final mids = GlobalData().blackMids;
    for (final mid in mids) {
      final key = '$mid';
      final base = baseline?.blackMids[key];
      state.blackMids[key] = base != null && !base.deleted
          ? base
          : _Record(updatedAt: restoreBasis ?? now);
    }
    _carryTombstones(
      state.blackMids,
      baseline?.blackMids,
      mids.map((e) => '$e'),
      now,
    );

    final names = <String>{
      for (final name in LocalBlacklist.names)
        if (name.trim().isNotEmpty) name.trim(),
    };
    for (final name in names) {
      final base = baseline?.blackNames[name];
      state.blackNames[name] = base != null && !base.deleted
          ? base
          : _Record(updatedAt: restoreBasis ?? now);
    }
    _carryTombstones(state.blackNames, baseline?.blackNames, names, now);

    return state;
  }

  static void _carryTombstones(
    Map<String, _Record> target,
    Map<String, _Record>? baseline,
    Iterable<String> liveKeys,
    int now,
  ) {
    if (baseline == null) return;
    final live = liveKeys.toSet();
    for (final entry in baseline.entries) {
      if (live.contains(entry.key)) continue;
      target[entry.key] = entry.value.deleted
          ? entry.value
          : _Record(updatedAt: now, deleted: true);
    }
  }

  static _SyncState merge(_SyncState local, _SyncState? remote) {
    if (remote == null) return local;
    return _SyncState(
      follows: _mergeMap(local.follows, remote.follows),
      favs: _mergeMap(local.favs, remote.favs),
      blackMids: _mergeMap(local.blackMids, remote.blackMids),
      blackNames: _mergeMap(local.blackNames, remote.blackNames),
    );
  }

  static Map<String, _Record> _mergeMap(
    Map<String, _Record> local,
    Map<String, _Record> remote,
  ) {
    final result = Map<String, _Record>.from(remote);
    for (final entry in local.entries) {
      final other = result[entry.key];
      if (other == null || entry.value.updatedAt > other.updatedAt) {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  void prune(int cutoff) {
    _pruneMap(follows, cutoff);
    _pruneMap(favs, cutoff);
    _pruneMap(blackMids, cutoff);
    _pruneMap(blackNames, cutoff);
  }

  static void _pruneMap(Map<String, _Record> map, int cutoff) {
    map.removeWhere((_, record) => record.deleted && record.updatedAt < cutoff);
  }

  bool sameAs(_SyncState other) =>
      _sameMap(follows, other.follows) &&
      _sameMap(favs, other.favs) &&
      _sameMap(blackMids, other.blackMids) &&
      _sameMap(blackNames, other.blackNames);

  static bool _sameMap(Map<String, _Record> a, Map<String, _Record> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || !entry.value.sameAs(other)) return false;
    }
    return true;
  }

  void applyToLocal() {
    final currentFollows = {
      for (final item in LocalLibrary.follows) '${item.mid}': item,
    };
    for (final entry in follows.entries) {
      final record = entry.value;
      final current = currentFollows[entry.key];
      if (record.deleted) {
        if (current != null) LocalLibrary.unfollow(current.mid);
        continue;
      }
      final data = record.data;
      if (data == null) continue;
      if (current != null && mapEquals(current.toMap(), data)) continue;
      final item = LocalFollowItem.fromMap(entry.key, data);
      if (item.mid > 0) LocalLibrary.follow(item);
    }

    final currentFavs = {for (final item in LocalLibrary.favs) item.key: item};
    for (final entry in favs.entries) {
      final record = entry.value;
      final current = currentFavs[entry.key];
      if (record.deleted) {
        if (current != null) LocalLibrary.removeFav(current.type, current.oid);
        continue;
      }
      final data = record.data;
      if (data == null) continue;
      if (current != null && mapEquals(current.toMap(), data)) continue;
      final item = LocalFavItem.fromMap(entry.key, data);
      if (item.oid > 0) LocalLibrary.addFav(item);
    }

    final mids = <int>{};
    for (final entry in blackMids.entries) {
      if (entry.value.deleted) continue;
      final mid = int.tryParse(entry.key);
      if (mid != null && mid > 0) mids.add(mid);
    }
    if (!setEquals(mids, GlobalData().blackMids)) {
      Pref.blackMids = GlobalData().blackMids
        ..clear()
        ..addAll(mids);
    }

    final names = <String>[
      for (final entry in blackNames.entries)
        if (!entry.value.deleted) entry.key,
    ];
    if (!listEquals(names, LocalBlacklist.names)) {
      LocalBlacklist.setNames(names);
    }
  }

  String _encodeString() => jsonEncode({
    'version': _syncFileVersion,
    'savedAt': DateTime.now().millisecondsSinceEpoch,
    'follows': _encodeMap(follows),
    'favs': _encodeMap(favs),
    'blackMids': _encodeMap(blackMids),
    'blackNames': _encodeMap(blackNames),
  });

  static Map<String, dynamic> _encodeMap(Map<String, _Record> map) => {
    for (final entry in map.entries) entry.key: entry.value.toJson(),
  };

  Uint8List encode() => utf8.encoder.convert(_encodeString());

  Future<void> save() async {
    await GStorage.localCache.put(
      LocalCacheKey.webdavSyncState,
      _encodeString(),
    );
  }
}
