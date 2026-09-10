// Handwritten semantics tests for the T-06 matching engine (minimal set —
// T-07 expands coverage). Every expected value is a golden copied from the
// uap-core test fixtures (snapshot 73e7340), not guessed: the reference
// point for each assertion is cited inline.
//
// Assertion style mirrors tests/differential: field-by-field `assert_eq`
// over interpolated strings, so a failure prints both sides.

///|
/// Test 1 — Chrome desktop UA: browser template/group fallback, OS literal
/// templates, device all-miss fallback.
///
/// Goldens: browser family/version shape from uap-core tests/test_ua.yaml:3039
/// (same `(Chromium|Chrome)/...` rule: family template absent -> group 1,
/// versions from groups 2..5 — that case carries `patch_minor: '78'` and the
/// vendored uap-python `Resolver` returns `patch_minor='78'` for it and
/// `patch_minor='0'` for this exact UA, both verified by running
/// `loaders.load_yaml("uap-core/regexes.yaml")` + `basic.Resolver`); OS
/// `Windows`/`10` from tests/test_os.yaml:3197 (the `(Windows NT 10\.0)`
/// rule with literal `Windows` / `10` templates — the family is NOT the
/// string "Windows 10"); device `"Other"`: no device rule matches a plain
/// desktop UA.
test "chrome desktop ua parses all three domains" {
  let ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  match @ua_parser.parse(ua) {
    Ok(info) => {
      let b = info.browser
      assert_eq("family=\{b.family}", "family=Chrome")
      assert_eq("major=\{b.major}", "major=Some(120)")
      assert_eq("minor=\{b.minor}", "minor=Some(0)")
      assert_eq("patch=\{b.patch}", "patch=Some(0)")
      assert_eq("patch_minor=\{b.patch_minor}", "patch_minor=Some(0)")
      let o = info.os
      assert_eq("os family=\{o.family}", "os family=Windows")
      assert_eq("os major=\{o.major}", "os major=Some(10)")
      assert_eq("os minor=\{o.minor}", "os minor=None")
      assert_eq("os patch=\{o.patch}", "os patch=None")
      assert_eq("os patch_minor=\{o.patch_minor}", "os patch_minor=None")
      let d = info.device
      assert_eq("device family=\{d.family}", "device family=Other")
      assert_eq("device brand=\{d.brand}", "device brand=None")
      assert_eq("device model=\{d.model}", "device model=None")
    }
    Err(_) => fail("parse never fails with the precompiled rule set")
  }
}

///|
/// Test 2 — `fakeLuminary/1.0`: browser all-miss fallback; OS all-miss
/// fallback; device hits the catch-all feature-phone rule whose
/// alternation includes the literal `fake` (flag i) — first match wins.
///
/// Goldens: browser from uap-core tests/test_ua.yaml:62 (`family: 'Other'`,
/// empty major/minor/patch); OS default `"Other"` + all-None (uap-python
/// core.py `Result.with_defaults`, L74-92; no OS rule matches); device from
/// the uap-core `^...(1207|...|fake|...)`-style device rule (generated
/// rules_data.mbt:1337): family `Generic Feature Phone`, brand `Generic`,
/// model `Feature Phone` — test_device.yaml has no case for this UA, so the
/// rule data is the golden.
test "fakeLuminary: browser/OS fall back to Other, device hits catch-all" {
  let ua = "fakeLuminary/1.0"
  let b = @ua_parser.parse_browser(ua)
  assert_eq("family=\{b.family}", "family=Other")
  assert_eq("major=\{b.major}", "major=None")
  assert_eq("minor=\{b.minor}", "minor=None")
  assert_eq("patch=\{b.patch}", "patch=None")
  let o = @ua_parser.parse_os(ua)
  assert_eq("os family=\{o.family}", "os family=Other")
  assert_eq("os major=\{o.major}", "os major=None")
  assert_eq("os minor=\{o.minor}", "os minor=None")
  assert_eq("os patch=\{o.patch}", "os patch=None")
  assert_eq("os patch_minor=\{o.patch_minor}", "os patch_minor=None")
  let d = @ua_parser.parse_device(ua)
  assert_eq("device family=\{d.family}", "device family=Generic Feature Phone")
  assert_eq("device brand=\{d.brand}", "device brand=Some(Generic)")
  assert_eq("device model=\{d.model}", "device model=Some(Feature Phone)")
}

///|
/// Test 3 — mid-template `$1` substitution: the
/// `(Collector|Explorer|Workforce)-(?:Android|iOS)-...` rule carries family
/// template `[Group(1), Literal(" for ArcGIS")]`, so the captured platform
/// word lands inside the family string.
///
/// Golden: uap-core tests/test_ua.yaml:8841 — family
/// `'Collector for ArcGIS'`, major `10`, minor `3`, patch `7`.
test "arcgis collector exercises mid-template group substitution" {
  let ua = "Collector-Android-10.3.7/ArcGIS.Android-10.2.5/7.0/SAMSUNG-SM-T815"
  let b = @ua_parser.parse_browser(ua)
  assert_eq("family=\{b.family}", "family=Collector for ArcGIS")
  assert_eq("major=\{b.major}", "major=Some(10)")
  assert_eq("minor=\{b.minor}", "minor=Some(3)")
  assert_eq("patch=\{b.patch}", "patch=Some(7)")
}

///|
/// Test 4 — device rule with templates: `(iPhone)(?:;| Simulator;)` carries
/// family `[Group(1)]`, brand literal `Apple`, model `[Group(1)]`.
///
/// Golden: uap-core tests/test_device.yaml:80537 — family `'iPhone'`,
/// brand `'Apple'`, model `'iPhone'`.
test "iphone device rule derives family brand model" {
  let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 14_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.3 Mobile/15E148 DuckDuckGo/7 Safari/605.1.15"
  let d = @ua_parser.parse_device(ua)
  assert_eq("family=\{d.family}", "family=iPhone")
  assert_eq("brand=\{d.brand}", "brand=Some(Apple)")
  assert_eq("model=\{d.model}", "model=Some(iPhone)")
}

///|
/// Test 5 — browser `patch_minor` fidelity (fix round R1): the QQ Browser
/// rule template chain populates the fourth version segment from capture
/// group 5 (`patch_minor or get(m, 5)`, matchers.py:50).
///
/// Golden: uap-core tests/test_ua.yaml:205-211 — family `'QQ Browser'`,
/// major `6`, minor `13`, patch `13719`, patch_minor `201`. Cross-verified
/// by running the vendored uap-python (`loaders.load_yaml` +
/// `basic.Resolver`), which returns exactly
/// `UserAgent(family='QQ Browser', major='6', minor='13', patch='13719',
/// patch_minor='201')` for this UA.
test "qq browser golden asserts patch_minor group-5 fallback" {
  let ua = "Mozilla/5.0 (Windows NT 5.1) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.15 Safari/535.11 QQBrowser/6.13.13719.201"
  let b = @ua_parser.parse_browser(ua)
  assert_eq("family=\{b.family}", "family=QQ Browser")
  assert_eq("major=\{b.major}", "major=Some(6)")
  assert_eq("minor=\{b.minor}", "minor=Some(13)")
  assert_eq("patch=\{b.patch}", "patch=Some(13719)")
  assert_eq("patch_minor=\{b.patch_minor}", "patch_minor=Some(201)")
}
