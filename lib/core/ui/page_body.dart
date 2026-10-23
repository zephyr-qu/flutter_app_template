import 'package:flutter/material.dart';
import 'package:my_app/core/ui/breakpoints.dart';

/// 页面主体：**宽屏时把整页内容限宽居中**，窄屏原样铺满。
///
/// 页面骨架的第二层 —— `PageHead` 与正文都放在它里面，这样平板上标题与正文
/// 仍然对齐，不会出现「标题贴左边缘、正文居中」的错位。形状见
/// ui/component-guidelines.md「页面骨架」与「布局断点与响应式」。
///
/// 必须放在**有界高度**的位置（`Scaffold.body` / `Expanded`）：它按父级高度
/// 撑满，正文里的 `Expanded` 才能正常工作。
class PageBody extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 判断点用内容区实际宽度，不是屏幕宽度（侧栏 / 分屏下两者不等）
        final isWide = constraints.maxWidth > Breakpoints.expanded;
        final width = isWide
            ? Breakpoints.contentMaxWidth
            : constraints.maxWidth;

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: width, child: child),
        );
      },
    );
  }
}
