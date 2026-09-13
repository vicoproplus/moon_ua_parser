// T-07 robust-input suite.
//
// synthetic:畸形输入构造 — expectation = deterministic non-crash, semantics
// per uap-python authority.
//
// Every expected value below was produced by RUNNING the vendored
// uap-python (snapshot 6dd8c39, `uap-python/src`, Python 3.12.10) on the
// EXACT same strings these tests construct (same repetition formulas, same
// control characters); nothing is guessed. Where uap-python returns None
// for a domain our engine reports family "Other" with all version fields
// None (core.py Result.with_defaults), so "Other" assertions below are the
// uap-python None answers translated through the engine contract.
//
// Determinism, not wall-clock, is the contract here: each case asserts a
// fixed outcome derived from the uap-python run; any crash, hang or
// nondeterministic result fails the suite. The 10KB performance guard
// (last test) simply asserts completion of the full-featured parse of the
// 10KB input — <1s is enforced by the `moon test` runner's per-test
// timeout, not by a fake timing assertion.

///|
/// Render an optional field in the uap-python `None` / `Some(v)` spelling
/// for debug interpolation inside assertions. Interpolating the `String?`
/// value directly routes through the deprecated core `Show for X?` impl
/// (moon check warning [0020], "Use Debug instead of Show for debugging
/// purposes"); interpolating the plain `String` produced here does not.
/// The output is byte-identical to the previous direct interpolation, so
/// every golden below is unchanged.
fn opt_str(o : String?) -> String {
  match o {
    None => "None"
    Some(v) => "Some(\{v})"
  }
}

///|
/// Build `s` repeated `n` times (helper for the over-long fixtures).
fn repeat_str(s : String, n : Int) -> String {
  let buf = StringBuilder()
  for _ in 0..<n {
    buf.write_string(s)
  }
  buf.to_string()
}

///|
/// Assert the uap-python "all three domains miss" shape field-by-field:
/// family "Other" everywhere, every other field None.
fn assert_all_other(tag : String, info : @ua_parser.UaInfo) -> Unit raise {
  let b = info.browser
  let o = info.os
  let d = info.device
  assert_eq("\{tag} browser.family=\{b.family}", "\{tag} browser.family=Other")
  assert_eq("\{tag} browser.major=\{opt_str(b.major)}", "\{tag} browser.major=None")
  assert_eq("\{tag} browser.minor=\{opt_str(b.minor)}", "\{tag} browser.minor=None")
  assert_eq("\{tag} browser.patch=\{opt_str(b.patch)}", "\{tag} browser.patch=None")
  assert_eq("\{tag} browser.patch_minor=\{opt_str(b.patch_minor)}", "\{tag} browser.patch_minor=None")
  assert_eq("\{tag} os.family=\{o.family}", "\{tag} os.family=Other")
  assert_eq("\{tag} os.major=\{opt_str(o.major)}", "\{tag} os.major=None")
  assert_eq("\{tag} os.minor=\{opt_str(o.minor)}", "\{tag} os.minor=None")
  assert_eq("\{tag} os.patch=\{opt_str(o.patch)}", "\{tag} os.patch=None")
  assert_eq("\{tag} os.patch_minor=\{opt_str(o.patch_minor)}", "\{tag} os.patch_minor=None")
  assert_eq("\{tag} device.family=\{d.family}", "\{tag} device.family=Other")
  assert_eq("\{tag} device.brand=\{opt_str(d.brand)}", "\{tag} device.brand=None")
  assert_eq("\{tag} device.model=\{opt_str(d.model)}", "\{tag} device.model=None")
}

///|
/// Fixture 1 — empty string. Vendored uap-python: UA None / OS None /
/// Device None, i.e. every domain falls back to "Other" with no versions.
test "empty string parses deterministically to Other everywhere" {
  let ua = ""
  let b = @ua_parser.parse_browser(ua)
  let o = @ua_parser.parse_os(ua)
  let d = @ua_parser.parse_device(ua)
  assert_eq("browser.family=\{b.family}", "browser.family=Other")
  assert_eq("browser.major=\{opt_str(b.major)}", "browser.major=None")
  assert_eq("browser.minor=\{opt_str(b.minor)}", "browser.minor=None")
  assert_eq("browser.patch=\{opt_str(b.patch)}", "browser.patch=None")
  assert_eq("browser.patch_minor=\{opt_str(b.patch_minor)}", "browser.patch_minor=None")
  assert_eq("os.family=\{o.family}", "os.family=Other")
  assert_eq("os.major=\{opt_str(o.major)}", "os.major=None")
  assert_eq("os.minor=\{opt_str(o.minor)}", "os.minor=None")
  assert_eq("os.patch=\{opt_str(o.patch)}", "os.patch=None")
  assert_eq("os.patch_minor=\{opt_str(o.patch_minor)}", "os.patch_minor=None")
  assert_eq("device.family=\{d.family}", "device.family=Other")
  assert_eq("device.brand=\{opt_str(d.brand)}", "device.brand=None")
  assert_eq("device.model=\{opt_str(d.model)}", "device.model=None")
  match @ua_parser.parse(ua) {
    Ok(info) => {
      assert_eq("info.browser=\{info.browser}", "info.browser=\{b}")
      assert_eq("info.os=\{info.os}", "info.os=\{o}")
      assert_eq("info.device=\{info.device}", "info.device=\{d}")
    }
    Err(_) => fail("parse must not fail on the empty string")
  }
}

