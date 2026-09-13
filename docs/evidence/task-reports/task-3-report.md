# Task T-03 Report — 共享 helper 包 moon_ua_parser_middleware_core

Branch `feat/v02-framework-middleware`, commit `a85da1f` (`T-03: shared middleware helper package moon_ua_parser_middleware_core`, 7 files, 613 insertions).

## Rubric judgement

- **R1 pass** — `moon_ua_parser_middleware_core/` exists (moon.mod/moon.pkg/core.mbt/core_tests.mbt/pkg.generated.mbti/README.mbt.md); `moon.work` members now `["./moon_ua_parser_lib", "./moon_ua_parser_middleware_core"]` (one appended line); root `moon build --target native` → `Finished. moon: no work to do` (0 errors), root `moon check --target native` → `ran 14 tasks … (44 warnings, 0 errors)` covering both members.
- **R2 pass** — public surface is pure functions only, zero framework API / zero IO: 组装 `assemble`/`assemble_error` (consume `Result[UaInfo, UaError]`), 降级判定 `is_empty_fallback`/`degradation_reason`/`is_degraded`, 取证构造 `make_forensics`/`truncate_ua_summary`, plus `empty_ua_info` and 4 pub constants — all `pub` with `///` doc comments (see committed `pkg.generated.mbti`).
- **R3 pass** — Err branch (via `assemble_error`, wired into `assemble`'s `Err(_)` arm) and all-fallback branch both mount `empty_ua_info()` + forensics, never raising; fallback literal codified as `FALLBACK_FAMILY = "Other"` with evidence comments (engine.mbt:33-65 + uap-core goldens below); runtime-verified for all three domains by the `SomethingWeNeverKnewExisted` test.
- **R4 pass** — golden healthy cases DuckDuckGo iPhone (`golden:uap-core-tests uap-core/tests/test_ua.yaml:8955` / `test_os.yaml:3302` / `test_device.yaml:80537`, case id `'DuckDuckGo/7 Safari/605.1.15'`) and HTC Amaze 4G (`test_ua.yaml:170` / `test_os.yaml:122` / `test_device.yaml:43`) assert three-group non-empty, non-fallback families; golden partial-fallback NCSA Mosaic (`test_ua.yaml:731` / `test_os.yaml:850` / `test_device.yaml:398`) stays healthy; synthetic cases tagged `synthetic: 失败注入专用` (3 tests) assert empty result + `ua_summary` (truncated ≤64, verbatim when short) + non-empty `reason`.
- **R5 pass** — 64-char UA kept verbatim, 65-char truncated to exactly 64 (`boundary` tests), empty-string UA tested through the full degradation path (all-miss fallback → empty UaInfo + forensics with empty summary).
- **R6 pass** — package-level `moon check --target native -p moon_ua_parser_middleware_core` → `12 warnings, 0 errors`, all 12 warnings located in `moon_ua_parser_lib/**` (pre-existing `derive(Show)` baseline; grep for `middleware_core` in check output = 0 hits); package `moon test --target native` → `Total tests: 10, passed: 10, failed: 0`.
- **R7 pass** — `moon info` generated `moon_ua_parser_middleware_core/pkg.generated.mbti`, committed; `git diff --exit-code -- '*.mbti'` → exit 0, re-verified exit 0 after a fresh scoped `moon info` regeneration.
- **R8 pass** — `git status --porcelain -- moon_ua_parser_lib` empty (no tracked file modified, no new file left behind); lib test blocks counted = 31, all green in the combined run (see R9/lib regression below).
- **R9 pass** — recorded: root `moon check --target native` (after clearing my package's check cache) → `ran 14 tasks … 44 warnings, 0 errors`; root `moon build --target native` → `Finished. moon: no work to do` (workspace with 2 members fully up to date / green). Workspace full test suite NOT run (per red line).

## Verified fallback values (empirical + citations)

Library's all-miss fallback family literal for **all three domains = `"Other"`**:

- Lib source: `moon_ua_parser_lib/src/ua_parser/engine.mbt:33-42` (`other_browser`), `:48-57` (`other_os`), `:63-65` (`other_device`) — each emits `family: "Other"`, other fields `None`.
- uap-core goldens: `uap-core/tests/test_ua.yaml:1020-1021` (`SomethingWeNeverKnewExisted` → family 'Other'), `uap-core/tests/test_os.yaml:710-711` (same UA → family 'Other'), `uap-core/tests/test_device.yaml:398-399` (`NCSA_Mosaic/2.0 (Windows 3.1)` → family 'Other'; uap-core has no device catch-all — lib semantics.mbt Test 12 comment).
- Empirical: package tests assert `parse("SomethingWeNeverKnewExisted")` and `parse("")` produce browser/os/device family `"Other"` at runtime; test `partial fallback (device only) stays healthy` shows a single-domain `"Other"` (desktop UA) does NOT degrade.
- Not-fallback clarification: Googlebot device `"Spider"` is rule-produced (device rule 625, `uap-core/regexes.yaml:6217`), documented on `FALLBACK_FAMILY` so no one mistakes it for the fallback.

Degradation trigger (per brief): `browser.family == os.family == device.family == "Other"` (all three), or `Err(_)`. Mounted empty UaInfo uses `family: ""` (deliberately distinct; pinned by `empty_ua_info definition` test asserting `is_empty_fallback(empty_ua_info()) == false`).

## Public function surface (pkg.generated.mbti)

```
pub const FALLBACK_FAMILY : String = "Other"
pub const UA_SUMMARY_MAX_LENGTH : Int = 64
pub const REASON_PARSE_ERROR : String = "parse_error"
pub const REASON_EMPTY_FALLBACK : String = "empty_fallback"
pub fn assemble(String, Result[@ua_parser.UaInfo, @ua_parser.UaError]) -> MiddlewareOutcome
pub fn assemble_error(String) -> MiddlewareOutcome
pub fn degradation_reason(Result[@ua_parser.UaInfo, @ua_parser.UaError]) -> String?
pub fn empty_ua_info() -> @ua_parser.UaInfo
pub fn is_degraded(Result[@ua_parser.UaInfo, @ua_parser.UaError]) -> Bool
pub fn is_empty_fallback(@ua_parser.UaInfo) -> Bool
pub fn make_forensics(String, String) -> ForensicsRecord
pub fn truncate_ua_summary(String) -> String
pub(all) struct ForensicsRecord { ua_summary : String, reason : String } derive(Eq, Debug)
pub(all) struct MiddlewareOutcome { ua_info, degraded, forensics }   // no derive
```

## Tests and gates (commands + result tails)

All relative to worktree root; `--target native` throughout; per-call timeouts ≤ 120 s (lib suite ran as its own background command ~7 min).

- `moon check --target native -p moon_ua_parser_middleware_core` → `Finished … (12 warnings, 0 errors)`; 0 warnings in my files.
- `moon test --target native -p moon_ua_parser_middleware_core` → `Total tests: 10, passed: 10, failed: 0.`
- `moon info --target native -p moon_ua_parser_middleware_core` → mbti regenerated; `git diff --exit-code -- '*.mbti'` → 0.
- `moon check --target native` (root, both members) → `ran 14 tasks … (44 warnings, 0 errors)`.
- `moon build --target native` (root) → `Finished. moon: no work to do`.
- `cd moon_ua_parser_lib && moon test --target native` → `Total tests: 41, passed: 41, failed: 0.` (workspace mode runs all members: 31 lib test blocks + 10 helper tests; lib-only baseline 31 confirmed by `grep -rn "^test " moon_ua_parser_lib --include="*.mbt" | wc -l` = 31, and by T-01 probe log "32 total = lib 31 + hello 1").

## Files changed / file accounting

Committed (deliverables): `moon.work` (1 appended member line), `moon_ua_parser_middleware_core/{moon.mod, moon.pkg, core.mbt, core_tests.mbt, pkg.generated.mbti, README.mbt.md}`.

Scratch-deleted (never staged): 7 stray `pkg.generated.mbti` files that an initial workspace-root `moon info` run created inside `moon_ua_parser_lib/**` (examples/middleware, module root, src/ua_parser/rules, tests/differential, tests/diffstats, tests/robust, tests/semantics) — removed immediately; `git status --porcelain -- moon_ua_parser_lib` now empty. Also restored `moon_ua_parser_lib/src/ua_parser/pkg.generated.mbti` via `git checkout --` after the root `moon info` re-wrote it (no content hunks, EOL-only touch) — committed state matches HEAD of the branch before my work.

None remaining unaccounted. Commit performed twice via amend (f90f93e → a85da1f) solely to fix the R4 tag spelling (`goldens:` → `golden:uap-core-tests`); zero deletions in every staged set (checked with `git diff --cached --name-status | grep ^D` → none).

## Assumptions / design notes

- `assemble` signature takes `(ua, result)`: the original UA string is needed for `ua_summary` (the `Result` does not carry it).
- `UaError` is a read-only `pub suberror` (external construction forbidden — compiler error 4036), so the Err branch is exercised through pub `assemble_error`, which `assemble`'s `Err(_)` arm calls; documented on the function.
- `MiddlewareOutcome` carries no derive: lib `UaInfo` implements neither `Debug` nor a non-deprecated `Show`, so `derive(Debug)` on the embedding struct is impossible; tests assert field-by-field (struct `==` via `UaInfo`'s `Eq` is used). `ForensicsRecord` (String fields only) derives `Eq, Debug`.
- `moon.mod` dependency written versioned (`"vicoproplus/moon_ua_parser@0.1.0"`) exactly per T-01 probe log §1 (unversioned registry import is rejected); package import path `vicoproplus/moon_ua_parser/src/ua_parser`, used as `@ua_parser.*`.
- README.mbt.md created because `readme = "README.mbt.md"` aligns with the lib's moon.mod style (brief design decision); kept to 20 lines.
- Golden case ids: uap-core YAML cases have no numeric ids; the rubric's "用例 id" is recorded as the quoted `user_agent_string` per case.

## Self-review findings / concerns

- All 24 rubric items above judged; global constraints R10 (only `@ua_parser.parse` consumed; mbti zero diff), R14 (only my one member line appended to moon.work; ci.yml untouched), R15 (build verified immediately after member registration), R17/R18 (moon 0.1.20260904; commands relative-path) hold for my scope. R11's "落框架日志通道" is adapter-layer (later tasks); helper only constructs the record. R12/R13/R16/R19–R23/R24 are documentation/toolchain attestations or later-task items — na/pass as applicable (guide read; spec/design/plan paths exist in repo docs as cited by the controller).
- Concern 1 (minor, cross-task): running `moon info` unscoped at workspace root rewrites/creates mbti files inside `moon_ua_parser_lib/**`, which collides with R8 for any task doing so; recommend later tasks use `moon info --target native -p <pkg>` (scoped) — my mbti gate was re-verified with the scoped form.
- Concern 2 (informational): `cd moon_ua_parser_lib && moon test --target native` now reports 41 tests (workspace-wide) instead of the 31 the task text expected, because my package joined the workspace; lib's own 31 all pass (block count verified). No action needed.
- The lib's 44 `derive(Show)` deprecation warnings are baseline; my files introduce none (grep over check output: 0 hits for my package).
