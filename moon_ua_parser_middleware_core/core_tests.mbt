// Internal unit tests for the middleware core (T-03). Runs as part of the
// package's internal test suite:
//   moon test --target native -p vicoproplus/moon_ua_parser_middleware_core
//
// Golden cases are quoted verbatim from the vendored uap-core test
// snapshots (`uap-core/tests/`, read-only); synthetic failure injections
// are marked `synthetic: 失败注入专用`.

///|
/// Pin the empty-UaInfo definition (design decision, task-3 brief): all
/// three families are the EMPTY string (meaning "no parse result"),
/// every version/brand/model field None — distinct from the library's
/// `"Other"` all-miss fallback (evidence on `FALLBACK_FAMILY`).
test "empty_ua_info definition: empty families, None versions" {
  let info = empty_ua_info()
  assert_eq("b=\{info.browser.family} o=\{info.os.family} d=\{info.device.family}", "b= o= d=")
  assert_eq(info.browser.major, None)
  assert_eq(info.browser.patch_minor, None)
  assert_eq(info.os.major, None)
  assert_eq(info.device.brand, None)
  assert_eq(info.device.model, None)
  // The empty definition must NOT itself be judged empty-fallback:
  // "" != "Other" keeps the two "nothing" states distinguishable.
  assert_eq(is_empty_fallback(info), false)
}

///|
/// Golden healthy case: all three domains match real families, so
/// `assemble` mounts the parsed UaInfo unchanged with no forensics.
///
/// golden:uap-core-tests uap-core/tests/test_ua.yaml:8955 (case id
/// 'DuckDuckGo/7 Safari/605.1.15' -> family 'DuckDuckGo Mobile', major 7);
/// golden:uap-core-tests uap-core/tests/test_os.yaml:3302 (same UA ->
/// family 'iOS', major 14, minor 3); golden:uap-core-tests
/// uap-core/tests/test_device.yaml:80537 (same UA -> family 'iPhone',
/// brand 'Apple', model 'iPhone').
test "assemble keeps a fully matched parse (DuckDuckGo iPhone golden)" {
  let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 14_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.3 Mobile/15E148 DuckDuckGo/7 Safari/605.1.15"
  match @ua_parser.parse(ua) {
    Ok(info) => {
      // Three-group results: non-empty AND non-fallback families.
      assert_eq("browser=\{info.browser.family}", "browser=DuckDuckGo Mobile")
      assert_eq(info.browser.family == FALLBACK_FAMILY, false)
      assert_eq(info.browser.major, Some("7"))
      assert_eq("os=\{info.os.family}", "os=iOS")
      assert_eq(info.os.family == FALLBACK_FAMILY, false)
      assert_eq(info.os.major, Some("14"))
      assert_eq(info.os.minor, Some("3"))
      assert_eq("device=\{info.device.family}", "device=iPhone")
      assert_eq(info.device.family == FALLBACK_FAMILY, false)
      assert_eq(info.device.brand, Some("Apple"))
      // Healthy assembly: parsed info passes through untouched.
      let outcome = assemble(ua, Ok(info))
      assert_eq(outcome.degraded, false)
      assert_eq(outcome.ua_info == info, true)
      match outcome.forensics {
        Some(_) => fail("healthy parse must not produce forensics")
        None => ()
      }
    }
    Err(_) => fail("parse never fails with the precompiled rule set")
  }
}

///|
/// Second golden healthy case (Android handset), also asserted through the
/// `is_degraded` judgment on the parse result.
///
/// golden:uap-core-tests uap-core/tests/test_ua.yaml:170 (case id
/// 'Amaze_4G Build/IML74K' -> browser family 'Android', 4.0.3);
/// golden:uap-core-tests uap-core/tests/test_os.yaml:122 (same UA ->
/// family 'Android', 4.0.3); golden:uap-core-tests
/// uap-core/tests/test_device.yaml:43 (same UA -> family
/// 'HTC Amaze 4G', brand 'HTC', model 'Amaze 4G').
test "assemble keeps a fully matched parse (HTC Amaze 4G golden)" {
  let ua = "Mozilla/5.0 (Linux; U; Android 4.0.3; en-us; Amaze_4G Build/IML74K) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30"
  let result = @ua_parser.parse(ua)
  assert_eq(is_degraded(result), false)
  match result {
    Ok(info) => {
      assert_eq("browser=\{info.browser.family}", "browser=Android")
      assert_eq("os=\{info.os.family}", "os=Android")
      assert_eq("device=\{info.device.family}", "device=HTC Amaze 4G")
      let outcome = assemble(ua, result)
      assert_eq(outcome.degraded, false)
      assert_eq(outcome.ua_info == info, true)
      assert_eq(outcome.forensics is None, true)
    }
    Err(_) => fail("parse never fails with the precompiled rule set")
  }
}

