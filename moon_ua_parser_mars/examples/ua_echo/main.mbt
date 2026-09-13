// One-command example (T-05 / R6): run from the workspace root with
//
//   moon run moon_ua_parser_mars/examples/ua_echo --target native
//
// Registers the framework's own logger_simple middleware (mars's log
// channel) plus the UA-parser middleware on a real mars Server, then
// dispatches four real HTTP requests (three real UAs + one malformed
// SYNTHETIC UA) over an ephemeral 127.0.0.1 listener through the
// framework's own network stack. Output per request: the framework log
// line, the status, and the handler body — the three browser/os/device
// family groups read back from the typed context mount by the handler;
// the degraded synthetic request additionally shows the forensics line
// emitted by the default console FO channel (the same println sink
// mars's own logger middleware writes to). The listener is closed when
// the task group body exits (`defer srv.close()`) — bounded, non-resident.
//
// Client note: requests are written with a raw socket (not the mizchi/x
// HTTP client) because that client merges its own default
// `User-Agent: moonbit-http-client/1.1` into outgoing headers, which
// would corrupt the user-agent under test. The /probe handler sets an
// exact Content-Length (a production pattern), so the response body is
// fixed-length framed and the client can read it directly.

///|
/// One GET with an explicit User-Agent over a raw loopback socket,
/// bounded and error-safe: (status-line-code, body-text) with
/// (0, "<request failed: ...>") on transport errors so the demo always
/// terminates deterministically.
async fn fetch_text(port : Int, ua : String) -> (Int, String) {
  try {
    let sock = @async_socket.Tcp::connect_to_host("127.0.0.1", port~)
    defer sock.close()
    sock.write(
      "GET /probe HTTP/1.1\r\nHost: 127.0.0.1\r\nUser-Agent: \{ua}\r\nConnection: close\r\n\r\n",
    )
    let resp = sock.read_all().text() catch { _ => "" }
    let first_line = resp.split("\r\n").to_array()[0]
    let status = match first_line.split(" ").to_array()[1] {
      "200" => 200
      _ => 0
    }
    let body = match find_substring(resp, "\r\n\r\n") {
      Some(idx) => resp[idx + 4:resp.length()].to_owned()
      None => ""
    }
    (status, body)
  } catch {
    err => (0, "<request failed: \{err}>")
  }
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
/// Accept exactly `count` connections and answer each through the
/// framework's own request parsing + `app.to_handler()` dispatch. Exits
/// when the listener is closed (`accept` raises) — shared bounded-server
/// lifetime pattern (the integration tests use the same shape).
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
async fn main {
  let app = @mars.Server::new()
  // The framework's own logger middleware (mars log channel, `--> ...`
  // lines) composed with the UA-parser middleware.
  app.middleware(@middleware.logger_simple())
  app.middleware(@moon_ua_parser_mars.middleware())
  app.get("/probe", ctx => {
    // Handler-side retrieval of the typed mount (ctx.vars read-back).
    let body = match @moon_ua_parser_mars.mounted_ua_info(ctx) {
      Some(info) =>
        "handler saw browser=\{info.browser.family} os=\{info.os.family} device=\{info.device.family}"
      None => "handler saw nothing-mounted"
    }
    // Exact Content-Length (bytes) so the response is fixed-length
    // framed instead of chunk-encoded.
    ctx.set_header(
      "Content-Length",
      @encoding.encode(@encoding.UTF8, body).length().to_string(),
    )
    ctx.text(body)
  })
  let requests : Array[(String, String)] = [
    (
      "desktop Chrome / Windows", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    ),
    (
      "iPhone DuckDuckGo / iOS 14.3", "Mozilla/5.0 (iPhone; CPU iPhone OS 14_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.3 Mobile/15E148 DuckDuckGo/7 Safari/605.1.15",
    ),
    (
      "Android 11 Chrome WebView", "Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/87.0.4280.141 Mobile DuckDuckGo/5 Safari/537.36",
    ),
    // SYNTHETIC malformed UA (not from any uap-core golden file): degrades
    // to the empty mount + a console forensics line, response stays 200.
    ("malformed (synthetic)", "SomethingWeNeverKnewExisted"),
  ]
  @async.with_task_group(tg => {
    let srv = @http.Server::new(host="127.0.0.1", port=0)
    defer srv.close()
    let port = srv.port()
    tg.spawn_bg(() => serve_requests(srv, app, 4))
    for (label, ua) in requests {
      let (status, body) = fetch_text(port, ua)
      println("GET /probe  [\{label}]")
      println("  user-agent : \{ua}")
      println("  status     : \{status}")
      println("  body       : \{body}")
      println("")
    }
  })
  println("done: 4 requests dispatched (3 healthy, 1 degraded synthetic)")
}
