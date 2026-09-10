// Public API of the ua_parser package (T-06).
//
// `parse` aggregates the three domains (browser, OS, device); the single-
// domain functions share the same rule scan. The `Result` contract on
// `parse` is kept for future failure modes: with the precompiled rule set
// (rules package, initialized lazily on first access) parsing itself cannot
// fail, so `parse` never returns `Err` in practice and no artificial
// failure is invented.

///|
/// Parse a user-agent string into its browser, OS and device components.
///
/// Semantics follow uap-python: per domain, rules are tried in order and
/// the first match wins; a domain whose rules all miss reports family
/// `"Other"` with every other field `None`. Parsing never fails with the
/// precompiled rule set, so the returned `Result` is always `Ok` today.
///
/// Example: `parse("Mozilla/5.0 (Windows NT 10.0; Win64; x64)
/// AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")`
/// yields `Ok` with browser `Chrome` 120.0.0, OS `Windows` 10, and device
/// family `"Other"`.
pub fn parse(ua : String) -> Result[UaInfo, UaError] {
  Ok({ browser: parse_browser(ua), os: parse_os(ua), device: parse_device(ua), })
}

///|
/// Parse only the browser (user-agent) component.
///
/// First matching UA rule wins; family comes from the rule's family
/// template (literal or `$1` substitution), and the version segments fall
/// back to capture groups 2/3/4 (missing or empty group -> `None`). When no
/// rule matches, family is `"Other"` and all versions are `None`.
///
/// Example: `parse_browser("Mozilla/5.0 (Windows NT 10.0; Win64; x64)
/// AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")`
/// yields family `"Chrome"`, major `"120"`, minor `"0"`, patch `"0"`.
pub fn parse_browser(ua : String) -> Browser {
  match_browser(ua)
}

///|
/// Parse only the operating-system component.
///
/// First matching OS rule wins; each of the four version segments evaluates
/// its template (or falls back to capture groups 2..5) under uap-python
/// `replacer` semantics: the whole substituted template is stripped once and
/// an empty result becomes `None`. When no rule matches, family is `"Other"`
/// and all versions are `None`.
///
/// Example: `parse_os("Mozilla/5.0 (Windows NT 10.0; Win64; x64)
/// AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")`
/// yields family `"Windows"`, major `"10"`, and `None` for the rest.
pub fn parse_os(ua : String) -> OS {
  match_os(ua)
}

///|
/// Parse only the device component.
///
/// First matching device rule wins; family falls back to capture group 1,
/// brand comes only from a brand template (no group fallback — absent
/// template means `None`), and model falls back to capture group 1. When no
/// rule matches, family is `"Other"` and brand/model are `None`.
///
/// Example: `parse_device("Mozilla/5.0 (iPhone; CPU iPhone OS 14_3 like Mac
/// OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.3 Mobile/15E148
/// DuckDuckGo/7 Safari/605.1.15")` yields family `"iPhone"`, brand
/// `"Apple"`, model `"iPhone"`.
pub fn parse_device(ua : String) -> Device {
  match_device(ua)
}