///|
/// Golden partial-fallback case: only the device domain falls back
/// (desktop browsers have no device rule), browser and OS match — so the
/// result stays HEALTHY (degradation requires all three domains empty).
///
/// golden:uap-core-tests uap-core/tests/test_ua.yaml:731 (case id
/// 'NCSA_Mosaic/2.0 (Windows 3.1)' -> family 'NCSA Mosaic', major 2);
/// golden:uap-core-tests uap-core/tests/test_os.yaml:850 (same UA ->
/// family 'Windows', major 3.1); golden:uap-core-tests
/// uap-core/tests/test_device.yaml:398 (same UA -> device fallback
/// family 'Other', no brand/model).
test "partial fallback (device only) stays healthy (NCSA Mosaic golden)" {
  let ua = "NCSA_Mosaic/2.0 (Windows 3.1)"
  match @ua_parser.parse(ua) {
    Ok(info) => {
      assert_eq("browser=\{info.browser.family}", "browser=NCSA Mosaic")
      assert_eq("os=\{info.os.family}", "os=Windows")
      // The device domain IS at the fallback literal here.
      assert_eq(info.device.family, FALLBACK_FAMILY)
      assert_eq(is_empty_fallback(info), false)
      let outcome = assemble(ua, Ok(info))
      assert_eq(outcome.degraded, false)
      assert_eq(outcome.ua_info == info, true)
      assert_eq(outcome.forensics is None, true)
    }
    Err(_) => fail("parse never fails with the precompiled rule set")
  }
}

///|
/// Golden ALL-fallback case — the empirical R3 verification: this UA
/// matches no rule in any domain, and the library reports the fallback
/// literal "Other" for ALL THREE families (see `FALLBACK_CONSTANT`
/// evidence). `assemble` must degrade: mount empty UaInfo + forensics.
///
/// golden:uap-core-tests uap-core/tests/test_ua.yaml:1020 (case id
/// 'SomethingWeNeverKnewExisted' -> browser family 'Other', no versions);
/// golden:uap-core-tests uap-core/tests/test_os.yaml:710 (same UA -> OS
/// family 'Other'); the device domain has no snapshot entry for this UA —
/// the library's no-rule fallback applies (engine.mbt:63-65, uap-core has
/// no device catch-all), and this test verifies that empirically at
/// runtime below.
test "all-fallback parse degrades to empty UaInfo (SomethingWeNeverKnewExisted golden)" {
  let ua = "SomethingWeNeverKnewExisted"
  let result = @ua_parser.parse(ua)
  match result {
    Ok(info) => {
      // Empirical fallback-value verification (all three domains).
      assert_eq(info.browser.family, "Other")
      assert_eq(info.os.family, "Other")
      assert_eq(info.device.family, "Other")
      assert_eq(is_empty_fallback(info), true)
      let outcome = assemble(ua, result)
      assert_eq(outcome.degraded, true)
      assert_eq(outcome.ua_info == empty_ua_info(), true)
      match outcome.forensics {
        Some(rec) => {
          assert_eq(rec.ua_summary, ua) // 27 chars, below the 64 cap
          assert_eq(rec.reason, REASON_EMPTY_FALLBACK)
          assert_eq(rec.reason.length() > 0, true)
        }
        None => fail("degraded outcome must carry a forensics record")
      }
    }
    Err(_) => fail("parse never fails with the precompiled rule set")
  }
}

///|
/// synthetic: 失败注入专用 — the Err branch of the degradation contract.
/// `@ua_parser.UaError` is a read-only error type (external code cannot
/// construct `Err` values), so the Err arm is pinned through
/// `assemble_error`, which `assemble` calls on its `Err(_)` arm: mounts
/// empty UaInfo, records `parse_error` forensics, does NOT raise.
test "synthetic Err result degrades with parse_error forensics" {
  let ua = "Mozilla/4.0 (compatible; synthetic-failure-injection)"
  let outcome = assemble_error(ua)
  assert_eq(outcome.degraded, true)
  assert_eq(outcome.ua_info == empty_ua_info(), true)
  match outcome.forensics {
    Some(rec) => {
      assert_eq(rec.ua_summary, ua)
      assert_eq(rec.reason, REASON_PARSE_ERROR)
      assert_eq(rec.reason.length() > 0, true)
    }
    None => fail("Err outcome must carry a forensics record")
  }
  // An Ok-but-healthy result is NOT degraded (judgment contrast).
  assert_eq(is_degraded(Ok(empty_ua_info())), false)
}

