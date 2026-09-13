#!/usr/bin/env python3
"""gen_bench_samples.py — fixed-seed stratified sampler for the moon_ua_parser benchmark.

Reads the vendored upstream user-agent corpus (uap-python/samples/useragents.txt)
and regenerates moon_ua_parser_lib/tests/bench/samples.mbt, a MoonBit source file
declaring three same-package constants consumed by the T-03 benchmark runner:

    let samples         : Array[String]   # sampled UA strings
    let sample_strata   : Array[String]   # parallel per-sample stratum labels
    let sample_set_hash : String          # "sha256:<hex>" of the source corpus

Guarantees
----------
* Stdlib only (hashlib / os / pathlib / random / re / sys / tempfile).
* Deterministic: identical source bytes + fixed seed => byte-identical output.
  No timestamps, no locale, no dict-ordering dependence; all allocation math
  is integer-only.
* The output file is replaced atomically (write to a temp file in the same
  directory, then os.replace), so a failure never truncates the previous file.
* Path guard: a missing/unreadable source corpus is a hard failure that logs
  to scripts/gen_bench_samples.error.log and exits with status 1.

Usage
-----
    python scripts/gen_bench_samples.py          # from anywhere; paths are
                                                 # resolved against the repo root
    MOON_UA_SAMPLES_SRC=<path> python ...        # override the source corpus
                                                 # (absolute, or relative to the
                                                 # repo root)

See moon_ua_parser_lib/tests/bench/MANIFEST.md for the full inventory:
stratum dimensions, per-stratum counts, anomaly accounting, seed rationale.
"""

from __future__ import annotations

import hashlib
import os
import random
import re
import sys
import tempfile
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SOURCE_REL = "uap-python/samples/useragents.txt"
SOURCE_ENV = "MOON_UA_SAMPLES_SRC"
OUTPUT_REL = Path("moon_ua_parser_lib/tests/bench/samples.mbt")
ERROR_LOG = REPO_ROOT / "scripts" / "gen_bench_samples.error.log"

SEED = 20260913          # fixed seed; same value recorded in MANIFEST.md
TARGET_TOTAL = 10000     # total sampled UAs (plan: ~10000)
MIN_FLOOR = 30           # minimum per-stratum sample count (capped by availability)
MIN_UA_LEN = 10          # lines shorter than this are anomalies, skipped

# Fixed stratum processing order (alphabetical) — the RNG is consumed in this
# order and the emitted arrays are grouped in this order, so the output is a
# pure function of (source bytes, seed).
STRATA = ("android", "bot", "ios", "linux", "macos", "other", "windows")

# Bot / crawler / non-browser HTTP client detection. Case-insensitive; matched
# only after android/ios so that mobile UAs are never misfiled as bots.
_BOT_RE = re.compile(
    r"(?i)(?:[a-z0-9_-]*bot|crawler|spider|slurp|curl/|wget|python-requests"
    r"|go-http-client|java/|okhttp|libwww|httpclient|apache-httpclient|scrapy"
    r"|headless|lighthouse|phantomjs|selenium|archiver|fetcher|monitor|scanner"
    r"|validator|checker|downloader|preview[-_ ]?generator)"
)


def classify(ua: str) -> str:
    """Assign a UA to a stratum. First match wins; order is load-bearing:
    android before linux (Android UAs contain "Linux"), ios before macos
    (iOS UAs contain "like Mac OS X"), bot before desktop families."""
    low = ua.lower()
    if "android" in low:
        return "android"
    if "iphone" in low or "ipad" in low or "ipod" in low:
        return "ios"
    if _BOT_RE.search(ua):
        return "bot"
    if "windows" in low:
        return "windows"
    if "macintosh" in low or "mac os" in low:
        return "macos"
    if "linux" in low or "x11" in low or "ubuntu" in low or "fedora" in low \
            or "debian" in low or "cros" in low:
        return "linux"
    return "other"


def fail(message: str) -> "NoReturn":  # type: ignore[valid-type]
    """Log the failure to scripts/gen_bench_samples.error.log and exit 1."""
    lines = [
        "gen_bench_samples.py: FAILED",
        message,
        f"repo_root: {REPO_ROOT}",
        f"cwd: {Path.cwd()}",
        f"source env override {SOURCE_ENV}: {os.environ.get(SOURCE_ENV, '<unset>')}",
    ]
    try:
        ERROR_LOG.parent.mkdir(parents=True, exist_ok=True)
        ERROR_LOG.write_text("\n".join(lines) + "\n", encoding="utf-8")
    except OSError as exc:  # never mask the original failure
        lines.append(f"(could not write {ERROR_LOG}: {exc})")
    print("gen_bench_samples.py: FAILED", file=sys.stderr)
    for line in lines[1:]:
        print(f"  {line}", file=sys.stderr)
    print(f"  error log: {ERROR_LOG}", file=sys.stderr)
    sys.exit(1)


