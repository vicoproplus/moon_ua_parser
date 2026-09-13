// Thin crescent middleware adapter for the moon_ua_parser library (T-04).
//
// This module is a deliberately thin layer between the bobzhang/crescent
// HTTP framework and the pure helper module
// vicoproplus/moon_ua_parser_middleware_core (T-03): registration
// adaptation, request-entry helper invocation, context mounting and
// log-channel adaptation only. All assembly/degradation/forensics
// semantics live in the helper — nothing is re-implemented here.
//
// Version range: tested against crescent 0.11.x (walkthrough + integration
// run against bobzhang/crescent 0.11.1, upstream commit d99287ae409d198e
// 1f7c1fd606e4883188d97c02). See README.mbt.md.

name = "vicoproplus/moon_ua_parser_crescent"

version = "0.1.0"

preferred_target = "native"

readme = "README.mbt.md"

repository = "https://github.com/vicoproplus/moon_ua_parser"

license = "Apache-2.0"

keywords = [ "user-agent", "middleware", "crescent", "http" ]

description = "Crescent framework middleware adapter for vicoproplus/moon_ua_parser: mounts parsed UaInfo on the request/response context and emits degradation forensics"

import {
  "bobzhang/crescent@0.11.1",
  "moonbitlang/async@0.20.3",
  "vicoproplus/moon_ua_parser@0.2.0",
  "vicoproplus/moon_ua_parser_middleware_core@0.1.0",
}
