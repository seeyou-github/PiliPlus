import 'package:characters/characters.dart';
import 'package:material_ui/material_ui.dart';

/// 用用户名首字符代替网络头像的圆形占位
///
/// 供「评论区不网络加载头像」使用：省掉头像请求。
/// 背景色由用户名哈希得到（同一个名字始终同色），并按当前亮暗主题压低亮度，
/// 不会太亮刺眼；文字取主题的 `onSurface`，两种主题下都保持适中的对比度。
class LetterAvatar extends StatelessWidget {
  const LetterAvatar({
    super.key,
    required this.name,
    required this.size,
    this.fallback = '?',
  });

  /// 用户名，取第一个字符（按字素簇处理，emoji / 组合字符不会被截断）
  final String name;

  /// 头像边长
  final double size;

  /// 用户名为空时的占位字符
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isDark = colorScheme.brightness == .dark;
    final hue = (_hash(name) % 360).toDouble();
    final background = HSLColor.fromAHSL(
      1,
      hue,
      // 暗色主题下饱和度略低，避免深色底过于浓艳
      isDark ? 0.30 : 0.42,
      // 固定在中低亮度区间：浅色主题是柔和淡色，暗色主题是压低的中性深色
      isDark ? 0.30 : 0.80,
    ).toColor();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: background),
      child: Text(
        _label,
        maxLines: 1,
        textAlign: .center,
        style: TextStyle(
          // 字号跟着头像尺寸走，34 的头像约 15
          fontSize: size * 0.44,
          height: 1,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface.withValues(alpha: isDark ? 0.88 : 0.78),
        ),
      ),
    );
  }

  String get _label {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return fallback;
    return trimmed.characters.first.toUpperCase();
  }

  /// 自己算一个稳定哈希：`String.hashCode` 跨进程不保证一致，颜色会变
  static int _hash(String text) {
    var hash = 0;
    for (final unit in text.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }
}
