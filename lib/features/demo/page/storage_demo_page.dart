import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:my_app/core/theme/app_theme_extension.dart';
import 'package:my_app/di/service_locator.dart';
import 'package:my_app/features/demo/logic/storage_demo_view_model.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:signals_hooks/signals_hooks.dart';

/// 本地存储示例页：演示 `FileStorage`（应用/临时目录读写、占用统计）
/// 与 `ArticleDao`（文章缓存 + seed）的用法。
///
/// 用不到时删掉 `lib/features/demo/`、`StorageDemoRoute` 与设置里的入口。
@RoutePage()
class StorageDemoPage extends HookWidget {
  const new({super.key, this.viewModel});

  /// 可选注入点——只有测试会传值（说明见 `login_page.dart`）
  final StorageDemoViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = AppThemeExtension.of(context);
    final l10n = AppLocalizations.of(context);

    final vm = useMemoized(() => viewModel ?? getIt<StorageDemoViewModel>());
    useEffect(() {
      unawaited(vm.refresh());
      return null;
    }, []);

    final String? savedContent = useSignalValue(vm.savedContent);
    final int usageKb = useSignalValue(vm.usageKb);
    final int cachedCount = useSignalValue(vm.cachedCount);
    final bool failed = useSignalValue(vm.lastActionFailed);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.storageDemoTitle), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _Section(
            title: l10n.storageDemoFileSection,
            description: l10n.storageDemoFileDescription,
            children: [
              TextField(
                onChanged: vm.updateNote,
                decoration: InputDecoration(
                  labelText: l10n.storageDemoInputHint,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(appTheme.radiusSm),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: vm.saveNote,
                    child: Text(l10n.storageDemoSave),
                  ),
                  OutlinedButton(
                    onPressed: vm.deleteNote,
                    child: Text(l10n.storageDemoDelete),
                  ),
                  TextButton(
                    onPressed: vm.clearTemp,
                    child: Text(l10n.storageDemoClearTemp),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                l10n.storageDemoContentLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                savedContent ?? l10n.storageDemoEmptyValue,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.storageDemoUsage(usageKb),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          _Section(
            title: l10n.storageDemoDbSection,
            description: l10n.storageDemoDbDescription,
            children: [
              Text(
                l10n.storageDemoCachedCount(cachedCount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: vm.seedCache,
                    child: Text(l10n.storageDemoSeed),
                  ),
                  OutlinedButton(
                    onPressed: vm.clearCache,
                    child: Text(l10n.storageDemoClearCache),
                  ),
                ],
              ),
            ],
          ),
          if (failed)
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.storageDemoFailed,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const new({
    required this.title,
    required this.description,
    required this.children,
  });
  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = AppThemeExtension.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}
