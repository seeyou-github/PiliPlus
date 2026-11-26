import 'package:PiliPlus/common/widgets/slotted_layout_helper.dart';
import 'package:flutter/rendering.dart' show ChildLayoutHelper;
import 'package:material_ui/material_ui.dart';

enum MainType { sideBar, bottomNav, body, statusBar }

class MainLayout
    extends SlottedMultiChildRenderObjectWidget<MainType, RenderBox> {
  const MainLayout({
    super.key,
    required this.sideBar,
    required this.bottomNav,
    required this.body,
    this.statusBar,
  });

  final Widget? sideBar;
  final Widget? bottomNav;
  final Widget body;

  /// 贴在底栏上方（桌面端只占侧栏右侧内容区）的底部提示条
  final Widget? statusBar;

  @override
  Iterable<MainType> get slots => MainType.values;

  @override
  Widget? childForSlot(slot) => switch (slot) {
    .sideBar => sideBar,
    .bottomNav => bottomNav,
    .body => body,
    .statusBar => statusBar,
  };

  @override
  SlottedContainerRenderObjectMixin<MainType, RenderBox> createRenderObject(
    BuildContext context,
  ) {
    return _RenderMainLayout();
  }
}

class _RenderMainLayout extends RenderBox
    with
        SlottedContainerRenderObjectMixin<MainType, RenderBox>,
        SlottedLayoutMixin {
  RenderBox? get sideBar => childForSlot(.sideBar);
  RenderBox? get bottomNav => childForSlot(.bottomNav);
  RenderBox get body => childForSlot(.body)!;
  RenderBox? get statusBar => childForSlot(.statusBar);

  @override
  Iterable<MainType> get slots => MainType.values;

  @override
  void performLayout() {
    final constraints = this.constraints;
    size = constraints.biggest;

    final sideBar = this.sideBar;
    var sideBarWidth = 0.0;
    if (sideBar != null) {
      sideBarWidth = ChildLayoutHelper.layoutChild(
        sideBar,
        BoxConstraints.tightFor(height: constraints.maxHeight),
      ).width;
      setOffset(sideBar, .zero);
    }

    // 底栏浮在内容之上，只占窗口底部，不参与内容区高度计算
    final bottomNav = this.bottomNav;
    var bottomNavHeight = 0.0;
    if (bottomNav != null) {
      final bottomNavSize = ChildLayoutHelper.layoutChild(
        bottomNav,
        constraints.loosen(),
      );
      bottomNavHeight = bottomNavSize.height;
      setOffset(
        bottomNav,
        Offset(
          (constraints.maxWidth - bottomNavSize.width) / 2,
          constraints.maxHeight - bottomNavSize.height,
        ),
      );
    }

    final contentWidth = constraints.maxWidth - sideBarWidth;

    // 底部提示条贴在底栏上方；桌面端从侧栏右侧开始，宽度只到内容区
    final statusBar = this.statusBar;
    if (statusBar != null) {
      final statusBarSize = ChildLayoutHelper.layoutChild(
        statusBar,
        BoxConstraints.tightFor(width: contentWidth),
      );
      setOffset(
        statusBar,
        Offset(
          sideBarWidth,
          constraints.maxHeight - bottomNavHeight - statusBarSize.height,
        ),
      );
    }

    final body = this.body
      ..layout(
        BoxConstraints.tightFor(
          width: contentWidth,
          height: constraints.maxHeight,
        ),
      );
    setOffset(body, Offset(sideBarWidth, 0));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    void doPaint(RenderBox? child) {
      if (child != null) {
        context.paintChild(child, getOffset(child) + offset);
      }
    }

    doPaint(sideBar);
    doPaint(body);
    doPaint(statusBar);
    doPaint(bottomNav);
  }
}
