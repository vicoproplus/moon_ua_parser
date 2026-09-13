# MANIFEST — bench sample set (`tests/bench/samples.mbt`)

Inventory for the generated benchmark sample set (plan unit T-02). `samples.mbt`
is **GENERATED — DO NOT EDIT**: regenerate it with the generator below; never
edit the file by hand.

## Generator

- Script: `scripts/gen_bench_samples.py` (repo root; Python 3 standard library only)
- Regenerate: `python scripts/gen_bench_samples.py` (any cwd; paths resolve against the repo root)
- Source path override: env `MOON_UA_SAMPLES_SRC` (absolute path, or path relative to the repo root)
- Determinism: fixed seed + integer-only allocation math; identical source bytes produce byte-identical output (no timestamps in the artifact)
- Failure contract: missing/undecodable source => message on stderr, log written to `scripts/gen_bench_samples.error.log`, exit code 1; the previous `samples.mbt` is never truncated (atomic replace). A successful run deletes any stale error log.

## Source corpus

| field | value |
|---|---|
| path (relative to repo root) | `uap-python/samples/useragents.txt` (tracked in git) |
| sha256 | `3640d3b74cd4efd6e5e1723d8e23493e3399b8b616d977cd5e18fb66302c4244` |
| size | 10,280,676 bytes |
| lines | 75,158 (all CRLF-terminated; file ends with a trailing newline) |
| encoding | UTF-8, printable ASCII throughout |

## Seed

`20260913` — a fixed constant (`SEED`) in the generator, also printed in the
`samples.mbt` header. One `random.Random(20260913)` instance is created per
run; strata are processed in fixed alphabetical order and each stratum is
drawn with `random.sample` over its pool in corpus file order. Reference
artifact: the committed `samples.mbt` (generated with Python 3.12.10,
moon 0.1.20260904); `random.Random`/`sample` have been sequence-stable across
CPython 3.x in practice, and the committed file is the regressed-against
reference regardless.

## Stratum dimensions and rationale

Strata are UA form keywords, first match wins (order is load-bearing:
`android` before `linux` because Android UAs contain "Linux"; `ios` before
`macos` because iOS UAs contain "like Mac OS X"; `bot` before desktop
families):

| # | stratum | match (case-insensitive) |
|---|---|---|
| 1 | `android` | contains `android` |
| 2 | `ios` | contains `iphone`, `ipad`, or `ipod` |
| 3 | `bot` | regex: `[a-z0-9_-]*bot`, `crawler`, `spider`, `slurp`, `curl/`, `wget`, `python-requests`, `go-http-client`, `java/`, `okhttp`, `libwww`, `httpclient`, `apache-httpclient`, `scrapy`, `headless`, `lighthouse`, `phantomjs`, `selenium`, `archiver`, `fetcher`, `monitor`, `scanner`, `validator`, `checker`, `downloader`, `preview[-_ ]?generator` |
| 4 | `windows` | contains `windows` |
| 5 | `macos` | contains `macintosh` or `mac os` |
| 6 | `linux` | contains `linux`, `x11`, `ubuntu`, `fedora`, `debian`, or `cros` |
| 7 | `other` | fallback |

Measured full-corpus distribution (Step-1 statistics over all 75,158 lines):
android 76.07%, ios 15.86%, macos 3.42%, windows 3.14%, linux 1.45%,
bot 0.04%, other 0.02%. The corpus is heavily Android-skewed, so pure
proportional allocation would give `bot` ~4 and `other` ~2 samples — too few
for stable per-stratum timings. Allocation therefore is:

1. integer largest-remainder (Hare) proportional allocation to 10,000;
2. tail strata below 30 samples are raised to 30, capped by corpus availability;
3. the residual is absorbed by the currently largest stratum (ties: alphabetical), keeping the total at exactly 10,000.

Rationale recorded per plan Step 1: proportions mirror the corpus for the
dominant families; the 30-sample floor makes the two tail strata measurable
instead of noise.

## Per-stratum counts

| stratum | corpus lines | sampled |
|---|---:|---:|
| android | 57,168 | 7,566 |
| bot | 31 | 30 |
| ios | 11,921 | 1,586 |
| linux | 1,088 | 145 |
| macos | 2,568 | 342 |
| other | 17 | 17 (entire stratum; floor capped by availability) |
| windows | 2,362 | 314 |
| **total** | **75,155 valid** | **10,000** |

Sampling is without replacement per stratum. The corpus contains many
duplicate lines (54,836 duplicate occurrences over 20,322 unique UAs);
duplicates are treated as distinct pool elements, so the sample keeps the
corpus's frequency weighting.

## Anomaly lines

| category | count | detail |
|---|---:|---|
| blank | 0 | (trailing newline of the file is line termination, not a blank line) |
| decode failure | 0 | whole corpus is valid UTF-8 |
| too short (< 10 chars) | 3 | two single-character lines `M`, one line `chrome` |
| **total skipped** | **3 / 75,158** | **0.0040%** — far below the 1% decision gate |

## Output artifact and contract

- File: `moon_ua_parser_lib/tests/bench/samples.mbt`, compiled into the
  executable package `tests/bench` (same-package visibility; no `pub`).
- Contents: header comment (GENERATED — DO NOT EDIT + source sha256 + seed +
  method summary + counts) and three constants consumed by the T-03 runner:
  - `let samples : Array[String]` — 10,000 UA strings, grouped by stratum in
    alphabetical stratum order; within a stratum, RNG draw order;
  - `let sample_strata : Array[String]` — parallel labels, same indices;
  - `let sample_set_hash : String` — `sha256:3640d3b74cd4efd6e5e1723d8e23493e3399b8b616d977cd5e18fb66302c4244`
    (identical to the source hash above; the runner prints it verbatim so the
    report carries provenance with zero file IO).
- As generated on this host: 1,531,230 bytes, sha256
  `2dbca0ee150b803ced43a3967c090093ecabe878e79d9cdebc5dccd17c0adc95`.

## Verification record (2026-09-13, Python 3.12.10, moon 0.1.20260904)

- Generator run exit 0; re-run byte-identical (`cmp` clean, same artifact
  sha256), `git diff --exit-code -- moon_ua_parser_lib/tests/bench/samples.mbt` exit 0.
- Re-run from a different cwd (`moon_ua_parser_lib/`) — identical output
  (repo-root path resolution).
- Path guard: `MOON_UA_SAMPLES_SRC=<missing>` => exit 1, clear message,
  `scripts/gen_bench_samples.error.log` written, `samples.mbt` untouched;
  next successful run removes the stale log.
- `moon check` — 0 errors (44 pre-existing warnings + 3 transient
  `unused_value` on `samples` / `sample_strata` / `sample_set_hash`; the
  T-01 probe `main` does not consume them yet, T-03 will).
- `moon test --target native` — 31/31 passed (baseline held).
