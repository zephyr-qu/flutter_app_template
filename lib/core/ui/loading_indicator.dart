import 'package:flutter/material.dart';

/// 统一加载指示器（零依赖，只用 SDK 自带的 [CircularProgressIndicator]）。
///
/// 想换成骨架屏 / 品牌动画就改本组件内部实现，上层页面不用动。
class LoadingIndicator extends StatelessWidget {
  const new({super.key, this.size = 40.0});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
