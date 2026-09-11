// Differential pass-rate reporter (T-08 stats; see moon.pkg for the contract).
//
// Failure messages have the generated format
//   <domain>[<i>] field=<f> expected=<e> got=<g> input=<ua>
// and are grouped by their "<field>...<got>" signature (the message minus the
// leading "<domain>[<i>] " and the trailing " input=<ua>") so that failure
// MODES can be counted, not just raw case counts.

///|
/// One domain row of the report.
struct DomainStats {
  name : String
  total : Int
  exempted : Int
  failures : Array[String]
  /// Acceptance gate in basis points of `total` (e.g. 9900 = 99.00 %).
  gate_bps : Int
}

///|
/// Extract the failure-mode signature from one generated failure message:
/// the part between the first " field=" and the trailing " input=" segment.
fn signature(msg : String) -> String {
  let start = match msg.find(" field=") {
    Some(i) => i + 1
    None => 0
  }
  let end = match msg.rev_find(" input=") {
    Some(i) => i
    None => msg.length()
  }
  if start < end {
    msg[start:end].to_owned()
  } else {
    msg
  }
}

///|
/// Parse a run of ASCII digits as a non-negative decimal integer.
fn parse_digits(s : String) -> Int? {
  let mut value = 0
  for ch in s {
    if ch >= '0' && ch <= '9' {
      value = value * 10 + (ch.to_int() - '0'.to_int())
    } else {
      return None
    }
  }
  Some(value)
}

///|
/// Extract the 0-based case index from the leading "<domain>[<i>]" of a
/// generated failure message (`None` when the prefix is malformed).
fn case_index(msg : String) -> Int? {
  let open = msg.find("[")
  let close = msg.find("]")
  match (open, close) {
    (Some(o), Some(c)) if o < c => parse_digits(msg[o + 1:c].to_owned())
    _ => None
  }
}

///|
/// Print the per-mode group counts (with up to 3 example case indices each)
/// for one domain's failure list.
fn print_groups(name : String, failures : Array[String]) -> Unit {
  if failures.is_empty() {
    println("\{name} failure groups: (none)")
    return
  }
  let counts : Map[String, Int] = Map([])
  let examples : Map[String, Array[String]] = Map([])
  for msg in failures {
    let sig = signature(msg)
    counts[sig] = counts.get(sig).unwrap_or(0) + 1
    let idx = match case_index(msg) {
      Some(i) => "\{i}"
      None => "?"
    }
    match examples.get(sig) {
      Some(list) => if list.length() < 3 {
        list.push(idx)
      }
      None => examples[sig] = [idx]
    }
  }
  println("\{name} failure groups: \{counts.length()} distinct")
  for sig, count in counts {
    let ex = match examples.get(sig) {
      Some(list) => list.join(", ")
      None => ""
    }
    println("  n=\{count} e.g.case=[\{ex}] \{sig}")
  }
}

///|
/// Render `numerator/denominator` in percent with two decimals (integer
/// math in basis points — no float formatting drift).
fn pct_bp(numerator : Int, denominator : Int) -> String {
  if denominator <= 0 {
    return "n/a"
  }
  let bp = numerator * 10000 / denominator
  let whole = bp / 100
  let frac = bp % 100
  let frac_txt = if frac < 10 {
    "0\{frac}"
  } else {
    "\{frac}"
  }
  "\{whole}.\{frac_txt}%"
}

///|
/// Print one domain row and return whether the gate is met.
fn report(stats : DomainStats) -> Bool {
  let failed = stats.failures.length()
  let passed = stats.total - stats.exempted - failed
  let met = passed * 10000 >= stats.total * stats.gate_bps
  let gate_pct = pct_bp(stats.gate_bps, 10000)
  let status = if met {
    "MET"
  } else {
    "NOT-MET"
  }
  println(
    "\{stats.name}\ttotal=\{stats.total}\texempted=\{stats.exempted}\tpassed=\{passed}\tfailed=\{failed}\trate=\{pct_bp(passed, stats.total)}\tgate>=\{gate_pct}\t\{status}",
  )
  met
}

///|
fn main {
  let ua_failures = @differential.ua_failures()
  let os_failures = @differential.os_failures()
  let device_failures = @differential.device_failures()
  println("domain\ttotal\texempted\tpassed\tfailed\trate\tgate\tstatus")
  let rows = [
    {
      name: "browser",
      total: @differential.ua_cases.length(),
      exempted: @differential.ua_exempted_count,
      failures: ua_failures,
      gate_bps: 9900,
    },
    {
      name: "os",
      total: @differential.os_cases.length(),
      exempted: @differential.os_exempted_count,
      failures: os_failures,
      gate_bps: 9700,
    },
    {
      name: "device",
      total: @differential.device_cases.length(),
      exempted: @differential.device_exempted_count,
      failures: device_failures,
      gate_bps: 9700,
    },
  ]
  let mut all_met = true
  for row in rows {
    if !report(row) {
      all_met = false
    }
  }
  print_groups("browser", ua_failures)
  print_groups("os", os_failures)
  print_groups("device", device_failures)
  if all_met {
    println("GATES: ALL MET")
  } else {
    println("GATES: NOT ALL MET (see rows above)")
    // The CI "Differential gate report" step can only fail the build if this
    // process exits non-zero, so an unmet gate must abort (fail-loud, same
    // mechanism as src/ua_parser/rules/rules_init.mbt). The report above is
    // printed first so stdout carries the full table before the fatal exit.
    abort("GATES: NOT ALL MET (see rows above)")
  }
}
