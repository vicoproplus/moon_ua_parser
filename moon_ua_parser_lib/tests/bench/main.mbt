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
//     structure, compared against the placeholder coarse threshold
//     SMOKE_NS_PER_PARSE_LIMIT (T-06 calibrates); if the median
//     ns_per_parse exceeds the limit the FULL report is printed FIRST and
//     only then abort() ends the process non-zero — the report is always
//     already on stdout when the exit code turns non-zero; the normal path
//     exits 0;
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
/// Placeholder coarse smoke threshold in ns per parse: 100 ms — above the
/// measured native reality (~37.5 ms/parse) so the normal path exits 0.
/// A NAMED PLACEHOLDER — T-06 calibrates it (B2 baseline median x 3).
const SMOKE_NS_PER_PARSE_LIMIT : Double = 100_000_000.0

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
/// Stratified stride subsample of the fully loaded corpus: indices
/// i*stride (i = 0, 1, 2, ...) cover the whole stratum-grouped array, so
/// every stratum appears proportionally to the generator's allocation.
/// Default stride 20 → 500 samples/round; smoke stride 50 → 200.
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
/// Format a non-negative Double with exactly 2 decimal places in plain
/// decimal form (never exponent form) so every key=value token in the
/// report stays greppable and keeps the required >=2 decimals of
/// precision.
fn fmt_fixed2(v : Double) -> String {
  let scaled = (v * 100.0).floor().to_int64()
  let whole = (scaled / 100L).to_string()
  let frac = scaled % 100L
  let frac_txt = if frac < 10L { "0\{frac}" } else { "\{frac}" }
  "\{whole}.\{frac_txt}"
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
    "bench-config mode=\{mode} backend=\{backend_label()} corpus_size=\{corpus_size} sample_count=\{sample_count} stride=\{stride} warmup_rounds=\{WARMUP_ROUNDS} timed_rounds=\{TIMED_ROUNDS} strata=\{strata_seen} smoke_threshold_ns_per_parse=\{fmt_fixed2(SMOKE_NS_PER_PARSE_LIMIT)} (placeholder, T-06)",
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
fn main {
  let smoke = @env.args().contains("--smoke")
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
        "smoke-verdict result=fail ns_per_parse=\{fmt_fixed2(ns)} limit=\{fmt_fixed2(SMOKE_NS_PER_PARSE_LIMIT)} (placeholder threshold, calibrated in T-06); aborting non-zero after the full report above",
      )
      abort("smoke threshold exceeded: ns_per_parse above SMOKE_NS_PER_PARSE_LIMIT")
    }
    println(
      "smoke-verdict result=pass ns_per_parse=\{fmt_fixed2(ns)} limit=\{fmt_fixed2(SMOKE_NS_PER_PARSE_LIMIT)} (placeholder threshold, calibrated in T-06)",
    )
  }
}
