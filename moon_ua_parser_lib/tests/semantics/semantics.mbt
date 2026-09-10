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

///|
/// Test 12 — T-09 `with_rule_index=true`: each matched domain reports the
/// 0-based position of its winning rule within the domain's rule list
/// (= uap-core regexes.yaml file order; the generated `@rules.*_rules`
/// arrays are index-aligned with it — verified pattern-by-pattern for all
/// 433/204/633 rules).
///
/// Goldens (0-based indices verified by scanning uap-core/regexes.yaml
/// snapshot 73e7340 with python re.search in file order, and cross-checked
/// against rules_data.mbt at the same position):
/// - browser 280: `(Chromium|Chrome)/(\d+)\.(\d+)(?:\.(\d+)|)(?:\.(\d+)|)`
///   — regexes.yaml:961 (family from capture group 1 = `Chrome`).
/// - os 47: `(Windows NT 10\.0)` — regexes.yaml:1586 (literal
///   `os_replacement: 'Windows'`, version from the literal `'10'` chain).
/// - device None: no device rule matches a plain desktop UA (family
///   `"Other"`, see Test 1); the no-match fallback carries `rule_index:
///   None` by design — uap-core has NO device catch-all, so a desktop
///   Chrome UA cannot produce a device index. (An all-three-`Some` case is
///   covered by Test 15's iPhone UA.)
test "with_rule_index reports winning rule positions for chrome desktop" {
  let ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  match @ua_parser.parse(ua, with_rule_index=true) {
    Ok(info) => {
      let b = info.browser
      assert_eq("browser rule_index=\{b.rule_index}", "browser rule_index=Some(280)")
      assert_eq("family=\{b.family}", "family=Chrome")
      assert_eq("major=\{b.major}", "major=Some(120)")
      assert_eq("minor=\{b.minor}", "minor=Some(0)")
      assert_eq("patch=\{b.patch}", "patch=Some(0)")
      assert_eq("patch_minor=\{b.patch_minor}", "patch_minor=Some(0)")
      let o = info.os
      assert_eq("os rule_index=\{o.rule_index}", "os rule_index=Some(47)")
      assert_eq("os family=\{o.family}", "os family=Windows")
      assert_eq("os major=\{o.major}", "os major=Some(10)")
      let d = info.device
      assert_eq("device rule_index=\{d.rule_index}", "device rule_index=None")
      assert_eq("device family=\{d.family}", "device family=Other")
      assert_eq("device brand=\{d.brand}", "device brand=None")
      assert_eq("device model=\{d.model}", "device model=None")
    }
    Err(_) => fail("parse never fails with the precompiled rule set")
  }
}

///|
/// Test 13 — T-09 default-off guarantee: `parse(ua)` (option omitted) keeps
/// every `rule_index` `None` AND every remaining field identical to the
/// `with_rule_index=true` result, so default-off output is byte-identical
/// to pre-T-09.
test "default parse leaves rule_index None with identical domain values" {
  let ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  match @ua_parser.parse(ua) {
    Ok(def) => {
      assert_eq("browser rule_index=\{def.browser.rule_index}", "browser rule_index=None")
      assert_eq("os rule_index=\{def.os.rule_index}", "os rule_index=None")
      assert_eq("device rule_index=\{def.device.rule_index}", "device rule_index=None")
      match @ua_parser.parse(ua, with_rule_index=true) {
        Ok(idx) => {
          let b1 = def.browser
          let b2 = idx.browser
          assert_eq("browser family \{b1.family} major \{b1.major} minor \{b1.minor} patch \{b1.patch} patch_minor \{b1.patch_minor}", "browser family \{b2.family} major \{b2.major} minor \{b2.minor} patch \{b2.patch} patch_minor \{b2.patch_minor}")
          let o1 = def.os
          let o2 = idx.os
          assert_eq("os family \{o1.family} major \{o1.major} minor \{o1.minor} patch \{o1.patch} patch_minor \{o1.patch_minor}", "os family \{o2.family} major \{o2.major} minor \{o2.minor} patch \{o2.patch} patch_minor \{o2.patch_minor}")
          let d1 = def.device
          let d2 = idx.device
          assert_eq("device family \{d1.family} brand \{d1.brand} model \{d1.model}", "device family \{d2.family} brand \{d2.brand} model \{d2.model}")
        }
        Err(_) => fail("parse never fails with the precompiled rule set")
      }
    }
    Err(_) => fail("parse never fails with the precompiled rule set")
  }
}

