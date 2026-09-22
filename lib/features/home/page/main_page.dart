import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:my_app/app/routing/router.dart';
import 'package:my_app/l10n/app_localizations.dart';

/// 主框架页面——窄屏（< 800px）底部导航栏、宽屏侧边导航栏。
///
/// 标签用 [AutoTabsRouter] 管理（而非本地 `_currentIndex`），且用默认的
/// IndexedStack 版本——两条理由见 frontend/directory-structure.md「应用层」。
@RoutePage()
class MainPage extends StatelessWidget {
  const new({super.key});

  /// 三个标签对应的路由，顺序即索引
  static const List<PageRouteInfo> _tabs = [
    HomeRoute(),
    ArticleListRoute(),
    ProfileRoute(),
  ];

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      routes: _tabs,
      builder: (context, child) {
        final tabsRouter = AutoTabsRouter.of(context);
        final colorScheme = Theme.of(context).colorScheme;
        final l10n = AppLocalizations.of(context);
        final selected = tabsRouter.activeIndex;

        TextStyle labelStyle(int index) => TextStyle(
          fontWeight: selected == index ? FontWeight.w600 : FontWeight.w400,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 800) {
              // ── Wide: NavigationRail ──
              return Scaffold(
                body: Row(
                  children: [
                    NavigationRail(
                      selectedIndex: selected,
                      onDestinationSelected: tabsRouter.setActiveIndex,
                      labelType: NavigationRailLabelType.all,
                      groupAlignment: -0.9,
                      backgroundColor: colorScheme.surfaceContainerLow,
                      indicatorColor: colorScheme.secondaryContainer,
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Icon(
                          Icons.spa_outlined,
                          color: colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      destinations: [
                        NavigationRailDestination(
                          icon: Icon(
                            Icons.home_outlined,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          selectedIcon: Icon(
                            Icons.home,
                            color: colorScheme.primary,
                          ),
                          label: Text(l10n.navHome, style: labelStyle(0)),
                        ),
                        NavigationRailDestination(
                          icon: Icon(
                            Icons.article_outlined,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          selectedIcon: Icon(
                            Icons.article,
                            color: colorScheme.primary,
                          ),
                          label: Text(l10n.navArticles, style: labelStyle(1)),
                        ),
                        NavigationRailDestination(
                          icon: Icon(
                            Icons.person_outline,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          selectedIcon: Icon(
                            Icons.person,
                            color: colorScheme.primary,
                          ),
                          label: Text(l10n.navProfile, style: labelStyle(2)),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                    Expanded(child: child),
                  ],
                ),
              );
            }

            // ── Narrow: Bottom Navigation ──
            return Scaffold(
              body: child,
              bottomNavigationBar: NavigationBar(
                selectedIndex: selected,
                onDestinationSelected: tabsRouter.setActiveIndex,
                backgroundColor: colorScheme.surfaceContainerLow,
                indicatorColor: colorScheme.secondaryContainer,
                elevation: 0,
                shadowColor: Colors.transparent,
                height: 72,
                labelBehavior:
                    NavigationDestinationLabelBehavior.onlyShowSelected,
                destinations: [
                  NavigationDestination(
                    icon: Icon(
                      Icons.home_outlined,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    selectedIcon: Icon(Icons.home, color: colorScheme.primary),
                    label: l10n.navHome,
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.article_outlined,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    selectedIcon: Icon(
                      Icons.article,
                      color: colorScheme.primary,
                    ),
                    label: l10n.navArticles,
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.person_outline,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    selectedIcon: Icon(
                      Icons.person,
                      color: colorScheme.primary,
                    ),
                    label: l10n.navProfile,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
