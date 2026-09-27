# 偏好落盘失败不再静默：setter 抛 + Notifier 回滚内存

## 目标

`SharedPreferences` 的写失败目前**完全静默**，表现为「界面显示新主题、重启后回退」。本任务让写失败成为一个无法忽略的信号，并让内存快照回到与磁盘一致的状态。

## 现状（证据）

```dart
// lib/core/config/user_preferences.dart:31
Future<void> setThemeMode(ThemeMode mode) =>
    _prefs.setInt(_keyThemeMode, mode.index);   // setInt 返回 Future<bool>，被当 Future<void> 丢掉

// lib/core/config/app_settings.dart:51
Future<void> setThemeMode(ThemeMode mode) async {
  if (state.themeMode == mode) return;
  state = state.copyWith(themeMode: mode);       // ① 先改内存：UI 立刻响应
  await ref.read(userPreferencesProvider).setThemeMode(mode);   // ② 落盘；失败无人处理
}
```

调用链末端是 `lib/features/profile/page/profile_page.dart:183` 的
`await ref.read(appSettingsProvider.notifier).setThemeMode(choice);` —— 没有 try/catch、没有提示、没有回滚。

`SharedPreferences.setX` 用**返回值**表示成功（失败返回 `false`，不抛），所以现在最可能的结果是
「内存 = 新值、磁盘 = 旧值」。

## 方案（乐观更新 + 失败回滚）

保持既有的「先改内存、再落盘」（UI 立刻响应），失败时把内存改回旧值：

1. **`UserPreferences` 的 3 个 setter**：`setX` 返回 `false` 时抛 `PreferenceWriteException`（新增的小异常类型，带 key）。
2. **`AppSettingsNotifier` 的 3 个方法**：写盘前留一份 `previous` 快照；`catch` 到失败就 `state = previous` 并 `Logging.warning(...)`。就地处理，不往上传（页面没有 try/catch，抛上去只会变成未捕获异常）。

不选的两条路，理由记在这里：

- **悲观写**（先落盘、成功才改内存）：不闪，但每次点击多等一次异步 IO；且与既有约定「先改内存再落盘」冲突。
- **setter 返回 `Future<bool>`**：失败是值不是异常，接口更诚实，但要改 3 个签名 + 所有调用方判返回值，且容易再次被忽略。

## 连带项

- `test/core/ui/failure_message_test.dart`：**加**一条遍历 `FailureCode.values` 的用例（现在只有 9 个 code 的逐条断言，`values` 里其余的没有覆盖）。原有的逐条精确文案断言保留。
- 测试：`app_settings_test.dart` 补「落盘失败 → 回滚内存」用例（mock `SharedPreferences`，`setInt` 返回 `false`）；`user_preferences_test.dart` 补「`setInt` 返回 `false` → 抛 `PreferenceWriteException`」用例。
- 文档同步 3 处：
  - `backend/database-guidelines.md`：失败策略表的「写状态」行 + 那条「现状缺口」引用块 → 改成已实现；
  - `frontend/state-management.md`：「（落盘失败只记日志，见 …）」→ 回滚内存并记 warning；
  - `backend/error-handling.md`：`failure_message_test` 那句「逐条列举、不遍历 `FailureCode.values`」→ 改成已遍历。
- `app_settings.dart` 的类注释：「落盘失败只记日志」→「落盘失败回滚内存并记 warning」。

## 验收标准

- [x] `UserPreferences` 的三个 setter 在 `setX` 返回 `false` 时抛 `PreferenceWriteException`
- [x] `AppSettingsNotifier` 的三个方法在落盘失败后 `state` 回到旧快照，并记一条 warning
- [x] `failure_message_test.dart` 有一条遍历 `FailureCode.values` 断言文案非空的用例，原有逐条断言保留
- [x] 新增用例覆盖「回滚」与「抛」（`app_settings_test.dart` / `user_preferences_test.dart` 各一条）
- [x] 3 处文档 + 类注释与新行为一致（`database-guidelines.md` 表格与链路说明、`state-management.md`、`error-handling.md`、`app_settings.dart` 类注释）
- [x] `just verify` 全绿（192 passed / 1 skipped；`just analyze` 两段 No issues found）

## 风险

- **行为变化**：主题设置失败时界面会「先变、再变回」（乐观更新的固有代价）。本地 prefs 写失败极罕见。
- **不解决 UI 提示**：用户不会看到「保存失败」的提示，只是发现设置没生效。要做提示需要给 Notifier 暴露可监听的失败信号，属后续（本任务不做）。
- `SharedPreferences.setX` 返回 `false` 触发条件苛刻（平台层写失败），本任务买的是结构正确性，不是修一个已观测到的故障。
