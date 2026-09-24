[windows]
set shell := ["cmd.exe", "/d", "/s", "/c"]

[unix]
set shell := ["sh", "-cu"]

app_file_list := if os() == 'windows' { `git ls-files --cached --others --exclude-standard -- "lib/*.dart" "lib/**/*.dart" "test/*.dart" "test/**/*.dart" ":(exclude,glob)**/*.g.dart" ":(exclude,glob)**/*.freezed.dart" ":(exclude,glob)**/*.gr.dart" ":(exclude,glob)**/*.config.dart" ":(exclude,glob)**/*.gen.dart" ":(exclude,glob)**/gen/**" ":(exclude,glob)**/*app_localizations*" | powershell.exe -NoLogo -NoProfile -Command "$input | Where-Object { Test-Path -LiteralPath $_ }"` } else { `git ls-files --cached --others --exclude-standard -- "lib/*.dart" "lib/**/*.dart" "test/*.dart" "test/**/*.dart" ":(exclude,glob)**/*.g.dart" ":(exclude,glob)**/*.freezed.dart" ":(exclude,glob)**/*.gr.dart" ":(exclude,glob)**/*.config.dart" ":(exclude,glob)**/*.gen.dart" ":(exclude,glob)**/gen/**" ":(exclude,glob)**/*app_localizations*" | while IFS= read -r file; do [ -f "$file" ] && printf '%s\n' "$file"; done` }
app_files := replace_regex(app_file_list, '\r?\n', ' ')

tool_file_list := if os() == 'windows' { `git ls-files --cached --others --exclude-standard -- "tool/*.dart" "tool/**/*.dart" "packages/*.dart" "packages/**/*.dart" ":(exclude,glob)**/*.g.dart" ":(exclude,glob)**/*.freezed.dart" ":(exclude,glob)**/*.gr.dart" ":(exclude,glob)**/*.config.dart" ":(exclude,glob)**/*.gen.dart" ":(exclude,glob)**/gen/**" ":(exclude,glob)**/*app_localizations*" | powershell.exe -NoLogo -NoProfile -Command "$input | Where-Object { Test-Path -LiteralPath $_ }"` } else { `git ls-files --cached --others --exclude-standard -- "tool/*.dart" "tool/**/*.dart" "packages/*.dart" "packages/**/*.dart" ":(exclude,glob)**/*.g.dart" ":(exclude,glob)**/*.freezed.dart" ":(exclude,glob)**/*.gr.dart" ":(exclude,glob)**/*.config.dart" ":(exclude,glob)**/*.gen.dart" ":(exclude,glob)**/gen/**" ":(exclude,glob)**/*app_localizations*" | while IFS= read -r file; do [ -f "$file" ] && printf '%s\n' "$file"; done` }
tool_files := replace_regex(tool_file_list, '\r?\n', ' ')

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

test-app-lints:
    cd packages/app_lints && dart test

verify: fmt-check analyze test-app-lints test
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
