# wasm × differential corpus — structural blocker record (2026-09-13)

Status (updated 2026-09-14): **RESOLVED — Followup-1 landed; see §5.** The
wasm differential TEST gate is restored: the generator now chunk-functions
the corpus and bare `moon test` (default wasm target) runs the differential
suite green (3/3 local; evidence §5). The historical 2026-09-13 status
below is kept verbatim as the Ruling B / registration record.

Status (2026-09-13): **blocker stands, scope = the debug/test wasm module
only.** The wasm test gate is the 7 non-differential packages (ruling B;
T-01: 28/28 green); re-verification queued as R-1. The three-domain
differential REPORT path is unblocked on all three targets — native, js and
wasm `--release` (see `diffstats-{native,js,wasm}-2026-09-13.txt`, report
sections byte-identical, md5 `bff7fc84866a9ad4b6ac8a79299788f9`). Followup-1
(generator split) remains registered to restore the wasm differential
**TEST** gate.

## 1. The structural obstacle

The generated differential corpus package (`tests/differential`, 4,006,487 bytes
of generated source, of which `diff_device.mbt` alone is 3,558,609) compiles —
under **debug** codegen — into a package-initialization function that declares
**125,840 wasm locals**, 2.52x the V8 engine's hard per-function cap of 50,000.
V8 rejects the module statically, before executing a single instruction:

```
Uncaught CompileError: WebAssembly.Module(): Compiling function
  #675:"_M0FP017____moonbit__init" failed: local count too large @+126090
```

Consequences (all proven in T-01, see §2):
- deterministic and engine-level, not environmental: reproduced byte-identically
  by `node v26.7.0`'s `new WebAssembly.Module(buf)`; moonrun is V8-based on
  **every** platform, so no OS/CI-environment escape exists;
- no engine-side switch exists (`moonrun --help` exposes no local-cap related
  flag);
- the only fix for the TEST gate lives in the generator: split
  `tests/differential` into multiple packages (Followup-1, §3).

## 2. Primary evidence — T-01 report

`.superpowers/sdd/2026-09-13-moon_ua_parser_v02-平台完备/task-1-report.md`
(2026-09-13), in particular:
- §3.1 phenomenon (`moon test`, default wasm target, exit 127, function #675);
- §3.2 forensics: node v26 cross-reproduction; hand-written wasm parser
  measurement (module 10,781,644 bytes, 672 code-section functions, code idx
  670 declaring 125,840 locals, body 2,746,730 bytes; imports 6 items → module
  index 675); GitHub API `actions/runs` total_count = 0 (the wasm differential
  suite has never passed in any environment);
- §4 green-evidence set: after the moonrun layer-1 repair, wasm `moon test` over
  the 7 non-differential packages = 28/28 green; native differential suite
  3/3 green (31/31 total).

Cross-check by T-02 (same-methodology parser, 2026-09-13): the same debug
artifact `_build/wasm/debug/test/tests/differential/differential.internal_test.wasm`
measures max 125,840 declared locals at code idx 670 (module 10,781,644 bytes,
672 functions) — exact reproduction of the T-01 figures.

## 3. Ruling B and Followup-1

- Ruling B (2026-09-13, plan exit-gate authority; recorded in
  `progress.md` and the T-02 brief addendum): at ruling time the diffstats wasm
  form was believed impossible and the three-domain differential evidence
  target moved to native+js; the wasm test gate was redefined as the **7
  non-differential packages** (T-01: 28/28; re-verification queued as R-1).
- **Followup-1** (registered 2026-09-13, rules-update domain): modify
  `scripts/gen_tests.py` to split `tests/differential` into multiple packages
  (per-domain or chunked) so every package-init function stays under the
  50,000-local cap, then regenerate (S4-compliant, no hand edits). This is the
  path that restores the wasm differential **TEST** gate. It is not required
  for the report path (§4): release codegen already fits under the cap.

## 4. Blocker scope: debug/test module only — the release report path is unblocked

The T-02 addendum permitted one capture run of the "expected" direct failure.
It did not fail, and subsequent verification pinned down the scope precisely:

```
2026-09-13T03:32:09+08:00 → 03:36:14+08:00   (cold build, first capture)
2026-09-13T04:09:39+08:00 → 04:14:05+08:00   (evidence run)
cmd:   moon run --target wasm --release tests/diffstats
exit:  0 (both) — report byte-identical to native/js
       (report-section md5 bff7fc84866a9ad4b6ac8a79299788f9;
       browser/os/device all 100.00%, GATES: ALL MET;
       full transcript: docs/evidence/diffstats-wasm-2026-09-13.txt)
direct execution cross-check:
       moonrun _build/wasm/release/build/tests/diffstats/diffstats.wasm → exit 0
```

Parser measurement of the **release** module explains why:
`_build/wasm/release/build/tests/diffstats/diffstats.wasm` (6,828,572 bytes,
352 code-section functions) — max declared locals **26,857** (code idx 350, the
corpus init; body 935,739 bytes) — **within** the 50,000 cap. Release codegen
folds the corpus literals; debug codegen materializes them as locals.

Therefore the precise statement is:

- **Blocked:** the **debug**-codegen differential wasm module (what `moon test`
  builds for the default wasm target): 125,840 locals > 50,000 — static,
  deterministic rejection on all V8-based runtimes. The wasm **test** gate
  remains redefined per ruling B until Followup-1 lands.
- **Not blocked:** the `--release` codegen of the diffstats executable
  (26,857 locals) — the wasm domain-level differential report runs and agrees
  byte-for-byte with native and js.

Ruling B's acceptance (native+js, later widened in T-02 finalization to include
the wasm report as core deliverable evidence) is met on all three targets.

## 5. Resolved — Followup-1 landed (2026-09-14)

The generator-level fix that this document registered as **Followup-1** is
now in place (toolchain `moon 0.1.20260904`, Windows 10 local, 2026-09-14):
`scripts/gen_tests.py` no longer emits the corpus as a single package-level
array literal. It emits private chunk functions
(`<domain>_chunk_0() … <domain>_chunk_N()`, at most `CHUNK_CASES = 3000`
entries each, so ~21,000 wasm locals: ~7 locals/case measured here times the
chunk size, well under V8's 50,000 cap) and concatenates them into the
public array via the core `Array` `Add` impl. The public surface
(`pkg.generated.mbti`, diffstats' `@differential` entry points) is unchanged.

Verified green (all gates, local Windows 10, moonrun V8-based):

- `moon test --target wasm -p vicoproplus/moon_ua_parser/tests/differential`
  → `Total tests: 3, passed: 3, failed: 0.` (was previously the static
  `local count too large` rejection).
- bare `moon test` (default wasm target) inside `moon_ua_parser_lib` →
  `Total tests: 41, passed: 41, failed: 0. [wasm]` + the native example route.
- regression sweep (native 55/55, js 41/41, native+wasm `--release`
  diffstats reports all three domains 100.00% and byte-consistent with the
  pre-fix md5 `bff7fc84866a9ad4b6ac8a79299788f9`, perf smoke pass
  ~42.8 ms/parse < 150 ms limit).
- idempotent regeneration: a second `python scripts/gen_tests.py` run leaves
  `tests/differential` byte-identical.

The CI wasm test step (`ci.yml` "Tests (wasm, default target)") was reverted
from the explicit 7-package list to bare `moon test`, keeping the
`ulimit -s unlimited` line that the Linux link-core stack-depth workaround
still requires. Sections 1–4 above are kept verbatim as the historical
record of Ruling B and the Followup-1 registration.