///|
/// Fixture 2 — 10240 'A' characters (10KB). Vendored uap-python: UA None /
/// OS None / Device None -> "Other" everywhere.
test "10KB of A yields Other everywhere without crashing" {
  let ua = repeat_str("A", 10240)
  assert_eq("len=\{ua.length()}", "len=10240")
  match @ua_parser.parse(ua) {
    Ok(info) => assert_all_other("10kA", info)
    Err(_) => fail("parse must not fail on a 10KB alphabetic input")
  }
}

///|
/// Fixture 3 — >8KB input built from 78 repetitions of a full Chrome
/// desktop UA (112 chars each, incl. trailing space = 8736 chars) plus a
/// truncated 47-char head of the same UA -> 8783 chars total. The LAST
/// complete Chrome UA occurrence sits far inside the string; vendored
/// uap-python still matches the bounded-context Chrome rule there:
/// UA Chrome 120.0.0.0 / OS Windows 10 / Device None.
test "8.7KB repeated chrome-like pattern with truncated tail still parses" {
  let chrome_ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  let ua = repeat_str(chrome_ua + " ", 78) + "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Apple"
  assert_eq("len=\{ua.length()}", "len=8783")
  let b = @ua_parser.parse_browser(ua)
  assert_eq("browser.family=\{b.family}", "browser.family=Chrome")
  assert_eq("browser.major=\{opt_str(b.major)}", "browser.major=Some(120)")
  assert_eq("browser.minor=\{opt_str(b.minor)}", "browser.minor=Some(0)")
  assert_eq("browser.patch=\{opt_str(b.patch)}", "browser.patch=Some(0)")
  assert_eq("browser.patch_minor=\{opt_str(b.patch_minor)}", "browser.patch_minor=Some(0)")
  let o = @ua_parser.parse_os(ua)
  assert_eq("os.family=\{o.family}", "os.family=Windows")
  assert_eq("os.major=\{opt_str(o.major)}", "os.major=Some(10)")
  match @ua_parser.parse(ua) {
    Ok(info) => {
      assert_eq("device.family=\{info.device.family}", "device.family=Other")
      assert_eq("device.brand=\{opt_str(info.device.brand)}", "device.brand=None")
      assert_eq("device.model=\{opt_str(info.device.model)}", "device.model=None")
    }
    Err(_) => fail("parse must not fail on an 8.7KB chrome-like input")
  }
}

///|
/// Fixture 4 — exactly 4100 chars: 61-char Mozilla/Windows prefix + 4024
/// embedded spaces + 15-char "Chrome/99.0.1.2" tail. Vendored uap-python:
/// UA Chrome 99.0.1.2 (the bounded front-context of the Chrome rule still
/// reaches the version tail) / OS Windows 10 / Device None.
test "4100-char UA with embedded space run parses to chrome 99.0.1.2" {
  let suffix = "Chrome/99.0.1.2"
  let prefix = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
  let ua = prefix + repeat_str(" ", 4100 - prefix.length() - suffix.length()) + suffix
  assert_eq("len=\{ua.length()}", "len=4100")
  let b = @ua_parser.parse_browser(ua)
  assert_eq("browser.family=\{b.family}", "browser.family=Chrome")
  assert_eq("browser.major=\{opt_str(b.major)}", "browser.major=Some(99)")
  assert_eq("browser.minor=\{opt_str(b.minor)}", "browser.minor=Some(0)")
  assert_eq("browser.patch=\{opt_str(b.patch)}", "browser.patch=Some(1)")
  assert_eq("browser.patch_minor=\{opt_str(b.patch_minor)}", "browser.patch_minor=Some(2)")
  match @ua_parser.parse(ua) {
    Ok(info) => {
      assert_eq("os.family=\{info.os.family}", "os.family=Windows")
      assert_eq("device.family=\{info.device.family}", "device.family=Other")
    }
    Err(_) => fail("parse must not fail on a 4100-char spaced input")
  }
}

///|
/// Fixture 5 — NUL (\x00) injected inside the `(KHTML, like Gecko)`
/// literal of a Chrome shell. Vendored uap-python STILL matches Chrome
/// 120.0.0.0 there (the rule's flexible front context reaches the version
/// tail) / OS Windows 10 / Device None.
test "NUL inside khtml literal keeps chrome parse deterministic" {
  let ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML,\u{00}like Gecko) Chrome/120.0.0.0 Safari/537.36"
  let b = @ua_parser.parse_browser(ua)
  assert_eq("browser.family=\{b.family}", "browser.family=Chrome")
  assert_eq("browser.major=\{opt_str(b.major)}", "browser.major=Some(120)")
  match @ua_parser.parse(ua) {
    Ok(info) => {
      assert_eq("os.family=\{info.os.family}", "os.family=Windows")
      assert_eq("device.family=\{info.device.family}", "device.family=Other")
    }
    Err(_) => fail("parse must not fail on a NUL-bearing input")
  }
}

