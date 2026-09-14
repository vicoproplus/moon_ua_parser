// Benchmark runner (T-03) — the T-01 clock probe main evolved into the full
// v0.2 performance runner per the plan ("演进为正式运行器"; the probe output
// is preserved in git history and docs/evidence/clock-probe-2026-09-13.log,
// no --probe mode is kept).
//
// Contract (see moon.pkg for run commands and the target-file mapping):
//   - load the T-02 generated sample set — `samples` / `sample_strata` /
//     `sample_set_hash`, same package (see samples.mbt); strata are loaded
//     via the declared stratum inventory check below, so all three T-02
//     bindings are consumed;
//   - measurement scope (v2 2026-09-13 revision, controller ruling): the
//     corpus is still FULLY loaded (sample_set_hash provenance unchanged),
//     but each timed round parses a declared STRATIFIED STRIDE SUBSAMPLE of
//     it — indices i*BENCH_STRIDE over the stratum-grouped corpus array
//     cover every stratum proportionally to the generator's allocation.
//     Rationale: the engine measures ~37.5 ms/parse (native --release) and
//     ~13.8 ms/parse (js --release) on this corpus, so a 10k full round
//     (~375 s / ~138 s) is not a feasible measurement unit; the per-round
//     iteration count is a declared measurement parameter (sample_count=),
//     not part of the loading contract;
//   - default run (no args): WARMUP_ROUNDS untimed warmup passes, then
//     TIMED_ROUNDS timed passes; each pass = one sequential parse() over
//     the stride subsample (default 10000/20 = 500 samples; smoke 10000/50
//     = 200); ops_per_sec[round] = sample_count / round_seconds; the
//     reported value is the MEDIAN of the per-round ops_per_sec, and
//     ns_per_parse = 1e9 / median_ops_per_sec (same-source dual metric,
//     self-consistent);
//   - every parse result is consumed into a deterministic checksum that is
//     compared across rounds and printed (samples_checksum=, folded over
//     the parsed subsample) so dead-code elimination cannot drop parses
//     and round data is validated;
//   - `-- --smoke`: the SMOKE_STRIDE subsample, same warmup/timed
//     structure, compared against the calibrated coarse threshold
//     SMOKE_NS_PER_PARSE_LIMIT (pinned in T-06); if the median
//     ns_per_parse exceeds the limit the FULL report is printed FIRST and
//     only then abort() ends the process non-zero — the report is always
//     already on stdout when the exit code turns non-zero; the normal path
//     exits 0;
//   - `-- --profile` (T-05, controller ruling a: permanent bench-infra
//     instrumentation): per-domain hot-path split on the PROFILE_STRIDE
//     subsample. One untimed warmup pass, then PROFILE_TIMED_REPS timed
//     reps; each rep times parse_browser / parse_os / parse_device and a
//     full parse() separately through the SAME single clock seam, so the
//     per-domain shares of a full parse are directly measurable. The
//     template-replacement cost is reported as
//     full − (browser + os + device): an UPPER-BOUND estimate (each
//     single-domain pass pays its own loop overhead once, and cross-pass
//     noise can push the difference negative — reported as measured).
//     An untimed rule-index pass (parse with with_rule_index=true) reports
//     per-domain miss counts and winning-rule index statistics, i.e. how
//     many regex trials each domain typically needs before its first match
//     (a miss means the domain scanned ALL its rules). Every pass folds a
//     checksum consumed into the report (profile-rep / profile-checksum
//     lines) so dead-code elimination cannot drop work and cross-rep drift
//     is detected. If both --profile and --smoke are given, --profile
//     takes precedence (the combination is not a defined mode).
//   - ALL clock access stays inside the single seam `clock_pair_diff_us`
//     (moonbitlang/core/bench monotonic clock pair; per-target dispatch
//     lives inside core/bench, per-backend file selection inside moon.pkg
//     options(targets:)). Statistics below have ZERO backend branching —
//     the only per-backend artifact in this package is backend_label()
//     from clock_{native,js,wasm}.mbt.

///|
/// Fixed round structure; declared in every report's bench-config line.
const WARMUP_ROUNDS : Int = 2

///|
/// Timed rounds k (odd, so the median is an exact measured round).
const TIMED_ROUNDS : Int = 7

///|
/// Default-mode stride over the fully loaded corpus: every round parses
/// indices 0, 20, 40, ... → 10000/20 = 500 samples per round (declared as
/// sample_count= in the bench-config line).
const BENCH_STRIDE : Int = 20

