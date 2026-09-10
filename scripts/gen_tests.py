#!/usr/bin/env python3
"""Generate the MoonBit differential test package from uap-core test suites.

Reads the vendored uap-core snapshot test files
(``uap-core/tests/test_ua.yaml``, ``test_os.yaml``, ``test_device.yaml``)
and writes, into ``moon_ua_parser_lib/tests/differential/``:

- ``diff_ua.mbt``     -- 1601 (snapshot count) UaCase entries + one ``test``
                          block looping every case and asserting
                          ``parse_browser(input).family/major/minor/patch/``
                          ``patch_minor`` field-by-field.
- ``diff_os.mbt``     -- OS cases, asserting ``parse_os`` on
                          ``family/major/minor/patch/patch_minor``.
- ``diff_device.mbt`` -- device cases, asserting ``parse_device`` on
                          ``family/brand/model``.
- ``moon.pkg``        -- package manifest (imports ``src/ua_parser``).

Encoding contract (None vs Some):
- The upstream YAML encodes "no expectation" in two ways: a MISSING key and
  an EMPTY value (``patch:`` / ``patch: ''``). Both convert to ``None`` in
  the generated MoonBit case; any non-empty string converts to ``Some(s)``.
- Each expected field is generated as ``String?`` so a missing expectation
  can never be asserted as the literal empty string.

Case identity: the generated cases array keeps upstream order, so the
0-based array position IS the 0-based ``test_cases`` YAML index. Assertion
messages embed ``index|input|field=value`` on BOTH sides of ``assert_eq``,
so any failure output identifies the offending case directly.

EXEMPTION HOOK (T-08 reconciliation; the differential suite must end green
at thresholds <100% with exemptions REGISTERED, never silent):
``scripts/test_exemptions.json`` is optional (shipped absent = zero
exemptions). Shape::

    {"ua": [case_index, ...], "os": [...], "device": [...]}

Indices are 0-based positions into the corresponding YAML ``test_cases``
order. An exempted case stays in the generated array at its upstream
position but is SKIPPED by the looping assertion, COUNTED in a generated
``pub const <domain>_exempted_count : Int``, listed in the generated file
header comment, and carried in a ``<domain>_exempted`` index array.

The script locates its inputs from its own location first, then relative
to the CWD, so it runs from any working directory. Output is deterministic:
running it twice produces byte-identical files (idempotent regeneration).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

# Reuse gen_rules.py helpers verbatim (escaping + atomic write + snapshot
# identity) so the two generators cannot drift apart. gen_rules.py has no
# import-time side effects (main is guarded). Bytecode writing is disabled so
# importing never drops a scripts/__pycache__/ directory into the repo.
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_rules import (  # noqa: E402
    UAP_CORE_COMMIT,
    UAP_CORE_DATE,
    atomic_write,
    moonbit_quote,
)

try:
    import yaml
except ImportError:  # pragma: no cover
    print(
        "error: PyYAML is required to run the generator "
        "(install with: python -m pip install pyyaml)",
        file=sys.stderr,
    )
    sys.exit(1)

# ---------------------------------------------------------------------------
# Layout.
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[1]
TESTS_RELATIVE = Path("uap-core") / "tests"
OUTPUT_DIR = REPO_ROOT / "moon_ua_parser_lib" / "tests" / "differential"
ERROR_LOG = REPO_ROOT / "scripts" / "gen_tests.error.log"
EXEMPTIONS_PATH = REPO_ROOT / "scripts" / "test_exemptions.json"
GENERATOR_NAME = "scripts/gen_tests.py"
REGENERATE_CMD = "python scripts/gen_tests.py"


class GenError(Exception):
    pass


# ---------------------------------------------------------------------------
# Domain schemas (driven by the actual uap-core test YAML keys).
# ---------------------------------------------------------------------------


class Domain:
    """Per-domain schema: file, names, asserted fields, ignorable keys."""

    def __init__(
        self,
        key: str,
        yaml_name: str,
        struct_name: str,
        array_name: str,
        parser: str,
        fields: list[str],
        ignored_keys: set[str],
    ):
        self.key = key  # exemption-file key
        self.yaml_name = yaml_name  # uap-core/tests/<yaml_name>
        self.struct_name = struct_name
        self.array_name = array_name
        self.parser = parser  # @ua_parser function name
        self.fields = fields  # expected fields asserted, in order
        self.ignored_keys = ignored_keys  # present upstream, not asserted
        self.user_agent_key = "user_agent_string"

    def allowed_keys(self) -> set[str]:
        return {self.user_agent_key, *self.ignored_keys} | set(self.fields)


DOMAINS = [
    Domain(
        key="ua",
        yaml_name="test_ua.yaml",
        struct_name="UaCase",
        array_name="ua_cases",
        parser="parse_browser",
        # Browser mirrors the upstream UserAgent record incl. patch_minor
        # (group-5 fallback, matchers.py:50); 41 upstream cases assert it.
        fields=["family", "major", "minor", "patch", "patch_minor"],
        ignored_keys=set(),
    ),
    Domain(
        key="os",
        yaml_name="test_os.yaml",
        struct_name="OsCase",
        array_name="os_cases",
        parser="parse_os",
        fields=["family", "major", "minor", "patch", "patch_minor"],
        ignored_keys=set(),
    ),
    Domain(
        key="device",
        yaml_name="test_device.yaml",
        struct_name="DeviceCase",
        array_name="device_cases",
        parser="parse_device",
        fields=["family", "brand", "model"],
        ignored_keys=set(),
    ),
]

# js_* keys (js_ua, js_ua_maj_ver, ...) may appear upstream; always ignored.
JS_PREFIX = "js_"


# ---------------------------------------------------------------------------
# Input loading.
# ---------------------------------------------------------------------------


def resolve_tests_dir() -> Path:
    candidates = [
        REPO_ROOT / TESTS_RELATIVE,
        Path.cwd() / TESTS_RELATIVE,
        Path.cwd().parent / TESTS_RELATIVE,
    ]
    for candidate in candidates:
        if candidate.is_dir():
            return candidate
    fail_with_log(
        [
            "uap-core/tests directory not found. Tried:",
            *[f"  {c}" for c in candidates],
            "Run this script from the repository (e.g. repo root) with the "
            "vendored uap-core snapshot present.",
        ],
        summary="uap-core/tests directory not found",
    )


def load_cases(domain: Domain, tests_dir: Path) -> list[dict]:
    yaml_path = tests_dir / domain.yaml_name
    if not yaml_path.is_file():
        fail_with_log(
            [f"missing input file: {yaml_path}"],
            summary=f"{domain.yaml_name} not found",
        )
    with open(yaml_path, encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict) or not isinstance(data.get("test_cases"), list):
        raise GenError(f"{domain.yaml_name}: top level must be a mapping with 'test_cases'")
    cases = data["test_cases"]
    for index, case in enumerate(cases):
        where = f"{domain.yaml_name}[{index}]"
        if not isinstance(case, dict):
            raise GenError(f"{where}: expected a mapping, got {type(case).__name__}")
        raw = case.get(domain.user_agent_key)
        if not isinstance(raw, str):
            raise GenError(f"{where}: '{domain.user_agent_key}' must be a string")
        unknown = sorted(
            k for k in case.keys() if k not in domain.allowed_keys() and not k.startswith(JS_PREFIX)
        )
        if unknown:
            raise GenError(f"{where}: unknown key(s) {unknown} (schema drift?)")
    return cases


def expected_field(case: dict, field: str, where: str) -> str:
    """Convert one expected YAML value to ``None`` / ``Some("...")``.

    Missing key, YAML null and the empty string ALL mean "no expectation"
    and become ``None``; any other string becomes ``Some(s)``.
    """
    if field not in case:
        return "None"
    value = case[field]
    if value is None or (isinstance(value, str) and value == ""):
        return "None"
    if not isinstance(value, str):
        raise GenError(f"{where}: expected field {field!r} must be a string or empty")
    return f'Some({moonbit_quote(value)})'


# ---------------------------------------------------------------------------
# Exemption hook.
# ---------------------------------------------------------------------------


def load_exemptions(domains: dict[str, Domain], cases_by_key: dict[str, list[dict]]) -> dict[str, list[int]]:
    """Load and validate scripts/test_exemptions.json (absent = no exemptions).

    Returns {domain_key: sorted unique 0-based indices}. Any malformed entry
    is a generation error (fail loud, never silently dropped).
    """
    if not EXEMPTIONS_PATH.is_file():
        return {domain.key: [] for domain in DOMAINS}
    try:
        with open(EXEMPTIONS_PATH, encoding="utf-8") as f:
            raw = json.load(f)
    except (OSError, ValueError) as exc:
        raise GenError(f"{EXEMPTIONS_PATH}: cannot read JSON: {exc}")
    if not isinstance(raw, dict):
        raise GenError(f"{EXEMPTIONS_PATH}: top level must be a mapping")
    unknown = sorted(set(raw.keys()) - set(domains.keys()))
    if unknown:
        raise GenError(f"{EXEMPTIONS_PATH}: unknown key(s) {unknown}")
    result: dict[str, list[int]] = {}
    for key in sorted(set(raw.keys()) & set(domains.keys())):
        entries = raw[key]
        where = f"{EXEMPTIONS_PATH}['{key}']"
        if not isinstance(entries, list):
            raise GenError(f"{where}: must be a list of 0-based case indices")
        seen: set[int] = set()
        for entry in entries:
            if isinstance(entry, bool) or not isinstance(entry, int):
                raise GenError(f"{where}: indices must be integers, got {entry!r}")
            if entry < 0 or entry >= len(cases_by_key[key]):
                raise GenError(
                    f"{where}: index {entry} out of range "
                    f"(domain has {len(cases_by_key[key])} cases)"
                )
            if entry in seen:
                raise GenError(f"{where}: duplicate index {entry}")
            seen.add(entry)
        result[key] = sorted(seen)
    return {domain.key: result.get(domain.key, []) for domain in DOMAINS}


# ---------------------------------------------------------------------------
# Rendering.
# ---------------------------------------------------------------------------


def header(source: str) -> str:
    return "\n".join(
        [
            "// GENERATED — DO NOT EDIT.",
            "//",
            f"// Generator         : {GENERATOR_NAME}",
            f"// uap-core snapshot : commit {UAP_CORE_COMMIT}, date {UAP_CORE_DATE}",
            f"// Source            : uap-core/tests/{source}",
            f"// Regenerate with   : {REGENERATE_CMD}",
            "//",
            "// Case index = 0-based position in this array = 0-based position",
            "// in the upstream YAML `test_cases` order.",
            "//",
            "// Exemption hook: scripts/test_exemptions.json (optional; absent",
            "// means zero exemptions). Exempted cases stay in the array but",
            "// are skipped by the test block and counted by",
            "// `<domain>_exempted_count`.",
        ]
    )


def render_domain_file(domain: Domain, cases: list[dict], exempted: list[int]) -> str:
    lines = [header(domain.yaml_name)]
    exempt_note = ", ".join(str(i) for i in exempted) if exempted else "(none)"
    lines.append(f"// Exempted indices for this domain: {exempt_note}")
    lines.append("")
    lines.append("///|")
    lines.append(
        f"/// One differential test case from `uap-core/tests/{domain.yaml_name}`."
    )
    lines.append("///")
    lines.append("/// `None` = the upstream YAML carried no expectation for this field")
    lines.append("/// (key missing, null, or empty string).")
    lines.append(f"pub(all) struct {domain.struct_name} {{")
    lines.append("  input : String")
    for field in domain.fields:
        lines.append(f"  {field} : String?")
    lines.append("} derive(Eq, Show)")
    lines.append("")
    lines.append("///|")
    lines.append(f"/// All {domain.yaml_name} cases, in upstream order.")
    lines.append(f"pub let {domain.array_name} : Array[{domain.struct_name}] = [")
    case_lines = []
    for index, case in enumerate(cases):
        where = f"{domain.yaml_name}[{index}]"
        items = [f"input : {moonbit_quote(case[domain.user_agent_key])}"]
        items += [f"{f} : {expected_field(case, f, where)}" for f in domain.fields]
        case_lines.append(f"  {domain.struct_name}::{{ {', '.join(items)} }},")
    lines.extend(case_lines)
    lines.append("]")
    lines.append("")
    lines.append("///|")
    lines.append("/// 0-based indices of cases exempted from differential assertions")
    lines.append(f"/// (registered in scripts/test_exemptions.json).")
    lines.append(f"let {domain.key}_exempted : Array[Int] = [")
    lines.extend(f"  {i}," for i in exempted)
    lines.append("]")
    lines.append("")
    lines.append("///|")
    lines.append(f"fn {domain.key}_is_exempted(i : Int) -> Bool {{")
    lines.append(f"  for e in {domain.key}_exempted {{")
    lines.append("    if e == i {")
    lines.append("      return true")
    lines.append("    }")
    lines.append("  }")
    lines.append("  false")
    lines.append("}")
    lines.append("")
    lines.append("///|")
    lines.append("/// Number of cases exempted from the assertions below.")
    # `pub let` (not `const`): MoonBit const names must be UPPER_CASE, and the
    # controller-fixed name for this counter is `<domain>_exempted_count`.
    lines.append(f"pub let {domain.key}_exempted_count : Int = {len(exempted)}")
    lines.append("")
    lines.append("///|")
    lines.append(
        f'/// Differential test: {len(cases) - len(exempted)} of {len(cases)} '
        f"{domain.key} cases asserted field-by-field."
    )
    lines.append(f'/// Failures print "<index>|<input>|<field>=<value>" for both sides.')
    lines.append(
        f'test "differential {domain.key}: {len(cases) - len(exempted)} asserted '
        f'/ {len(cases)} total ({len(exempted)} exempted)" {{'
    )
    lines.append(f"  for i, c in {domain.array_name} {{")
    lines.append(f"    if {domain.key}_is_exempted(i) {{")
    lines.append("      continue")
    lines.append("    }")
    lines.append(f"    let got = @ua_parser.{domain.parser}(c.input)")
    for field in domain.fields:
        lines.append("    assert_eq(")
        lines.append(f'      "\\{{i}}|\\{{c.input}}|{field}=\\{{c.{field}}}",')
        lines.append(f'      "\\{{i}}|\\{{c.input}}|{field}=\\{{got.{field}}}",')
        lines.append("    )")
    lines.append("  }")
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def render_moon_pkg() -> str:
    return "\n".join(
        [
            "// GENERATED — DO NOT EDIT.",
            "//",
            f"// Generator         : {GENERATOR_NAME}",
            f"// uap-core snapshot : commit {UAP_CORE_COMMIT}, date {UAP_CORE_DATE}",
            f"// Regenerate with   : {REGENERATE_CMD}",
            "//",
            "// Differential test package: imports the engine under test.",
            "",
            "import {",
            '  "vicoproplus/moon_ua_parser/src/ua_parser",',
            "}",
            "",
        ]
    )


# ---------------------------------------------------------------------------
# Driver.
# ---------------------------------------------------------------------------


def write_error_log(errors: list[str]) -> None:
    ERROR_LOG.parent.mkdir(parents=True, exist_ok=True)
    atomic_write(ERROR_LOG, "\n".join(errors) + "\n")


def fail_with_log(errors: list[str], summary: str | None = None) -> None:
    write_error_log(errors)
    if summary is None:
        summary = f"{len(errors)} generation error(s)"
    print(f"error: {summary}; see {ERROR_LOG}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    tests_dir = resolve_tests_dir()
    print(f"Reading {tests_dir}")
    try:
        cases_by_key = {d.key: load_cases(d, tests_dir) for d in DOMAINS}
        exemptions = load_exemptions({d.key: d for d in DOMAINS}, cases_by_key)
    except GenError as exc:
        fail_with_log([str(exc)], summary=str(exc))

    # Self-consistency: rendered case count must equal the loaded YAML count.
    for domain in DOMAINS:
        cases = cases_by_key[domain.key]
        marker = f"{domain.struct_name}::{{"
        rendered = render_domain_file(domain, cases, exemptions[domain.key])
        emitted = sum(1 for ln in rendered.splitlines() if marker in ln)
        assert emitted == len(cases), (
            f"{domain.yaml_name}: rendered case count mismatch ({emitted} != {len(cases)})"
        )

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    total = 0
    for domain in DOMAINS:
        cases = cases_by_key[domain.key]
        content = render_domain_file(domain, cases, exemptions[domain.key])
        path = OUTPUT_DIR / f"diff_{domain.key}.mbt"
        atomic_write(path, content)
        total += len(cases)
        print(
            f"{domain.yaml_name:18s}: {len(cases):6d} cases "
            f"({len(exemptions[domain.key])} exempted)"
        )
    pkg_path = OUTPUT_DIR / "moon.pkg"
    atomic_write(pkg_path, render_moon_pkg())

    # Remove a stale error log from any previous failed run.
    if ERROR_LOG.exists():
        ERROR_LOG.unlink()

    print(f"{'total':18s}: {total:6d} cases")
    written = [f"diff_{d.key}.mbt" for d in DOMAINS] + ["moon.pkg"]
    for name in written:
        path = OUTPUT_DIR / name
        print(f"wrote {path} ({path.stat().st_size} bytes)")
    print("OK")


if __name__ == "__main__":
    main()
