// Clock probe (T-01, E5 Task 0) — minimal three-backend timing main.
//
// Contract (see moon.pkg for run commands and the target-file mapping):
//   - print the backend label, the clock API in use, two consecutive
//     monotonic-clock difference readings, and the smallest non-zero
//     difference over a sampling run (observed resolution);
//   - keep ALL clock access inside the single seam function
//     `clock_pair_diff_us`, so statistics/business logic has zero backend
//     branching. The backend-specific clocks are behind
//     moonbitlang/core/bench (imported as @core_bench; see the pair
//     `monotonic_clock_start` / `monotonic_clock_end`), which
//     itself dispatches per target:
//       native: extern "C" moonbit_monotonic_clock_start/stop
//       js:     extern "js" performance.now()
//       wasm:   "__moonbit_time_unstable" instant_now /
//               instant_elapsed_as_secs_f64
//   - registered fallback directions (T-01 implements none — every backend
//     compiles against core/bench, so no fallback was needed):
//       js:   extern "js" Date.now() (millisecond wall clock)
//       wasm: host-injected clock / WASI clock probing
//
// T-03 reuses `clock_pair_diff_us` as the timing seam of the full runner.

///|
/// Single-point timing seam: elapsed microseconds between two consecutive
/// monotonic clock reads (read overhead + resolution). The ONLY place in
/// this package that names a clock API.
fn clock_pair_diff_us() -> Double {
  let t0 = @core_bench.monotonic_clock_start()
  @core_bench.monotonic_clock_end(t0)
}

///|
/// Smallest non-zero seam reading over `samples` consecutive reads; `None`
/// when every reading was zero (resolution below one pair-read overhead).
fn min_nonzero_diff_us(samples : Int) -> Double? {
  let mut best : Double? = None
  for _ in 0..<samples {
    let d = clock_pair_diff_us()
    if d > 0.0 {
      match best {
        Some(m) => if d < m { best = Some(d) }
        None => best = Some(d)
      }
    }
  }
  best
}

///|
fn main {
  println("clock-probe backend=\{backend_label()}")
  println(
    "api=@core_bench.monotonic_clock_start/monotonic_clock_end (moonbitlang/core/bench, elapsed in microseconds)",
  )
  println("diff1_us=\{clock_pair_diff_us()}")
  println("diff2_us=\{clock_pair_diff_us()}")
  match min_nonzero_diff_us(1000) {
    Some(m) => println("min_nonzero_us=\{m} (1000 samples)")
    None => println("min_nonzero_us=none-nonzero (1000 samples)")
  }
}