///|
/// Smoke-mode stride: indices 0, 50, 100, ... → 10000/50 = 200 samples.
const SMOKE_STRIDE : Int = 50

///|
/// Calibrated coarse smoke threshold: 150 ms per parse (T-06, pinned
/// 2026-09-13 from the B2 baseline). Derivation: T-04 native
/// median-of-medians 23.64 ops/s = 42,299,995.40 ns/parse; x3 ≈ 126.9 ms;
/// rounded up to 150 ms so the buffer additionally covers the hardware
/// difference between this host (Windows 10 19045) and the CI runner
/// (ubuntu-latest) plus the native noise band (T-04 measured up to 11.85%
/// cross-run deviation). Sanity: T-05 measured smoke-mode ≈44.33 ms/parse
/// → ≈3.4x headroom, so the normal path exits 0. If a CI run ever misfires
/// here, return to THIS constant and recalibrate from a fresh baseline —
/// do not tune the engine for the threshold.
const SMOKE_NS_PER_PARSE_LIMIT : Double = 150_000_000.0

///|
/// Profile-mode stride (T-05): indices 0, 50, 100, ... → 10000/50 = 200
/// samples per pass. One parse is ~40 ms on native, so 200 samples give
/// multi-second passes (well above clock noise) while a whole profile run
/// stays around one minute.
const PROFILE_STRIDE : Int = 50

///|
/// Profile-mode untimed warmup passes (compiles the lazily initialized
/// rule set and warms caches; the last pass anchors the checksums).
const PROFILE_WARMUP_PASSES : Int = 1

///|
/// Profile-mode timed repetitions per domain (odd, so the median is an
/// exactly measured rep).
const PROFILE_TIMED_REPS : Int = 3

///|
/// Single-point timing seam: run `work` once between two monotonic clock
/// reads and return the elapsed microseconds. The ONLY place in this
/// package that names a clock API (T-01's read-pair seam evolved to time a
/// unit of work; same @core_bench.monotonic_clock_start/end pair).
fn clock_pair_diff_us(work : () -> Unit) -> Double {
  let t0 = @core_bench.monotonic_clock_start()
  work()
  @core_bench.monotonic_clock_end(t0)
}

///|
/// One sequential parse pass over `inputs` — one benchmark round of work.
/// Folds a deterministic checksum from every result (browser/os/device
/// family lengths; +1 per Err) so every parse is consumed and dead-code
/// elimination cannot skip work. Deterministic: identical inputs give an
/// identical checksum, and main compares it across rounds.
fn parse_pass(inputs : Array[String]) -> Int {
  let mut checksum = 0
  for ua in inputs {
    match @ua_parser.parse(ua) {
      Ok(info) => {
        checksum = checksum + info.browser.family.length()
        checksum = checksum + info.os.family.length()
        checksum = checksum + info.device.family.length()
      }
      Err(_) => checksum = checksum + 1
    }
  }
  checksum
}

///|
/// Browser-domain-only pass (T-05 --profile): same fold structure as
/// parse_pass so every call is consumed and dead-code elimination cannot
/// skip work.
fn browser_pass(inputs : Array[String]) -> Int {
  let mut checksum = 0
  for ua in inputs {
    checksum = checksum + @ua_parser.parse_browser(ua).family.length()
  }
  checksum
}

///|
/// OS-domain-only pass (T-05 --profile); see browser_pass.
fn os_only_pass(inputs : Array[String]) -> Int {
  let mut checksum = 0
  for ua in inputs {
    checksum = checksum + @ua_parser.parse_os(ua).family.length()
  }
  checksum
}

///|
/// Device-domain-only pass (T-05 --profile); see browser_pass.
fn device_only_pass(inputs : Array[String]) -> Int {
  let mut checksum = 0
  for ua in inputs {
    checksum = checksum + @ua_parser.parse_device(ua).family.length()
  }
  checksum
}

///|
/// Stratified stride subsample of the fully loaded corpus: indices
/// i*stride (i = 0, 1, 2, ...) cover the whole stratum-grouped array, so
/// every stratum appears proportionally to the generator's allocation.
/// Default stride 20 → 500 samples/round; smoke/profile stride 50 → 200.
fn stride_subsample(inputs : Array[String], stride : Int) -> Array[String] {
  let out : Array[String] = []
  for i in 0..<inputs.length() {
    if i % stride == 0 {
      out.push(inputs[i])
    }
  }
  out
}

