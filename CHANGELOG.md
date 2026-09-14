# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/).


## [Unreleased]

### Fixed

- Followup-1 landed: the wasm differential TEST gate is restored.
  `scripts/gen_tests.py` now emits each differential corpus as private chunk
  functions (≤ 3,000 cases each, ~21,000 wasm locals under debug codegen)
  and concatenates them into the public array, replacing the single
  package-level literal whose package-init function declared 125,840 wasm
  locals — 2.52x V8's hard per-function cap of 50,000 — which V8 rejected
  statically on every V8-based runtime (moonrun included). The public
  surface (`pkg.generated.mbti`, tests/diffstats entry points) is unchanged;
  case order is preserved so array position still equals the 0-based YAML
  index. Verified: `moon test --target wasm
  -p vicoproplus/moon_ua_parser/tests/differential` → 3/3, bare `moon test`
  (default wasm) → 41/41, native 55/55, js 41/41, native+wasm `--release`
  diffstats reports unchanged (all three domains 100.00%, report-section md5
  `bff7fc84866a9ad4b6ac8a79299788f9`), perf smoke pass; regeneration is
  idempotent (byte-identical). Evidence:
  `docs/evidence/wasm-differential-blocker-2026-09-13.md` §5.
- CI: the wasm test step converted back from the explicit 7-package form to
  bare `moon test` (the Linux link-core `ulimit -s unlimited` workaround is
  kept), now that the differential package no longer exceeds the V8 cap.

## [0.2.0] - 2026-09-13

Scope: this entry covers the platform-completeness (平台完备) unit of the v0.2
plan. Deliverables from the sibling v0.2 units (performance benchmarks, rules
update, framework integration) are appended here by their own plans before the
final close.

### Added

- Domain-level differential reports (diffstats) captured on all three backends
  — native, js, and wasm `--release` — with byte-identical report sections
  (LF-normalized report-section md5 `bff7fc84866a9ad4b6ac8a79299788f9`):
  browser 1601/1601, os 483/483, device 16129/16129, all 100.00%, gates MET.
  Transcripts: `docs/evidence/diffstats-native-2026-09-13.txt`,
  `docs/evidence/diffstats-js-2026-09-13.txt`,
  `docs/evidence/diffstats-wasm-2026-09-13.txt`.
- CI: a "Wasm differential gate report" step running
  `moon run --target wasm --release tests/diffstats`, so the final evidence
  line prints on the default wasm target too (`.github/workflows/ci.yml`).

### Changed

- Scope contraction, registered per the plan exit gate: the wasm test gate
  covers the 7 non-differential packages (28 tests, proven green on wasm),
  listed explicitly in CI. The differential suite's wasm TEST module is
  structurally unexecutable: under debug codegen its package-initialization
  function declares 125,840 wasm locals — 2.52x V8's hard per-function cap of
  50,000 — so V8 rejects the module statically on every V8-based runtime.
  Release codegen folds the corpus literals to 26,857 locals, which is why the
  wasm `--release` diffstats report above runs. Differential tests therefore
  remain native/js. Evidence:
  `docs/evidence/wasm-differential-blocker-2026-09-13.md`. Follow-up
  registered (rules-update domain, Followup-1): split `tests/differential`
  into multiple packages in `scripts/gen_tests.py` and regenerate, restoring
  the wasm differential test gate.
- CI: the wasm test step converted from bare `moon test` to the explicit
  7-package form `moon test -p . -p examples/middleware -p src/ua_parser
  -p src/ua_parser/rules -p tests/diffstats -p tests/robust
  -p tests/semantics`.
- README three-backend statements aligned to verified reality: the wasm test
  gate scope with the structural blocker note, and the three-target diffstats
  report replacing the native-only table.
- Deprecation migration in handwritten test files: `Show`-routed debug call
  sites migrated to `Debug` semantics, 26 deprecation warnings -> 0
  (tests/semantics 17,
  tests/robust 9, including `StringBuilder::new` -> `StringBuilder()`). The
  `derive(Show)` relied on by the frozen interface contract is kept (11
  documented residuals in `src/ua_parser/types.mbt`); the 6 generated
  residuals in `tests/differential/` are untouched (S4) and registered as
  generator-level Followup-3. Evidence:
  `docs/evidence/deprecated-2026-09-13.log`.

### Fixed

