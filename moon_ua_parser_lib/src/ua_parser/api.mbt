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
///
/// T-09 — `with_rule_index` (optional, default `false`): when true, each
/// component's `rule_index` is `Some(i)` where `i` is the 0-based position
/// of the rule that produced that component within its domain's rule list
/// (`@rules.ua_rules` / `@rules.os_rules` / `@rules.device_rules`, i.e. the
/// uap-core `regexes.yaml` rule order for `user_agent_parsers` /
/// `os_parsers` / `device_parsers`). A domain whose rules all miss reports
/// `rule_index: None` — the `"Other"` fallback is not produced by any
/// rule. The index is diagnostic metadata only: parsing behavior is
/// identical with and without it. With the default `with_rule_index=false`
/// every `rule_index` is `None`, so results are byte-identical to
/// pre-T-09 output (backward-compatible: `parse(ua)` keeps its meaning).
pub fn parse(
  ua : String,
  with_rule_index? : Bool = false,
) -> Result[UaInfo, UaError] {
  Ok({
    browser: match_browser(ua, with_rule_index),
    os: match_os(ua, with_rule_index),
    device: match_device(ua, with_rule_index),
  })
}

///|
/// Parse only the browser (user-agent) component.
///
/// First matching UA rule wins; family comes from the rule's family
/// template (literal or `$1` substitution), and the version segments fall
/// back to capture groups 2/3/4/5 (missing or empty group -> `None`). When
/// no rule matches, family is `"Other"` and all versions are `None`.
///
/// Example: `parse_browser("Mozilla/5.0 (Windows NT 10.0; Win64; x64)
/// AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")`
/// yields family `"Chrome"`, major `"120"`, minor `"0"`, patch `"0"`,
/// patch_minor `"0"`.
///
/// T-09: this entry point never requests rule indices, so the returned
/// `rule_index` is always `None` (the diagnostic index is available via
/// `parse(ua, with_rule_index=true)`).
pub fn parse_browser(ua : String) -> Browser {
  match_browser(ua, false)
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
///
/// T-09: this entry point never requests rule indices, so the returned
/// `rule_index` is always `None` (the diagnostic index is available via
/// `parse(ua, with_rule_index=true)`).
pub fn parse_os(ua : String) -> OS {
  match_os(ua, false)
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
///
/// T-09: this entry point never requests rule indices, so the returned
/// `rule_index` is always `None` (the diagnostic index is available via
/// `parse(ua, with_rule_index=true)`).
pub fn parse_device(ua : String) -> Device {
  match_device(ua, false)
}