///|
/// Fixture 6 — 0x01 injected between the iOS version digits. Vendored
/// uap-python: UA Mobile Safari 14.3 / OS iOS 14.3 patch None (a later
/// flexible iOS rule still lands on 14/3) / Device iPhone Apple iPhone.
test "0x01 inside iOS version yields mobile safari iOS iphone" {
  let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 14\u{01}3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.3 Mobile/15E148 Safari/605.1.15"
  let b = @ua_parser.parse_browser(ua)
  assert_eq("browser.family=\{b.family}", "browser.family=Mobile Safari")
  assert_eq("browser.major=\{opt_str(b.major)}", "browser.major=Some(14)")
  assert_eq("browser.minor=\{opt_str(b.minor)}", "browser.minor=Some(3)")
  let o = @ua_parser.parse_os(ua)
  assert_eq("os.family=\{o.family}", "os.family=iOS")
  assert_eq("os.major=\{opt_str(o.major)}", "os.major=Some(14)")
  assert_eq("os.patch=\{opt_str(o.patch)}", "os.patch=None")
  let d = @ua_parser.parse_device(ua)
  assert_eq("device.family=\{d.family}", "device.family=iPhone")
  assert_eq("device.brand=\{opt_str(d.brand)}", "device.brand=Some(Apple)")
  assert_eq("device.model=\{opt_str(d.model)}", "device.model=Some(iPhone)")
}

///|
/// Fixture 7 — 0x1F after "Mozilla/5.0 " and 0x7F before " AppleWebKit"
/// inside a Chrome 55 shell. Vendored uap-python: UA Chrome 55.0.2883.75 /
/// OS Windows 10 / Device None.
test "0x1f and 0x7f inside chrome shell keep chrome parse deterministic" {
  let ua = "Mozilla/5.0 \u{1f}(Windows NT 10.0; Win64; x64)\u{7f} AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.75 Safari/537.36"
  let b = @ua_parser.parse_browser(ua)
  assert_eq("browser.family=\{b.family}", "browser.family=Chrome")
  assert_eq("browser.major=\{opt_str(b.major)}", "browser.major=Some(55)")
  assert_eq("browser.minor=\{opt_str(b.minor)}", "browser.minor=Some(0)")
  assert_eq("browser.patch=\{opt_str(b.patch)}", "browser.patch=Some(2883)")
  assert_eq("browser.patch_minor=\{opt_str(b.patch_minor)}", "browser.patch_minor=Some(75)")
  match @ua_parser.parse(ua) {
    Ok(info) => {
      assert_eq("os.family=\{info.os.family}", "os.family=Windows")
      assert_eq("device.family=\{info.device.family}", "device.family=Other")
    }
    Err(_) => fail("parse must not fail on 0x1f/0x7f-bearing input")
  }
}

///|
/// Fixture 8 — leading NUL before "Mozilla/5.0". Vendored uap-python:
/// UA Chrome 120.0.0.0 / OS Windows 10 / Device None (search skips the
/// prefix garbage).
test "leading NUL before mozilla prefix keeps chrome parse deterministic" {
  let ua = "\u{00}Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  let b = @ua_parser.parse_browser(ua)
  assert_eq("browser.family=\{b.family}", "browser.family=Chrome")
  assert_eq("browser.patch_minor=\{opt_str(b.patch_minor)}", "browser.patch_minor=Some(0)")
  match @ua_parser.parse(ua) {
    Ok(info) => {
      assert_eq("os.family=\{info.os.family}", "os.family=Windows")
      assert_eq("device.family=\{info.device.family}", "device.family=Other")
    }
    Err(_) => fail("parse must not fail on a leading-NUL input")
  }
}

///|
/// Performance guard — the full API surface over the 10KB 'A' input must
/// complete and be stable across calls. No wall-clock is asserted: moon's
/// test runner enforces the <1s budget via its per-test timeout; a hang
/// here fails the suite, which is the sanctioned guard per the task plan.
test "10KB input completes across the full API surface deterministically" {
  let ua = repeat_str("A", 10240)
  for i in 0..<3 {
    let b = @ua_parser.parse_browser(ua)
    let o = @ua_parser.parse_os(ua)
    let d = @ua_parser.parse_device(ua)
    assert_eq("run\{i} browser.family=\{b.family}", "run\{i} browser.family=Other")
    assert_eq("run\{i} os.family=\{o.family}", "run\{i} os.family=Other")
    assert_eq("run\{i} device.family=\{d.family}", "run\{i} device.family=Other")
    match @ua_parser.parse(ua) {
      Ok(info) => assert_all_other("guard\{i}", info)
      Err(_) => fail("parse must not fail on the 10KB guard input")
    }
  }
}