- Local wasm test runtime failure root-caused and repaired: the pinned
  moonrun 0.1.20260904 Windows build statically imports the kernel32 API
  `GetTempPath2W`, which exists only on Windows 11 / Windows Server 2022 and
  later, so on Windows 10 the loader fails with `0xc0000139`
  (STATUS_ENTRYPOINT_NOT_FOUND), moonrun cannot start (exit 127), and no wasm
  test could run. Repair: a 2-byte in-place import-table name-string patch
  `GetTempPath2W` -> `GetTempPathW` (equal-length NUL padding; same function
  signature and return semantics; file offset 0x199F64A of
  `~/.moon/bin/moonrun.exe`; md5 `9149a2da4cc29bfa2d699e603ece8b1d` ->
  `584fd4468b042e60acb434bfdf4973e8`). The upstream defect is registered as
  follow-up work: report to moonbitlang requesting a Windows 10-compatible
  build or `GetProcAddress`-style probing (the local patch is lost on moon
  reinstall/upgrade and must then be re-applied).

### Publishing

- **Published (2026-09-13):** all four packages are live on the mooncakes
  registry — `vicoproplus/moon_ua_parser` 0.2.0 plus
  `moon_ua_parser_middleware_core` / `moon_ua_parser_crescent` /
  `moon_ua_parser_mars` at 0.1.0. The formal publish ran through the GH
  Actions Linux workflow (`.github/workflows/publish-manual.yml`, run
  34762686652) because the Windows publish sandbox hits the upstream
  mizchi/x fd defect; `moon search` and the registry package pages were
  verified. Evidence: `docs/evidence/publish-final-2026-09-13.log`.
- Consumers: `moon add vicoproplus/moon_ua_parser` (and the three companion
  packages) works against the published versions.
- History: before the formal publish, the registry API returned 404 for the
  module and packaging was dry-run-verified only — `moon publish --dry-run`
  packaged a 29-file zip and the server accepted it (status 202, "Dry run
  completed successfully. No changes were made"), with a known CLI quirk
  (the moon CLI exits 127 after the server's 202). Evidence:
  `docs/evidence/publish-dryrun-2026-09-13.log`.

## [0.1.0] - 2026-09-10

Retrospective entry for the initial delivery (terminal state commit `a56a85c`).

### Added

- uap-core rule port: 1270 rules (user-agent 433 / OS 204 / device 633,
  including 65 case-insensitive device rules) from snapshot `uap-core@73e7340`,
  precompiled into MoonBit data at library initialization (fail-loud); regexes
  run on `moonbitlang/regexp` (`@0.3.5`), the only runtime dependency.
- Public parse API, four functions: `parse`, `parse_browser`, `parse_os`,
  `parse_device`; `parse(ua, with_rule_index = true)` reports the 0-based
  index of the winning rule per domain for debugging and rule attribution.
- uap-python-compatible matching semantics (alternation order, replacement
  templates, group fallbacks, catch-all "Spider" / "Other" rules), with
  uap-python (commit `6dd8c39`, vendored read-only) as the semantic authority;
  `patch_minor` comparison policy follows uap-python (upstream issue
  ua-parser/uap-core#562).
- Differential test suite covering all 18213 upstream test cases, with
  generators `scripts/gen_rules.py` and `scripts/gen_tests.py` regenerating
  `src/ua_parser/rules/` and `tests/differential/` byte-identically.
  Per-domain pass rates: browser 1601/1601 = 100.00% (gate >=99%), os
  483/483 = 100.00% (gate >=97%), device 16129/16129 = 100.00% (gate >=97%)
  — all gates MET. A three-way audit (golden fixtures x uap-python x this
  engine) confirmed field-for-field identical output on all 18213 cases;
  registered exemptions and the device empty-family skip deviation (rule 451)
  are documented in `docs/regex-migration.md`.
- Semantics expansion and robust-input test suites
  (`tests/semantics`, `tests/robust`).
- Three backends: MoonBit native, JavaScript, and WebAssembly
  (`preferred_target = "wasm"`). The differential suite runs green on native
  and js; `moon build --target wasm` succeeds.
- Middleware-style request-entry example (`examples/middleware`).
- Module metadata and README (`moon_ua_parser_lib/README.mbt.md`).
- CI workflow: pinned toolchain 0.1.20260904, static check, interface drift
  check (`moon info` + zero diff), generation consistency, and the native
  differential gate report (`.github/workflows/ci.yml`); at v0.1.0 the
  workflow had no recorded runs and its wasm test step was structurally red
  (the differential wasm module exceeded V8's local cap) — that issue was
  only diagnosed and resolved in v0.2.0.

[0.2.0]: https://github.com/vicoproplus/moon_ua_parser/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/vicoproplus/moon_ua_parser/releases/tag/v0.1.0
