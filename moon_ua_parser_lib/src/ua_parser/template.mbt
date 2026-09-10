// Template and capture-group evaluation for the matching engine.
//
// Semantics mirror the uap-python snapshot (uap-python/ 6dd8c39, read-only
// authority) exactly:
//
// - `utils.get` (utils.py:8-9): a group reference yields `None` when the
//   index is out of range or the group did not participate in the match,
//   and also `None` when the group captured the empty string
//   (`m[idx] or None`).
// - `utils.replacer` (utils.py:12-33): absent/empty template -> `None`;
//   otherwise every `$N` is substituted with `get(m, N) or ""` (a missing
//   group contributes the empty string), then the WHOLE substituted result
//   is stripped once, and an empty result becomes `None`. Strip is applied
//   to the final template result only — never to individual group values.
// - The UA (browser) family has bespoke semantics (utils.py:23-27,
//   matchers.py:41-45): the family template is a literal or `$1`
//   substitution with the raw group value; it is NOT stripped and an empty
//   result stays empty (no `None` transition). Generated data keeps the
//   invariant that UA family templates only ever reference `Group(1)`.
//
// Whitespace note: Python `str.strip()` removes Unicode whitespace; MoonBit
// `StringView::trim` removes the ASCII set "\t\n\r ". Every group value and
// template in uap-core is ASCII around its whitespace, so the two agree on
// all real data.

///|
/// Read capture group `n` of `m` with uap-python `utils.get` semantics:
/// `None` when the group is out of range, did not participate, or captured
/// the empty string; the owned captured text otherwise.
fn get_group(m : @regexp.MatchResult, n : Int) -> String? {
  match m.get(n) {
    Some(view) => if view.is_empty() { None } else { Some(view.to_owned()) }
    None => None
  }
}

///|
/// Evaluate a present replacement template, mirroring `utils.replacer`:
/// substitute each `Group(n)` with the raw captured text (a missing or
/// empty group contributes the empty string), strip the whole result once,
/// and return `None` when nothing remains.
fn eval_template(
  parts : Array[@rules.TemplatePart],
  m : @regexp.MatchResult,
) -> String? {
  let buf = StringBuilder()
  for part in parts {
    match part {
      @rules.Literal(text) => buf.write_string(text)
      @rules.Group(n) =>
        // `get` returns `None` for missing/empty groups -> empty string,
        // exactly like uap-python's `get(m, n) or ""` inside `re.sub`.
        match m.get(n) {
          Some(view) => buf.write_stringview(view)
          None => ()
        }
    }
  }
  let stripped = buf.to_string().trim()
  if stripped.is_empty() {
    None
  } else {
    Some(stripped.to_owned())
  }
}

///|
/// Evaluate one replacement field that falls back to a capture group when
/// the template was absent in the rule data (`None` template -> `Group(
/// fallback_group)`), both under `utils.replacer` semantics. This is the
/// flavor used for every OS field and for the device family and model.
fn eval_field(
  parts : Array[@rules.TemplatePart]?,
  fallback_group : Int,
  m : @regexp.MatchResult,
) -> String? {
  match parts {
    Some(ps) => eval_template(ps, m)
    // Absent template: the upstream default template is the bare group
    // reference `"$\{fallback_group}"` (matchers.py:94-98,153-155), i.e.
    // replacer evaluation over a single group part — strip once, empty
    // -> None. (The `TemplatePart` constructors are read-only outside the
    // generated `rules` package, so this case is spelled out instead of
    // building `[@rules.Group(fallback_group)]`.)
    None =>
      match m.get(fallback_group) {
        Some(view) => {
          let stripped = view.trim()
          if stripped.is_empty() {
            None
          } else {
            Some(stripped.to_owned())
          }
        }
        None => None
      }
  }
}

///|
/// Evaluate the UA (browser) family with the bespoke upstream semantics
/// (matchers.py:41-45): literal parts are copied as-is and `Group(n)` parts
/// are substituted with the raw captured text (missing group contributes
/// the empty string; upstream would raise on a non-participating group 1,
/// which no uap-core rule can trigger). The result is NOT stripped and is
/// never converted to `None` — an empty family is returned as `""`, because
/// the modern upstream matcher reports the first regex match unconditionally
/// (`Resolver.__call__` filters only `None` results, and a populated
/// `UserAgent` record is always truthy).
fn eval_ua_family(
  parts : Array[@rules.TemplatePart]?,
  m : @regexp.MatchResult,
) -> String {
  let buf = StringBuilder()
  match parts {
    Some(ps) =>
      for part in ps {
        match part {
          @rules.Literal(text) => buf.write_string(text)
          @rules.Group(n) =>
            match m.get(n) {
              Some(view) => buf.write_stringview(view)
              None => ()
            }
        }
      }
    // No family template: fall back to raw capture group 1 (`family or
    // "$1"` in matchers.py:33, substituted via `replace("$1", m[1])`).
    None =>
      match m.get(1) {
        Some(view) => buf.write_stringview(view)
        None => ()
      }
  }
  buf.to_string()
}

///|
/// Evaluate one UA (browser) version field. Upstream semantics
/// (matchers.py:47-50): a static `v1/v2/v3_replacement` is used verbatim,
/// otherwise the field falls back to capture group 2/3/4 under `utils.get`
/// semantics (`None` when the group is missing or empty). Generated UA
/// version templates are literal-only, so evaluating them through
/// `eval_template` (strip + empty -> `None`) is indistinguishable from the
/// upstream verbatim use on all real data.
fn eval_ua_version(
  parts : Array[@rules.TemplatePart]?,
  fallback_group : Int,
  m : @regexp.MatchResult,
) -> String? {
  match parts {
    Some(ps) => eval_template(ps, m)
    None => get_group(m, fallback_group)
  }
}
