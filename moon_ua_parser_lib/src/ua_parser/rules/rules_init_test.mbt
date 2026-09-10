// Inline tests for rules_init.mbt. Accessing each precompiled array forces
// its lazy initialization, so these tests compile every rule pattern
// (433 ua / 204 os / 633 device = 1270); any compile failure aborts the
// process with the fail-loud diagnostic (FR-06). No printing: output stays
// pristine.

///|
test "ua_regexps compile all 433 ua rules" {
  inspect(ua_regexps.length(), content="433")
  assert_eq(ua_regexps.length(), ua_rules.length())
}

///|
test "os_regexps compile all 204 os rules" {
  inspect(os_regexps.length(), content="204")
  assert_eq(os_regexps.length(), os_rules.length())
}

///|
test "device_regexps compile all 633 device rules" {
  inspect(device_regexps.length(), content="633")
  assert_eq(device_regexps.length(), device_rules.length())
}

///|
test "ua_regexps[0] is a usable compiled regexp" {
  // ua_rules[0] = "(GeoEvent Server) (\d+)(?:\.(\d+)(?:\.(\d+)|)|)"
  // (group parens are metacharacters, so the input carries none).
  let re = ua_regexps[0]
  assert_true(re.execute("GeoEvent Server 11.2").matched())
}
