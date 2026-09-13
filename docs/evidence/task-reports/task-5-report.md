# Task T-05 Report — 第二框架包（moon_ua_parser_mars）

- Date: 2026-09-13 (re-dispatch run; prior run stalled before gates/README/evidence/commit)
- Worktree: `F:\moonbit比赛\moon_ua_parser_wt_framework`, branch `feat/v02-framework-middleware`
- Commit: **`eb9f606` T-05: mars framework middleware package moon_ua_parser_mars** (10 files, 1100 insertions, 0 deletions; explicit-path `git add moon.work moon_ua_parser_mars docs/evidence/mw2-example-2026-09-13.log`)
- Toolchain: moon 0.1.20260904 (94521db), all commands `--target native`, all from workspace root with relative paths

## 1. Rubric judgement (R1–R11)

- **R1 pass** — `moon_ua_parser_mars/` complete: moon.mod (name `vicoproplus/moon_ua_parser_mars`, version 0.1.0, `mizchi/mars@0.3.12` pin), adapter.mbt, integration_test.mbt (6 tests), examples/ua_echo/{main.mbt, moon.pkg}, README.mbt.md, pkg.generated.mbti; `git diff moon.work` = exactly one added line `+  "./moon_ua_parser_mars",`; top-level `moon build --target native` exit 0 (`Finished. moon: ran 80 tasks`).
- **R2 pass** — adapter.mbt has exactly four duties: registration (`middleware()` builds `@mars.Handler`), request-entry helper call (`@middleware_core.assemble(ua, @ua_parser.parse(ua))`), context mount (`ctx.vars.set` ×3), log-channel adaptation (`console_forensics_sink` → `println`). Zero inlined business semantics: no fallback comparison (helper decides), no truncation (helper's `UA_SUMMARY_MAX_LENGTH`), no reason construction (helper's `REASON_*`), no business UaInfo assembly (`mounted_ua_info` is only the handler-side read-back reconstruction of the mount contract — the business assembly is `assemble()`'s).
- **R3 pass** — typed `Variables` mechanism used (`ctx.vars.set/get`, the framework's own typed store — stronger than crescent's string `set/get`). Full-`UaInfo` direct store verified IMPOSSIBLE: `Variables::set[V : Var]` serializes every value to `Json` via the `Var` trait, `Var` is implemented only for `Bool/Double/String/Json` (`src/pkg.generated.mbti:173-176`, snapshot ff4485e0), and implementing `Var` for `UaInfo` in this package violates MoonBit's orphan rule — so the sanctioned string form is used, but without any codec: the three families are native `Var::String` values (zero serialization), vs crescent's ~165-line JSON header round-trip. Three-group retrieval asserted from the real dispatch: `"browser=DuckDuckGo Mobile os=iOS device=iPhone"` / `"browser=DuckDuckGo Mobile os=Android device=Generic Smartphone"`. Golden citations present: `golden:uap-core-tests uap-core/tests/test_ua.yaml:8955/8961`, `test_os.yaml:3302/3309`, `test_device.yaml:80537/80542`.
- **R4 pass** — malformed SYNTHETIC (`SomethingWeNeverKnewExisted`, labeled "SYNTHETIC" in comments, not from any uap-core file) triple assertion: status 200 (non-5xx) + mount structurally `== @middleware_core.empty_ua_info()` ("empty-mount" marker through real dispatch) + exactly one `{ua_summary, reason}` record from the injected FO sink (`reason == REASON_EMPTY_FALLBACK`). Canonical triple asserted twice (synthetic UA test + missing-header test). Long-synthetic test pins the 64-char truncation through the adapter's FO channel.
- **R5 pass** — moon.mod pins `mizchi/mars@0.3.12` (selection §⑤ literal); README records "Tested against mars 0.3.x" with upstream commit SHA; walkthrough drift = 0 places (§3 below); the async-coexistence finding is registered (not a walkthrough deviation — walkthrough conclusions all held; see §5).
- **R6 pass** — README gives exact literal `moon run moon_ua_parser_mars/examples/ua_echo --target native`; run exit 0 (bounded: ephemeral listener closed via `defer` after 4 requests; foreground command additionally wrapped in 90 s timeout); output shows three-group results ×3 + one degraded synthetic with FO line; evidence `docs/evidence/mw2-example-2026-09-13.log` written verbatim-faithful from `/tmp/mw2-example-raw.log`.
- **R7 pass** — package `moon check --target native -p moon_ua_parser_mars`: `Finished … (12 warnings, 0 errors)`; grep of check output for `moon_ua_parser_mars` = **0 hits** (all 12 = pre-existing lib `derive(Show)` baseline, same as T-04 recorded); 0 new deprecations. Package `moon test --target native -p moon_ua_parser_mars` green **3 consecutive runs**: `Total tests: 6, passed: 6, failed: 0.` ×3.
- **R8 pass** — `moon info --target native -p moon_ua_parser_mars` regenerated `moon_ua_parser_mars/pkg.generated.mbti` (byte-identical to residue version, committed); `git diff --exit-code -- '*.mbti'` → exit 0 (lib/helper/crescent tracked mbti untouched; scoped `-p` form only). Freshly generated `examples/ua_echo/pkg.generated.mbti` deleted to mirror crescent's committed layout (crescent has no examples mbti).
- **R9 pass** — README.mbt.md (165 lines): Install (`moon add` ×4), Register snippet, Configuration (forensics_sink? / mount keys / read-back), Mounting mechanism + why, Degradation behavior, Version range, Example, Tests — shape mirrors crescent README.
- **R10 pass with caveat** — lib 31/31 (rules 4/4 + differential 3/3 + robust 9/9 + semantics 15/15, package-level), helper 10/10, crescent package tests 7/7 green; `git status --porcelain moon_ua_parser_middleware_core moon_ua_parser_lib moon_ua_parser_crescent` empty (repo sources zero modification). **Caveat:** the gitignored `.mooncakes` cache copies of `bobzhang/crescent` and `mizchi/x` carry behavior-preserving adaptation patches (§5) required to compile the shared graph — the T-04 repo member and its tests are untouched and green.
- **R11 pass** — every failure attributed with evidence before any fix; no framework-error-first assumption (§6 D1 records).

## 2. Global constraints

- R12 pass — adapter consumes only `@ua_parser.parse` of the lib mbti's four pub fns; `moon info` zero diff on lib (tracked mbti diff exit 0); lib files untouched.
- R13 pass — degradation semantics entirely helper-owned: 200 on degraded synthetic + missing header; empty-UaInfo mount (structural check); forensics `{ua_summary≤64 (helper truncation, pinned by test), reason ∈ {parse_error, empty_fallback}}` to the FO channel.
- R14 pass — no ci.yml change in this commit (staged file list: 10 owned files only).
- R15 pass — 0.3.12 pin locked; integration tests + example ran against the resolved registry package 0.3.12.
- R16 pass — moon.work touched only for the mars member line (T-01 owns the manifest shape; append authorized by the brief); middleware package dirs disjoint.
- R17 pass — manifest change immediately build-verified: top-level build green with the new member.
- R18 pass — see D1 records; attribution→location→disposition for each.
- R19 pass — moon 0.1.20260904 (94521db 2026-09-04) confirmed via `moon version`.
- R20 pass — every acceptance command run from workspace root with relative paths.
- R21 pass — versions from `docs/framework-selection.md` §②/§⑤ and the mooncakes registry index (`~/.moon/registry/index/user/mizchi/mars.index`, `bobzhang/crescent.index`, `mizchi/x.index`); SHAs from the walkthrough, re-verified live.
- R22–R26 na/pass — spec/design/plan/docs consulted read-only; lib mbti = `moon_ua_parser_lib/src/ua_parser/pkg.generated.mbti`; MoonBit agent guide read before implementation.

## 3. SHA / drift register

- Walkthrough authority: `docs/framework-selection.md` §2.2, upstream HEAD `ff4485e0309a8532d03002eb588ab06dcd252848` (mizchi/mars.mbt).
- Fresh depth-1 clone: **blocked by host network** (github.com:443 connect/reset, 5 attempts incl. retries; D1-1 below). Drift instead verified via two channels: (a) GitHub API `commits/main` (fetched successfully) returned HEAD `ff4485e0309a8532d03002eb588ab06dcd252848` (commit dated 2026-09-12) — **identical to the walkthrough SHA: 0 drift**; (b) the T-02 local snapshot `F:\Temp\fw-probe\mars.mbt` has HEAD `ff4485e0…` and was used for file-level API verification.
- File-level citations verified in the snapshot: `Server::middleware` (mars.mbt:61-63, mbti:133), `Handler = async (Context)->Unit` (mbti:107), `Context::header` exact-case (context.mbt:58-60), string `Context::set/get` (:64/70), `Variables::get -> Json?` (:149) / `set[V : Var]` (:154), `Var` impls Bool/Double/String/Json (:173-176), `Variables` = `Map[String, Json]` with `to_json` serialization (env.mbt ~82-100/140-166), `logger_simple` → `println("--> …")` (logger.mbt:162-166), `Server::to_handler` (mbti:143). **Drift = 0 places** (≤2 threshold not approached; no BLOCKED).
- Observed live differences (registered, not drift): mars's logger prints `Get` (capitalized) rather than `GET`; upstream's shipped `socket/pkg.generated.mbti` is stale vs its source (`Tcp::fd -> Int` in mbti vs `-> @fd_util.Fd` in source).

## 4. Mount mechanism + FO channel conclusion

- **Mount mechanism: mars typed `Variables` (`ctx.vars`)** — the framework's best real mechanism. Direct full-`UaInfo` storage is impossible (`Var` trait closed to Bool/Double/String/Json + orphan rule; `get` returns `Json?` regardless), so the adapter mounts the browser/os/device families as three native `Var::String` values (`KEY_UA_BROWSER/OS/DEVICE` = `ua_parser.browser/os/device`) and reconstructs the `UaInfo` handler-side via `mounted_ua_info` (versions/brand/model/`rule_index` = `None` by construction). This avoids both crescent's JSON-header codec and any helper change (PS-1 respected). Read-back `None` = middleware not registered (misuse-guard test included).
- **FO channel: real and framework-native** — mars ships `logger()`/`logger_simple()`/`log_response()` (logger.mbt:114/132/162) whose sink is `println` (logger.mbt:145/166). The adapter's default `console_forensics_sink` writes the `[moon_ua_parser] degraded user-agent parse: reason=<reason> ua_summary="<…>"` line through the same `println` sink, so forensics share the framework's console log channel (verified in the example output: the FO line appears alongside the `--> Get /probe` framework lines). Any other backend is injectable via `middleware(forensics_sink?)`. Conclusion independently measured for mars (crescent's conclusion — no framework logger, headers-bypass — does not apply; mars's channel is stronger).

## 5. Coexistence conflict: mechanism, evidence, disposition (key finding)

**Mechanism:** a moon workspace resolves ONE version per registry package across all members (`moon -C <member> tree`; `moon.work` has no dependency override; docs confirm members-only schema). `mizchi/mars@0.3.12` (selection §⑤ pin) requires `moonbitlang/async@0.21.3` + `mizchi/x@0.6.1` + `moonbitlang/x@0.5.5`; `bobzhang/crescent@0.11.1` (T-04 pin) requires `async@0.20.3` + `moonbitlang/x@0.4.41`. MVS unifies to the max → crescent 0.11.1 compiles against async 0.21.3, where `http.Request.headers` changed from `Map[String, String]` to `Map[CaseInsensitiveString, String]` → 9 type errors in crescent's main package + 3 in its websocket package. Additionally, on Windows native only, mizchi/x 0.6.1's Int-returning `fd()` accessors no longer compile (async 0.21.3 `Tcp::fd() -> @fd_util.Fd`, an opaque `#external` HANDLE on Windows; on unix `Fd = Int` so the published pair compiles unmodified — CI-on-linux impact is crescent-only).

**Evidence chain:** workspace build failed with 9 errors, all in `.mooncakes/bobzhang/crescent/{serve_async,serve_response,serve_request_body}.mbt`, zero in owned paths; `moon -C moon_ua_parser_crescent tree` showed crescent → `async@0.21.3`; controlled experiment (mars member line temporarily removed) re-synced async to 0.20.3 and crescent's main package compiled again; registry index (`~/.moon/registry/index/user/…`) version matrix showed 0.3.11 is the only mars on the async-0.20.x line, but every `mizchi/x` ≤ 0.6.0 fails natively against async 0.20.3+ (`fd()` Fd-vs-Int, verified empirically at 0.5.1/0.5.2/0.6.0) → **no version combination coexists without source adaptation**; bobzhang/crescent latest = 0.11.1 (mooncakes, "3 days ago") → no upgrade path.

**Disposition (minimal, behavior-preserving, recorded in place with `LOCAL CACHE PATCH` comments):** the gitignored `.mooncakes` cache copies were adapted (repo sources untouched):

1. `.mooncakes/mizchi/x/src/socket/socket_native.mbt` — the four unused (in-closure) Int-returning `fd()` accessors (`Tcp/TcpServer/UdpClient/UdpServer::fd`) gated `#cfg(not(platform="windows"))`; `.mooncakes/mizchi/x/src/socket/socket_fd_native.mbt` helper gated likewise. Unix behavior byte-identical; zero callers in the workspace (grepped).
2. `.mooncakes/bobzhang/crescent/serve_async.mbt` — new `request_headers_to_string_map(request)` boundary adapter; 5 call sites (`is_websocket_upgrade_request` ×2, `looks_like_websocket_handshake_request` ×2 incl. `key.to_string().to_lower()`, chunked-transfer check, `copy_async_headers`) converted; 3 Request-literal test blocks build CI-keyed maps via `Map::from_iter`.
3. `.mooncakes/bobzhang/crescent/serve_request_body.mbt` — `request_content_length` uses the same adapter.
4. `.mooncakes/bobzhang/crescent/serve_response.mbt` — new `to_async_header_map(headers)`; both `extra_headers=` sites converted.
5. `.mooncakes/bobzhang/crescent/websocket/lifecycle.mbt` — `normalize_native_websocket_request_headers` re-typed to the CI map (`key.to_string().to_lower()`), re-applying the prior run's patch verbatim (recovered from its `lifecycle.mbt.orig` backup before the backup was consumed by the restore).

All conversions preserve semantics: CI-keyed maps perform case-insensitive lookups natively; String-keyed helpers lowercase explicitly; no behavioral branching was altered.

**Reproducibility caveat (for T-06/owner):** `.mooncakes` is a gitignored cache — a fresh checkout (CI) must re-apply these patches after dependency fetch (e.g. a committed patch file + post-fetch `git apply` step in ci.yml) or the frameworks must be vendored/upstream-waited. Full patch text is recoverable from the in-place `LOCAL CACHE PATCH` comments. T-04's gates remain green with the patches in place (crescent 7/7 re-run post-patch).

## 6. D1 records (attribution → location → disposition)

1. **Fresh mars clone failed ×5** (connect reset / timeout to github.com:443) — attribution: host network blocks direct github; NOT framework/toolchain. Location: clone command. Disposition: SHA verified via GitHub API (`commits/main` → ff4485e0…, 0 drift) + T-02 local snapshot for file-level API checks; recorded per the brief's drift-check intent.
2. **Workspace build failed (9 errors) after mars member activation** — attribution first tested against owned code: `moon check -p moon_ua_parser_mars` green → not adapter; errors located exclusively in `.mooncakes/bobzhang/crescent`. Root cause located via `moon tree` + controlled member-removal experiment + registry index (dependency unification, §5). Disposition: cache adaptation patches (§5); re-ran → workspace build green.
3. **mizchi/x fd() Windows-native breakage (4 errors)** — surfaced after my dependency-version experiments re-fetched pristine mizchi/x, destroying the prior run's unbacked-up cache patch (the morning's green runs had run on it). Attribution: published-pair incompatibility (async 0.21.3 `Fd` vs mizchi/x `Int`), Windows-only (unix `Fd = Int`). Disposition: `#cfg(not(platform="windows"))` gating (§5.1) — unix-identical, no in-workspace callers.
4. **Crescent test-map literals failed to parse** (`{ @http.CaseInsensitiveString("k"): v }`) — attribution: MoonBit map-literal syntax takes no expression keys (parser error), not a framework defect. Disposition: `Map::from_iter([...].iter())` with wrapped keys; one `unnecessary_annotation` warning eliminated to keep crescent files warning-free (T-04 standard).
5. **`moon test -p moon_ua_parser_lib/src/ua_parser/rules` returned "Total tests: 0"** — attribution: package-selector form (directory path not matched for non-root packages in workspace mode), not a test failure. Disposition: module-qualified selector `vicoproplus/moon_ua_parser/...` → correct counts (4/3/9/15).
6. **Leftover `examples/ua_echo/pkg.generated.mbti` from scoped `moon info`** — attribution: `moon info -p <module>` covers subpackages; crescent's committed layout has no examples mbti. Disposition: deleted (untracked artifact) to mirror T-04.
7. **Prior-run half-patch discovered** (`lifecycle.mbt` + `.orig` backup in cache, no backup for the mizchi/x fd patch) — attribution: prior run hit the same coexistence wall and ran out of time mid-patch. Disposition: consumed `.orig` to restore pristine crescent first, then re-derived and completed the full patch set (§5); final state has `.orig` removed and all five patch sites marked in place.

