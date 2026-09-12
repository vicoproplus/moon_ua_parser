# wasm × differential corpus — structural blocker record (2026-09-13)

Status: **blocker stands, scope = the debug/test wasm module only.** The wasm
test gate is the 7 non-differential packages (ruling B; T-01: 28/28 green);
re-verification queued as R-1. The three-domain differential REPORT path is
unblocked on all three targets — native, js and wasm `--release` (see
`diffstats-{native,js,wasm}-2026-09-13.txt`, report sections byte-identical,
md5 `bff7fc84866a9ad4b6ac8a79299788f9`). Followup-1 (generator split) remains
registered to restore the wasm differential **TEST** gate.

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
