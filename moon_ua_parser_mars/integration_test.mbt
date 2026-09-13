// Integration tests (T-05): real HTTP requests through a real mars Server
// via the framework's own network stack — an ephemeral 127.0.0.1 listener
// (`@http.Server::new(port=0)`, real port via getsockname) driven by the
// framework's own request parsing (`ServerConnection::read_request`) and a
// bounded accept-exactly-N loop, answered by `app.to_handler()` (the same
// handler `Server::serve` would install). mars ships no network-free test
// client (unlike crescent's `test_client`); the bounded loopback
// round-trip IS the real dispatch path. Every server has a bounded
// lifetime: the task group closes the listener via `defer` when the
// round-trip helper returns, and the accept loop exits with it (accept
// raises once the listener is closed) — nothing stays resident.
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
/// Build a server with the UA middleware registered and a `/probe` route
/// whose handler echoes the handler-side typed mount read-back.
fn probe_app(
  sink~ : (@middleware_core.ForensicsRecord) -> Unit,
) -> @mars.Server {
  let app = @mars.Server::new()
  app.middleware(middleware(forensics_sink=sink))
  app.get("/probe", ctx => {
    match mounted_ua_info(ctx) {
      Some(info) =>
        ctx.text(
          "browser=\{info.browser.family} os=\{info.os.family} device=\{info.device.family}",
        )
      None => ctx.text("nothing-mounted")
    }
  })
  app
}

///|
/// Like `probe_app`, but the handler answers with a mount-class marker:
/// `empty-mount` when the mounted UaInfo is structurally the helper's
/// `empty_ua_info` (degradation), `healthy-mount` otherwise, and
/// `nothing-mounted` when no middleware ran. This turns the R4 "empty
/// result mounted" assertion into a structural check through the real
/// dispatch (UaInfo derives Eq).
fn mount_marker_app(
  sink~ : (@middleware_core.ForensicsRecord) -> Unit,
) -> @mars.Server {
  let app = @mars.Server::new()
  app.middleware(middleware(forensics_sink=sink))
  app.get("/probe", ctx => {
    match mounted_ua_info(ctx) {
      Some(info) =>
        if info == @middleware_core.empty_ua_info() {
          ctx.text("empty-mount")
        } else {
          ctx.text("healthy-mount")
        }
      None => ctx.text("nothing-mounted")
    }
  })
  app
}

///|
/// Accept exactly `count` connections and answer each through the
/// framework's own request parsing + `app.to_handler()` dispatch. Exits
/// when the listener is closed (`accept` raises) — a bounded server
/// lifetime by construction, shared by the tests and the example.
async fn serve_requests(
  srv : @http.Server,
  app : @mars.Server,
  count : Int,
) -> Unit {
  let handler = app.to_handler()
  for _ in 0..<count {
    let (conn, _addr) = srv.accept() catch { _ => return }
    let req = conn.read_request() catch {
      _ => {
        conn.close()
        continue
      }
    }
    handler(req, conn, conn)
    conn.close()
  }
}

///|
/// One bounded real-loopback round-trip: bind the framework's own HTTP
/// server on an ephemeral 127.0.0.1 port, serve exactly this request, and
/// return (status, body). The request is written with a raw socket (not
/// `@http.get`) because the mizchi/x client merges its own default
/// `User-Agent: moonbit-http-client/1.1` into the request headers, which
/// would corrupt the user-agent under test; a raw request carries exactly
/// the headers this test chooses. `ua=None` sends no User-Agent header at
/// all (the missing-header degradation case). The `defer` closes the
/// listener when the task-group body exits, which also ends the accept
/// loop and the connection — a bounded server lifetime by construction.
async fn roundtrip(
  app : @mars.Server,
  ua~ : String?,
) -> (Int, String) raise {
  @async.with_task_group(tg => {
    let srv = @http.Server::new(host="127.0.0.1", port=0)
    defer srv.close()
    let port = srv.port()
    tg.spawn_bg(() => serve_requests(srv, app, 1))
    let sock = @socket.Tcp::connect_to_host("127.0.0.1", port~)
    defer sock.close()
    let ua_line = match ua {
      Some(u) => "User-Agent: \{u}\r\n"
      None => ""
    }
    sock.write(
      "GET /probe HTTP/1.1\r\nHost: 127.0.0.1\r\n\{ua_line}Connection: close\r\n\r\n",
    )
    let resp = sock.read_all().text() catch { _ => "" }
    (response_status_code(resp), response_body(resp))
  })
}

