// Handwritten file — registered exception inside the generated `rules`
// package (spec section 2, GO registry). The generator owns the data files
// (`rules_data.mbt`, `rules_version.mbt`, `moon.pkg`); this file holds only
// the precompiled-initialization layer on top of that data.

///|
/// Compiles one uap-core rule pattern into a `@regexp.Regexp`.
///
/// The case-insensitive flag is applied exactly when the rule carries it
/// (mirrors upstream `regex_flag: "i"`). A pattern that fails to compile is
/// fatal: the process aborts with a diagnostic naming the domain, the
/// 0-based rule index within the domain, and a snippet of the offending
/// pattern — a broken rule set must refuse to run (FR-06, design D8).
fn compile_rule(
  domain : String,
  index : Int,
  pattern : String,
  flag_i : Bool
) -> @regexp.Regexp {
  let snippet = if pattern.length() > 60 {
    "\{pattern[:60]}..."
  } else {
    pattern
  }
  if flag_i {
    @regexp.compile(pattern, flags="i") catch {
      @regexp.RegexpError(err~, source_fragment~) =>
        abort(
          "ua_parser: failed to compile \{domain} rule[\{index}] (flag i): \{snippet} (\{err}, near \{source_fragment})",
        )
    }
  } else {
    @regexp.compile(pattern) catch {
      @regexp.RegexpError(err~, source_fragment~) =>
        abort(
          "ua_parser: failed to compile \{domain} rule[\{index}]: \{snippet} (\{err}, near \{source_fragment})",
        )
    }
  }
}

///|
/// Precompiled regular expressions for `ua_rules` (same order, same length).
///
/// Top-level lets are initialized lazily on first access — once per process.
/// Initialization compiles every ua pattern; the first broken pattern aborts
/// the process with its domain/index/snippet diagnostic.
pub let ua_regexps : Array[@regexp.Regexp] = ua_rules.mapi(
  fn(index, rule) { compile_rule("ua", index, rule.pattern, rule.flag_i) },
)

///|
/// Precompiled regular expressions for `os_rules` (same order, same length).
/// See `ua_regexps` for initialization semantics.
pub let os_regexps : Array[@regexp.Regexp] = os_rules.mapi(
  fn(index, rule) { compile_rule("os", index, rule.pattern, rule.flag_i) },
)

///|
/// Precompiled regular expressions for `device_rules` (same order, same
/// length). See `ua_regexps` for initialization semantics.
pub let device_regexps : Array[@regexp.Regexp] = device_rules.mapi(
  fn(index, rule) { compile_rule("device", index, rule.pattern, rule.flag_i) },
)
