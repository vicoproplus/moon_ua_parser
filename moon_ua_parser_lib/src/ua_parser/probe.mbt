///|
/// T-01 minimal compile probe (temporary scaffolding; T-02 removes or reworks
/// it). Proves the toolchain plus moonbitlang/regexp can compile one real
/// uap-core rule and execute it against a Chrome Mobile UA.
const PROBE_RULE : String = "(Chrome)/(\\d+)\\.(\\d+)\\.(\\d+)\\.(\\d+) Mobile(?:[ /]|$)"

///|
const PROBE_UA : String = "Mozilla/5.0 (Linux; Android 10; SM-G960F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"

///|
/// Compiles the probe rule. `try!` because a malformed rule here is a probe
/// failure, not a recoverable condition.
fn compile_probe_rule() -> @regexp.Regexp {
  try! @regexp.compile(PROBE_RULE)
}

///|
test "chrome mobile rule compiles and matches" {
  let re = compile_probe_rule()
  let result = re.execute(PROBE_UA)
  assert_eq(result.matched(), true)
  // group_count() includes the whole match at index 0, so 5 capture groups
  // yield 6 (documented in moonbitlang/regexp Regexp::group_count).
  assert_eq(re.group_count(), 6)
  assert_eq(result.get(1), Some("Chrome"))
  assert_eq(result.get(2), Some("120"))
  assert_eq(result.get(3), Some("0"))
  assert_eq(result.get(4), Some("0"))
  assert_eq(result.get(5), Some("0"))
}