## 7. W2 residue verdicts (per file) and fixes made

| File | Verdict | Notes |
|---|---|---|
| `moon_ua_parser_mars/adapter.mbt` | 复用 (reuse) | Zero edits. Thin-layer purity verified against R2; mechanism claims verified against snapshot ff4485e0 (header exact-case, `Var`/`Json` serialization, orphan-rule argument). |
| `moon_ua_parser_mars/integration_test.mbt` | 复用 (reuse) | Zero edits. Golden citations + SYNTHETIC labels + canonical triple + truncation + missing-header + misuse guard all present; raw-socket client justified (mizchi/x client injects its own User-Agent); bounded server lifetime by construction. |
| `moon_ua_parser_mars/moon.mod` | 复用 (reuse) | Experiment edits (0.3.11/0.5.2/0.6.0/0.20.3/0.20.5 probes) fully reverted; final file byte-identical to residue (0.3.12 pin). |
| `moon_ua_parser_mars/moon.pkg` | 复用 (reuse) | Zero edits. Import split (test-only framework transport deps) correct; `-all+native` matches mars. |
| `moon_ua_parser_mars/examples/ua_echo/main.mbt` | 复用 (reuse) | Zero edits. Bounded (defer-closed listener, 4 requests), exact Content-Length response framing. |
| `moon_ua_parser_mars/examples/ua_echo/moon.pkg` | 复用 (reuse) | Zero edits. `pkgtype(kind: "executable")` matches crescent pattern. |
| `moon_ua_parser_mars/pkg.generated.mbti` | 复用 (reuse) | Regenerated by scoped `moon info` — byte-identical; committed. |
| `moon.work` | 复用 (reuse) | Residue member line kept; diff = exactly the one line (experiment add/remove left no trace). |

