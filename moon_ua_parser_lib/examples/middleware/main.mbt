// Middleware-style example for the moon_ua_parser library (T-10).
//
// Simulates a request-entry middleware: each incoming request carries a
// User-Agent header, which is parsed once and summarized per domain
// (browser / os / device) plus a bot verdict. The verdict follows uap-core
// semantics: catch-all spider rules report the device family "Spider", so
// `device.family == "Spider"` is the detection test.
//
// Only the public API is used (`@ua_parser.parse` with the optional
// `with_rule_index` flag); no library internals.
//
// Every UA string below is copied verbatim from this repo's own suites so
// the expected output is pre-documented:
//   #1 Chrome desktop - tests/semantics (Chrome 120.0.0.0 / Windows 10 /
//      device fallback "Other", rule indices 280 / 47 / none)
//   #2 iPhone Safari  - tests/differential (Mobile Safari 9.0 / iOS 9.3.1 /
//      iPhone, Apple, iPhone); the '+'-encoded form is the URL-encoded
//      shape in which this UA appears in real access logs
//   #3 Googlebot      - tests/semantics (Googlebot 2.1 / OS fallback "Other" /
//      device Spider, Spider, Desktop)
//
// Run from the moon project root:
//   moon run --target native examples/middleware

///|
/// One simulated request reaching the middleware entry point.
struct Request {
  route : String
  user_agent : String
}

///|
/// Join the available version segments with "." (missing segments are
/// skipped, matching uap-python's version join; "-" when none remain).
fn dotted(parts : Array[String?]) -> String {
  let buf = StringBuilder()
  let mut first = true
  for part in parts {
    match part {
      Some(v) => {
        if !first {
          buf.write_string(".")
        }
        buf.write_string(v)
        first = false
      }
      None => ()
    }
  }
  let s = buf.to_string()
  if s == "" {
    "-"
  } else {
    s
  }
}

///|
/// "Family major.minor" when a version exists, bare family otherwise.
fn family_with_version(family : String, parts : Array[String?]) -> String {
  let v = dotted(parts)
  if v == "-" {
    family
  } else {
    "\{family} \{v}"
  }
}

///|
/// Optional field rendered for the summary line ("-" instead of None).
fn opt(v : String?) -> String {
  match v {
    Some(s) => s
    None => "-"
  }
}

///|
/// Rule index rendered for the debug line ("none" when no rule matched).
fn idx(v : Int?) -> String {
  match v {
    Some(i) => "#\{i}"
    None => "none"
  }
}

///|
/// Handle one simulated request: parse and print the per-domain summary.
fn handle(id : Int, req : Request) -> Unit {
  println("[request #\{id}] \{req.route}")
  println("  User-Agent: \{req.user_agent}")
  match @ua_parser.parse(req.user_agent) {
    Ok(info) => {
      let b = info.browser
      println(
        "  Browser: \{family_with_version(b.family, [b.major, b.minor, b.patch, b.patch_minor])}",
      )
      let o = info.os
      println(
        "  OS     : \{family_with_version(o.family, [o.major, o.minor, o.patch, o.patch_minor])}",
      )
      let d = info.device
      println("  Device : \{d.family} / \{opt(d.brand)} / \{opt(d.model)}")
      // Bot detection per uap-core semantics: catch-all spider rules
      // report the device family "Spider".
      let is_spider = d.family == "Spider"
      println("  Spider : \{is_spider}")
    }
    Err(_) => println("  parse error (unreachable: rules are precompiled)")
  }
}

///|
/// Debug view for one request: which uap-core rule won per domain
/// (`parse` with `with_rule_index = true`; index 0-based, file order).
fn rule_debug(id : Int, req : Request) -> Unit {
  match @ua_parser.parse(req.user_agent, with_rule_index=true) {
    Ok(info) =>
      println(
        "[request #\{id}] rule-index debug: browser=\{idx(info.browser.rule_index)} os=\{idx(info.os.rule_index)} device=\{idx(info.device.rule_index)}",
      )
    Err(_) => println("  parse error (unreachable: rules are precompiled)")
  }
}

///|
fn main {
  let requests = [
    Request::{
      route: "GET /api/v1/users",
      user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    },
    Request::{
      route: "GET /feed",
      user_agent: "Mozilla/5.0+(iPhone;+CPU+iPhone+OS+9_3_1+like+Mac+OS+X)+AppleWebKit/601.1.46+(KHTML,+like+Gecko)+Version/9.0+Mobile/13E238+Safari/601.1",
    },
    Request::{
      route: "GET /robots.txt",
      user_agent: "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
    },
  ]
  println("moon_ua_parser middleware demo - \{requests.length()} simulated requests")
  for i, req in requests {
    handle(i + 1, req)
  }
  rule_debug(1, requests[0])
}