///|
/// Status code of a raw HTTP/1.1 response's first line ("HTTP/1.1 200 OK"
/// -> 200; 0 for an unparsable response).
fn response_status_code(resp : String) -> Int {
  let first_line = resp.split("\r\n").to_array()[0]
  let parts = first_line.split(" ").to_array()
  if parts.length() >= 2 {
    match parts[1] {
      "200" => 200
      "201" => 201
      "204" => 204
      "301" => 301
      "302" => 302
      "400" => 400
      "401" => 401
      "403" => 403
      "404" => 404
      "405" => 405
      "500" => 500
      "502" => 502
      "503" => 503
      _ => 0
    }
  } else {
    0
  }
}

///|
/// Body of a raw HTTP response whose body is chunk-encoded (the
/// moonbitlang/async server frames bodies written without a
/// Content-Length header as chunked): strips headers, then removes the
/// `<hex-size>\r\n` / `\r\n` chunk framing and the terminal `0` chunk.
fn response_body(resp : String) -> String {
  let parts = resp.split("\r\n\r\n").to_array()
  if parts.length() < 2 {
    return ""
  }
  let mut rest = parts[1].to_owned()
  for i in 1..<(parts.length() - 1) {
    rest = rest + "\r\n\r\n" + parts[i + 1].to_owned()
  }
  let buf = StringBuilder()
  let mut done = false
  while !done && rest.length() > 0 {
    // one iteration: "<hex-size>[;ext]\r\n<data>\r\n" prefix of `rest`
    let head_end = match find_substring(rest, "\r\n") {
      Some(idx) => idx
      None => break
    }
    let size = parse_hex_prefix(rest[:head_end].to_owned())
    if size <= 0 {
      break
    }
    let data_start = head_end + 2
    let data_end = data_start + size
    if data_end > rest.length() {
      break
    }
    buf.write_string(rest[data_start:data_end].to_owned())
    rest = rest[data_end + 2:rest.length()].to_owned()
    if rest == "0" || rest == "0\r\n\r\n" || rest.has_prefix("0\r\n") {
      done = true
    }
  }
  buf.to_string()
}

///|
/// Index of the first occurrence of `needle` in `s` (None when absent).
fn find_substring(s : String, needle : String) -> Int? {
  let n = needle.length()
  if n == 0 || s.length() < n {
    return if n == 0 { Some(0) } else { None }
  }
  for i in 0..=(s.length() - n) {
    if s[i:i + n] == needle {
      return Some(i)
    }
  }
  None
}

///|
/// Parse a hexadecimal chunk-size prefix (digits before any `;`
/// extension); -1 when the prefix is not a valid hex number.
fn parse_hex_prefix(s : String) -> Int {
  let mut value = 0
  let mut digits = 0
  for ch in s {
    if ch == ';' {
      break
    }
    let d = match ch {
      '0'..='9' => ch.to_int() - '0'.to_int()
      'a'..='f' => ch.to_int() - 'a'.to_int() + 10
      'A'..='F' => ch.to_int() - 'A'.to_int() + 10
      _ => return -1
    }
    value = value * 16 + d
    digits += 1
    if digits > 8 {
      return -1
    }
  }
  if digits == 0 {
    -1
  } else {
    value
  }
}

///|
/// Real UA: three-group results retrievable from the typed context mount,
/// through the framework's own dispatch. Also composes the framework's
/// own `logger_simple` middleware upstream to show the adapter registers
/// like any native mars middleware (it prints one `--> GET /probe` line
/// per request to the framework's console log channel).
async test "real UA: three-group results retrievable from the context mount" {
  let app = @mars.Server::new()
  app.middleware(@middleware.logger_simple())
  app.middleware(middleware())
  app.get("/probe", ctx => {
    match mounted_ua_info(ctx) {
      Some(info) =>
        ctx.text(
          "browser=\{info.browser.family} os=\{info.os.family} device=\{info.device.family}",
        )
      None => ctx.text("nothing-mounted")
    }
  })
  let (status, body) = roundtrip(app, ua=Some(UA_IOS))
  assert_eq(status, 200)
  // handler-side retrieval of the three mounted groups from ctx.vars
  // golden:uap-core-tests uap-core/tests/test_ua.yaml:8955   (DuckDuckGo Mobile)
  // golden:uap-core-tests uap-core/tests/test_os.yaml:3302   (iOS)
  // golden:uap-core-tests uap-core/tests/test_device.yaml:80537 (iPhone)
  assert_eq(body, "browser=DuckDuckGo Mobile os=iOS device=iPhone")
}

