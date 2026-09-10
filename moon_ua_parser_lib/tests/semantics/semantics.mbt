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

///|
/// Test 6 — device `$1 $2` multi-group template: the uap-core device rule
/// `\bSmartWatch {0,2}\( {0,2}([^;]{1,200}) {0,2}; {0,2}([^;]{1,200}) {0,2};`
/// carries `device_replacement: '$1 $2'`, `brand_replacement: '$1'`,
/// `model_replacement: '$2'`, so BOTH capture groups flow into the family
/// string (no UA/OS rule in snapshot 73e7340 carries a 2+ `$n` template —
/// verified by scanning regexes.yaml — multi-group templates live in the
/// device section).
///
/// Goldens: uap-core tests/test_device.yaml:69093 — family `'Sony SW2'`,
/// brand `'Sony'`, model `'SW2'`. Cross-verified by running the vendored
/// uap-python (`loaders.load_yaml("uap-core/regexes.yaml")` matchers): it
/// returns exactly `Device(family='Sony SW2', brand='Sony', model='SW2')`
/// for this UA.
test "smartwatch device rule combines two groups in family template" {
  let ua = "Mozilla/5.0 (Linux; Android 4.4.2; C6833 Build/14.3.A.0.681) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/30.0.0.0 Mobile Safari/537.36 SmartWatch(Sony;SW2;660x800)"
  let d = @ua_parser.parse_device(ua)
  assert_eq("family=\{d.family}", "family=Sony SW2")
  assert_eq("brand=\{d.brand}", "brand=Some(Sony)")
  assert_eq("model=\{d.model}", "model=Some(SW2)")
}

///|
/// Test 7 — strip + empty group -> None under uap-python `replacer`
/// semantics (utils.py: `re.sub(r"\$(\d)", ..., repl).strip() or None`):
/// the device rule `Android Application[^\-]{1,300} - (Sony) ?(Ericsson|)
/// (.{1,200}) \w{1,20} - ` carries `device_replacement: '$1 $2'` where the
/// `Ericsson` group matched the EMPTY alternative, so `$1 $2` evaluates to
/// `"Sony "` (trailing space) and the strip turns it into `"Sony"`; brand
/// `'$1$2'` concatenates to `"Sony"`; model `'$3'` substitutes `C1505`.
///
/// Golden: uap-core tests/test_device.yaml:69098 — family `'Sony'`,
/// brand `'Sony'` (model not pinned upstream). Cross-verified by running
/// the vendored uap-python: it returns exactly
/// `Device(family='Sony', brand='Sony', model='C1505')` for this UA.
test "sony ericsson empty group exercises strip to family value" {
  let ua = "ERO247 Android Application (13, ero247 v2.1) - Sony C1505 Sony - FFFFFFFF-9DDE-1B81-FFFF-FFFFA4625391"
  let d = @ua_parser.parse_device(ua)
  assert_eq("family=\{d.family}", "family=Sony")
  assert_eq("brand=\{d.brand}", "brand=Some(Sony)")
  assert_eq("model=\{d.model}", "model=Some(C1505)")
}

///|
/// Test 8 — optional version group not participating -> `None`:
/// (a) OS: the iOS rule `(CPU[ +]OS|iPhone[ +]OS|CPU[ +]iPhone|CPU IPhone
/// OS|CPU iPad OS)[ +]+(\d+)[_\.](\d+)(?:[_\.](\d+)|)` has an OPTIONAL
/// patch group; for `CPU iPhone OS 14_3` the input ends at `14_3`, group 4
/// never participates, and uap-python (`matchers.py` OSMatcher +
/// `utils.replacer`) yields `patch=None`.
/// (b) Browser: the generic spiders rule `...Googlebot...
/// (?:[ /]v?(\d+)(?:\.(\d+)(?:\.(\d+)|)|)|)` — for `Googlebot/2.1` the
/// patch group does not participate -> `None` (uap-python
/// `UserAgentMatcher`: `self.patch or get(m, 4)`).
///
/// Evidence: running the vendored uap-python on these exact UAs returns
/// `OS(family='iOS', major='14', minor='3', patch=None, patch_minor=None)`
/// and `UserAgent(family='Googlebot', major='2', minor='1', patch=None,
/// patch_minor=None)`.
test "optional version group absent yields None in OS and browser" {
  let ios_ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 14_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.3 Mobile/15E148 DuckDuckGo/7 Safari/605.1.15"
  let o = @ua_parser.parse_os(ios_ua)
  assert_eq("os family=\{o.family}", "os family=iOS")
  assert_eq("os major=\{o.major}", "os major=Some(14)")
  assert_eq("os minor=\{o.minor}", "os minor=Some(3)")
  assert_eq("os patch=\{o.patch}", "os patch=None")
  assert_eq("os patch_minor=\{o.patch_minor}", "os patch_minor=None")
  let bot_ua = "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
  let b = @ua_parser.parse_browser(bot_ua)
  assert_eq("family=\{b.family}", "family=Googlebot")
  assert_eq("major=\{b.major}", "major=Some(2)")
  assert_eq("minor=\{b.minor}", "minor=Some(1)")
  assert_eq("patch=\{b.patch}", "patch=None")
  assert_eq("patch_minor=\{b.patch_minor}", "patch_minor=None")
}

