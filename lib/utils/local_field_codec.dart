import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// 设置文件中少量敏感字段的本地编码工具
///
/// 只是初级防护：避免 WebDAV 地址 / 用户名 / 密码在 Hive 设置盒、
/// 「导入/导出设置」以及备份包里以明文出现，不作为真正的安全边界。
/// 解密口令以逐位掩码的形式分散保存在源码中，不会直接以明文出现。
abstract final class LocalFieldCodec {
  /// 编码结果前缀：用于区分「已编码」与历史明文
  static const _tag = 'pp1:';

  /// 口令片段：与 [_maskSeed] + i * [_maskStep] 逐位异或后还原
  static const List<int> _fragments = [
    0x22,
    0xB2,
    0x96,
    0x9E,
    0x9A,
    0x41,
    0x40,
    0x0C,
    0xE8,
    0xEB,
    0xAE,
    0x9F,
    0x66,
    0x51,
    0x51,
    0xD7,
    0x9A,
    0x9C,
    0xC4,
    0x49,
    0x12,
    0x52,
    0xBD,
    0x8D,
    0xEB,
    0xBF,
    0x6A,
    0x28,
    0x2F,
    0xA6,
    0x97,
    0xE1,
  ];

  static const int _maskSeed = 0x5B;
  static const int _maskStep = 37;

  static enc.Encrypter? _cipher;

  static enc.Encrypter get _encrypter {
    final cached = _cipher;
    if (cached != null) return cached;
    final password = String.fromCharCodes([
      for (var i = 0; i < _fragments.length; i++)
        _fragments[i] ^ ((_maskSeed + i * _maskStep) & 0xFF),
    ]);
    final key = sha256.convert(utf8.encode(password)).bytes;
    final created = enc.Encrypter(
      enc.AES(enc.Key(Uint8List.fromList(key)), mode: enc.AESMode.cbc),
    );
    _cipher = created;
    return created;
  }

  /// 是否为本工具编码过的值
  static bool isSealed(Object? value) =>
      value is String && value.startsWith(_tag);

  /// 编码明文；空值保持空串，便于沿用「未设置」语义
  static String seal(Object? plain) {
    final text = plain is String ? plain : '';
    if (text.isEmpty) return '';
    final iv = enc.IV.fromSecureRandom(16);
    final body = _encrypter.encrypt(text, iv: iv);
    final bytes = Uint8List(16 + body.bytes.length)
      ..setRange(0, 16, iv.bytes)
      ..setRange(16, 16 + body.bytes.length, body.bytes);
    return '$_tag${base64Url.encode(bytes)}';
  }

  /// 还原 [seal] 的结果
  ///
  /// 不带前缀的值按历史明文原样返回（兼容旧版本与旧备份）；
  /// 内容损坏时返回空串，避免一条坏字段让整份配置读不出来。
  static String unseal(Object? stored) {
    if (stored is! String) return '';
    if (!stored.startsWith(_tag)) return stored;
    try {
      final bytes = base64Url.decode(stored.substring(_tag.length));
      if (bytes.length <= 16) return '';
      final iv = enc.IV(Uint8List.sublistView(bytes, 0, 16));
      final body = enc.Encrypted(Uint8List.sublistView(bytes, 16));
      return _encrypter.decrypt(body, iv: iv);
    } catch (_) {
      return '';
    }
  }
}
