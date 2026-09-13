# moon_ua_parser_mars

mizchi/mars framework middleware for [`vicoproplus/moon_ua_parser`](https://github.com/vicoproplus/moon_ua_parser) (T-05).
One `Server::middleware` call parses each request's `User-Agent`, mounts the
resulting `browser` / `os` / `device` groups on the framework's typed request
context (`ctx.vars`), and reports degraded parses through a forensics
channel — all assembly / degradation / forensics semantics live in the pure
helper [`vicoproplus/moon_ua_parser_middleware_core`](../moon_ua_parser_middleware_core/README.mbt.md);
this package is a thin adapter only.

## Install

```bash
moon add mizchi/mars
moon add vicoproplus/moon_ua_parser
moon add vicoproplus/moon_ua_parser_middleware_core
moon add vicoproplus/moon_ua_parser_mars
```

> Pre-release note: `vicoproplus/moon_ua_parser_mars` is not yet published to the mooncakes registry — `moon add` applies after the first release; until then, users inside this repository's `moon.work` workspace already consume the package as a local path dependency.

## Register

```moonbit nocheck
// build + register on a mars Server (Hono-style sequential chain)
let app = @mars.Server::new()
app.middleware(@middleware.logger_simple())             // optional: mars's own log channel
app.middleware(@moon_ua_parser_mars.middleware())       // UA parsing + mount + forensics
app.get("/probe", ctx => {
  // handler-side typed read-back of the mounted value
  match @moon_ua_parser_mars.mounted_ua_info(ctx) {
    Some(info) => "browser=\{info.browser.family}"
    None => "nothing-mounted"
  }
})
```

The middleware registers like any native mars `Handler`
(`async (Context) -> Unit`) via `Server::middleware`, before the route
handlers.

## Configuration

`middleware(forensics_sink?)` takes one optional parameter:

- `forensics_sink : (@middleware_core.ForensicsRecord) -> Unit` — the
  forensics (FO) output channel invoked for every **degraded** request.
  Default: `console_forensics_sink`, which prints one line
  `[moon_ua_parser] degraded user-agent parse: reason=<reason> ua_summary="<≤64 chars>"`
  via `println` — the same output sink mars's own logger middleware
  (`@middleware.logger_simple()` / `logger()`) writes to, so forensics
  lines land on the framework's console log channel. Inject a closure to
  forward records to any other backend.

Mount keys (typed `Variables` store, `ctx.vars`):

- `KEY_UA_BROWSER` = `"ua_parser.browser"`, `KEY_UA_OS` = `"ua_parser.os"`,
  `KEY_UA_DEVICE` = `"ua_parser.device"` (values are JSON strings).

Read-back API:

- `mounted_ua_info(ctx : @mars.Context) -> @ua_parser.UaInfo?` —
  handler-side; reconstructs the mounted `UaInfo` from the three
  `ctx.vars` families. `None` when the middleware was not registered
  upstream; on degradation the reconstruction is structurally
  `empty_ua_info()` (empty-string families).

## Mounting mechanism (and why)

mars's `Context` carries a typed custom key-value store, `ctx.vars :
Variables` — the framework's own mechanism (its logger middleware uses the
string `ctx.set/get` sibling of the same design). The adapter mounts the
three group **families** as native `Var::String` values instead of a full
`UaInfo`:

- `Variables::set[V : Var]` serializes every value through the `Var` trait
  to `Json` and `Variables::get` returns `Json?` (upstream `env.mbt`,
  verified against commit `ff4485e0`); `Var` is implemented only for
  `Bool` / `Double` / `String` / `Json`;
- a full-`UaInfo` mount would therefore need a ~165-line JSON transport
  codec (the crescent adapter's header round-trip pattern), while the
  three families are natively storable `Var::String` values with zero
  serialization; implementing `Var` for `UaInfo` is not possible outside
  the defining packages (MoonBit orphan rule);
- the mount is written **before** the route handler runs, so every
  downstream handler sees it through `ctx.vars` / `mounted_ua_info`.

The mount therefore carries exactly the browser/os/device three-group
contract; the version / brand / model / `rule_index` fields of the
read-back `UaInfo` are `None` by construction.

Header note: mars `Context::header` is an exact-case map lookup while the
mizchi/x native transport lowercases request-header keys; the adapter tries
the canonical `User-Agent` spelling first and falls back to the lowercase
form. A missing header is treated as the empty string (the helper's
degradation semantics decide what that mounts).

## Degradation behavior

Degradation (parse `Err`, or all three families at the library's "Other"
all-miss fallback — including a missing `User-Agent` header, which is
treated as the empty string) **never** interrupts the request chain and
**never** turns into a 5xx:

1. the response keeps its normal status (e.g. 200);
2. the mount is the empty `UaInfo` — empty-string families (deliberately
   distinct from the library's `"Other"` fallback), visible as empty
   families through `mounted_ua_info`;
3. one `{ua_summary, reason}` forensics record is emitted to the sink,
   with `ua_summary` truncated to 64 characters (`UA_SUMMARY_MAX_LENGTH`)
   and `reason` ∈ {`parse_error`, `empty_fallback`}.

All three behaviors are implemented by
`vicoproplus/moon_ua_parser_middleware_core`; the adapter only forwards the
record to the sink.

## Version range

- **Tested against mars 0.3.x** — dependency pinned to `mizchi/mars@0.3.12`
  in `moon.mod` (upstream commit
  `ff4485e0309a8532d03002eb588ab06dcd252848`, moon.mod version 0.3.12);
  integration tests + example run against the resolved registry package.
- Transitive pins (mars's own requirements): `moonbitlang/async@0.21.3`,
  `moonbitlang/x@0.5.5`, `mizchi/x@0.6.1`.
- `vicoproplus/moon_ua_parser@0.1.0`,
  `vicoproplus/moon_ua_parser_middleware_core@0.1.0` (workspace-resolved).
- Toolchain: moon 0.1.20260904, `--target native`
  (`supported_targets = "-all+native"`, mirroring mizchi/mars itself).
- Workspace coexistence note: `mizchi/mars@0.3.12` requires
  `moonbitlang/async@0.21.3`, and a moon workspace resolves **one** version
  per registry package across all members; `bobzhang/crescent@0.11.1`
  (pinned by the sibling adapter package) targets the `async 0.20.x`
  header API and does not compile against `0.21.3`. The workspace-level
  resolution of this conflict is recorded in
  `docs/evidence/mw2-example-2026-09-13.log` and the T-05 task report;
  this package's own gates (check / tests / example) are all verified at
  package level against the 0.3.12 pin.

## Example (one command)

From the workspace root:

```bash
moon run moon_ua_parser_mars/examples/ua_echo --target native
```

Dispatches four requests through a real mars `Server` (three real UAs + one
malformed synthetic UA) over an ephemeral 127.0.0.1 listener — bounded,
non-resident — and prints, per request, the framework's `-->` log line, the
status and the handler-side read-back of the three browser/os/device
groups; the degraded request additionally shows the default console
forensics line. Captured output:
`docs/evidence/mw2-example-2026-09-13.log`.

## Tests

```bash
moon test --target native -p moon_ua_parser_mars
```

Integration tests drive real HTTP requests through a real mars `Server`
over the framework's own network stack (ephemeral loopback listener with a
bounded accept-exactly-N loop — mars ships no network-free test client),
asserting uap-core golden cases (citations in `integration_test.mbt`), the
malformed-UA degradation triple (not-5xx / empty mount / forensics
retrievable from an injected sink), the 64-character `ua_summary`
truncation, the missing-header case and a no-middleware misuse guard.