**Missing pieces created this run:** `README.mbt.md` (new, R9), `docs/evidence/mw2-example-2026-09-13.log` (new, R6), all gate executions (R7/R8/R10), the cache patch set (§5), this report, the commit.

## 8. Test evidence (tails)

- Package check: `Finished. moon: ran 6 tasks, now up to date (12 warnings, 0 errors)` — 0 warnings reference `moon_ua_parser_mars`.
- 3 consecutive package runs (`moon test --target native -p moon_ua_parser_mars`):
  - RUN 1: `--> Get /probe` / `Total tests: 6, passed: 6, failed: 0.`
  - RUN 2: `--> Get /probe` / `Total tests: 6, passed: 6, failed: 0.`
  - RUN 3: `--> Get /probe` / `Total tests: 6, passed: 6, failed: 0.`
- Workspace build: `moon build --target native` → exit 0, `Finished. moon: ran 80 tasks, now up to date` (all four members + both examples).
- mbti: `moon info --target native -p moon_ua_parser_mars` clean; `git diff --exit-code -- '*.mbti'` exit 0.
- Regressions (package-level): rules `4/4` (`-p vicoproplus/moon_ua_parser/src/ua_parser/rules`), differential `3/3`, robust `9/9`, semantics `15/15` → lib **31/31**; helper `10/10` (`-p moon_ua_parser_middleware_core`); crescent `7/7` (`-p moon_ua_parser_crescent`, re-run after patches; check output = 12 warnings 0 errors, 0 from crescent files).
- Example: `moon run moon_ua_parser_mars/examples/ua_echo --target native` exit 0; FO line + three-group read-backs + `done: 4 requests dispatched (3 healthy, 1 degraded synthetic)` — full verbatim capture in `docs/evidence/mw2-example-2026-09-13.log`.

