[windows]
set shell := ["cmd.exe", "/d", "/s", "/c"]

[unix]
set shell := ["sh", "-cu"]

# 显式文件列表是 dart analyze 加载 app_lints 插件的前提
app_files := `dart run tool/list_dart_files.dart lib test`
tool_files := `dart run tool/list_dart_files.dart tool packages`

default: verify

deps:
    flutter pub get
    cd packages/app_lints && dart pub get

fmt:
    just --fmt
    dart format lib test tool packages

fmt-check:
    just --fmt --check
    dart format --output=none --set-exit-if-changed lib test tool packages

fix:
    dart fix --apply
    cd packages/app_lints && dart fix --apply
    dart format lib test tool packages

analyze: analyze-app analyze-tool

analyze-app:
    dart analyze --fatal-infos {{ app_files }}

analyze-tool:
    dart analyze --fatal-infos {{ tool_files }}

test *args:
    flutter test {{ args }}

# 本地运行：注入示例 env（bootstrap 会校验 BASE_URL，缺了直接抛）
run *args:
    flutter run --dart-define-from-file=.env.example {{ args }}

# 端到端冒烟：集成测试启动真 App，同样需要 env
e2e:
    flutter test integration_test/ --dart-define-from-file=.env.example

test-app-lints:
    cd packages/app_lints && dart test

test-readme-tree:
    dart run tool/check_readme_tree.dart

test-coverage:
    flutter test --coverage

check-coverage:
    dart run tool/check_coverage.dart coverage/lcov.info --src=lib

verify: fmt-check analyze test-app-lints test-readme-tree test-coverage check-coverage
    @echo All gates passed.

codegen *args:
    dart run build_runner build {{ args }}

codegen-reset:
    dart run build_runner clean
    dart run build_runner build

init *args:
    dart run tool/init_project.dart {{ args }}

prune *args:
    dart run tool/prune.dart {{ args }}
