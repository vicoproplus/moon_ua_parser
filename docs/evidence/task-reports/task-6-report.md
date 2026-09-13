# Task T-06 Report — 文档与 CI 增量合入（含框架缓存补丁固化）

- Date: 2026-09-13
- Worktree: `F:\moonbit比赛\moon_ua_parser_wt_framework`, branch `feat/v02-framework-middleware` (never switched)
- Commit: **`fc26bd9` T-06: docs + CI incremental integration; capture framework cache patches** — 6 files, 390 insertions, **0 deletions**, explicit-path `git add` only
- Toolchain: moon 0.1.20260904 (94521db 2026-09-04), `moon version` verified this session
- All acceptance commands run from repo root with relative paths; every Bash call ≤ 120000 ms; no workspace full-suite test run

## 1. Patch reconstruction (R3) — route (a) used

**Route (a): local registry tarball** — succeeded on the first route, no download needed:

- Pristine sources: `~/.moon/registry/cache/bobzhang/crescent/0.11.1.zip` and `~/.moon/registry/cache/mizchi/x/0.6.1.zip` (the exact tarballs moon itself fetched from), extracted with `unzip` to `/tmp/t6-pristine/`.
- `diff -rq` pristine vs the live patched `.mooncakes` cache → **exactly** 4 crescent files differ (`serve_async.mbt`, `serve_request_body.mbt`, `serve_response.mbt`, `websocket/lifecycle.mbt`) + 2 mizchi/x files (`src/socket/socket_native.mbt`, `src/socket/socket_fd_native.mbt`); zero other drift (no `.orig` residue, `moon.mod`/`pkg.generated.mbti` identical).
- Route (b) (curl from mooncakes registry) not needed; recorded as available.

**Patch generation** (temp, then file-tool write): temp git repo `/tmp/t6-patchgen/repo` with pristine files committed under `.mooncakes/bobzhang/crescent/`, patched files overlaid from the live cache, `git diff` → `crescent-async-compat.patch` (212 lines, 4 file hunks, repo-root-relative paths).

**Verification (three independent rounds):**

1. `git apply --check` on pristine extraction → OK; `git apply` → result **byte-identical (`cmp`) to the live patched cache** for all 4 files.
2. Sandbox end-to-end CI simulation (`/tmp/t6-fetch-probe`: fresh `moon.work` workspace, one member importing `bobzhang/crescent@0.11.1`): `moon install` → "Using cached bobzhang/crescent@0.11.1", populates root `.mooncakes/` pristine → `git apply --check` OK → `git apply` → all 4 files **byte-identical vs live patched cache**.
3. Real-repo dry-run with the local crescent cache reset to pristine (see §4) — same result.

**Inventory:**
- `scripts/framework-cache-patches/crescent-async-compat.patch` — 212 lines, hunks: serve_async.mbt (+27/-0 adapter + 6 call-site conversions + 3 test-map literals), serve_request_body.mbt (+4/-1), serve_response.mbt (+18/-2), websocket/lifecycle.mbt (+7/-5).
- `scripts/framework-cache-patches/README.md` — target version (0.11.1), one-line cause (MVS-unified async 0.21.3 `CaseInsensitiveString` headers), apply mechanism (`git apply` post-fetch, repo root), upstream-tracking status (local adapter only, not submitted; re-check triggers).

