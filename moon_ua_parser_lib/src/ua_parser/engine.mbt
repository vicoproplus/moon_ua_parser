// Shared loop plumbing and no-match fallbacks for the matching engine.
//
// Engine structure (uap-python authority):
// - Per domain, rules are tried in upstream order and the FIRST rule whose
//   regex matches wins (`Resolver.__call__`, basic.py:55-84, via
//   `next(filter(None, ...))`).
// - When no rule matches, the domain reports the "Other" fallback:
//   `family = "Other"` and every other field `None` (`Result.with_defaults`
//   / dataclass defaults, core.py:22-49,74-92).

///|
/// Scan a domain's rules in order and return the index of the first rule
/// whose precompiled regex matches `ua`, together with the match result.
/// `rules` and `regexps` are index-aligned (T-04/T-05 invariant).
fn first_match(
  rules_length : Int,
  regexps : Array[@regexp.Regexp],
  ua : String,
) -> (Int, @regexp.MatchResult)? {
  for i = 0; i < rules_length; i = i + 1 {
    let m = regexps[i].execute(ua)
    if m.matched() {
      return Some((i, m))
    }
  }
  return None
}

///|
/// The all-miss browser fallback: family `"Other"`, no version segments.
/// No rule produced it, so `rule_index` is `None` even under
/// `with_rule_index=true` (T-09).
fn other_browser() -> Browser {
  {
    family: "Other",
    major: None,
    minor: None,
    patch: None,
    patch_minor: None,
    rule_index: None,
  }
}

///|
/// The all-miss OS fallback: family `"Other"`, no version segments.
/// No rule produced it, so `rule_index` is `None` even under
/// `with_rule_index=true` (T-09).
fn other_os() -> OS {
  {
    family: "Other",
    major: None,
    minor: None,
    patch: None,
    patch_minor: None,
    rule_index: None,
  }
}

///|
/// The all-miss device fallback: family `"Other"`, no brand or model.
/// No rule produced it, so `rule_index` is `None` even under
/// `with_rule_index=true` (T-09).
fn other_device() -> Device {
  { family: "Other", brand: None, model: None, rule_index: None, }
}