///|
/// Median of the per-round readings. TIMED_ROUNDS is odd by design, so
/// this is an exactly measured round, not an interpolation.
fn median(values : Array[Double]) -> Double {
  let sorted : Array[Double] = []
  for v in values {
    sorted.push(v)
  }
  sorted.sort()
  sorted[sorted.length() / 2]
}

///|
/// Median of a non-empty Int array (rule-index statistics in --profile).
/// Caller must guarantee non-emptiness (guarded at every call site).
fn median_int(values : Array[Int]) -> Int {
  let sorted : Array[Int] = []
  for v in values {
    sorted.push(v)
  }
  sorted.sort()
  sorted[sorted.length() / 2]
}

///|
/// Maximum of a non-empty Int array. Caller must guarantee non-emptiness
/// (guarded at every call site).
fn max_int(values : Array[Int]) -> Int {
  let mut m = values[0]
  for v in values {
    if v > m {
      m = v
    }
  }
  m
}

///|
/// Format a Double (possibly negative) with exactly 2 decimal places in
/// plain decimal form (never exponent form) so every key=value token in
/// the report stays greppable and keeps the required >=2 decimals of
/// precision. Negative values keep the sign on the whole part
/// (e.g. the noisy template_est estimate can go negative).
fn fmt_fixed2(v : Double) -> String {
  let neg = v < 0.0
  let scaled = ((if neg { -v } else { v }) * 100.0).floor().to_int64()
  let whole = (scaled / 100L).to_string()
  let frac = scaled % 100L
  let frac_txt = if frac < 10L { "0\{frac}" } else { "\{frac}" }
  let sign = if neg { "-" } else { "" }
  "\{sign}\{whole}.\{frac_txt}"
}

///|
/// Sanity-check the declared stratum inventory of the T-02 sample set:
/// `samples` and `sample_strata` are parallel arrays (same-name same-type
/// contract, see samples.mbt); scan them in parallel and return the number
/// of distinct strata actually seen, so the runner provably consumes
/// `sample_strata` alongside `samples`.
fn strata_inventory_check(inputs : Array[String], strata : Array[String]) -> Int {
  let seen : Array[String] = []
  let limit = if inputs.length() < strata.length() {
    inputs.length()
  } else {
    strata.length()
  }
  for i in 0..<limit {
    let s = strata[i]
    if !seen.contains(s) {
      seen.push(s)
    }
  }
  seen.length()
}

///|
/// Print the full report: configuration declaration (mode / backend /
/// corpus_size / sample_count / warmup_rounds / timed_rounds / stride /
/// strata), per-round readings, and the four-field result line
///   backend= ops_per_sec= ns_per_parse= sample_set_hash=
/// (ops/s + ns-per-parse dual metric, same-source). No backend branching
/// here: backend= comes from the existing per-backend backend_label().
fn print_report(
  mode : String,
  corpus_size : Int,
  sample_count : Int,
  stride : Int,
  strata_seen : Int,
  rounds : Array[Double],
  median_ops : Double,
  checksum : Int,
  rounds_consistent : Bool,
) -> Unit {
  let ns_per_parse = 1_000_000_000.0 / median_ops
  println(
    "bench-config mode=\{mode} backend=\{backend_label()} corpus_size=\{corpus_size} sample_count=\{sample_count} stride=\{stride} warmup_rounds=\{WARMUP_ROUNDS} timed_rounds=\{TIMED_ROUNDS} strata=\{strata_seen} smoke_threshold_ns_per_parse=\{fmt_fixed2(SMOKE_NS_PER_PARSE_LIMIT)} (calibrated, T-06)",
  )
  let mut i = 0
  for ops in rounds {
    println(
      "bench-round round=\{i} ops_per_sec=\{fmt_fixed2(ops)} ns_per_parse=\{fmt_fixed2(1_000_000_000.0 / ops)}",
    )
    i = i + 1
  }
  println(
    "bench-result backend=\{backend_label()} ops_per_sec=\{fmt_fixed2(median_ops)} ns_per_parse=\{fmt_fixed2(ns_per_parse)} sample_set_hash=\{sample_set_hash} samples_checksum=\{checksum} rounds_consistent=\{rounds_consistent}",
  )
}

