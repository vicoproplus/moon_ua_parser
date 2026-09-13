// Thin bobzhang/crescent middleware adapter (T-04) for the
// vicoproplus/moon_ua_parser library.
//
// Responsibility boundary (plan R2 — four duties only, zero inlined
// business semantics):
//
// 1. Registration adaptation — `middleware()` builds a crescent
//    `Middleware` (`async (Event, MiddlewareNext) -> &Responder`, onion
//    model) for `App::use_middleware`.
// 2. Request-entry helper call — the middleware reads the `User-Agent`
//    request header and calls
//    `@middleware_core.assemble(ua, @ua_parser.parse(ua))`. Assembly,
//    degradation judgment and forensics-record construction all live in
//    `vicoproplus/moon_ua_parser_middleware_core` (T-03); nothing is
//    re-implemented in this file.
// 3. Context mounting — the assembled `UaInfo` is mounted on
//    `event.res.headers` BEFORE `next()` (see "Mounting mechanism" in
//    README.mbt.md for why res.headers beats the request_id-map bypass):
//    one JSON round-trip header carrying the full `UaInfo`
//    (`HEADER_UA_INFO`) plus one family header per domain
//    (`HEADER_UA_BROWSER` / `HEADER_UA_OS` / `HEADER_UA_DEVICE`). Because
//    crescent's `Event` is a shared mutable record and `App::dispatch`
//    finalizes the response from `event.res`, downstream handlers can read
//    the mount during the request (`mounted_ua_info`) and clients/tests can
//    read the very same values from the response headers.
// 4. Log-channel adaptation — a degraded request's `ForensicsRecord` is
//    forwarded to an injectable sink (default `console_forensics_sink`,
//    one console line). bobzhang/crescent ships no logger middleware
//    (verified against the walkthrough snapshot at upstream commit
//    d99287ae: `middleware/pkg.generated.mbti` exports only rate_limit /
//    request_id / security_headers), so the injectable sink IS the
//    forensics (FO) channel adaptation.
//
// Degradation behavior (spec §3, implemented entirely by the helper): a
// parse `Err` or an all-three-families-at-fallback result mounts the EMPTY
// `UaInfo` (empty-string families), never raises into the request chain,
// and emits `{ua_summary, reason}` forensics to the sink. The response
// therefore keeps its normal (non-5xx) status with empty family headers.

///|
/// Response-header name carrying the JSON round-trip of the mounted
/// `UaInfo` (see `ua_info_to_json` for the transport schema).
pub const HEADER_UA_INFO : String = "X-Ua-Info"

///|
/// Response-header name carrying the mounted browser family.
pub const HEADER_UA_BROWSER : String = "X-Ua-Browser"

///|
/// Response-header name carrying the mounted OS family.
pub const HEADER_UA_OS : String = "X-Ua-Os"

///|
/// Response-header name carrying the mounted device family.
pub const HEADER_UA_DEVICE : String = "X-Ua-Device"

///|
/// Prefix of the default console forensics line (FO channel).
pub const FORENSICS_LOG_PREFIX : String = "[moon_ua_parser]"

///|
/// Forensics output channel type: `(@middleware_core.ForensicsRecord) -> Unit`.
/// Injectable so tests can capture records (`integration_test.mbt`) and
/// applications can forward them to any logging backend; the default is
/// `console_forensics_sink`. (Spelled inline at use sites — this toolchain
/// build does not support `typealias` declarations.)

///|
/// Default FO channel: one console line per degraded request.
///
/// Format: `<FORENSICS_LOG_PREFIX> degraded user-agent parse: reason=<reason> ua_summary="<ua_summary>"`
/// where `ua_summary` is already truncated to
/// `UA_SUMMARY_MAX_LENGTH` characters by the helper.
pub fn console_forensics_sink(rec : @middleware_core.ForensicsRecord) -> Unit {
  println(
    "\{FORENSICS_LOG_PREFIX} degraded user-agent parse: reason=\{rec.reason} ua_summary=\"\{rec.ua_summary}\"",
  )
}