def moonbit_escape(s: str) -> str:
    """Escape a UA string as a MoonBit string literal body.

    Printable ASCII passes through; backslash and double quote are escaped;
    any control or non-ASCII codepoint becomes \\u{XXXX}. Keeps the generated
    file pure printable-ASCII regardless of corpus content.
    """
    out = []
    for ch in s:
        code = ord(ch)
        if ch == '"':
            out.append('\\"')
        elif ch == "\\":
            out.append("\\\\")
        elif 0x20 <= code <= 0x7E:
            out.append(ch)
        else:
            out.append(f"\\u{{{code:x}}}")
    return "".join(out)


def load_corpus(src_path: Path, source_label: str):
    """Read the corpus; return (raw_bytes, valid_lines, anomaly_counter).

    Anomalies (blank lines, undecodable lines, too-short lines) are skipped
    and counted per category; they never enter the sampler pools.
    """
    if not src_path.exists():
        fail(f"source corpus not found: {source_label} (resolved: {src_path})")
    if not src_path.is_file():
        fail(f"source corpus is not a regular file: {src_path}")
    try:
        raw = src_path.read_bytes()
    except OSError as exc:
        fail(f"cannot read source corpus {src_path}: {exc}")

    anomalies: Counter = Counter()
    valid: list[str] = []
    segments = raw.split(b"\n")
    if segments and segments[-1] == b"":
        segments.pop()  # trailing newline terminates the last line, not an empty line
    for seg in segments:
        if seg.endswith(b"\r"):
            seg = seg[:-1]
        try:
            line = seg.decode("utf-8")
        except UnicodeDecodeError:
            anomalies["decode"] += 1
            continue
        if line.strip() == "":
            anomalies["blank"] += 1
            continue
        if len(line) < MIN_UA_LEN:
            anomalies["short"] += 1
            continue
        valid.append(line)
    return raw, valid, anomalies