///|
/// One profile-rulestats line: per-domain miss count and winning-rule
/// index statistics over the profile subsample. A miss means the domain
/// scanned ALL of its rules; a win at index i means i+1 regex trials.
fn print_index_stats(
  domain : String,
  indices : Array[Int],
  misses : Int,
  samples : Int,
) -> Unit {
  let matched = samples - misses
  let rate = if samples > 0 {
    matched.to_double() * 100.0 / samples.to_double()
  } else {
    0.0
  }
  let avg = if indices.length() > 0 {
    let mut s = 0
    for v in indices {
      s = s + v
    }
    fmt_fixed2(s.to_double() / indices.length().to_double())
  } else {
    "-"
  }
  let med = if indices.length() > 0 {
    "\{median_int(indices)}"
  } else {
    "-"
  }
  let max = if indices.length() > 0 { "\{max_int(indices)}" } else { "-" }
  println(
    "profile-rulestats domain=\{domain} samples=\{samples} matches=\{matched} misses=\{misses} match_rate_pct=\{fmt_fixed2(rate)} index_avg=\{avg} index_median=\{med} index_max=\{max}",
  )
}

///|
/// T-05 --profile mode: per-domain hot-path split. See the file-header
/// contract comment. All timing goes through the single clock seam
/// clock_pair_diff_us; per-rep checksums guard against dead-code
/// elimination and cross-rep drift; the rule-index pass additionally
/// cross-checks that with_rule_index=true parsing produces the same
/// families (index checksum == full checksum).
fn profile_main() -> Unit {
  let inputs = stride_subsample(samples, PROFILE_STRIDE)
  let n = inputs.length()
  let strata_seen = strata_inventory_check(samples, sample_strata)
  // Warmup: untimed passes; the last pass anchors the expected checksums.
  let mut full_sum = parse_pass(inputs)
  for _ in 1..<PROFILE_WARMUP_PASSES {
    full_sum = parse_pass(inputs)
  }
  let browser_sum = browser_pass(inputs)
  let os_sum = os_only_pass(inputs)
  let device_sum = device_only_pass(inputs)
  println(
    "profile-config mode=profile backend=\{backend_label()} corpus_size=\{samples.length()} sample_count=\{n} stride=\{PROFILE_STRIDE} warmup_passes=\{PROFILE_WARMUP_PASSES} timed_reps=\{PROFILE_TIMED_REPS} strata=\{strata_seen} sample_set_hash=\{sample_set_hash}",
  )
  let bns : Array[Double] = []
  let ons : Array[Double] = []
  let dns : Array[Double] = []
  let fns : Array[Double] = []
  let mut reps_consistent = true
  for rep in 0..<PROFILE_TIMED_REPS {
    let mut bs = 0
    let mut ocs = 0
    let mut dcs = 0
    let mut fs = 0
    let bus = clock_pair_diff_us(fn() { bs = browser_pass(inputs) })
    let ous = clock_pair_diff_us(fn() { ocs = os_only_pass(inputs) })
    let dus = clock_pair_diff_us(fn() { dcs = device_only_pass(inputs) })
    let fus = clock_pair_diff_us(fn() { fs = parse_pass(inputs) })
    if bs != browser_sum ||
      ocs != os_sum ||
      dcs != device_sum ||
      fs != full_sum {
      reps_consistent = false
    }
    let b_np = bus * 1000.0 / n.to_double()
    let o_np = ous * 1000.0 / n.to_double()
    let d_np = dus * 1000.0 / n.to_double()
    let f_np = fus * 1000.0 / n.to_double()
    println(
      "profile-rep rep=\{rep} browser_ns_per_call=\{fmt_fixed2(b_np)} os_ns_per_call=\{fmt_fixed2(o_np)} device_ns_per_call=\{fmt_fixed2(d_np)} full_ns_per_call=\{fmt_fixed2(f_np)} browser_checksum=\{bs} os_checksum=\{ocs} device_checksum=\{dcs} full_checksum=\{fs}",
    )
    bns.push(b_np)
    ons.push(o_np)
    dns.push(d_np)
    fns.push(f_np)
  }
  let med_b = median(bns)
  let med_o = median(ons)
  let med_d = median(dns)
  let med_f = median(fns)
  let template_est = med_f - (med_b + med_o + med_d)
  let share_denom = if med_f > 0.0 { med_f } else { 1.0 }
  println(
    "profile-median browser_ns_per_call=\{fmt_fixed2(med_b)} os_ns_per_call=\{fmt_fixed2(med_o)} device_ns_per_call=\{fmt_fixed2(med_d)} full_ns_per_call=\{fmt_fixed2(med_f)}",
  )
  println(
    "profile-share browser_pct=\{fmt_fixed2(med_b * 100.0 / share_denom)} os_pct=\{fmt_fixed2(med_o * 100.0 / share_denom)} device_pct=\{fmt_fixed2(med_d * 100.0 / share_denom)} template_est_pct=\{fmt_fixed2(template_est * 100.0 / share_denom)} template_est_ns_per_call=\{fmt_fixed2(template_est)} (template = full - (browser+os+device), upper bound; noise can make it negative)",
  )
  // Untimed rule-index pass: winning rule index per domain with
  // with_rule_index=true. Families are unaffected by the flag, so the
  // folded checksum must equal the default full-parse checksum.
  let bidx : Array[Int] = []
  let oidx : Array[Int] = []
  let didx : Array[Int] = []
  let mut bmiss = 0
  let mut omiss = 0
  let mut dmiss = 0
  let mut idx_sum = 0
  for ua in inputs {
    match @ua_parser.parse(ua, with_rule_index=true) {
      Ok(info) => {
        idx_sum = idx_sum + info.browser.family.length()
        idx_sum = idx_sum + info.os.family.length()
        idx_sum = idx_sum + info.device.family.length()
        match info.browser.rule_index {
          Some(i) => bidx.push(i)
          None => bmiss = bmiss + 1
        }
        match info.os.rule_index {
          Some(i) => oidx.push(i)
          None => omiss = omiss + 1
        }
        match info.device.rule_index {
          Some(i) => didx.push(i)
          None => dmiss = dmiss + 1
        }
      }
      Err(_) => idx_sum = idx_sum + 1
    }
  }
  print_index_stats("browser", bidx, bmiss, n)
  print_index_stats("os", oidx, omiss, n)
  print_index_stats("device", didx, dmiss, n)
  let domain_sums_match = browser_sum + os_sum + device_sum == full_sum
  println(
    "profile-checksum samples_checksum=\{full_sum} browser_checksum=\{browser_sum} os_checksum=\{os_sum} device_checksum=\{device_sum} index_checksum=\{idx_sum} domain_sums_match=\{domain_sums_match} index_matches_full=\{idx_sum == full_sum} reps_consistent=\{reps_consistent}",
  )
}

