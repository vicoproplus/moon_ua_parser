// One-command example (T-04 / R6): run from the workspace root with
//
//   moon run moon_ua_parser_crescent/examples/ua_echo --target native
//
// Registers the framework's request_id middleware plus the UA-parser
// middleware on a real crescent App, then dispatches four requests (three
// real UAs + one malformed SYNTHETIC UA) through the public
// `App::dispatch` pipeline. Output per request: status, the three
// browser/os/device family groups as mounted on the response, the
// handler-side read-back, and — for the degraded synthetic request — the
// forensics line emitted by the default console FO channel.

///|
async fn main {
  let app = @crescent.App()
  app.use_middleware(@middleware.request_id())
  app.use_middleware(@moon_ua_parser_crescent.middleware())
  app.get("/probe", event => {
    // Handler-side retrieval of the typed mount (same values the response
    // headers carry).
    match @moon_ua_parser_crescent.mounted_ua_info(event) {
      Some(info) =>
        "handler saw browser=\{info.browser.family} os=\{info.os.family} device=\{info.device.family}"
      None => "handler saw nothing-mounted"
    }
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
  for (label, ua) in requests {
    let (status, headers, body) = app.dispatch(
      "GET",
      "/probe",
      { "User-Agent": ua },
      b"",
    )
    let browser = headers
      .get(@moon_ua_parser_crescent.HEADER_UA_BROWSER)
      .unwrap_or("<absent>")
    let os = headers
      .get(@moon_ua_parser_crescent.HEADER_UA_OS)
      .unwrap_or("<absent>")
    let device = headers
      .get(@moon_ua_parser_crescent.HEADER_UA_DEVICE)
      .unwrap_or("<absent>")
    let body_text = @utf8.decode(body) catch { _ => "<binary>" }
    println("GET /probe  [\{label}]")
    println("  user-agent : \{ua}")
    println("  status     : \{status.to_int()}")
    println("  browser    : \{browser}")
    println("  os         : \{os}")
    println("  device     : \{device}")
    println("  body       : \{body_text}")
    println("")
  }
  println("done: 4 requests dispatched (3 healthy, 1 degraded synthetic)")
}
