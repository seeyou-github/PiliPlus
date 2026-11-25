import 'package:material_ui/material_ui.dart';

/// 桌面端左侧栏。
///
/// 导航项（主页 / 动态 / 我的）作为一组整体垂直居中，顶部搜索区与底部设置入口
/// 以浮层形式固定，不参与导航项所在区域的布局计算，避免出现“仅首个导航项
/// 接近垂直居中”的问题。
///
/// 导航项复用 NavigationDrawer 的选中指示器，保持与改动前一致的圆角矩形按钮
/// 样式；显示文字时通过自定义 destination 把文字放到图标下方，不改变侧栏宽度。
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

  /// NavigationDrawer 单项高度：tileHeight 56 + 上下 tilePadding 各 5。
  static const double _itemHeight = 66;

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

  /// 复用 NavigationDrawer 的选中指示器，恢复改动前的圆角矩形按钮样式。
  Widget _drawer(BuildContext context) {
    return DrawerTheme(
      data: DrawerThemeData(width: width),
      child: NavigationDrawer(
        backgroundColor: Colors.transparent,
        onDestinationSelected: onDestinationSelected,
        selectedIndex: selectedIndex,
        tilePadding: const .symmetric(vertical: 5, horizontal: 12),
        indicatorShape: indicatorShape,
        children: destinations.map((destination) {
          // NavigationDrawerDestination 内部固定为 16 + icon + 12 + label，
          // 用 4px 的空 label 抵消左侧 16px 偏移，使内容在导航项内居中。
          return NavigationDrawerDestination(
            icon: _destinationContent(context, destination, selected: false),
            selectedIcon: _destinationContent(
              context,
              destination,
              selected: true,
            ),
            label: const SizedBox(width: 4),
          );
        }).toList(),
      ),
    );
  }

  Widget _destinationContent(
    BuildContext context,
    NavigationRailDestination destination, {
    required bool selected,
  }) {
    final colorScheme = ColorScheme.of(context);
    final icon = IconTheme(
      data: IconThemeData(
        color: selected
            ? colorScheme.onSecondaryContainer
            : colorScheme.onSurfaceVariant,
      ),
      child: selected
          ? destination.selectedIcon ?? destination.icon
          : destination.icon,
    );

    if (labelType == .none) {
      return icon;
    }

    return Column(
      mainAxisSize: .min,
      children: [
        icon,
        const SizedBox(height: 2),
        DefaultTextStyle(
          style:
              (Theme.of(context).textTheme.labelMedium ??
                      const TextStyle(fontSize: 12))
                  .copyWith(color: colorScheme.onSurface),
          child: destination.label,
        ),
      ],
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
              // 导航项组高度固定为单项高度之和，居中后与侧栏几何中心重合。
              Positioned.fill(
                bottom: 8,
                child: Center(
                  child: SizedBox(
                    height: destinations.length * _itemHeight,
                    child: _drawer(context),
                  ),
                ),
              ),
              Positioned(top: 0, left: 0, right: 0, child: header),
              Positioned(bottom: 0, left: 0, right: 0, child: footer),
            ],
          );
        },
      ),
    );
  }
}
