// Integration tests (T-04): real requests through a real crescent App via
// the framework's own network-free `test_client`, asserting the three-group
// (browser / os / device) mount contract end to end.
//
// Golden cases (uap-core, exact paths in this repository):
// - UA_IOS  : golden:uap-core-tests uap-core/tests/test_ua.yaml:8955
//             golden:uap-core-tests uap-core/tests/test_os.yaml:3302
//             golden:uap-core-tests uap-core/tests/test_device.yaml:80537
// - UA_ANDR : golden:uap-core-tests uap-core/tests/test_ua.yaml:8961
//             golden:uap-core-tests uap-core/tests/test_os.yaml:3309
//             golden:uap-core-tests uap-core/tests/test_device.yaml:80542
// - malformed cases are SYNTHETIC (not from any uap-core golden file):
//   they use the all-miss literal `SomethingWeNeverKnewExisted` that the
//   helper package (T-03) runtime-verified to degrade (all three families
//   "Other"), plus a lengthened variant to pin the 64-char ua_summary
//   truncation.

///|
/// iPhone DuckDuckGo 7 on iOS 14.3 (all three uap-core golden files carry
/// this exact string — see file header for line numbers).
const UA_IOS : String = "Mozilla/5.0 (iPhone; CPU iPhone OS 14_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.3 Mobile/15E148 DuckDuckGo/7 Safari/605.1.15"

///|
/// Android 11 Chrome WebView DuckDuckGo 5 (all three uap-core golden files
/// carry this exact string — see file header for line numbers).
const UA_ANDR : String = "Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/87.0.4280.141 Mobile DuckDuckGo/5 Safari/537.36"

///|
/// SYNTHETIC malformed UA (not a uap-core golden): runtime-verified
/// all-miss literal -> all three families "Other" -> helper degradation.
const UA_MALFORMED_SYNTHETIC : String = "SomethingWeNeverKnewExisted"

///|
/// SYNTHETIC malformed UA, longer than UA_SUMMARY_MAX_LENGTH (64) to pin
/// the helper's truncation through the adapter's FO channel.
const UA_MALFORMED_LONG_SYNTHETIC : String = "SomethingWeNeverKnewExisted-padding-padding-padding-padding-padding"

///|
/// Build an app with the UA middleware registered and a `/probe` route
/// whose handler echoes the handler-side typed mount read-back.
fn probe_app(
  sink~ : (@middleware_core.ForensicsRecord) -> Unit,
) -> @crescent.App {
  let app = @crescent.App()
  app.use_middleware(middleware(forensics_sink=sink))
  app.get("/probe", event => {
    match mounted_ua_info(event) {
      Some(info) =>
        "browser=\{info.browser.family} os=\{info.os.family} device=\{info.device.family}"
      None => "nothing-mounted"
    }
  })
  app
}

///|
async test "real UA: three-group results retrievable from headers, response and handler" {
  let app = @crescent.App()
  // Compose with the framework's own request_id middleware to show the
  // adapter registers like any native crescent middleware.
  app.use_middleware(@middleware.request_id())
  app.use_middleware(middleware())
  app.get("/probe", event => {
    match mounted_ua_info(event) {
      Some(info) => "browser=\{info.browser.family}"
      None => "nothing-mounted"
    }
  })
  let client = @test_client.TestClient(app)
  let res = client.get("/probe", headers={ "User-Agent": UA_IOS })
  // (a) response carries the three-group family headers
  // golden:uap-core-tests uap-core/tests/test_ua.yaml:8955   (DuckDuckGo Mobile)
  assert_eq(res.headers.get(HEADER_UA_BROWSER), Some("DuckDuckGo Mobile"))
  // golden:uap-core-tests uap-core/tests/test_os.yaml:3302   (iOS)
  assert_eq(res.headers.get(HEADER_UA_OS), Some("iOS"))
  // golden:uap-core-tests uap-core/tests/test_device.yaml:80537 (iPhone)
  assert_eq(res.headers.get(HEADER_UA_DEVICE), Some("iPhone"))
  // (b) typed round-trip: the JSON header reconstructs EXACTLY the value
  // the library parse produced (full UaInfo structural equality).
  let mounted = parse_mounted_ua_info(
    res.headers.get(HEADER_UA_INFO).unwrap_or(""),
  )
  match @ua_parser.parse(UA_IOS) {
    Ok(parsed) => assert_true(mounted == Some(parsed))
    Err(_) => fail("parse never fails with the precompiled rule set")
  }
  // (c) handler-side retrieval: the route handler read the same mount
  // from the event context during the request.
  assert_eq(res.body_text(), "browser=DuckDuckGo Mobile")
  // (d) the framework's own middleware ran alongside ours.
  assert_true(res.headers.get("X-Request-Id") is Some(_))
}

///|
async test "real UA 2 (Android golden): three-group round-trip equality" {
  let app = @crescent.App()
  app.use_middleware(middleware())
  let client = @test_client.TestClient(app)
  let res = client.get("/probe", headers={ "User-Agent": UA_ANDR })
  // golden:uap-core-tests uap-core/tests/test_ua.yaml:8961   (DuckDuckGo Mobile)
  assert_eq(res.headers.get(HEADER_UA_BROWSER), Some("DuckDuckGo Mobile"))
  // golden:uap-core-tests uap-core/tests/test_os.yaml:3309   (Android)
  assert_eq(res.headers.get(HEADER_UA_OS), Some("Android"))
  // golden:uap-core-tests uap-core/tests/test_device.yaml:80542 (Generic Smartphone)
  assert_eq(res.headers.get(HEADER_UA_DEVICE), Some("Generic Smartphone"))
  let mounted = parse_mounted_ua_info(
    res.headers.get(HEADER_UA_INFO).unwrap_or(""),
  )
  match @ua_parser.parse(UA_ANDR) {
    Ok(parsed) => assert_true(mounted == Some(parsed))
    Err(_) => fail("parse never fails with the precompiled rule set")
  }
}

