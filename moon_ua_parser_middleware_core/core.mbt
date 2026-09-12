// Shared middleware helper (T-03) for the vicoproplus/moon_ua_parser
// library: pure functions only — no framework API, no IO.
//
// Contract (spec §3, degradation/forensics):
// - The framework adapter parses once per request via `@ua_parser.parse`
//   and hands the resulting `Result[UaInfo, UaError]` to `assemble`.
// - Degradation: the result is `Err`, OR all three domain families equal
//   the library's all-miss fallback literal (see `FALLBACK_FAMILY`). In
//   both cases the middleware mounts the empty `UaInfo`
//   (`empty_ua_info`, empty-string families — deliberately distinct from
//   the library's `"Other"` fallback) and emits a forensics record
//   (`ForensicsRecord`) instead of surfacing an error to the caller.
// - Otherwise the parsed `UaInfo` is mounted unchanged.
//
// Everything here is a total, side-effect-free function: errors never
// propagate to the caller and no logging/IO happens inside this module —
// the framework thin layer only adapts `ForensicsRecord` to its own log
// channel (PS-2).

///|
/// The family literal the library reports for a domain whose rules all
/// missed (the "empty fallback"). Verified against the current snapshot —
/// do not "fix" from memory:
///
/// - Library source: `moon_ua_parser_lib/src/ua_parser/engine.mbt:33-65`
///   (`other_browser` / `other_os` / `other_device` all emit
///   `family: "Other"` with every other field `None`).
/// - uap-core goldens: browser `uap-core/tests/test_ua.yaml:1020-1024`
///   (`SomethingWeNeverKnewExisted` -> family 'Other'); OS
///   `uap-core/tests/test_os.yaml:710-715` (same UA -> family 'Other');
///   device `uap-core/tests/test_device.yaml:398-401` (`NCSA_Mosaic/2.0
///   (Windows 3.1)` -> family 'Other'; uap-core has no device catch-all
///   rule, see moon_ua_parser_lib/tests/semantics/semantics.mbt Test 12
///   comment).
/// - Runtime-verified for all three domains at once by the
///   `SomethingWeNeverKnewExisted` test in `core_tests.mbt`.
///
/// Note: a bot UA such as Googlebot reports device family `"Spider"`
/// because a real device rule produced it (rule 625,
/// `uap-core/regexes.yaml:6217`) — that is a match, NOT this fallback,
/// and must not trigger degradation by itself.
pub const FALLBACK_FAMILY : String = "Other"

///|
/// Maximum length of `ForensicsRecord.ua_summary` in characters. Longer
/// user-agent strings are truncated to exactly this many leading
/// characters by `truncate_ua_summary`.
pub const UA_SUMMARY_MAX_LENGTH : Int = 64

///|
/// Degradation reason recorded when the parse result is `Err`. With the
/// precompiled rule set `parse` never returns `Err` today; the reason is
/// kept distinct so adapters can attribute future failure modes.
pub const REASON_PARSE_ERROR : String = "parse_error"

///|
/// Degradation reason recorded when the parse succeeded but all three
/// domain families equal the library's all-miss fallback literal
/// (`FALLBACK_FAMILY`) — i.e. nothing about the UA was actually learned.
pub const REASON_EMPTY_FALLBACK : String = "empty_fallback"

///|
/// A forensics record describing one degraded parse. Built only by this
/// module (`make_forensics`); the framework thin layer forwards it to its
/// log channel (PS-2) — this module performs no IO itself.
pub(all) struct ForensicsRecord {
  /// The original user-agent string truncated to at most
  /// `UA_SUMMARY_MAX_LENGTH` characters (forensics-safe size).
  ua_summary : String
  /// Machine-readable degradation reason (`REASON_PARSE_ERROR` or
  /// `REASON_EMPTY_FALLBACK`); never empty.
  reason : String
} derive(Eq, Debug)

///|
/// Outcome of `assemble`: what the middleware mounts for this request,
/// plus the optional forensics record to log.
///
/// No `derive`: the embedded `@ua_parser.UaInfo` implements neither
/// `Debug` nor a non-deprecated `Show` (the lib derives the deprecated
/// `Show`, engine baseline), so this struct is compared/asserted
/// field-by-field (its `ua_info` field supports `==` via `UaInfo`'s `Eq`).
pub(all) struct MiddlewareOutcome {
  /// The effective UaInfo to mount: the parsed one when healthy, or
  /// `empty_ua_info()` when degraded (empty-string families, `None`
  /// versions — deliberately distinct from the library's `"Other"`
  /// fallback values).
  ua_info : @ua_parser.UaInfo
  /// `true` iff the result was degraded (Err or empty fallback).
  degraded : Bool
  /// Forensics record iff degraded, `None` when healthy.
  forensics : ForensicsRecord?
}

