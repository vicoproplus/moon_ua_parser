///|
/// Backend label for the clock probe (wasm/wasm-gc targets; selected by the
/// options(targets: ...) map in moon.pkg). Timing itself is backend-neutral:
/// see clock_pair_diff_us in main.mbt.
fn backend_label() -> String {
  "wasm"
}