///|
fn main {
  let args = @env.args()
  let smoke = args.contains("--smoke")
  let profile = args.contains("--profile")
  if profile {
    // T-05 --profile takes precedence over --smoke (mutually exclusive
    // measurement modes; the combination is not a defined mode).
    profile_main()
    return
  }
  let stride = if smoke { SMOKE_STRIDE } else { BENCH_STRIDE }
  // The T-02 corpus is fully loaded; each round parses the declared stride
  // subsample of it.
  let inputs = stride_subsample(samples, stride)
  let n = inputs.length()
  let mode = if smoke { "smoke" } else { "full" }
  let strata_seen = strata_inventory_check(samples, sample_strata)
  // Warmup: fixed untimed passes over the same work.
  let mut checksum = parse_pass(inputs)
  for _ in 1..<WARMUP_ROUNDS {
    checksum = parse_pass(inputs)
  }
  // Timed rounds: all timing through the single seam.
  let rounds : Array[Double] = []
  let mut rounds_consistent = true
  for _ in 0..<TIMED_ROUNDS {
    let mut result = 0
    let us = clock_pair_diff_us(fn() { result = parse_pass(inputs) })
    if result != checksum {
      rounds_consistent = false
    }
    checksum = result
    rounds.push(n.to_double() / (us / 1_000_000.0))
  }
  let med = median(rounds)
  // Full four-field report is ALWAYS on stdout before any verdict.
  print_report(
    mode,
    samples.length(),
    n,
    stride,
    strata_seen,
    rounds,
    med,
    checksum,
    rounds_consistent,
  )
  if smoke {
    let ns = 1_000_000_000.0 / med
    if ns > SMOKE_NS_PER_PARSE_LIMIT {
      println(
        "smoke-verdict result=fail ns_per_parse=\{fmt_fixed2(ns)} limit=\{fmt_fixed2(SMOKE_NS_PER_PARSE_LIMIT)} (calibrated threshold, T-06); aborting non-zero after the full report above",
      )
      abort("smoke threshold exceeded: ns_per_parse above SMOKE_NS_PER_PARSE_LIMIT")
    }
    println(
      "smoke-verdict result=pass ns_per_parse=\{fmt_fixed2(ns)} limit=\{fmt_fixed2(SMOKE_NS_PER_PARSE_LIMIT)} (calibrated threshold, T-06)",
    )
  }
}
