// Per-domain matchers: derive the Browser / OS / Device result for a
// user-agent string from the generated rule data and precompiled regexps.
//
// Semantics per uap-python (snapshot 6dd8c39):
// - UA domain (matchers.py UserAgentMatcher, L39-52): on regex match the
//   result is produced unconditionally — first regex match wins even if the
//   derived family is empty (the modern `Resolver.__call__` only filters
//   `None`, and a populated record is always truthy).
// - OS / Device domains (matchers.py OSMatcher/DeviceMatcher, L100-112 /
//   L157-167): first regex match wins as well. Upstream raises ValueError
//   when the family template evaluates to `None`, which no uap-core rule
//   can trigger; we mirror the legacy reference loops instead
//   (user_agent_parser.py `_ParseOS`/`_ParseDevice`, L290-302/L321-330:
//   `if os/device: break`) by skipping such a rule and continuing the scan
//   — same observable behavior on all real data, without the crash.

///|
/// Match the browser (user-agent) domain: first matching rule wins; derive
/// family via the raw-template flavor and versions via get-flavor fallbacks
/// to capture groups 2/3/4/5 (matchers.py:47-50, `or get(m, n)` chain). No
/// match -> `"Other"` browser.
///
/// T-09: when `want_index` is true the result carries `rule_index =
/// Some(i)` for the winning rule (0-based, uap-core rule order); otherwise
/// the field is `None`, keeping default-off results byte-identical to
/// pre-T-09 output.
fn match_browser(ua : String, want_index : Bool) -> Browser {
  match first_match(@rules.ua_rules.length(), @rules.ua_regexps, ua) {
    Some((index, m)) => {
      let rule = @rules.ua_rules[index]
      {
        family: eval_ua_family(rule.family, m),
        major: eval_ua_version(rule.v1, 2, m),
        minor: eval_ua_version(rule.v2, 3, m),
        patch: eval_ua_version(rule.v3, 4, m),
        patch_minor: eval_ua_version(rule.v4, 5, m),
        rule_index: if want_index { Some(index) } else { None },
      }
    }
    None => other_browser()
  }
}

///|
/// Match the OS domain: first matching rule wins; every field evaluates its
/// template (or falls back to capture groups 1..5) under replacer
/// semantics. No match (or only rules with empty-derived family) ->
/// `"Other"` OS. `rule_index` (T-09) names the rule that actually produced
/// the result — a matching rule skipped for an empty-derived family is not
/// reported; `None` unless `want_index` is true.
fn match_os(ua : String, want_index : Bool) -> OS {
  for i = 0; i < @rules.os_rules.length(); i = i + 1 {
    let m = @rules.os_regexps[i].execute(ua)
    if m.matched() {
      let rule = @rules.os_rules[i]
      match eval_field(rule.family, 1, m) {
        Some(family) =>
          return {
            family,
            major: eval_field(rule.v1, 2, m),
            minor: eval_field(rule.v2, 3, m),
            patch: eval_field(rule.v3, 4, m),
            patch_minor: eval_field(rule.v4, 5, m),
            rule_index: if want_index { Some(i) } else { None },
          }
        // Matched rule cannot produce a family: skip and keep scanning
        // (see module comment — mirrors the legacy `if os: break` loop).
        None => continue
      }
    }
  }
  other_os()
}

///|
/// Match the device domain: first matching rule wins; family falls back to
/// capture group 1, brand has NO group fallback (absent template ->
/// `None`, matchers.py:154,164), model falls back to capture group 1. No
/// match -> `"Other"` device. `rule_index` (T-09) names the rule that
/// actually produced the result — a matching rule skipped for an
/// empty-derived family is not reported; `None` unless `want_index` is
/// true.
fn match_device(ua : String, want_index : Bool) -> Device {
  for i = 0; i < @rules.device_rules.length(); i = i + 1 {
    let m = @rules.device_regexps[i].execute(ua)
    if m.matched() {
      let rule = @rules.device_rules[i]
      match eval_field(rule.family, 1, m) {
        Some(family) => {
          // Brand: template present -> replacer evaluation (empty -> None);
          // template absent -> None unconditionally (upstream `brand or ""`
          // makes `replacer("")` always return None).
          let brand = match rule.brand {
            Some(parts) => eval_template(parts, m)
            None => None
          }
          let model = eval_field(rule.model, 1, m)
          return {
            family,
            brand,
            model,
            rule_index: if want_index { Some(i) } else { None },
          }
        }
        // Matched rule cannot produce a family: skip and keep scanning
        // (see module comment — mirrors the legacy `if device: break` loop).
        None => continue
      }
    }
  }
  other_device()
}