///|
/// Registration adapter: builds the UA-parser middleware for
/// `App::use_middleware`.
///
/// The middleware, per request:
/// 1. reads the `User-Agent` request header (missing header = empty
///    string; the helper's semantics decide what that mounts);
/// 2. calls `@middleware_core.assemble(ua, @ua_parser.parse(ua))`;
/// 3. mounts `outcome.ua_info` on `event.res.headers` before `next()`;
/// 4. forwards `outcome.forensics` (iff degraded) to the sink.
///
/// `forensics_sink` defaults to `console_forensics_sink` when omitted.
pub fn middleware(
  forensics_sink? : (@middleware_core.ForensicsRecord) -> Unit,
) -> @crescent.Middleware {
  let sink = forensics_sink.unwrap_or(console_forensics_sink)
  (event, next) => {
    let ua = event.req.get_header("User-Agent").unwrap_or("")
    let outcome = @middleware_core.assemble(ua, @ua_parser.parse(ua))
    mount(event, outcome.ua_info)
    match outcome.forensics {
      Some(rec) => sink(rec)
      None => ()
    }
    next()
  }
}

///|
/// Handler-side read-back: the `UaInfo` mounted for this request, parsed
/// from the middleware's JSON header on `event.res.headers`. `None` when
/// the middleware is not registered upstream or the header was removed /
/// is not valid transport JSON.
pub fn mounted_ua_info(event : @crescent.Event) -> @ua_parser.UaInfo? {
  match event.res.headers.get(HEADER_UA_INFO) {
    Some(value) => parse_mounted_ua_info(value)
    None => None
  }
}

///|
/// Client-side read-back: parse a `HEADER_UA_INFO` header value (e.g. from
/// a `TestResponse.headers` map or an HTTP client's response headers) back
/// into the mounted `UaInfo`. `None` on absent/invalid transport JSON.
pub fn parse_mounted_ua_info(header_value : String) -> @ua_parser.UaInfo? {
  let json = @json.parse(header_value) catch { _ => return None }
  ua_info_from_json(json)
}

///|
/// Mount `info` on the request context (duty 3). Pure header writes on the
/// shared `event.res` — before `next()`, so handlers see it and
/// `App::dispatch` finalizes the response from the same record.
fn mount(event : @crescent.Event, info : @ua_parser.UaInfo) -> Unit {
  let headers = event.res.headers
  headers.set(HEADER_UA_BROWSER, info.browser.family)
  headers.set(HEADER_UA_OS, info.os.family)
  headers.set(HEADER_UA_DEVICE, info.device.family)
  headers.set(HEADER_UA_INFO, ua_info_to_json(info).stringify())
}

///|
/// Transport schema (adapter-owned, mechanical field copying — no business
/// semantics): `{"browser":D,"os":D,"device":D}` where a versioned domain
/// `D` is `{"family":String,"major":S?,"minor":S?,"patch":S?,"patch_minor":S?,"rule_index":N?}`,
/// and the device domain replaces the four version fields with
/// `{"brand":S?,"model":S?}`. `S?` is a JSON string or null, `N?` a JSON
/// number or null. All fields round-trip exactly, so
/// `parse_mounted_ua_info(ua_info_to_json(info).stringify()) == Some(info)`.
fn ua_info_to_json(info : @ua_parser.UaInfo) -> Json {
  Json::object({
    "browser": versioned_domain_to_json(
      family=info.browser.family,
      v1=info.browser.major,
      v2=info.browser.minor,
      v3=info.browser.patch,
      v4=info.browser.patch_minor,
      rule_index=info.browser.rule_index,
    ),
    "os": versioned_domain_to_json(
      family=info.os.family,
      v1=info.os.major,
      v2=info.os.minor,
      v3=info.os.patch,
      v4=info.os.patch_minor,
      rule_index=info.os.rule_index,
    ),
    "device": Json::object({
      "family": Json::string(info.device.family),
      "brand": optional_string_to_json(info.device.brand),
      "model": optional_string_to_json(info.device.model),
      "rule_index": optional_int_to_json(info.device.rule_index),
    }),
  })
}

