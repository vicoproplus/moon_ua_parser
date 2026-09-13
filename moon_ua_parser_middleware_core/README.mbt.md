# moon_ua_parser_middleware_core

Shared pure helper for framework middleware adapters of
[`vicoproplus/moon_ua_parser`](https://github.com/vicoproplus/moon_ua_parser).

No framework API, no IO — only pure functions to:

- **assemble** the library's `parse` result (`Result[UaInfo, UaError]`) into
  the effective `UaInfo` a middleware should mount (`assemble`);
- **judge degradation**: `Err` results, or parses whose three domain
  families all equal the library's all-miss fallback (`FALLBACK_FAMILY`,
  verified against the vendored uap-core snapshot), are degraded
  (`degradation_reason` / `is_degraded`);
- **construct forensics records** (`ForensicsRecord`): the UA truncated to
  at most 64 characters plus a machine-readable `reason` (`make_forensics`).

Degraded requests mount `empty_ua_info()` (empty-string families, `None`
versions — distinct from the library's `"Other"` fallback) and the request
chain continues without surfacing an error. The framework thin layer only
forwards the forensics record to its own log channel.
