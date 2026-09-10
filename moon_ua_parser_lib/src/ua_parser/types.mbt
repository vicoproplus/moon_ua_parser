///|
/// The browser component of a parsed user agent.
///
/// `family` is the browser family name (for example `"Chrome"`); it is
/// `"Other"` when no browser rule matched. The version fields carry the
/// dotted version segments extracted from the matched rule; each is `None`
/// when the rule provides no corresponding capture (an empty capture also
/// counts as unknown).
pub(all) struct Browser {
  /// Browser family name; `"Other"` when no browser rule matched.
  family : String
  /// Major version segment, or `None` when unknown.
  major : String?
  /// Minor version segment, or `None` when unknown.
  minor : String?
  /// Patch version segment, or `None` when unknown.
  patch : String?
  /// Fourth (patch-minor) version segment, or `None` when unknown.
  patch_minor : String?
  /// Diagnostic metadata (T-09): 0-based index of the rule that produced
  /// this result within the browser rule list (`@rules.ua_rules`, i.e. the
  /// uap-core `user_agent_parsers` order). `Some` only when the parse was
  /// run with `with_rule_index=true` AND a rule matched; `None` otherwise
  /// (including the no-match `"Other"` fallback — no rule produced it).
  rule_index : Int?
} derive(Eq, Show)

///|
/// The operating-system component of a parsed user agent.
///
/// `family` is the OS family name (for example `"Android"`); it is `"Other"`
/// when no OS rule matched. The version fields carry the dotted version
/// segments extracted from the matched rule; each is `None` when the rule
/// provides no corresponding capture (an empty capture also counts as
/// unknown).
pub(all) struct OS {
  /// Operating-system family name; `"Other"` when no OS rule matched.
  family : String
  /// Major version segment, or `None` when unknown.
  major : String?
  /// Minor version segment, or `None` when unknown.
  minor : String?
  /// Patch version segment, or `None` when unknown.
  patch : String?
  /// Fourth (patch-minor) version segment, or `None` when unknown.
  patch_minor : String?
  /// Diagnostic metadata (T-09): 0-based index of the rule that produced
  /// this result within the OS rule list (`@rules.os_rules`, i.e. the
  /// uap-core `os_parsers` order). `Some` only when the parse was run with
  /// `with_rule_index=true` AND a rule matched; `None` otherwise (including
  /// the no-match `"Other"` fallback — no rule produced it).
  rule_index : Int?
} derive(Eq, Show)

///|
/// The device component of a parsed user agent.
///
/// `family` is the device family name (for example `"SM-G960F"`); it is
/// `"Other"` when no device rule matched. `brand` and `model` are `None`
/// when the matched rule does not supply them.
pub(all) struct Device {
  /// Device family name; `"Other"` when no device rule matched.
  family : String
  /// Device brand (from `brand_replacement`), or `None` when unknown.
  brand : String?
  /// Device model, or `None` when unknown.
  model : String?
  /// Diagnostic metadata (T-09): 0-based index of the rule that produced
  /// this result within the device rule list (`@rules.device_rules`, i.e.
  /// the uap-core `device_parsers` order). `Some` only when the parse was
  /// run with `with_rule_index=true` AND a rule matched; `None` otherwise
  /// (including the no-match `"Other"` fallback — no rule produced it).
  rule_index : Int?
} derive(Eq, Show)

///|
/// The full result of parsing a user agent: browser, operating system and
/// device, each described by its own component struct. Produced by
/// `parse`; the three components always exist (a component whose rules
/// all miss reports `"Other"` in `family` and `None` in every other
/// field).
pub(all) struct UaInfo {
  /// Parsed browser component.
  browser : Browser
  /// Parsed operating-system component.
  os : OS
  /// Parsed device component.
  device : Device
} derive(Eq, Show)

///|
/// Errors raised by the ua_parser package.
///
/// Currently only reports failures to compile a uap-core rule; later tasks
/// enrich payloads with rule-location context.
pub suberror UaError {
  /// A uap-core rule failed to compile. The payload is the diagnostic
  /// message (rule-location context may be added by later tasks).
  RegexpCompileError(String)
} derive(Eq, Show)
