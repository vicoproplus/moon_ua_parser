// Thin mizchi/mars middleware adapter (T-05) for the
// vicoproplus/moon_ua_parser library.
//
// Responsibility boundary (plan R2 — four duties only, zero inlined
// business semantics):
//
// 1. Registration adaptation — `middleware()` builds a mars `Handler`
//    (`async (Context) -> Unit`, Hono-style sequential chain) for
//    `Server::middleware`.
// 2. Request-entry helper call — the middleware reads the `User-Agent`
//    request header and calls
//    `@middleware_core.assemble(ua, @ua_parser.parse(ua))`. Assembly,
//    degradation judgment and forensics-record construction all live in
//    `vicoproplus/moon_ua_parser_middleware_core` (T-03); nothing is
//    re-implemented in this file.
// 3. Context mounting — the three mounted groups (browser / os / device
//    families of the assembled `UaInfo`) are written to mars's typed
//    `Variables` request store (`ctx.vars`, the framework's own custom
//    key-value context) BEFORE the route handler runs — see "Mounting
//    mechanism" in README.mbt.md for why families beat a JSON round-trip
//    here: mars `Variables::set` serializes every value through the
//    `Var` trait to `Json` and `Variables::get` returns `Json?`
//    (env.mbt:82-100/140-166, verified against upstream commit ff4485e0),
//    so a full `UaInfo` mount would need a ~165-line JSON transport codec,
//    while the three families are natively storable `Var::String` values
//    with zero serialization. The mount therefore carries exactly the
//    browser/os/device three-group contract of plan R3.
// 4. Log-channel adaptation — a degraded request's `ForensicsRecord` is
//    forwarded to an injectable sink (default `console_forensics_sink`,
//    one console line via `println`). mars DOES ship a logger middleware
//    (`@mars/middleware.logger()` / `logger_simple()`, verified against
//    upstream commit ff4485e0: logger.mbt:114/162) whose output sink is
//    also `println` (logger.mbt:145/166) — the default sink is the same
//    channel, so forensics lines and the framework's own request logs
//    share one console stream; applications can inject any other backend.
//
// Degradation behavior (spec §3, implemented entirely by the helper): a
// parse `Err` or an all-three-families-at-fallback result mounts the EMPTY
// `UaInfo` (empty-string families), never raises into the request chain,
// and emits `{ua_summary, reason}` forensics to the sink. The response
// therefore keeps its normal (non-5xx) status with empty families on the
// mount.

///|
/// Typed-`Variables` key carrying the mounted browser family.
pub const KEY_UA_BROWSER : String = "ua_parser.browser"

///|
/// Typed-`Variables` key carrying the mounted OS family.
pub const KEY_UA_OS : String = "ua_parser.os"

///|
/// Typed-`Variables` key carrying the mounted device family.
pub const KEY_UA_DEVICE : String = "ua_parser.device"

///|
/// Prefix of the default console forensics line (FO channel).
pub const FORENSICS_LOG_PREFIX : String = "[moon_ua_parser]"

///|
/// Default FO channel: one console line per degraded request.
///
/// Format: `<FORENSICS_LOG_PREFIX> degraded user-agent parse: reason=<reason> ua_summary="<ua_summary>"`
/// where `ua_summary` is already truncated to
/// `UA_SUMMARY_MAX_LENGTH` characters by the helper. `println` is the same
/// output sink mars's own logger middleware uses (upstream logger.mbt:145),
/// so this line lands on the framework's log channel.
pub fn console_forensics_sink(rec : @middleware_core.ForensicsRecord) -> Unit {
  println(
    "\{FORENSICS_LOG_PREFIX} degraded user-agent parse: reason=\{rec.reason} ua_summary=\"\{rec.ua_summary}\"",
  )
}