///|
/// synthetic: 失败注入专用 — an 80-character malformed UA (only '#' bytes,
/// guaranteed to match no uap-core rule) flowing through the full
/// pipeline: parse falls back in all three domains, so `assemble`
/// degrades and the forensics ua_summary is truncated to exactly the
/// first 64 characters of the original UA.
test "synthetic malformed UA degrades with truncated 64-char summary" {
  let buf = StringBuilder()
  for i = 0; i < 80; i = i + 1 {
    buf.write_char('#')
  }
  let ua = buf.to_string()
  assert_eq(ua.length(), 80)
  let result = @ua_parser.parse(ua)
  match result {
    Ok(info) => {
      assert_eq(is_empty_fallback(info), true)
      let outcome = assemble(ua, result)
      assert_eq(outcome.degraded, true)
      match outcome.forensics {
        Some(rec) => {
          assert_eq(rec.ua_summary.length(), 64)
          assert_eq(rec.ua_summary, truncate_ua_summary(ua))
          assert_eq(rec.reason, REASON_EMPTY_FALLBACK)
        }
        None => fail("degraded outcome must carry a forensics record")
      }
    }
    Err(_) => fail("parse never fails with the precompiled rule set")
  }
}

///|
/// Boundary (R5): a UA of exactly 64 characters passes through
/// `truncate_ua_summary` and `make_forensics` unchanged.
test "boundary: 64-char UA summary kept verbatim" {
  let buf = StringBuilder()
  for i = 0; i < 64; i = i + 1 {
    buf.write_char('a')
  }
  let ua = buf.to_string()
  assert_eq(ua.length(), 64)
  assert_eq(truncate_ua_summary(ua), ua)
  let rec = make_forensics(ua, REASON_EMPTY_FALLBACK)
  assert_eq(rec.ua_summary, ua)
  assert_eq(rec.ua_summary.length(), UA_SUMMARY_MAX_LENGTH)
}

///|
/// Boundary (R5): a UA of exactly 65 characters is truncated to exactly
/// the first 64 characters.
test "boundary: 65-char UA summary truncated to 64" {
  let buf = StringBuilder()
  for i = 0; i < 65; i = i + 1 {
    buf.write_char('b')
  }
  let ua = buf.to_string()
  assert_eq(ua.length(), 65)
  let truncated = truncate_ua_summary(ua)
  assert_eq(truncated.length(), 64)
  let buf64 = StringBuilder()
  for i = 0; i < 64; i = i + 1 {
    buf64.write_char('b')
  }
  assert_eq(truncated, buf64.to_string())
  let rec = make_forensics(ua, REASON_EMPTY_FALLBACK)
  assert_eq(rec.ua_summary.length(), UA_SUMMARY_MAX_LENGTH)
}

///|
/// Boundary (R5): the empty-string UA — classified as degraded and
/// asserted through the full degradation path (all-miss fallback ->
/// empty UaInfo + forensics with an empty summary).
test "boundary: empty-string UA degrades with empty summary" {
  let result = @ua_parser.parse("")
  match result {
    Ok(info) => {
      // Empirical: no rule matches the empty string in any domain.
      assert_eq(info.browser.family, "Other")
      assert_eq(info.os.family, "Other")
      assert_eq(info.device.family, "Other")
    }
    Err(_) => fail("parse never fails with the precompiled rule set")
  }
  assert_eq(is_degraded(result), true)
  let outcome = assemble("", result)
  assert_eq(outcome.degraded, true)
  assert_eq(outcome.ua_info == empty_ua_info(), true)
  match outcome.forensics {
    Some(rec) => {
      assert_eq(rec.ua_summary, "")
      assert_eq(rec.reason, REASON_EMPTY_FALLBACK)
      assert_eq(rec.reason.length() > 0, true)
    }
    None => fail("degraded outcome must carry a forensics record")
  }
}