///|
/// Test 9 — `regex_flag: i` case-insensitivity (65 uap-core device rules
/// carry it in snapshot 73e7340; UA/OS matchers compile WITHOUT it —
/// uap-python matchers.py: DeviceMatcher `re.compile(regex, flags=
/// re.IGNORECASE if regex_flag == "i" else 0)` vs UserAgentMatcher plain
/// `re.compile(regex)`):
/// (a) the flag-i device rule `Android Application[^\-]{1,300} -
/// (?:HTC|HUAWEI|LGE|LENOVO|MEDION|TCT) (HTC|HUAWEI|LG|LENOVO|MEDION|
/// ALCATEL)[ _\-](.{1,200}) \w{1,20} - ` — lowercasing the upstream golden
/// UA's `TCT` token (tests/test_device.yaml:1713) to `tct` must STILL match
/// and give the identical device (vendored uap-python run confirms:
/// `Device(family='ALCATEL one touch 890D', brand='ALCATEL',
/// model='one touch 890D')` for the lowercased variant).
/// (b) the contrast: `Yeti` -> `YETI` keeps the flag-i device spider rule
/// matching (`Device(family='Spider', ...)`) while the case-sensitive UA
/// rules all miss (`family='Other'`) — vendored uap-python returns UA None
/// + Device(family='Spider', brand='Spider', model='Desktop') for
/// `Mozilla/5.0 (compatible; YETI/1.1; +http://naver.me/spd)`.
test "flag-i device rules match case variants exactly where uap-python does" {
  let tct_lower = "SV1 Android Application (13, sv1 v2.1) - tct ALCATEL one touch 890D tct - FFFFFFFF-9EAF-9658-730A-F6590033C587"
  let d = @ua_parser.parse_device(tct_lower)
  assert_eq("family=\{d.family}", "family=ALCATEL one touch 890D")
  assert_eq("brand=\{d.brand}", "brand=Some(ALCATEL)")
  assert_eq("model=\{d.model}", "model=Some(one touch 890D)")
  let yeti_upper = "Mozilla/5.0 (compatible; YETI/1.1; +http://naver.me/spd)"
  let b = @ua_parser.parse_browser(yeti_upper)
  assert_eq("family=\{b.family}", "family=Other")
  let d2 = @ua_parser.parse_device(yeti_upper)
  assert_eq("spider family=\{d2.family}", "spider family=Spider")
  assert_eq("spider brand=\{d2.brand}", "spider brand=Some(Spider)")
  assert_eq("spider model=\{d2.model}", "spider model=Some(Desktop)")
}

///|
/// Test 10 — `parse()` vs single-domain consistency (spec §4.9 B2): the
/// aggregate `parse` must report exactly the same three components as the
/// individual `parse_browser` / `parse_os` / `parse_device` calls, for
/// three diverse UAs (Chrome desktop, iPhone third-party browser, bot).
/// All structs derive `Eq`, so whole-struct equality is asserted via
/// interpolated `Show` (a mismatch prints both sides).
test "parse aggregates identical results to single-domain functions" {
  let uas = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 14_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.3 Mobile/15E148 DuckDuckGo/7 Safari/605.1.15",
    "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
  ]
  for i, ua in uas {
    let b = @ua_parser.parse_browser(ua)
    let o = @ua_parser.parse_os(ua)
    let d = @ua_parser.parse_device(ua)
    match @ua_parser.parse(ua) {
      Ok(info) => {
        assert_eq("\{i} browser \{info.browser}", "\{i} browser \{b}")
        assert_eq("\{i} os \{info.os}", "\{i} os \{o}")
        assert_eq("\{i} device \{info.device}", "\{i} device \{d}")
      }
      Err(_) => fail("parse never fails with the precompiled rule set")
    }
  }
}

///|
/// Test 11 — determinism (spec §4.9 B2): parsing the same input repeatedly
/// must return structurally identical results (rule scan order and
/// evaluation are static; no caching may alter outcomes). The same Chrome
/// desktop UA is parsed 5 times via every entry point and each result is
/// compared against the first.
test "repeated parses of identical input are deterministic" {
  let ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  let first_b = @ua_parser.parse_browser(ua)
  let first_o = @ua_parser.parse_os(ua)
  let first_d = @ua_parser.parse_device(ua)
  let first_info = match @ua_parser.parse(ua) {
    Ok(info) => info
    Err(_) => fail("parse never fails with the precompiled rule set")
  }
  for i in 0..<5 {
    assert_eq("run\{i} browser \{@ua_parser.parse_browser(ua)}", "run\{i} browser \{first_b}")
    assert_eq("run\{i} os \{@ua_parser.parse_os(ua)}", "run\{i} os \{first_o}")
    assert_eq("run\{i} device \{@ua_parser.parse_device(ua)}", "run\{i} device \{first_d}")
    match @ua_parser.parse(ua) {
      Ok(info) => assert_eq("run\{i} info \{info}", "run\{i} info \{first_info}")
      Err(_) => fail("parse never fails with the precompiled rule set")
    }
  }
}
