# Journal - zs (Part 1)

> AI development session journal
> Started: 2026-07-08

---

## 2026-07-08: Bootstrap Guidelines — Completed

**Summary**: Filled all 11 spec files for the P1 Bootstrap Guidelines task.

**Backend (data layer) — 5 files**:

- `directory-structure.md` — Clean Architecture feature-first layout with layer dependency rules
- `database-guidelines.md` — SharedPreferences + FileStorage patterns (no SQLite)
- `error-handling.md` — Result<T,E> sealed class, Failure hierarchy, DioException→Failure conversion
- `logging-guidelines.md` — `logger` package facade with 4 levels, what to log/not log
- `quality-guidelines.md` — Forbidden patterns, DI annotations, code review checklist

**Frontend (UI layer) — 6 files**:

- `directory-structure.md` — Feature page organization, shared widgets
- `component-guidelines.md` — Flutter widget patterns, Theme-based styling, three-state rendering
- `hook-guidelines.md` — flutter_hooks usage (app root only), ViewModel pattern for state
- `state-management.md` — Signals + BaseViewModel pattern, async/sync/derived state categories
- `type-safety.md` — Dart sealed classes, @JsonSerializable, generated code patterns
- `quality-guidelines.md` — UI-layer forbidden patterns, code review checklist, linter rules

All specs reference real code paths and examples from the actual codebase (no aspirational/placeholder content).

---


## Session 1: P0 Scaffold Quality Audit and Fix

**Date**: 2026-07-08
**Task**: P0 Scaffold Quality Audit and Fix
**Branch**: `master`

### Summary

Completed full P0 quality audit: R1 LoginPage memory leak (Stateless→StatefulWidget), R2 ArticleDetailPage type-safe routing + body field, R3 FileStorage @Singleton annotation, R4 systematic audit (Profile Chinese template, runAsync helper, disposed guards, rename checklist), R5 spec updates for personal scaffold vision. All fixes pass flutter analyze with zero errors.

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `3032915` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 2: Dependency upgrade: signals v7 + signals_lint

**Date**: 2026-07-08
**Task**: Dependency upgrade: signals v7 + signals_lint
**Branch**: `master`

### Summary

Upgraded 59+ dependencies: signals_flutter 6→7 (Watch.builder→SignalBuilder), injectable 2→3, analyzer 10→13, flutter_gen 5.12→5.14, and many more. Added signals_lint 7.1 via analysis_server_plugin. Fixed deprecated onDispose→EffectOptions API. All flutter analyze zero issues.

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `0993b51` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 3: Extract lib/app/ layer, flatten core/ui, record architecture review

**Date**: 2026-09-21
**Task**: Architecture review follow-up — app layer + ui flattening
**Branch**: `master`

### Summary

Extracted an explicit `lib/app/` application layer (composition root) and flattened `core/presentation/` into `core/ui/`, then recorded a full architecture review (`docs/architecture-review.md`) with the current status of every finding. The review corrected one of its own conclusions: the "ViewModel needs dispose" finding was a false alarm, and the suggested fix would have introduced a runtime exception.

### Main Changes

**Structure**

- Added `lib/app/` — `app.dart`, `routing/` (router.dart, router.gr.dart, auth_reevaluate.dart), `pages/` (splash_page.dart, not_found_page.dart)
- Removed `lib/app.dart`, `lib/routing/`, `lib/core/presentation/pages/`
- Flattened `lib/core/presentation/` → `lib/core/ui/` (parallel to `core/theme/`); moved `test/core/presentation/` → `test/core/ui/`
- Global pages now use typed routing instead of string paths: `replacePath('/')` → `replaceRoute(const MainRoute())` / `const LoginRoute()`

**Tooling**

- `tool/check_boundaries.dart` — `compositionDirs` `['lib/routing/']` → `['lib/app/']`; rule 1 target changed to `lib/app/`; removed `compositionFiles`
- `tool/init_project.dart` — rewrites `lib/app/app.dart`

**Tests**

- Updated imports in 5 feature pages, 3 test files, and the boundary-checker test cases
- `test/core/ui/failure_message_test.dart` (migrated)

**Docs**

- New `docs/architecture-review.md` — P1–P7 findings with per-item status and source-level evidence
- `docs/adr/ADR-0001.md` / `ADR-0002.md` — "关联候选" now links to the review; ADR-0002 gained the dispose boundary condition
- `.trellis/spec/frontend/state-management.md` — new section "什么时候才需要 dispose（上一条的边界）"
- `README.md`, `AGENTS.md`, `docs/optional-additions.md`, and 4 spec files synced to the new paths

### Review Findings (status)

- **P1 ViewModel dispose** — **false alarm, retracted.** `signals_core` / `signals_flutter` have no `FlutterMemoryAllocations` integration (grep: 0 matches), so `leak_tracker` cannot see signals; `useSignalValue` → `SignalHookState.dispose()` unsubscribes correctly, so the VM + its signals form a collectable island. Worse, adding `vm.dispose()` would throw `SignalsWriteAfterDisposeError` (from `Signal.set`) when an in-flight response lands after the page is popped.
- **P4 boundary check is regex-based** — **partially valid.** Only conditional-import branches are a real gap; `part` and `.config.dart` are model-incompleteness that is not currently exploitable.
- **P5 runAsync lacks request de-duplication** — **resolved** prior to this session (`Expando<int> _latestCallId` + `AsyncState.dataRefreshing`).
- **P7 global page placement / string paths** — **resolved** by the `lib/app/` extraction in this session.
- **P2 / P3 / P6** — still valid, but long-term governance rather than defects.

### Git Commits

(No commits - planning session)

### Testing

- [SKIP] Cannot run in this environment — `flutter` and `dart` are not on PATH (verified with `where.exe`). Static edits only.
- Verification left to the user: `dart run tool/check_boundaries.dart`, `flutter analyze lib/ test/`, `dart analyze tool/`, `flutter test`
- `build_runner` is NOT required: `router.gr.dart` is a `part` file whose content is path-independent, and the DI config does not reference `app/` or `routing/`

### Status

[P] **Blocked** — pending local verification

### Next Steps

- Run the four verification commands above and fix any import left behind
- When conditional imports (`if (dart.library.…)`) are first used, migrate `check_boundaries.dart` to `package:analyzer`'s AST API