///|
/// Real UA 2 (Android golden): three-group retrieval through a second
/// registered server (repeatability of the mount contract).
async test "real UA 2 (Android golden): three-group results retrievable" {
  let app = @mars.Server::new()
  app.middleware(middleware())
  app.get("/probe", ctx => {
    match mounted_ua_info(ctx) {
      Some(info) =>
        ctx.text(
          "browser=\{info.browser.family} os=\{info.os.family} device=\{info.device.family}",
        )
      None => ctx.text("nothing-mounted")
    }
  })
  let (status, body) = roundtrip(app, ua=Some(UA_ANDR))
  assert_eq(status, 200)
  // golden:uap-core-tests uap-core/tests/test_ua.yaml:8961   (DuckDuckGo Mobile)
  // golden:uap-core-tests uap-core/tests/test_os.yaml:3309   (Android)
  // golden:uap-core-tests uap-core/tests/test_device.yaml:80542 (Generic Smartphone)
  assert_eq(body, "browser=DuckDuckGo Mobile os=Android device=Generic Smartphone")
}

///|
/// R4 triple assertion on a malformed (SYNTHETIC) user-agent:
/// 1. the request still answers with a normal (non-5xx) status;
/// 2. the mount is the empty result — structurally the helper's
///    `empty_ua_info` (empty-string families), not the library's "Other"
///    fallback;
/// 3. a `{ua_summary, reason}` forensics record is retrievable from the
///    injected FO sink.
async test "malformed synthetic UA: not-5xx + empty mount + forensics retrievable" {
  let captured : Ref[Array[@middleware_core.ForensicsRecord]] = Ref([])
  let app = mount_marker_app(sink=rec => captured.val.push(rec))
  let (status, body) = roundtrip(app, ua=Some(UA_MALFORMED_SYNTHETIC))
  // 1. degradation never turns into a 5xx (200 OK, chain continues).
  assert_eq(status, 200)
  // 2. mounted value is the empty UaInfo (empty families), asserted
  //    structurally by the handler through the real dispatch.
  assert_eq(body, "empty-mount")
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
  let (status, body) = roundtrip(app, ua=Some(UA_MALFORMED_LONG_SYNTHETIC))
  assert_eq(status, 200)
  assert_eq(body, "browser= os= device=")
  assert_eq(captured.val.length(), 1)
  let rec = captured.val[0]
  assert_eq(rec.ua_summary.length(), @middleware_core.UA_SUMMARY_MAX_LENGTH)
  assert_eq(rec.reason, @middleware_core.REASON_EMPTY_FALLBACK)
  // truncation keeps the leading characters (helper contract)
  assert_true(UA_MALFORMED_LONG_SYNTHETIC.has_prefix(rec.ua_summary))
}

///|
/// Without the middleware registered upstream, the read-back is None
/// (misuse guard; no spurious mount).
async test "no middleware: handler-side read-back is None" {
  let app = @mars.Server::new()
  app.get("/probe", ctx => {
    match mounted_ua_info(ctx) {
      Some(_) => ctx.text("mounted")
      None => ctx.text("nothing-mounted")
    }
  })
  let (status, body) = roundtrip(app, ua=Some(UA_IOS))
  assert_eq(status, 200)
  assert_eq(body, "nothing-mounted")
}

///|
/// Missing User-Agent header degrades through the same helper path (empty
/// UA = all-miss): not-5xx, empty mount, forensics emitted. The round-trip
/// sends NO User-Agent header at all (ua=None, raw socket) — this is also
/// why the adapter keeps a lowercase fallback lookup: mars native
/// lowercases header keys, and a request without User-Agent must degrade,
/// not misread.
async test "missing User-Agent header: empty mount + forensics, no 5xx" {
  let captured : Ref[Array[@middleware_core.ForensicsRecord]] = Ref([])
  let app = mount_marker_app(sink=rec => captured.val.push(rec))
  let (status, body) = roundtrip(app, ua=None)
  // 1. non-5xx: the framework answered 200.
  assert_eq(status, 200)
  // 2. empty mount through the real dispatch.
  assert_eq(body, "empty-mount")
  // 3. forensics record retrievable from the FO channel.
  assert_eq(captured.val.length(), 1)
  assert_eq(captured.val[0].reason, @middleware_core.REASON_EMPTY_FALLBACK)
}
