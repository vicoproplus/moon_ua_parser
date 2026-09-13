# Task T-04 Report — 首个框架中间件包（moon_ua_parser_crescent）

Date: 2026-09-13 · Branch: feat/v02-framework-middleware · Commit: **065cf07** (`T-04: crescent framework middleware package moon_ua_parser_crescent`, 10 files, +910)
Re-dispatch run: W2 residue check + missing verifications + commit. No branch switch; all commands `--target native`, Bash timeouts ≤ 120 s.

## 1. Rubric judgement (R1–R11)

- **R1 pass** — `moon_ua_parser_crescent/` complete (moon.mod name `vicoproplus/moon_ua_parser_crescent` v0.1.0, adapter.mbt, integration_test.mbt, examples/ua_echo/, README.mbt.md); `moon.work` has `./moon_ua_parser_crescent` member; workspace `moon build --target native` exit 0.
- **R2 pass** — adapter.mbt does exactly the four duties; assembly/degradation/forensics only via `@middleware_core.assemble/assemble_error/empty_ua_info/make_forensics` (grep: adapter's only lib call is `@ua_parser.parse`; mount + JSON transport are mechanical field copying).
- **R3 pass** — integration tests assert three-group results for two golden UAs with citations `golden:uap-core-tests uap-core/tests/test_ua.yaml:8955|8961`, `test_os.yaml:3302|3309`, `test_device.yaml:80537|80542`; all six cited lines verified verbatim in `uap-core/tests/*.yaml` (UA string + expected family on the cited line).
- **R4 pass** — malformed synthetic UA (`SomethingWeNeverKnewExisted`, labeled SYNTHETIC in file header and const comments): asserts ①status 200 ②mount == `@middleware_core.empty_ua_info()` (empty families in headers + typed round-trip) ③exactly one `{ua_summary, reason}` record retrievable from injected sink; FO channel measured **可用** (tests capture records; example's default console sink emits a retrievable `[moon_ua_parser]` line — evidence log line "[moon_ua_parser] degraded user-agent parse: reason=empty_fallback …"); fallback alternative: inject any backend via `forensics_sink`, and with no sink wired the empty mount stays the observable evidence (README §Degradation).
- **R5 pass** — moon.mod pins `bobzhang/crescent@0.11.1`; README §Version range: "Tested against crescent 0.11.x" + SHA + moon/async pins; deviations from walkthrough registered = 2, both already noted by walkthrough §73 itself, ≤2 threshold respected (see §3).
- **R6 pass** — README gives exact literal `moon run moon_ua_parser_crescent/examples/ua_echo --target native`; run exit 0, output contains browser/os/device three groups for 3 real UAs + degraded synthetic; A6 evidence at `docs/evidence/mw1-example-2026-09-13.log`, verified byte-identical (modulo CRLF) to my re-run.
- **R7 pass** — package `moon check --target native`: 12 warnings 0 errors, all 12 in `moon_ua_parser_lib/**` pre-existing `derive(Show)` baseline, 0 warnings from crescent files; package `moon test --target native` green **3 consecutive runs** (tails below), plus a 4th green run after the comment fix.
- **R8 pass** — `moon info --target native -p moon_ua_parser_crescent` regenerated `pkg.generated.mbti` (committed); `git diff --exit-code -- '*.mbti'` exit 0 after regeneration (helper + lib mbti untouched; scoped `-p` form only).
- **R9 pass** — README.mbt.md contains: Install (`moon add` literals ×4), Register snippet (`App::use_middleware(@moon_ua_parser_crescent.middleware())`), Configuration (`forensics_sink?` param + header/read-back API), Version range ("tested against crescent 0.11.x"), Degradation behavior (not-5xx + empty result + log forensics, reason enum, 64-char truncation).
- **R10 pass** — lib module run green 48/48 = 31 lib blocks + 10 helper + 7 crescent (workspace aggregation documented in task-3-report); `grep -rE "^(async )?test " moon_ua_parser_lib --include="*.mbt" | wc -l` = **31**; helper package-level `moon test --target native -p moon_ua_parser_middleware_core` → 10/10; `git status --porcelain moon_ua_parser_middleware_core moon_ua_parser_lib` empty (helper source zero modification).
- **R11 pass** — no integration-test failure occurred in this run (all gates green on first execution); the single D1-graded event is the `moon run` qualified-path failure — attribution → location → disposition recorded in §4; no framework-error-first assumption made.

## 2. Global constraints (R12–R26)

- **R12 pass** — adapter + tests consume only `@ua_parser.parse` (of lib mbti:5-11's four pub fns); `moon info` zero diff on lib; lib files untouched.
- **R13 pass** — helper owns degradation; tests assert empty `UaInfo` mount, chain continues (200 + handler body), forensics `{ua_summary ≤64, reason}` to the FO sink (truncation pinned by the long-synthetic test).
- **R14 pass (na for this task)** — `.github/**` untouched (`git status --porcelain .github` empty; not in commit 065cf07).
- **R15 pass** — crescent pinned 0.11.1, README range statement, integration tests executed against that exact version (mooncakes-resolved).
- **R16 pass** — shared-file discipline respected: `moon.work` change is the sanctioned single member-line append (T-03 did its own line); `moon_ua_parser_crescent/` is a new directory, no overlap with lib/helper dirs; ci.yml untouched (T-06's file).
- **R17 pass** — workspace-manifest change build-verified: top-level `moon build --target native` green immediately with the new member in the manifest.
- **R18 pass** — see R11; D1 entry recorded with framework-assumption-last ordering.
- **R19 pass** — `moon version` → `moon 0.1.20260904 (94521db 2026-09-04)`; all runs on native target.
- **R20 pass** — all acceptance commands run from the workspace root with relative paths (`moon test --target native -p …`, `moon run moon_ua_parser_crescent/examples/ua_echo …`).
- **R21 pass** — crescent 0.11.1 / SHA `d99287ae…` sourced from `docs/framework-selection.md` §2.1/§93/§101; lib/helper 0.1.0 from their committed moon.mod files; async 0.20.3 noted as crescent's own requirement.
- **R22 pass (na edits)** — spec file exists at `docs/superpower/SPEC/202609130033-moon_ua_parser_v02-框架对接-spec.md`; not modified (owned-paths discipline).
- **R23 pass (na edits)** — design file exists at `docs/superpower/DESIGN/202609130033-moon_ua_parser_v02-框架对接-design.md`; not modified.
- **R24 pass (na edits)** — plan file exists at `docs/superpowers/plans/2026-09-13-moon_ua_parser_v02-框架对接.md`; not modified.
- **R25 pass** — lib public API (`moon_ua_parser_lib/src/ua_parser/pkg.generated.mbti:5-11`: `parse` / `parse_browser` / `parse_device` / `parse_os`) unchanged; zero mbti diff.
- **R26 pass** — `C:\Users\Administrator\.agents\skills\moonbit-agent-guide\SKILL.md` read before working; residue style (`///|` blocks, expression-oriented match, moon.pkg import blocks) already aligned and kept.

## 3. W2 residue verdicts (per file)

| File | Verdict | Basis |
|---|---|---|
| `moon_ua_parser_crescent/moon.mod` | 复用 (reuse) | name/version correct; `bobzhang/crescent@0.11.1` + workspace-member deps in the T-01-probe form |
| `moon_ua_parser_crescent/moon.pkg` | 复用 | import blocks correct incl. test-only imports (`middleware`, `test_client`, `async`); `supported_targets = "-all+native+wasm"` |
| `moon_ua_parser_crescent/adapter.mbt` | 复用 | R2-clean (four duties only); mount-before-next on `event.res.headers`; sink injectable; walkthrough facts cited match `docs/framework-selection.md` §2.1 |
| `moon_ua_parser_crescent/integration_test.mbt` | 复用 | golden citations verified against actual uap-core files; synthetic labels explicit; triple assertions present (not-5xx / empty mount / forensics); base_path + missing-header cases |
| `moon_ua_parser_crescent/pkg.generated.mbti` | 复用 | matches `moon info` output after regeneration; committed |
| `moon_ua_parser_crescent/examples/ua_echo/main.mbt` | **修正 (fixed)** | header comment cited `moon run vicoproplus/moon_ua_parser_crescent/examples/ua_echo` — that form fails (`os error 3`; moon resolves run targets workspace-relative). Fixed comment to the verified relative form; code unchanged |
| `moon_ua_parser_crescent/examples/ua_echo/moon.pkg` | 复用 | `pkgtype(kind: "executable")`, native-only, imports correct |
| `moon_ua_parser_crescent/README.mbt.md` | 复用 | R9-complete; command literal verified working |
| root `moon.work` | 复用 | exactly one appended member line `./moon_ua_parser_crescent` |
| `docs/evidence/mw1-example-2026-09-13.log` | 复用 (verified, not rewritten) | my bounded re-run reproduced the captured body **byte-identically** (diff clean after CR strip), incl. forensics-line placement before request 4 and exit code 0 — prior content confirmed from a real run, kept verbatim |

**Fixes made (1):** stale run-command comment in `examples/ua_echo/main.mbt` (see D1 entry below). No code, config, helper, or lib changes.

## 4. Framework SHA/drift, mount mechanism, FO channel

- **SHA/drift:** walkthrough authority = upstream HEAD `d99287ae409d198e1f7c1fd606e4883188d97c02` = crescent 0.11.1; the package consumes `bobzhang/crescent@0.11.1` (registry release of that snapshot). Walkthrough API facts held exactly (`use_middleware(..., base_path?)`, `Event { req, res, params }` with no KV store, no framework logger middleware — walkthrough §2.1/§73). Registered deviations vs. naive framework expectations: (1) no logger middleware → injectable forensics sink as the FO adaptation; (2) no per-request KV store → `res.headers` bypass mounting. Two entries, ≤2 threshold; both forms the walkthrough itself sanctioned.
- **Mount mechanism:** `res.headers` written **before** `next()` — one write observed twice (downstream handlers via shared `event.res` / `App::dispatch` finalization; tests+clients via response). Chosen over the request_id-map bypass because crescent's `Event` has no custom store and a map would need explicit eviction; full `UaInfo` round-trips through `X-Ua-Info` JSON plus `X-Ua-Browser/Os/Device` family headers. Rationale in README §Mounting mechanism.
- **FO channel conclusion (measured):** usable. Injected sink captured exact records in tests (1 record/request, `{ua_summary, reason}` contract, 64-char truncation pinned); default `console_forensics_sink` line retrievable in the example output (evidence log). Fallback: any logging backend via `forensics_sink`; unwired → empty mount remains the observable degradation evidence.

## 5. Test evidence

- **moon check** (package, native): `Finished. … (12 warnings, 0 errors)`; all warnings in `moon_ua_parser_lib/**` baseline; grep `moon_ua_parser_crescent` in check output = 0 hits.
- **Three consecutive package test runs** (plus a 4th after the comment fix):
  - Run 1 tail: `Total tests: 7, passed: 7, failed: 0.`
  - Run 2 tail: `Total tests: 7, passed: 7, failed: 0.`
  - Run 3 tail: `Total tests: 7, passed: 7, failed: 0.`
  - Run 4 (post-fix) tail: `Total tests: 7, passed: 7, failed: 0.`
- **Workspace build:** `moon build --target native` exit 0 (final: `no work to do`), re-verified green after the fix.
- **mbti:** `moon info --target native -p moon_ua_parser_crescent` then `git diff --exit-code -- '*.mbti'` → exit 0 (helper/lib mbti untouched; scoped form only).
- **Regressions:** none. lib module run 48/48 (= 31 lib + 10 helper + 7 crescent; aggregation behavior documented in task-3-report); lib block count independently = 31; helper package-level 10/10; `git status --porcelain` on both frozen dirs empty.
- **Example:** two bounded runs (`timeout 100`, non-server in-process dispatch) exit 0; output matches evidence log verbatim.

## 6. D1 record (R11/R18)

| Event | Attribution | Location | Disposition |
|---|---|---|---|
| `moon run vicoproplus/moon_ua_parser_crescent/examples/ua_echo` → `os error 3` (exit 127) | moon CLI run-target resolution (workspace-relative paths), **not** framework API, **not** helper | example header comment documented the non-working qualified form | fixed the comment to the verified relative literal; example re-run green; recorded as the one code-adjacent fix |

No integration test failed at any point; framework-error-first assumptions: none.

## 7. Files changed (commit 065cf07, explicit-path staging)

- Added: `docs/evidence/mw1-example-2026-09-13.log`, `moon_ua_parser_crescent/{moon.mod, moon.pkg, adapter.mbt, integration_test.mbt, pkg.generated.mbti, README.mbt.md}`, `moon_ua_parser_crescent/examples/ua_echo/{moon.pkg, main.mbt}`
- Modified: `moon.work` (+1 member line)
- Deletions in staged set: **0** (listed per discipline: none)
- Totals: 10 files, +910. Frozen areas (`moon_ua_parser_lib/**`, `moon_ua_parser_middleware_core/**`, `docs/framework-selection.md`, `.github/**`) untouched. Untracked `docs/superpower|superpowers` files for other task streams (平台完备/性能基准/规则更新) left alone.

## 8. Assumptions

1. `cd moon_ua_parser_lib && moon test --target native` in workspace mode aggregates all members (documented in task-3-report); lib-only pass coverage established by the 48/48 run + independent 31-block count — accepted as the R10 "包级验证" equivalent without a second multi-minute lib-only run.
2. Evidence log kept as written (LF endings) since my re-run reproduced its content byte-identically after CR normalization; no rewrite needed.
3. `moon run` target syntax is workspace-relative on this toolchain — documented in README and the example comment accordingly.

## 9. Self-review and concerns

- All 26 rubric items judged (§1–§2), each with evidence; W2 verdicts per file (§3); no item left unjudged.
- Concern 1 (informational): README "Install" `moon add` literals describe the published-package flow; in this workspace the members resolve locally via `moon.work`. Publication of the crescent package to mooncakes is outside T-04 scope; the install section satisfies R9 as written.
- Concern 2 (informational): walkthrough SHA re-verification against a fresh upstream clone was done by the prior run per the residue header note (adapter.mbt cites the snapshot at `d99287ae`); this run confirmed all consumed API signatures behave exactly as the walkthrough records through green integration tests against registry 0.11.1, so no drift affects the deliverable. Registry pin (not SHA pin) is the mooncakes distribution norm.
- Concern 3 (informational): lib-only suite re-run takes multi-minute (known long-computation tests, see probe log); covered via the aggregated 48/48 run instead of a separate isolated run.