///|
/// Registration adapter: builds the UA-parser middleware for
/// `Server::middleware`.
///
/// The middleware, per request:
/// 1. reads the `User-Agent` request header (missing header = empty
///    string; the helper's semantics decide what that mounts);
/// 2. calls `@middleware_core.assemble(ua, @ua_parser.parse(ua))`;
/// 3. mounts `outcome.ua_info`'s three families on `ctx.vars` before the
///    route handler runs;
/// 4. forwards `outcome.forensics` (iff degraded) to the sink.
///
/// `forensics_sink` defaults to `console_forensics_sink` when omitted.
pub fn middleware(
  forensics_sink? : (@middleware_core.ForensicsRecord) -> Unit,
) -> @mars.Handler {
  let sink = forensics_sink.unwrap_or(console_forensics_sink)
  ctx => {
    let ua = request_user_agent(ctx)
    let outcome = @middleware_core.assemble(ua, @ua_parser.parse(ua))
    mount(ctx, outcome.ua_info)
    match outcome.forensics {
      Some(rec) => sink(rec)
      None => ()
    }
  }
}

///|
/// Handler-side read-back: the `UaInfo` mounted for this request,
/// reconstructed from the typed `Variables` mount. `None` when the
/// middleware is not registered upstream (no mount keys present).
///
/// Mount contract: the mars mount carries the three group families
/// (browser / os / device). The version, brand, model and `rule_index`
/// fields of the returned `UaInfo` are `None` by construction — they are
/// not part of the mount (see the mounting-mechanism note in the file
/// header). On degradation the reconstruction is structurally equal to
/// `@middleware_core.empty_ua_info()` (empty families, `None` elsewhere),
/// so callers can distinguish "middleware had nothing" (`Some(empty)`)
/// from "middleware not registered" (`None`).
pub fn mounted_ua_info(ctx : @mars.Context) -> @ua_parser.UaInfo? {
  let browser = mounted_family(ctx, KEY_UA_BROWSER)
  let os = mounted_family(ctx, KEY_UA_OS)
  let device = mounted_family(ctx, KEY_UA_DEVICE)
  match (browser, os, device) {
    (Some(browser_family), Some(os_family), Some(device_family)) =>
      Some({
        browser: {
          family: browser_family,
          major: None,
          minor: None,
          patch: None,
          patch_minor: None,
          rule_index: None,
        },
        os: {
          family: os_family,
          major: None,
          minor: None,
          patch: None,
          patch_minor: None,
          rule_index: None,
        },
        device: {
          family: device_family,
          brand: None,
          model: None,
          rule_index: None,
        },
      })
    _ => None
  }
}

///|
/// Read the `User-Agent` request header with a case-pair lookup.
///
/// Why two lookups: mars `Context::header` is an exact-case map lookup
/// (context.mbt:58-60, upstream ff4485e0) while the mizchi/x native
/// transport lowercases request-header keys when building the framework
/// request (`http_native.mbt to_request`). Trying the canonical
/// `User-Agent` spelling first keeps the adapter correct on transports
/// that preserve case; the lowercase fallback covers the native stack.
/// Missing header = empty string (the helper's degradation semantics
/// decide what an empty UA mounts).
fn request_user_agent(ctx : @mars.Context) -> String {
  match ctx.header("User-Agent") {
    Some(ua) => ua
    None =>
      match ctx.header("user-agent") {
        Some(ua) => ua
        None => ""
      }
  }
}

///|
/// Mount `info`'s three families on the request context (duty 3). Pure
/// `Variables::set` writes with `Var::String` values — no serialization —
/// before the route handler runs, so every downstream handler sees the
/// mount via `mounted_ua_info` / the raw `ctx.vars` store.
fn mount(ctx : @mars.Context, info : @ua_parser.UaInfo) -> Unit {
  ctx.vars.set(KEY_UA_BROWSER, info.browser.family)
  ctx.vars.set(KEY_UA_OS, info.os.family)
  ctx.vars.set(KEY_UA_DEVICE, info.device.family)
}

///|
/// Read one mounted family back from the typed `Variables` store.
/// `Variables::get` returns `Json?` (`Var::String` values are stored as
/// `Json::String`); `None` when the middleware did not run for this
/// request (key absent) or the stored value is not a JSON string.
fn mounted_family(ctx : @mars.Context, key : String) -> String? {
  match ctx.vars.get(key) {
    Some(Json::String(family)) => Some(family)
    _ => None
  }
}
