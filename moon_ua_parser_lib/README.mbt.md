# vicoproplus/moon_ua_parser

User-agent parser for MoonBit: one call turns a `User-Agent` header into
browser, OS, and device families with versions. The rule set is ported from
the [uap-core](https://github.com/ua-parser/uap-core) snapshot
`73e7340` and compiled into MoonBit data at build time, so there is no YAML
and no network access at runtime. Matching semantics follow
[uap-python](https://github.com/ua-parser/uap-python), the ua-parser project's
reference implementation, and are validated by a differential test suite
covering all 18213 upstream test cases with a 100% pass rate in all three
domains.

## Features

- **1270 uap-core rules** (user-agent 433 / OS 204 / device 633, including 65
  case-insensitive device rules) from snapshot `uap-core@73e7340`, precompiled
  at library initialization — regexes run on `moonbitlang/regexp`, the only
  runtime dependency (`@0.3.5`).
- **Three domains in one call**: `parse(ua)` returns `UaInfo` with `browser`,
  `os`, and `device` structs (family + version parts); single-domain helpers
  `parse_browser` / `parse_os` / `parse_device` are also available.
- **uap-python-compatible semantics**: the engine mirrors uap-python's modern
  matcher (alternation order, replacement templates, group fallbacks,
  catch-all "Spider" rules, "Other" fallbacks).
- **Three backends**: MoonBit native, JavaScript, and WebAssembly
  (`preferred_target = "wasm"`). The differential suite runs green on native
  and js; the wasm backend builds with `moon build --target wasm`.
- **Diagnostic rule indices**: `parse(ua, with_rule_index=true)` reports the
  0-based index of the winning rule per domain (file order in
  `regexes.yaml`), for debugging and rule attribution.

## Quickstart

Install into a new MoonBit project:

```bash
moon new hello_ua
cd hello_ua
moon add vicoproplus/moon_ua_parser
```

Declare the package import in `cmd/main/moon.pkg` (the entry package created
by `moon new`):

```text
pkgtype(kind: "executable")

import {
  "vicoproplus/moon_ua_parser/src/ua_parser",
}
```

Replace `cmd/main/main.mbt` with:

```moonbit
///|
fn opt(v : String?) -> String {
  match v {
    Some(s) => s
    None => "-"
  }
}

///|
fn main {
  let ua =
    "Mozilla/5.0 (iPhone; CPU iPhone OS 9_3_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13E238 Safari/601.1"
  match @ua_parser.parse(ua) {
    Ok(info) => {
      let b = info.browser
      let o = info.os
      let d = info.device
      println("browser : \{b.family} \{opt(b.major)}.\{opt(b.minor)}")
      println("os      : \{o.family} \{opt(o.major)}.\{opt(o.minor)}.\{opt(o.patch)}")
      println("device  : \{d.family} / \{opt(d.brand)} / \{opt(d.model)}")
    }
    Err(e) => println("parse error: \{e}")
  }
}
```

Run it:

```bash
moon run --target native cmd/main
```

Output:

```text
browser : Mobile Safari 9.0
os      : iOS 9.3.1
device  : iPhone / Apple / iPhone
```

The same program runs on the native and js backends today
(`moon run --target native` / `moon run --target js`); the wasm backend
compiles via `moon build --target wasm`.

## API

```text
pub fn parse(ua : String, with_rule_index? : Bool = false) -> Result[UaInfo, UaError]
pub fn parse_browser(ua : String) -> Browser
pub fn parse_os(ua : String) -> OS
pub fn parse_device(ua : String) -> Device
```

- `UaInfo` bundles `browser : Browser`, `os : OS`, `device : Device`.
- `Browser` / `OS`: `family : String`, `major` / `minor` / `patch` /
  `patch_minor : String?` (`None` = absent, as in upstream fixtures).
- `Device`: `family : String`, `brand` / `model : String?`.
- Every struct carries `rule_index : Int?`, populated only when
  `parse` is called with `with_rule_index = true`.
- `parse` returns `Err(UaError)` only if a rule fails to compile; with the
  shipped precompiled rules this branch is unreachable in practice.

A request-entry middleware demo (parsing, bot detection via the "Spider"
device family, and rule-index debugging) lives in
[`examples/middleware`](examples/middleware/):

```bash
moon run --target native examples/middleware
```

## Differential quality

The engine is differentially tested against the complete uap-core test
fixtures (18213 cases), with uap-python as the semantic authority. Per-domain
pass rates, as printed by
`moon run --target native --release tests/diffstats`:

| domain  | cases | passed | rate     | gate  | status |
|---------|-------|--------|----------|-------|--------|
| browser | 1601  | 1601   | 100.00%  | ≥99%  | MET    |
| os      | 483   | 483    | 100.00%  | ≥97%  | MET    |
| device  | 16129 | 16129  | 100.00%  | ≥97%  | MET    |

Methodology notes:

- Browser-domain assertions compare `family` / `major` / `minor` / `patch`.
  The `patch_minor` expectation column is excluded, following the uap-python
  project's own test protocol (`tests/test_core.py` pops `patch_minor`
  because the golden fixtures disagree with the reference implementation on
  20 cases; upstream tracking issue ua-parser/uap-core#562). Engine
  `patch_minor` fidelity is still covered directly by the semantics suite.
- A three-way audit (golden fixtures × uap-python × this engine) confirmed
  engine output is field-for-field identical to uap-python on all 18213
  cases. Full attribution registry and evidence:
  [`../docs/regex-migration.md`](../docs/regex-migration.md).

## Snapshot provenance

- **Rules source**: [uap-core](https://github.com/ua-parser/uap-core) commit
  `73e7340` (`regexes.yaml`: 1270 rules), vendored read-only at `uap-core/`
  in the repository root; snapshot taken 2026-08-24.
- **Semantic authority**: [uap-python](https://github.com/ua-parser/uap-python)
  commit `6dd8c39`, vendored read-only at `uap-python/` (reference only; not
  a runtime dependency).
- **Generated code**: `src/ua_parser/rules/` (rule data) and
  `tests/differential/` (test cases) are `GENERATED — DO NOT EDIT`. Change
  the generators, not the output:
  `python scripts/gen_rules.py` (rules),
  `python scripts/gen_tests.py` (differential suite); both regenerate
  byte-identically from the vendored snapshots.

## Acknowledgments and license

This project is licensed under **Apache-2.0** (see `LICENSE`).

- The parser rules are derived from
  [uap-core](https://github.com/ua-parser/uap-core), licensed under
  Apache-2.0 (Copyright 2009 Google Inc.).
- The matching semantics follow
  [uap-python](https://github.com/ua-parser/uap-python), licensed under
  Apache-2.0.
- Both vendored copies retain their upstream `LICENSE` files, and the
  upstream projects are credited above and in
  [`../docs/regex-migration.md`](../docs/regex-migration.md).