///|
/// R4 triple assertion on a malformed (SYNTHETIC) user-agent:
/// 1. the request still answers with a normal (non-5xx) status;
/// 2. the mount is the empty result (empty-string families, the helper's
///    `empty_ua_info`) — not the library's "Other" fallback;
/// 3. a `{ua_summary, reason}` forensics record is retrievable from the
///    injected FO sink.
async test "malformed synthetic UA: not-5xx + empty mount + forensics retrievable" {
  let captured : Ref[Array[@middleware_core.ForensicsRecord]] = Ref([])
  let app = probe_app(sink=rec => captured.val.push(rec))
  let client = @test_client.TestClient(app)
  let res = client.get("/probe", headers={
    "User-Agent": UA_MALFORMED_SYNTHETIC,
  })
  // 1. degradation never turns into a 5xx (200 OK, chain continues).
  assert_eq(res.status.to_int(), 200)
  // 2. mounted value is the empty UaInfo (empty families), visible in the
  //    family headers and in the typed round-trip.
  assert_eq(res.headers.get(HEADER_UA_BROWSER), Some(""))
  assert_eq(res.headers.get(HEADER_UA_OS), Some(""))
  assert_eq(res.headers.get(HEADER_UA_DEVICE), Some(""))
  let mounted_empty = parse_mounted_ua_info(
    res.headers.get(HEADER_UA_INFO).unwrap_or(""),
  )
  assert_true(mounted_empty == Some(@middleware_core.empty_ua_info()))
  // the handler still answered (chain not interrupted)
  assert_eq(res.body_text(), "browser= os= device=")
  // 3. forensics record retrievable from the FO channel: exactly one
  //    record with the helper's contract fields.
  assert_eq(captured.val.length(), 1)
  let rec = captured.val[0]
  assert_eq(rec.ua_summary, UA_MALFORMED_SYNTHETIC)
  assert_eq(rec.reason, @middleware_core.REASON_EMPTY_FALLBACK)
}

///|
/// SYNTHETIC long malformed UA: the FO channel record carries the helper's
/// 64-character truncation (adapter forwards the record unmodified).
async test "malformed long synthetic UA: forensics ua_summary truncated to 64" {
  let captured : Ref[Array[@middleware_core.ForensicsRecord]] = Ref([])
  let app = probe_app(sink=rec => captured.val.push(rec))
  let client = @test_client.TestClient(app)
  let res = client.get("/probe", headers={
    "User-Agent": UA_MALFORMED_LONG_SYNTHETIC,
  })
  assert_eq(res.status.to_int(), 200)
  assert_eq(captured.val.length(), 1)
  let rec = captured.val[0]
  assert_eq(rec.ua_summary.length(), @middleware_core.UA_SUMMARY_MAX_LENGTH)
  assert_eq(rec.reason, @middleware_core.REASON_EMPTY_FALLBACK)
  // truncation keeps the leading characters (helper contract)
  assert_true(UA_MALFORMED_LONG_SYNTHETIC.has_prefix(rec.ua_summary))
}

///|
/// Without the middleware registered upstream, the read-back is None
/// (misuse guard; no spurious empty mount).
async test "no middleware: handler-side read-back is None" {
  let app = @crescent.App()
  app.get("/probe", event => {
    match mounted_ua_info(event) {
      Some(_) => "mounted"
      None => "nothing-mounted"
    }
  })
  let client = @test_client.TestClient(app)
  let res = client.get("/probe", headers={ "User-Agent": UA_IOS })
  assert_eq(res.body_text(), "nothing-mounted")
}

///|
/// Registration adaptation covers crescent's optional `base_path` scoping:
/// outside the scope the middleware does not mount; inside it does.
async test "base_path scoped registration mounts only inside the scope" {
  let app = @crescent.App()
  app.use_middleware(middleware(), base_path="/api")
  app.get("/probe", event => {
    match mounted_ua_info(event) {
      Some(info) => "browser=\{info.browser.family}"
      None => "nothing-mounted"
    }
  })
  app.get("/api/probe", event => {
    match mounted_ua_info(event) {
      Some(info) => "browser=\{info.browser.family}"
      None => "nothing-mounted"
    }
  })
  let client = @test_client.TestClient(app)
  let outside = client.get("/probe", headers={ "User-Agent": UA_IOS })
  assert_eq(outside.body_text(), "nothing-mounted")
  let inside = client.get("/api/probe", headers={ "User-Agent": UA_IOS })
  assert_eq(inside.body_text(), "browser=DuckDuckGo Mobile")
}

///|
/// Missing User-Agent header degrades through the same helper path (empty
/// UA = all-miss): not-5xx, empty mount, forensics emitted.
async test "missing User-Agent header: empty mount + forensics, no 5xx" {
  let captured : Ref[Array[@middleware_core.ForensicsRecord]] = Ref([])
  let app = probe_app(sink=rec => captured.val.push(rec))
  let client = @test_client.TestClient(app)
  let res = client.get("/probe")
  assert_eq(res.status.to_int(), 200)
  assert_eq(res.headers.get(HEADER_UA_BROWSER), Some(""))
  assert_eq(captured.val.length(), 1)
  assert_eq(captured.val[0].reason, @middleware_core.REASON_EMPTY_FALLBACK)
}