///|
/// The empty UaInfo mounted on degradation: every domain family is the
/// empty string (meaning "no parse result") and every version/brand/model
/// field is `None`. This is deliberately distinct from the library's
/// all-miss fallback (`FALLBACK_FAMILY = "Other"` per domain), so callers
/// can tell "middleware had nothing" from "the library matched nothing".
pub fn empty_ua_info() -> @ua_parser.UaInfo {
  {
    browser: {
      family: "",
      major: None,
      minor: None,
      patch: None,
      patch_minor: None,
      rule_index: None,
    },
    os: {
      family: "",
      major: None,
      minor: None,
      patch: None,
      patch_minor: None,
      rule_index: None,
    },
    device: { family: "", brand: None, model: None, rule_index: None },
  }
}

///|
/// Degradation judgment for an already-parsed UaInfo: `true` iff ALL
/// THREE domain families equal the library's all-miss fallback literal
/// (`FALLBACK_FAMILY`). A single fallback domain (e.g. desktop UAs whose
/// device rules all miss) is NOT degraded — the other domains still carry
/// real information. Partial or exact family matches on any domain keep
/// the result healthy.
pub fn is_empty_fallback(info : @ua_parser.UaInfo) -> Bool {
  info.browser.family == FALLBACK_FAMILY &&
  info.os.family == FALLBACK_FAMILY &&
  info.device.family == FALLBACK_FAMILY
}

///|
/// Degradation judgment for a parse result: `Some(reason)` when the
/// request must degrade — `REASON_PARSE_ERROR` for `Err(_)`,
/// `REASON_EMPTY_FALLBACK` when the parsed UaInfo satisfies
/// `is_empty_fallback` — and `None` when the parse is healthy. Pure and
/// total: never raises.
pub fn degradation_reason(
  result : Result[@ua_parser.UaInfo, @ua_parser.UaError],
) -> String? {
  match result {
    Err(_) => Some(REASON_PARSE_ERROR)
    Ok(info) => if is_empty_fallback(info) { Some(REASON_EMPTY_FALLBACK) } else { None }
  }
}

///|
/// Degradation judgment convenience wrapper: `true` iff
/// `degradation_reason(result)` is `Some(_)`.
pub fn is_degraded(result : Result[@ua_parser.UaInfo, @ua_parser.UaError]) -> Bool {
  degradation_reason(result) is Some(_)
}

///|
/// Truncate a user-agent string to at most `UA_SUMMARY_MAX_LENGTH`
/// characters (character-based, not bytes/code units). Strings at or
/// below the limit are returned unchanged.
pub fn truncate_ua_summary(ua : String) -> String {
  if ua.length() <= UA_SUMMARY_MAX_LENGTH {
    return ua
  }
  let buf = StringBuilder()
  let mut count = 0
  for ch in ua {
    if count >= UA_SUMMARY_MAX_LENGTH {
      break
    }
    buf.write_char(ch)
    count = count + 1
  }
  buf.to_string()
}

///|
/// Construct a forensics record: `ua_summary` is the original UA truncated
/// to `UA_SUMMARY_MAX_LENGTH` characters, `reason` is the degradation
/// reason from `degradation_reason`. Pure data construction only — the
/// caller (framework thin layer) decides where the record goes.
pub fn make_forensics(ua : String, reason : String) -> ForensicsRecord {
  { ua_summary: truncate_ua_summary(ua), reason }
}

///|
/// Assemble the middleware result for one request (T-03 core entry
/// point). Consumes the library's parse result:
///
/// - `Err(_)`: mounts `empty_ua_info()` + forensics with reason
///   `REASON_PARSE_ERROR`. Never re-raises — the caller's response chain
///   continues (spec §3 degradation).
/// - `Ok(info)` where `is_empty_fallback(info)` (all three families are
///   the library's all-miss fallback): mounts `empty_ua_info()` +
///   forensics with reason `REASON_EMPTY_FALLBACK`.
/// - otherwise (`Ok(info)`): mounts `info` unchanged with no forensics.
pub fn assemble(
  ua : String,
  result : Result[@ua_parser.UaInfo, @ua_parser.UaError],
) -> MiddlewareOutcome {
  match result {
    Err(_) => assemble_error(ua)
    Ok(info) =>
      if is_empty_fallback(info) {
        degraded_outcome(ua, REASON_EMPTY_FALLBACK)
      } else {
        { ua_info: info, degraded: false, forensics: None }
      }
  }
}

///|
/// Err-branch of `assemble`, also usable directly: mounts `empty_ua_info()`
/// plus a `REASON_PARSE_ERROR` forensics record for `ua`, never raising.
/// Exposed separately because `@ua_parser.UaError` is a read-only error
/// type (external code cannot construct `Err` values to test with): an
/// adapter that handles the parse result itself can call this on its
/// `Err` arm, and unit tests pin the Err behavior through it.
pub fn assemble_error(ua : String) -> MiddlewareOutcome {
  degraded_outcome(ua, REASON_PARSE_ERROR)
}

///|
/// Internal: build the degraded outcome (empty UaInfo + forensics record).
fn degraded_outcome(ua : String, reason : String) -> MiddlewareOutcome {
  {
    ua_info: empty_ua_info(),
    degraded: true,
    forensics: Some(make_forensics(ua, reason)),
  }
}
