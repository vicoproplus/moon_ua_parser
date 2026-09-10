#!/usr/bin/env python3
"""Generate the MoonBit rules data package from uap-core/regexes.yaml.

Reads the vendored uap-core snapshot (repo root ``uap-core/regexes.yaml``)
and writes, into ``moon_ua_parser_lib/src/ua_parser/rules/``:

- ``rules_data.mbt``    -- one line of structured data per rule: regex text
                           (verbatim) + case-insensitive flag + replacement
                           templates pre-parsed into ``TemplatePart``
                           (``Literal(String) | Group(Int)``) sequences.
- ``rules_version.mbt`` -- constants pinning the uap-core snapshot.
- ``moon.pkg``          -- package manifest (imports ``moonbitlang/regexp``
                           for the handwritten ``rules_init.mbt`` compile
                           layer, a registered exception inside this
                           generated directory).

Semantics follow uap-python (the engine authority):
- UA rules    : family_replacement / v1..v3_replacement (v1..v3 fallback to
                capture groups 2..4 when absent).
- OS rules    : os_replacement / os_v1..os_v4_replacement (fallback groups
                1..5 when absent).
- Device rules: device_replacement / brand_replacement / model_replacement;
                brand has no fallback; device regexes may carry
                ``regex_flag: "i"``.
- Template pre-parse: ``$N`` -> ``Group(N)`` (single digit, left-to-right,
  like uap-python ``replacer``), all other text -> ``Literal(s)``. Every
  referenced group number is validated against the pattern's capture-group
  count at generation time (computed with Python ``re``); an out-of-range
  reference or a pattern Python cannot compile is a generation error.

Data encoding contract (None vs Some):
- ``None``  = replacement field ABSENT in the upstream YAML; at runtime the
  engine falls back to the corresponding capture group (or to no value) --
  exactly like uap-python's matcher defaults.
- ``Some(parts)`` = template PRESENT, even if it evaluates to an empty
  string after substitution (runtime strips and maps "" to None).

The script locates its inputs from its own location first, then relative to
the CWD, so it runs from any working directory. Output is deterministic:
running it twice produces byte-identical files.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

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
# Snapshot identity (fixed by the project plan; update when bumping uap-core).
# ---------------------------------------------------------------------------

UAP_CORE_COMMIT = "73e7340"
UAP_CORE_DATE = "2026-08-24"
GENERATOR_NAME = "scripts/gen_rules.py"
REGENERATE_CMD = "python scripts/gen_rules.py"

# ---------------------------------------------------------------------------
# Layout.
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[1]
YAML_RELATIVE = Path("uap-core") / "regexes.yaml"
OUTPUT_DIR = REPO_ROOT / "moon_ua_parser_lib" / "src" / "ua_parser" / "rules"
ERROR_LOG = REPO_ROOT / "scripts" / "gen_rules.error.log"

# ---------------------------------------------------------------------------
# Rule schema (driven by uap-python matchers.py + uap-core regexes.yaml).
# ---------------------------------------------------------------------------


class Section:
    """Per-section schema: YAML key -> generated struct field."""

    def __init__(
        self,
        yaml_key: str,
        struct_name: str,
        array_name: str,
        fields: list[str],
        template_keys: dict[str, str],
    ):
        self.yaml_key = yaml_key
        self.struct_name = struct_name
        self.array_name = array_name
        self.fields = fields  # struct fields, in declaration order
        self.template_keys = template_keys  # yaml replacement key -> field name
        known = {"regex", "flags", "regex_flag", *template_keys.keys()}
        self.known_keys = known


SECTIONS = [
    Section(
        yaml_key="user_agent_parsers",
        struct_name="UaRuleData",
        array_name="ua_rules",
        fields=["family", "v1", "v2", "v3"],
        template_keys={
            "family_replacement": "family",
            "v1_replacement": "v1",
            "v2_replacement": "v2",
            "v3_replacement": "v3",
        },
    ),
    Section(
        yaml_key="os_parsers",
        struct_name="OsRuleData",
        array_name="os_rules",
        fields=["family", "v1", "v2", "v3", "v4"],
        template_keys={
            "os_replacement": "family",
            "os_v1_replacement": "v1",
            "os_v2_replacement": "v2",
            "os_v3_replacement": "v3",
            "os_v4_replacement": "v4",
        },
    ),
    Section(
        yaml_key="device_parsers",
        struct_name="DeviceRuleData",
        array_name="device_rules",
        fields=["family", "brand", "model"],
        template_keys={
            "device_replacement": "family",
            "brand_replacement": "brand",
            "model_replacement": "model",
        },
    ),
]

# '$N' single-digit group reference, exactly like uap-python's replacer.
TEMPLATE_REF = re.compile(r"\$(\d)")


# ---------------------------------------------------------------------------
# Generation errors are collected, reported, and fatal.
# ---------------------------------------------------------------------------


class GenError(Exception):
    pass


def parse_template(value: str, ngroups: int, where: str) -> list[tuple[str, object]]:
    """Pre-parse a replacement template into (kind, payload) parts.

    ``$N`` -> ``("group", N)``; everything else accumulates into
    ``("literal", s)`` chunks. Consecutive literal characters are merged.
    """
    parts: list[tuple[str, object]] = []
    lit: list[str] = []
    pos = 0
    while pos < len(value):
        ch = value[pos]
        if ch == "$" and pos + 1 < len(value) and value[pos + 1].isdigit():
            n = int(value[pos + 1])
            if n < 1 or n > ngroups:
                raise GenError(
                    f"{where}: template {value!r} references ${n} but the "
                    f"pattern only has {ngroups} capture group(s)"
                )
            if lit:
                parts.append(("literal", "".join(lit)))
                lit = []
            parts.append(("group", n))
            pos += 2
        else:
            lit.append(ch)
            pos += 1
    if lit:
        parts.append(("literal", "".join(lit)))
    return parts


def moonbit_escape(s: str) -> str:
    """Escape a Python string for a MoonBit double-quoted string literal.

    Patterns and template literals are copied verbatim; only literal-level
    escaping is applied (backslash, quote, and control characters).
    """
    out = []
    for ch in s:
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif ord(ch) < 0x20:
            out.append(f"\\u{ord(ch):04x}")
        else:
            out.append(ch)
    return "".join(out)


def moonbit_quote(s: str) -> str:
    """Render a Python string as a MoonBit double-quoted string literal."""
    return '"' + moonbit_escape(s) + '"'


def parts_to_moonbit(parts: list[tuple[str, object]]) -> str:
    """Render pre-parsed parts as ``Some([...])`` (empty template -> Some([]))."""
    if not parts:
        return "Some([])"
    rendered = []
    for kind, payload in parts:
        if kind == "literal":
            rendered.append(f"Literal({moonbit_quote(payload)})")
        else:
            rendered.append(f"Group({payload})")
    return "Some([" + ", ".join(rendered) + "])"


def render_rule(
    section: Section,
    pattern: str,
    flag_i: bool,
    templates: dict[str, list[tuple[str, object]]],
) -> str:
    field_items = []
    for name in section.fields:
        if name in templates:
            value = parts_to_moonbit(templates[name])
        else:
            value = "None"
        field_items.append(f"{name} : {value}")
    body = ", ".join(
        [f"pattern : {moonbit_quote(pattern)}", f"flag_i : {'true' if flag_i else 'false'}"]
        + field_items
    )
    return f"  {section.struct_name}::{{ {body} }},"


def convert_entry(section: Section, entry: object, index: int) -> tuple[str, bool]:
    """Convert one YAML entry into a rendered rule line.

    Returns (line, flag_i). Raises GenError on any validation failure.
    """
    where = f"{section.yaml_key}[{index}]"
    if not isinstance(entry, dict):
        raise GenError(f"{where}: expected a mapping, got {type(entry).__name__}")
    unknown = sorted(set(entry.keys()) - section.known_keys)
    if unknown:
        raise GenError(f"{where}: unknown key(s) {unknown} (schema drift?)")

    raw_pattern = entry.get("regex")
    if not isinstance(raw_pattern, str):
        raise GenError(f"{where}: 'regex' must be a string")

    # Flag: upstream device parsers key this as regex_flag; accept 'flags'
    # as well (both must be exactly "i" when present).
    flag_values = []
    for key in ("flags", "regex_flag"):
        if key in entry:
            flag_values.append((key, entry[key]))
    flag_i = False
    if len(flag_values) > 1:
        raise GenError(f"{where}: both 'flags' and 'regex_flag' present")
    for key, value in flag_values:
        if value != "i":
            raise GenError(f"{where}: {key} must be \"i\", got {value!r}")
        flag_i = True

    # Compile exactly as upstream would (proves the pattern parses and gives
    # the capture-group count used to bound $N references).
    import_flags = re.IGNORECASE if flag_i else 0
    try:
        compiled = re.compile(raw_pattern, import_flags)
    except re.error as exc:
        raise GenError(f"{where}: Python re cannot compile {raw_pattern!r}: {exc}")
    ngroups = compiled.groups

    templates: dict[str, list[tuple[str, object]]] = {}
    for key, field in section.template_keys.items():
        if key not in entry:
            continue
        value = entry[key]
        if not isinstance(value, str):
            raise GenError(f"{where}: {key!r} must be a string, got {type(value).__name__}")
        templates[field] = parse_template(value, ngroups, f"{where} ({key})")

    return render_rule(section, raw_pattern, flag_i, templates), flag_i


def header(comment: str = "//") -> str:
    return "\n".join(
        [
            f"{comment} GENERATED — DO NOT EDIT.",
            f"{comment}",
            f"{comment} Generator         : {GENERATOR_NAME}",
            f"{comment} uap-core snapshot : commit {UAP_CORE_COMMIT}, date {UAP_CORE_DATE}",
            f"{comment} Regenerate with   : {REGENERATE_CMD}",
        ]
    )


def generate_rules_data(sections_data: list[tuple[Section, list[str], int]]) -> str:
    lines = [
        header(),
        "//",
        "// Data encoding (None vs Some):",
        "// - `pattern` is the uap-core regex copied verbatim (only MoonBit string",
        "//   literal escaping applied); patterns are JS-flavored.",
        "// - `flag_i` mirrors the upstream `regex_flag: \"i\"`.",
        "// - Replacement templates are pre-parsed: `$N` -> `Group(N)`, remaining",
        "//   text -> `Literal(s)`.",
        "// - `None` = the replacement field was ABSENT in the upstream YAML; the",
        "//   runtime falls back to the corresponding capture group (device brand",
        "//   has no fallback), exactly like uap-python. `Some(parts)` = template",
        "//   PRESENT, even if it evaluates to an empty string at runtime.",
        "",
        "///|",
        "/// One part of a pre-parsed replacement template.",
        "///",
        "/// `Group(n)` references capture group `n` of the rule pattern (1-based);",
        "/// `Literal(s)` is literal text copied from the template.",
        "pub enum TemplatePart {",
        "  Literal(String)",
        "  Group(Int)",
        "}",
        "",
        "///|",
        "/// A user-agent (browser) rule: pattern plus pre-parsed templates.",
        "pub(all) struct UaRuleData {",
        "  pattern : String",
        "  flag_i : Bool",
        "  family : Array[TemplatePart]?",
        "  v1 : Array[TemplatePart]?",
        "  v2 : Array[TemplatePart]?",
        "  v3 : Array[TemplatePart]?",
        "}",
        "",
        "///|",
        "/// An operating-system rule: pattern plus pre-parsed templates.",
        "pub(all) struct OsRuleData {",
        "  pattern : String",
        "  flag_i : Bool",
        "  family : Array[TemplatePart]?",
        "  v1 : Array[TemplatePart]?",
        "  v2 : Array[TemplatePart]?",
        "  v3 : Array[TemplatePart]?",
        "  v4 : Array[TemplatePart]?",
        "}",
        "",
        "///|",
        "/// A device rule: pattern plus pre-parsed templates.",
        "pub(all) struct DeviceRuleData {",
        "  pattern : String",
        "  flag_i : Bool",
        "  family : Array[TemplatePart]?",
        "  brand : Array[TemplatePart]?",
        "  model : Array[TemplatePart]?",
        "}",
    ]
    for section, rule_lines, _flag_count in sections_data:
        lines.append("")
        lines.append("///|")
        lines.append(f"/// {section.yaml_key} rules, in upstream order.")
        lines.append(f"pub let {section.array_name} : Array[{section.struct_name}] = [")
        lines.extend(rule_lines)
        lines.append("]")
    lines.append("")
    return "\n".join(lines)


def generate_rules_version() -> str:
    return "\n".join(
        [
            header(),
            "//",
            "///|",
            "/// Short commit hash of the vendored uap-core snapshot these rules",
            "/// were generated from.",
            f'pub const UAP_CORE_COMMIT : String = "{UAP_CORE_COMMIT}"',
            "",
            "///|",
            "/// Date of the vendored uap-core snapshot these rules were generated",
            "/// from.",
            f'pub const UAP_CORE_DATE : String = "{UAP_CORE_DATE}"',
            "",
        ]
    )


def generate_moon_pkg() -> str:
    return "\n".join(
        [
            header(),
            "//",
            "// The handwritten rules_init.mbt (registered exception, spec section",
            "// 2 GO registry) precompiles every pattern with the regexp engine",
            "// imported below.",
            "",
            "import {",
            '  "moonbitlang/regexp",',
            "}",
            "",
        ]
    )


def atomic_write(path: Path, content: str) -> None:
    tmp = path.with_name(path.name + ".tmp")
    with open(tmp, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)
    os.replace(tmp, path)


def resolve_yaml() -> Path:
    candidates = [
        REPO_ROOT / YAML_RELATIVE,
        Path.cwd() / YAML_RELATIVE,
        Path.cwd().parent / YAML_RELATIVE,
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    fail_with_log(
        [
            "uap-core/regexes.yaml not found. Tried:",
            *[f"  {c}" for c in candidates],
            "Run this script from the repository (e.g. repo root) with the "
            "vendored uap-core snapshot present.",
        ],
        summary="uap-core/regexes.yaml not found",
    )


def write_error_log(errors: list[str]) -> None:
    ERROR_LOG.parent.mkdir(parents=True, exist_ok=True)
    atomic_write(ERROR_LOG, "\n".join(errors) + "\n")


def fail_with_log(errors: list[str], summary: str | None = None) -> None:
    write_error_log(errors)
    if summary is None:
        summary = f"{len(errors)} generation error(s)"
    print(
        f"error: {summary}; see {ERROR_LOG}",
        file=sys.stderr,
    )
    sys.exit(1)


def main() -> None:
    yaml_path = resolve_yaml()
    print(f"Reading {yaml_path}")
    with open(yaml_path, encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict):
        print("error: regexes.yaml top level is not a mapping", file=sys.stderr)
        sys.exit(1)

    errors: list[str] = []
    sections_data: list[tuple[Section, list[str], int]] = []
    total = 0
    for section in SECTIONS:
        entries = data.get(section.yaml_key)
        if not isinstance(entries, list):
            errors.append(f"missing or invalid section {section.yaml_key!r}")
            continue
        rule_lines: list[str] = []
        flag_count = 0
        for index, entry in enumerate(entries):
            try:
                line, flag_i = convert_entry(section, entry, index)
            except GenError as exc:
                errors.append(str(exc))
                continue
            if flag_i:
                flag_count += 1
            rule_lines.append(line)
        if len(rule_lines) != len(entries):
            errors.append(
                f"{section.yaml_key}: converted {len(rule_lines)} of "
                f"{len(entries)} entries (see errors above)"
            )
        sections_data.append((section, rule_lines, flag_count))
        total += len(rule_lines)

    if errors:
        fail_with_log(errors)

    # Self-consistency: generated text must carry exactly the section counts.
    for section, rule_lines, _flag_count in sections_data:
        emitted = sum(
            1 for ln in rule_lines if f"{section.struct_name}::{{" in ln
        )
        assert emitted == len(rule_lines), (
            f"{section.yaml_key}: rendered line count mismatch "
            f"({emitted} != {len(rule_lines)})"
        )

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    rules_data = generate_rules_data(sections_data)
    rules_version = generate_rules_version()
    moon_pkg = generate_moon_pkg()
    atomic_write(OUTPUT_DIR / "rules_data.mbt", rules_data)
    atomic_write(OUTPUT_DIR / "rules_version.mbt", rules_version)
    atomic_write(OUTPUT_DIR / "moon.pkg", moon_pkg)

    # Remove a stale error log from any previous failed run.
    if ERROR_LOG.exists():
        ERROR_LOG.unlink()

    print(f"uap-core snapshot: commit {UAP_CORE_COMMIT}, date {UAP_CORE_DATE}")
    for section, rule_lines, flag_count in sections_data:
        print(f"{section.yaml_key:20s}: {len(rule_lines):4d} rules ({flag_count} with flag i)")
    print(f"{'total':20s}: {total:4d} rules")
    for name in ("rules_data.mbt", "rules_version.mbt", "moon.pkg"):
        path = OUTPUT_DIR / name
        print(f"wrote {path} ({path.stat().st_size} bytes)")
    print("OK")


if __name__ == "__main__":
    main()
