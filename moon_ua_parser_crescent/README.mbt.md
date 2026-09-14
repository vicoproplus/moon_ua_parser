# moon_ua_parser_crescent

Crescent framework middleware for [`vicoproplus/moon_ua_parser`](https://github.com/vicoproplus/moon_ua_parser) (T-04).
One `App::use_middleware` call parses each request's `User-Agent`, mounts
the resulting `browser` / `os` / `device` groups on the request context
**and** the response, and reports degraded parses through a forensics
channel — all assembly / degradation / forensics semantics live in the
pure helper [`vicoproplus/moon_ua_parser_middleware_core`](../moon_ua_parser_middleware_core/README.mbt.md);
this package is a thin adapter only.

## Install

```bash
moon add bobzhang/crescent
moon add vicoproplus/moon_ua_parser
moon add vicoproplus/moon_ua_parser_middleware_core
moon add vicoproplus/moon_ua_parser_crescent
```

> Published: `vicoproplus/moon_ua_parser_crescent` 0.1.0 is live on the mooncakes registry (2026-09-13; publish evidence `docs/evidence/publish-final-2026-09-13.log` in the source repository) — `moon add` works as written.

## Register

```moonbit nocheck
// build + register on a crescent App (onion model, async callbacks)
let app = @crescent.App()
app.use_middleware(@middleware.request_id())            // optional: request correlation
app.use_middleware(@moon_ua_parser_crescent.middleware()) // UA parsing + mount + forensics
app.get("/probe", event => {
  // handler-side typed read-back of the mounted value
  match @moon_ua_parser_crescent.mounted_ua_info(event) {
    Some(info) => "browser=\{info.browser.family}"
    None => "nothing-mounted"
  }
})
```

## Configuration

`middleware(forensics_sink?)` takes one optional parameter:

- `forensics_sink : (@middleware_core.ForensicsRecord) -> Unit` — the
  forensics (FO) output channel invoked for every **degraded** request.
  Default: `console_forensics_sink`, which prints one line
  `[moon_ua_parser] degraded user-agent parse: reason=<reason> ua_summary="<≤64 chars>"`
  to the console. Inject a closure to forward records to any logging
  backend; bobzhang/crescent ships no logger middleware, so the sink IS
  the log-channel adaptation.

Read-back API:

- `mounted_ua_info(event : @crescent.Event) -> @ua_parser.UaInfo?` —
  handler-side; parses the mount back from the event's response headers.
- `parse_mounted_ua_info(header_value : String) -> @ua_parser.UaInfo?` —
  client-side; parse a `X-Ua-Info` response header value.
- Family headers: `X-Ua-Browser` / `X-Ua-Os` / `X-Ua-Device`
  (constants `HEADER_UA_BROWSER` / `HEADER_UA_OS` / `HEADER_UA_DEVICE`),
  plus the full JSON round-trip header `X-Ua-Info` (`HEADER_UA_INFO`).

## Mounting mechanism (and why)

crescent's `Event` has no custom key-value store (`pub(all) struct Event {
req, res, params }`), so the adapter uses the framework-sanctioned
**`res.headers` bypass** instead of the alternative request_id-keyed map:

- headers are written **before** `next()`, so downstream handlers see the
  mount on the shared `event.res` **and** `App::dispatch` finalizes the
  HTTP response from the same record — one write, two observers;
- no global mutable state and no per-request entry lifecycle (a
  request_id-keyed map would need explicit eviction to avoid unbounded
  growth);
- the mounted value is therefore directly observable by tests/clients in
  the response (`X-Ua-Info` JSON round-trips the full `UaInfo`, including
  versions and `rule_index`).

## Degradation behavior

Degradation (parse `Err`, or all three families at the library's
"Other" all-miss fallback — including a missing `User-Agent` header,
which is treated as the empty string) **never** interrupts the request
chain and **never** turns into a 5xx:

1. the response keeps its normal status (e.g. 200);
2. the mount is the empty `UaInfo` — empty-string families (deliberately
   distinct from the library's `"Other"` fallback), visible as empty
   `X-Ua-Browser` / `X-Ua-Os` / `X-Ua-Device` headers;
3. one `{ua_summary, reason}` forensics record is emitted to the sink,
   with `ua_summary` truncated to 64 characters (`UA_SUMMARY_MAX_LENGTH`)
   and `reason` ∈ {`parse_error`, `empty_fallback`}.

If no log channel is wired in, the empty mount itself remains the
observable degradation evidence (empty family headers / `degraded` fields
in `X-Ua-Info`).

## Version range

- **Tested against crescent 0.11.x** — dependency pinned to
  `bobzhang/crescent@0.11.1` in `moon.mod` (upstream commit
  `d99287ae409d198e1f7c1fd606e4883188d97c02`, `moon.mod` version 0.11.1).
- `vicoproplus/moon_ua_parser@0.2.0`,
  `vicoproplus/moon_ua_parser_middleware_core@0.1.0` (workspace-resolved),
  `moonbitlang/async@0.20.3` (crescent's own requirement).
- Toolchain: moon 0.1.20260904, `--target native`
  (`supported_targets = "-all+native"` — wasm deliberately NOT declared:
  the adapter has no wasm build/test evidence yet (local wasm-gc runtime
  broken; CI wasm gate covers the lib only). Re-declare `+wasm` together
  with a CI wasm build/test step for this package).

## Example (one command)

From the workspace root:

```bash
moon run moon_ua_parser_crescent/examples/ua_echo --target native
```

Dispatches four requests through a real `App` (three real UAs + one
malformed synthetic UA) and prints, per request, the status, the three
browser/os/device groups and the handler-side read-back; the degraded
request additionally shows the default console forensics line. Captured
output: `docs/evidence/mw1-example-2026-09-13.log`.

## Tests

```bash
moon test --target native -p moon_ua_parser_crescent
```

Integration tests drive a real crescent `App` through the framework's own
network-free `test_client`, asserting uap-core golden cases (citations in
`integration_test.mbt`) and the malformed-UA degradation triple
(not-5xx / empty mount / forensics retrievable from an injected sink).