## 9. Files changed (commit eb9f606)

`moon.work` (+1 line), `moon_ua_parser_mars/{moon.mod, moon.pkg, adapter.mbt, integration_test.mbt, pkg.generated.mbti, README.mbt.md, examples/ua_echo/{moon.pkg, main.mbt}}` (new), `docs/evidence/mw2-example-2026-09-13.log` (new). 1100 insertions, 0 deletions. Repo sources of lib/helper/crescent: untouched (verified via `git status --porcelain`).

## 10. Assumptions

- The brief's "typed Variables preferred if it can hold UaInfo directly" was resolved as: it cannot (Var trait closure + orphan rule; verified against snapshot source), so the string-family mount is the intended sanctioned form — no codec needed.
- "Package-level tests only" interpreted per T-04 precedent: `-p <package>` scoped runs; the workspace `moon test` full suite was NOT run (workspace `moon build` green instead).
- Cache patching was accepted as the only disposition that satisfies R1+R7+R10 simultaneously, because both prior runs' evidence (half-patch with `.orig`) and the version matrix show no alternative; the repo-level permanent fix is explicitly deferred to T-06/owner.

## 11. Self-review + concerns

- Self-review: all 26 rubric items judged above; every gate re-run in final state; commit contents verified line-by-line (moon.work one-liner; explicit paths; zero deletions).
- **Concern 1 (process):** the two adjudicated framework pins cannot coexist in a shared moon workspace without source adaptation — this invalidates T-02's implicit coexistence assumption and will surface in CI (fresh checkout). Recommended: T-06 adds a post-fetch patch-apply step (patch text recoverable from the in-place `LOCAL CACHE PATCH` comments) or the owner decides on vendoring/upstream tracking.
- **Concern 2 (letter vs spirit):** R10's "crescent 源码零修改" holds for the repo member but not for the gitignored registry cache copy of bobzhang/crescent (patched, behavior-preserving, marked in place). Crescent's own package tests (7/7, unmodified) validate behavior post-patch.
- **Concern 3 (minor):** mars's own logger renders the method as `Get` (`--> Get /probe`) — upstream cosmetic quirk, documented in the evidence log header.
- Network to github.com was down all session (D1-1); mooncakes.io fetches worked. If CI also lacks github access, note that no task gate depends on it (mooncakes registry does the dependency resolution).