///|
/// One browser/OS domain of the transport schema (labeled arguments keep
/// the mechanical copy readable).
fn versioned_domain_to_json(
  family~ : String,
  v1~ : String?,
  v2~ : String?,
  v3~ : String?,
  v4~ : String?,
  rule_index~ : Int?,
) -> Json {
  Json::object({
    "family": Json::string(family),
    "major": optional_string_to_json(v1),
    "minor": optional_string_to_json(v2),
    "patch": optional_string_to_json(v3),
    "patch_minor": optional_string_to_json(v4),
    "rule_index": optional_int_to_json(rule_index),
  })
}

///|
fn optional_string_to_json(value : String?) -> Json {
  match value {
    Some(s) => Json::string(s)
    None => Json::null()
  }
}

///|
fn optional_int_to_json(value : Int?) -> Json {
  match value {
    Some(n) => Json::number(n.to_double())
    None => Json::null()
  }
}

///|
/// Inverse of `ua_info_to_json`; `None` when the JSON does not match the
/// transport schema.
fn ua_info_from_json(json : Json) -> @ua_parser.UaInfo? {
  match json {
    Json::Object(obj) => {
      let browser = match object_domain(obj, "browser") {
        Some(domain) => versioned_domain_from_json(domain)
        None => None
      }
      let os = match object_domain(obj, "os") {
        Some(domain) => os_domain_from_json(domain)
        None => None
      }
      let device = match object_domain(obj, "device") {
        Some(domain) => device_domain_from_json(domain)
        None => None
      }
      match (browser, os, device) {
        (Some(browser), Some(os), Some(device)) =>
          Some({ browser, os, device, })
        _ => None
      }
    }
    _ => None
  }
}

///|
fn object_domain(obj : Map[String, Json], key : String) -> Map[String, Json]? {
  match obj.get(key) {
    Some(Json::Object(domain)) => Some(domain)
    _ => None
  }
}

///|
fn versioned_domain_from_json(obj : Map[String, Json]) -> @ua_parser.Browser? {
  match obj.get("family") {
    Some(Json::String(family)) =>
      Some({
        family,
        major: json_string(obj, "major"),
        minor: json_string(obj, "minor"),
        patch: json_string(obj, "patch"),
        patch_minor: json_string(obj, "patch_minor"),
        rule_index: json_int(obj, "rule_index"),
      })
    _ => None
  }
}

///|
/// OS reconstruction mirrors the browser field layout (`Browser` and `OS`
/// are structurally identical but distinct types).
fn os_domain_from_json(obj : Map[String, Json]) -> @ua_parser.OS? {
  match obj.get("family") {
    Some(Json::String(family)) =>
      Some({
        family,
        major: json_string(obj, "major"),
        minor: json_string(obj, "minor"),
        patch: json_string(obj, "patch"),
        patch_minor: json_string(obj, "patch_minor"),
        rule_index: json_int(obj, "rule_index"),
      })
    _ => None
  }
}

///|
/// Device reconstruction mirrors the browser/OS field layout
/// (family/brand/model/rule_index); returns a `Device`.
fn device_domain_from_json(obj : Map[String, Json]) -> @ua_parser.Device? {
  match obj.get("family") {
    Some(Json::String(family)) =>
      Some({
        family,
        brand: json_string(obj, "brand"),
        model: json_string(obj, "model"),
        rule_index: json_int(obj, "rule_index"),
      })
    _ => None
  }
}

///|
fn json_string(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(Json::String(s)) => Some(s)
    _ => None
  }
}

///|
fn json_int(obj : Map[String, Json], key : String) -> Int? {
  match obj.get(key) {
    Some(Json::Number(n, ..)) => Some(n.to_int())
    _ => None
  }
}