**mizchi/x adjudication (brief's conditional):** the fd gating is `#cfg(not(platform="windows"))` on 4 unused-in-workspace Int-returning accessors + 1 helper; on Linux the gated code compiles identically to pristine (`Fd = Int` there), i.e. a **Linux/CI no-op** — confirmed by T-05 §5 ("CI-on-linux impact is crescent-only"). Per the brief's rule (linux no-op ⇒ 不落盘), **no `mizchi-x-windows-fd.patch`**; the decision, the full gating description, and Windows re-derivation guidance are recorded in the dir README. Live mizchi/x cache files left untouched.

**Known deviation (documented in dir README):** the committed patch stores empty context lines without the conventional leading single space — the mandated file-writing channel strips trailing whitespace (verified: a Write of " \n" lands as "\n"). Consequence: none functional — `git apply`/GNU patch treat such lines as plain context, proven by all three verification rounds above (apply output byte-identical). A `git diff`-regenerated canonical form is recoverable from pristine zip + current cache at any time.

## 2. ci.yml (R2, R11) — pure insertion + append, existing lines byte-identical

`git diff .github/workflows/ci.yml` → **46 insertions, 0 deletions**; `git diff | grep '^-'` (excluding header) → empty. YAML parses (python yaml.safe_load, 16 steps).

Final step order (new steps at index 5, 14, 15):

```
4  Verify toolchain
5  Apply framework cache patches (post-fetch, pre-build)   [NEW, INSERTED]
6  Static check                                            (existing, verbatim)
...
13 Differential gate report                                 (existing, verbatim)
14 Workspace build (middleware)                             [NEW, APPENDED]
15 Middleware integration tests (crescent + mars)           [NEW, APPENDED]
```

Key discovery driving placement: **the member-directory steps are workspace-wide since T-01 added `moon.work`**. Empirical probe (local cache reset to pristine, then `cd moon_ua_parser_lib && moon check`): `Failed with 44 warnings, 2 errors` — both errors in `.mooncakes/bobzhang/crescent/websocket/lifecycle.mbt:162` (`Map[String, String]` vs `Map[@moonbitlang/async/http.CaseInsensitiveString, String]`), i.e. the v0.1 "Static check" already compiles crescent and would fail on a fresh CI checkout **before** any later patch step. Hence the patch step is inserted immediately after "Verify toolchain" and before the first moon command. Placement satisfies R2's "补丁应用步骤位于首个 workspace 级构建/测试步骤之前" under the empirically verified fetch timing.

Step literals (new):

```yaml
- name: Apply framework cache patches (post-fetch, pre-build)
  timeout-minutes: 15
  working-directory: .
  run: |
    moon install
    git -c core.autocrlf=false apply --check scripts/framework-cache-patches/*.patch
    git -c core.autocrlf=false apply scripts/framework-cache-patches/*.patch

- name: Workspace build (middleware)          # timeout-minutes: 30, working-directory: .
  run: moon build --target native

- name: Middleware integration tests (crescent + mars)   # timeout-minutes: 15, working-directory: .
  run: |
    moon test --target native -p moon_ua_parser_crescent
    moon test --target native -p moon_ua_parser_mars
```

Design notes (also in step comments in-file): `moon install` (no-arg deprecated form, still the explicit dependency-fetch trigger named by the brief; sandbox-verified to populate root `.mooncakes/` from the registry) forces the fetch so patches land between fetch and first compilation. `moon build`/`moon test` do **not** re-extract an already-fetched cache (sandbox-verified: applied patch survives a second `moon install` + `moon build`). `-c core.autocrlf=false` pins patch application bytes (no-op on linux; without it a Windows host's global `autocrlf=true` writes CRLF into the cache — observed and corrected locally). `--target native` rationale (local wasm-gc breakage is a Windows fact; plan backfilled native literals) is in the comment block. R7 grep note: `grep -n "middleware\|集成\|patch"` hits the new steps at lines 67/72/73 (patch step), 120/125 (middleware build + comment), 129-133 region (lowercase "middleware integration tests" in the comment directly above the tests step).

## 3. READMEs (R1, R5)

- `moon_ua_parser_lib/README.mbt.md`: new `## Ecosystem` section (48 lines, between API and Differential quality) — lists `moon_ua_parser_crescent` (header mounting: `res.headers` bypass, `X-Ua-Info` JSON round-trip, distilled from the package README's "Mounting mechanism" section) and `moon_ua_parser_mars` (Variables mounting: three families as native `Var::String` on `ctx.vars`), each with its `moon add` literal, mentions `vicoproplus/moon_ua_parser_middleware_core` as the pure helper owning all semantics, and the shared degradation contract. `grep -c "moon_ua_parser" moon_ua_parser_lib/README.mbt.md` = **10 ≥ 4**. Structure matches spec §3 row 「主库 README 生态节」 (列出已发布中间件包、安装命令与框架适配说明).
- `moon_ua_parser_crescent/README.mbt.md` + `moon_ua_parser_mars/README.mbt.md`: exactly one added `> Pre-release note:` line each, at the Install section (diff = +2 lines per file: note + blank).

## 4. V2 dry-run (R4) — every new step literal executed locally, all green

Local crescent cache was first reset to pristine (registry zip) so the dry-run exercises the CI scenario (fresh fetch), not a no-op:

1. `moon install` → exit 0 (output: deprecation warning only; deps unchanged → nothing to re-fetch). Earlier fresh-fetch sandbox run showed `Using cached bobzhang/crescent@0.11.1`.
2. `git -c core.autocrlf=false apply --check scripts/framework-cache-patches/*.patch` → OK.
3. `git -c core.autocrlf=false apply scripts/framework-cache-patches/*.patch` → OK; post-state **byte-identical (`cmp` ×4) to the T-05 patched cache backup** (`/tmp/t6-livecache-backup`), mizchi/x patched files untouched.
4. `moon build --target native` (repo root) → exit 0, `Finished. moon: ran 11 tasks, now up to date`.
5. `moon test --target native -p moon_ua_parser_crescent` → exit 0, `Total tests: 7, passed: 7, failed: 0.`
6. `moon test --target native -p moon_ua_parser_mars` → exit 0, `--> Get /probe` + `Total tests: 6, passed: 6, failed: 0.`

Sandbox addendum: a second `moon install` + `moon build` after patching did **not** revert the applied cache (git diff on the 4 files unchanged; marker grep = 1 in serve_async.mbt).

## 5. Gates

- R6: `git diff --exit-code -- '*.mbti'` → exit 0 (after scoped `moon info --target native -p vicoproplus/moon_ua_parser`; its stray untracked module-root `moon_ua_parser_lib/pkg.generated.mbti` deleted, mirroring T-05 residue handling). `moon check --target native -p moon_ua_parser_lib/src/ua_parser` → exit 0, `12 warnings, 0 errors` (identical to the T-04/T-05 baseline; the 12 warnings are the pre-existing lib `derive(Show)` deprecations). No `.mbt`/`.mbti`/`moon.mod`/`moon.work` modifications: `git status --porcelain | grep -E '\.mbt$|\.mbti$|moon\.mod|moon\.work'` → empty.
- R7: ci.yml grep hits new steps (see §2); README grep count 10 ≥ 4.
- R9: only `@ua_parser` public API consumed by untouched adapters; `moon info` zero diff; lib public face unchanged.

## 6. Files changed (commit fc26bd9)

| File | Change |
|---|---|
| `.github/workflows/ci.yml` | +46 (3 new steps + comment blocks; existing 92 lines byte-identical) |
| `scripts/framework-cache-patches/crescent-async-compat.patch` | new, 212 lines |
| `scripts/framework-cache-patches/README.md` | new, 80 lines |
| `moon_ua_parser_lib/README.mbt.md` | +48 (Ecosystem section) |
| `moon_ua_parser_crescent/README.mbt.md` | +2 (one note line + blank) |
| `moon_ua_parser_mars/README.mbt.md` | +2 (one note line + blank) |

Not committed (by design): this report and the `.superpowers` SDD tree (untracked/ignored). Pre-existing untracked `docs/superpower|superpowers/*` files from other task units left untouched.

## 7. Assumptions

1. **Patch step inserted before "Static check" rather than "just before the new workspace steps"** — the controller context's suggested placement is demonstrably broken on CI (probe in §2: member-dir `moon check` fails on pristine cache). The brief itself mandates "确认 moon 的 fetch 时点…补丁步骤须置于首个 workspace 级构建/测试步骤之前"; with workspace-wide member commands, Static check IS the first workspace-level check. The insertion keeps every existing line byte-identical (R2/R11 verified).
2. `moon install` (deprecated no-arg) accepted as the fetch trigger because the brief names it, the sandbox proved it populates root `.mooncakes/` offline, and `moon fetch` is a different unstable mechanism (downloads to `.repos`, not the workspace cache).
3. mizchi/x patch not shipped per the brief's Linux no-op rule (§1); Windows-local fresh-fetch breakage risk accepted and documented in the dir README.
4. Ecosystem section says "Companion packages" rather than "published packages" — the two middleware packages are pre-release (their own pre-release notes say so); spec §3's 「已发布」 row is satisfied in structure and will be literally true at release time.

## 8. Rubric self-review

- **R1 pass** — `## Ecosystem` at README.mbt.md:126 with both packages + one-line purposes, both `moon add` literals, crescent=header / mars=Variables adaptation distilled from the package READMEs, helper package named; `grep -c "moon_ua_parser"` = 10 ≥ 4.
- **R2 pass** — ci.yml diff = 46 insertions / 0 deletions, no existing line touched (grep '^-' empty); new steps mirror existing shape (name/timeout-minutes/working-directory/run); patch step at index 5, before the first workspace-wide moon command and before both new workspace build/test steps.
- **R3 pass** — `scripts/framework-cache-patches/` contains `.patch` + README.md; `git apply --check` verified against pristine extraction, fresh `moon install` fetch, and the real repo after pristine reset (all OK; apply output byte-identical to the green T-04/T-05 cache); README documents version/cause/mechanism/upstream status.
- **R4 pass** — all six step-literal command lines executed locally once against a pristine-reset cache; output tails in §4, all green.
- **R5 pass** — one `> Pre-release note:` line per middleware README (diff: exactly +2 lines each), at the Install section.
- **R6 pass** — `git diff --exit-code -- '*.mbti'` exit 0; lib package check 0 errors (12 pre-existing warnings); zero `.mbt`/`.mbti`/`moon.mod`/`moon.work` modifications.
- **R7 pass** — ci.yml grep hits new steps (lines 67/72/73/120/125/129-133); README grep count 10 ≥ 4.
- **R8 pass** — registered here, not fabricated: CI run evidence for the new steps = `[LOCAL_DEAD_LINK — 推送后 GitHub run 历史]` (requires push; local V2 dry-run §4 is the pre-push evidence).
- **R9 pass** — no adapter code touched (git status clean of `.mbt`); `moon info` zero diff; lib mbti unchanged.
- **R10 na** — degradation semantics belong to T-03/T-04/T-05 deliverables (helper + adapters, untouched here); this task's Ecosystem section re-states the contract (`{ua_summary ≤64, reason}`, empty-mount continuation) verbatim from the package READMEs.
- **R11 pass** — CI增量 only: 46 insertions, 0 deletions, existing job/steps verbatim.
- **R12 pass** — framework pins unchanged (`bobzhang/crescent@0.11.1`, `mizchi/mars@0.3.12` in the members' moon.mod, committed by T-04/T-05); the new CI steps run the two packages' integration tests against exactly those resolved versions.
- **R13 pass** — ci.yml and READMEs edited only in this task (single point); `moon.work` untouched; middleware package dirs not overlapped (only their README.mbt.md note lines, as authorized).
- **R14 pass** — V2 dry-run executed for the configuration/step changes (§4), including the workspace-level build.
- **R15 pass** — the one failure encountered (2 errors under `moon check` with pristine cache) was attributed with evidence to the unpatched cache (crescent lifecycle.mbt:162 type mismatch vs async 0.21.3), located to the known T-05 root cause, and dispositioned by the committed patch + step placement — no framework-error-first assumption.
- **R16 pass** — moon 0.1.20260904 (94521db 2026-09-04) verified via `moon version`; ci.yml install step still pins the same version (untouched line).
- **R17 pass** — every acceptance command run from the repo root with relative paths (`scripts/...`, `moon_ua_parser_lib/...`).
- **R18 pass** — versions/names traced to: member `moon.mod` files, registry cache zips + index, T-05 report §5, spec §3 rows cited in-file.
- **R19–R22 pass/na** — spec §3 rows (README 生态节 / CI 增量) consulted and matched; design/plan consumed via the task brief (the requirements document); lib public API file untouched.
- **R23 pass** — MoonBit agent guide read; it governs `.mbt`/moon.pkg authoring, which this task does not touch (doc/CI/patch artifacts only).

## 9. Concerns

1. **CI has never actually run these steps on GitHub** (no push from this session). Everything is verified locally, including a fresh-fetch sandbox that mirrors the CI sequence exactly; the residual risk is CI-environment-specific (e.g. `moon install`'s deprecated no-arg form being removed in a future moon release — the pin at ci.yml:43 protects this).
2. **Windows-local fresh fetch** will break mizchi/x compilation until the fd gating is re-applied by hand (deliberately not shipped; documented in the patch-dir README with re-derivation pointers). CI/linux is unaffected.
3. **Patch file whitespace deviation** (§1): empty context lines lack the leading space due to the authoring channel; verified harmless for `git apply` (the CI mechanism) three times, noted in the dir README. If a future maintainer switches to GNU `patch` or `git am`, regenerate the file canonically first.
4. **Windows checkouts of the repo** (autocrlf=true) may check the patch file out as CRLF; CI (linux) is unaffected, and the CI step's `-c core.autocrlf=false` keeps application deterministic. Re-run `git apply --check` after any suspect checkout.
5. The existing lib CI steps now (post-T-01 workspace) implicitly compile the whole graph, so their runtime grows on CI; not modifiable under S3, and orthogonal to correctness once the patch step runs first.