def allocate(counts: Counter, valid_total: int) -> dict[str, int]:
    """Per-stratum sample counts, integer-only and deterministic.

    1. Largest-remainder (Hare) proportional allocation to TARGET_TOTAL.
    2. Tail strata below MIN_FLOOR are raised to MIN_FLOOR, capped by their
       corpus availability (a stratum can never receive more than it has).
    3. The (possibly negative) residual from step 2 is absorbed by the
       currently largest stratum (ties: alphabetical), keeping the total at
       exactly TARGET_TOTAL.
    """
    assert STRATA == tuple(sorted(STRATA)), "STRATA must stay alphabetical"
    alloc = {s: counts[s] * TARGET_TOTAL // valid_total for s in STRATA}
    remainder = {s: counts[s] * TARGET_TOTAL % valid_total for s in STRATA}
    leftover = TARGET_TOTAL - sum(alloc.values())
    for s in sorted(STRATA, key=lambda x: (-remainder[x], x))[:leftover]:
        alloc[s] += 1
    for s in STRATA:
        alloc[s] = max(alloc[s], min(counts[s], MIN_FLOOR))
    residual = TARGET_TOTAL - sum(alloc.values())
    biggest = max(STRATA, key=lambda s: (alloc[s], s))
    alloc[biggest] += residual
    assert sum(alloc.values()) == TARGET_TOTAL
    for s in STRATA:
        assert 0 <= alloc[s] <= counts[s], f"stratum {s}: {alloc[s]} > corpus {counts[s]}"
    return alloc


def render(source_label: str, source_sha: str, raw_size: int, total_lines: int,
           anomalies: Counter, counts: Counter, alloc: dict[str, int],
           samples: list[str], strata_labels: list[str]) -> str:
    """Render the full samples.mbt content (deterministic; no timestamps)."""
    strata_line = " ".join(f"{s}={alloc[s]}" for s in STRATA)
    anomaly_line = " ".join(f"{k}={anomalies[k]}" for k in sorted(anomalies)) or "none"
    header = f"""\
// GENERATED — DO NOT EDIT.
//
// This file is machine-generated by scripts/gen_bench_samples.py. Edit the
// generator (or its constants) and regenerate; never edit this file by hand.
//
// Regenerate:   python scripts/gen_bench_samples.py
// Source:       {source_label}
// Source sha256: {source_sha}
// Source size:  {raw_size} bytes, {total_lines} lines
// Seed:         {SEED}
// Method:       fixed-seed stratified sampling; strata by UA form keyword
//               (first match wins: android / ios / bot / windows / macos /
//               linux / other); per-stratum counts by integer largest-remainder
//               proportional allocation to {TARGET_TOTAL} with a {MIN_FLOOR}-sample floor
//               for tail strata (capped by availability); within-stratum
//               selection with one random.Random({SEED}) instance drawing
//               random.sample over corpus file order, strata processed in
//               alphabetical order; arrays below are grouped in that order.
// Samples:      {len(samples)}
// Strata:       {strata_line}
// Anomalies:    {sum(anomalies.values())} skipped ({anomaly_line})
//
// Contract (consumed by the T-03 benchmark runner, same package):
//   samples / sample_strata are parallel arrays; sample_set_hash is the
//   source-corpus sha256 in "sha256:<hex>" form so the runner can report
//   provenance with zero file IO. See MANIFEST.md next to this file.
"""

    parts = [header]
    parts.append("///|\n/// Sampled user-agent strings for the v0.2 performance benchmark.\n"
                 "let samples : Array[String] = [\n")
    parts.extend(f'  "{moonbit_escape(ua)}",\n' for ua in samples)
    parts.append("]\n\n")

    parts.append("///|\n/// Stratum label of the sample at the same index in `samples`.\n"
                 "let sample_strata : Array[String] = [\n")
    parts.extend(f'  "{label}",\n' for label in strata_labels)
    parts.append("]\n\n")

    parts.append("///|\n/// sha256 of the source corpus (\"sha256:<hex>\"); printed verbatim\n"
                 "/// by the runner's provenance report.\n"
                 f'let sample_set_hash : String = "sha256:{source_sha}"\n')
    return "".join(parts)


def atomic_write(path: Path, content: str) -> None:
    """Replace path atomically: temp file in the same directory, then os.replace."""
    fd, tmp_name = tempfile.mkstemp(
        dir=str(path.parent), prefix=".gen_bench_samples.tmp-", suffix=".mbt")
    tmp_path = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(content)
        os.replace(tmp_path, path)
    except BaseException:
        tmp_path.unlink(missing_ok=True)
        raise


def main() -> None:
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass  # non-standard stdout; printing may degrade but generation must not

    override = os.environ.get(SOURCE_ENV)
    source_label = override if override else DEFAULT_SOURCE_REL
    src_path = Path(source_label)
    if not src_path.is_absolute():
        src_path = REPO_ROOT / src_path

    raw, valid, anomalies = load_corpus(src_path, source_label)
    valid_total = len(valid)
    if valid_total == 0:
        fail(f"source corpus has no usable lines: {src_path}")
    total_lines = sum(anomalies.values()) + valid_total
    source_sha = hashlib.sha256(raw).hexdigest()

    counts = Counter(classify(ua) for ua in valid)
    alloc = allocate(counts, valid_total)

    pools: dict[str, list[str]] = {s: [] for s in STRATA}
    for ua in valid:  # corpus file order
        pools[classify(ua)].append(ua)

    rng = random.Random(SEED)
    samples: list[str] = []
    strata_labels: list[str] = []
    for s in STRATA:
        picked = rng.sample(pools[s], alloc[s])
        samples.extend(picked)
        strata_labels.extend([s] * alloc[s])
    assert len(samples) == TARGET_TOTAL == len(strata_labels)

    content = render(source_label, source_sha, len(raw), total_lines,
                     anomalies, counts, alloc, samples, strata_labels)

    out_path = REPO_ROOT / OUTPUT_REL
    out_path.parent.mkdir(parents=True, exist_ok=True)
    atomic_write(out_path, content)

    # A success invalidates any error log left by an earlier failed run.
    if ERROR_LOG.exists():
        ERROR_LOG.unlink()

    print(f"source:     {source_label} ({len(raw)} bytes, {total_lines} lines)")
    print(f"sha256:     {source_sha}")
    print(f"seed:       {SEED}  method: fixed-seed stratified (largest-remainder, floor {MIN_FLOOR})")
    for s in STRATA:
        print(f"  stratum {s:8s} corpus={counts[s]:6d} sampled={alloc[s]:5d}")
    anomaly_total = sum(anomalies.values())
    print(f"anomalies:  {anomaly_total}/{total_lines} skipped ({dict(anomalies) or 'none'})"
          f" = {anomaly_total * 100.0 / total_lines:.4f}%")
    print(f"wrote:      {out_path} ({len(samples)} samples)")


if __name__ == "__main__":
    main()