///|
/// Test 14 — T-09 indices for `fakeLuminary/1.0` (Test 2's UA): browser and
/// OS rules all miss -> family `"Other"` with `rule_index None` (fallback
/// is not produced by any rule); device hits the feature-phone catch-all.
///
/// Golden indices verified by scanning uap-core/regexes.yaml snapshot
/// 73e7340 with python re.search in file order:
/// - device 626: the `^(1207|3gso|4thp|...|fake|...)` flag-i catch-all —
///   regexes.yaml:6227 (family/brand/model templates `Generic Feature
///   Phone` / `Generic` / `Feature Phone`, matching Test 2's goldens).
/// - browser: NO user_agent_parsers rule matches (family `Other` — the
///   only Luminary UA rule `^(Luminary)[Stage]+/...` requires the CFNetwork
///   suffix), hence `rule_index None`.
/// - os: NO os_parsers rule matches (family `Other`), `rule_index None`.
test "fakeLuminary: catch-all device index Some, fallbacks stay None" {
  let ua = "fakeLuminary/1.0"
  match @ua_parser.parse(ua, with_rule_index=true) {
    Ok(info) => {
      let b = info.browser
      assert_eq("browser rule_index=\{b.rule_index}", "browser rule_index=None")
      assert_eq("family=\{b.family}", "family=Other")
      let o = info.os
      assert_eq("os rule_index=\{o.rule_index}", "os rule_index=None")
      assert_eq("os family=\{o.family}", "os family=Other")
      let d = info.device
      assert_eq("device rule_index=\{d.rule_index}", "device rule_index=Some(626)")
      assert_eq("device family=\{d.family}", "device family=Generic Feature Phone")
      assert_eq("device brand=\{d.brand}", "device brand=Some(Generic)")
      assert_eq("device model=\{d.model}", "device model=Some(Feature Phone)")
    }
    Err(_) => fail("parse never fails with the precompiled rule set")
  }
  // Default call keeps the index unset even for the matched device rule.
  match @ua_parser.parse(ua) {
    Ok(info) =>
      assert_eq("default device rule_index=\{info.device.rule_index}", "default device rule_index=None")
    Err(_) => fail("parse never fails with the precompiled rule set")
  }
}

///|
/// Test 15 — T-09 consistency: with `with_rule_index=true`, the aggregate
/// `parse` reports exactly the same domain values as the single-domain
/// functions (whose `rule_index` is always `None`), for two UAs whose
/// indices were verified by scanning uap-core/regexes.yaml snapshot 73e7340
/// with python re.search in file order (and cross-checked against
/// rules_data.mbt at the same position):
/// - iPhone DuckDuckGo UA: browser 167 (`Mozilla.{1,200}Mobile.{1,100}
///   (DuckDuckGo)/(\d+)`, regexes.yaml:517 — family template
///   `DuckDuckGo Mobile`), os 69 (`(CPU[ +]OS|iPhone[ +]OS|CPU[ +]iPhone|
///   CPU IPhone OS|CPU iPad OS)[ +]+(\d+)[_\.](\d+)...`, regexes.yaml:1697),
///   device 539 (`(iPhone)(?:;| Simulator;)`, regexes.yaml:5730) — all
///   three domains matched, all three indices `Some`.
/// - Googlebot UA: browser 51 (generic spiders rule, regexes.yaml:155 —
///   family from capture group 1), os None (no OS rule matches, family
///   `Other`), device 625 (`^.{0,100}(bot|BUbiNG|zao|borg|...)`, regexes
///   .yaml:6217 — `Spider`/`Spider`/`Desktop`).
test "with_rule_index parse stays consistent with single-domain functions" {
  let uas = [
    ("Mozilla/5.0 (iPhone; CPU iPhone OS 14_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.3 Mobile/15E148 DuckDuckGo/7 Safari/605.1.15", (Some(167), Some(69), Some(539))),
    ("Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)", (Some(51), None, Some(625))),
  ]
  for i, pair in uas {
    let (ua, (bi, oi, di)) = pair
    match @ua_parser.parse(ua, with_rule_index=true) {
      Ok(info) => {
        assert_eq("\{i} browser rule_index \{info.browser.rule_index}", "\{i} browser rule_index \{bi}")
        assert_eq("\{i} os rule_index \{info.os.rule_index}", "\{i} os rule_index \{oi}")
        assert_eq("\{i} device rule_index \{info.device.rule_index}", "\{i} device rule_index \{di}")
        let b = @ua_parser.parse_browser(ua)
        assert_eq("\{i} browser family \{info.browser.family} major \{info.browser.major} minor \{info.browser.minor} patch \{info.browser.patch} patch_minor \{info.browser.patch_minor}", "\{i} browser family \{b.family} major \{b.major} minor \{b.minor} patch \{b.patch} patch_minor \{b.patch_minor}")
        let o = @ua_parser.parse_os(ua)
        assert_eq("\{i} os family \{info.os.family} major \{info.os.major} minor \{info.os.minor} patch \{info.os.patch} patch_minor \{info.os.patch_minor}", "\{i} os family \{o.family} major \{o.major} minor \{o.minor} patch \{o.patch} patch_minor \{o.patch_minor}")
        let d = @ua_parser.parse_device(ua)
        assert_eq("\{i} device family \{info.device.family} brand \{info.device.brand} model \{info.device.model}", "\{i} device family \{d.family} brand \{d.brand} model \{d.model}")
        assert_eq("\{i} single-domain browser rule_index \{@ua_parser.parse_browser(ua).rule_index}", "\{i} single-domain browser rule_index None")
        assert_eq("\{i} single-domain os rule_index \{@ua_parser.parse_os(ua).rule_index}", "\{i} single-domain os rule_index None")
        assert_eq("\{i} single-domain device rule_index \{@ua_parser.parse_device(ua).rule_index}", "\{i} single-domain device rule_index None")
      }
      Err(_) => fail("parse never fails with the precompiled rule set")
    }
  }
}
