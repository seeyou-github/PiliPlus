import 'package:material_ui/material_ui.dart';

/// 桌面端左侧栏。
///
/// 导航项（主页 / 动态 / 我的）作为一组整体垂直居中，顶部搜索区与底部设置入口
/// 以浮层形式固定，不参与导航项所在区域的布局计算，避免出现“仅首个导航项
/// 接近垂直居中”的问题。
class DesktopSideBar extends StatelessWidget {
  const DesktopSideBar({
    super.key,
    required this.width,
    required this.header,
    required this.footer,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.labelType,
    required this.indicatorShape,
  });

  /// 侧栏高度低于该值时改为常规布局，避免顶部/底部浮层与导航项重叠。
  static const double _overlayMinHeight = 520;

  /// 侧栏宽度。
  final double width;

  /// 顶部固定区域（搜索 / 消息入口）。
  final Widget header;

  /// 底部固定区域（设置入口）。
  final Widget footer;

  final List<NavigationRailDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final NavigationRailLabelType labelType;
  final ShapeBorder indicatorShape;

  NavigationRail _rail({
    double groupAlignment = 0,
    Widget? leading,
    Widget? trailing,
    bool trailingAtBottom = false,
  }) {
    return NavigationRail(
      groupAlignment: groupAlignment,
      labelType: labelType,
      indicatorShape: indicatorShape,
      backgroundColor: Colors.transparent,
      onDestinationSelected: onDestinationSelected,
      selectedIndex: selectedIndex,
      leading: leading,
      trailing: trailing,
      trailingAtBottom: trailingAtBottom,
      destinations: destinations,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight < _overlayMinHeight) {
            return _rail(
              groupAlignment: 0.5,
              leading: header,
              trailing: footer,
              trailingAtBottom: true,
            );
          }

          return Stack(
            children: [
              // NavigationRail 内部顶部自带 8px 间距，这里在底部预留同样的 8px，
              // 使导航项组的中心与侧栏的几何中心重合。
              Positioned.fill(bottom: 8, child: _rail()),
              Positioned(top: 0, left: 0, right: 0, child: header),
              Positioned(bottom: 0, left: 0, right: 0, child: footer),
            ],
          );
        },
      ),
    );
  }
}
