// Thin mars middleware adapter for the moon_ua_parser library (T-05).
//
// This module is a deliberately thin layer between the mizchi/mars HTTP
// framework and the pure helper module
// vicoproplus/moon_ua_parser_middleware_core (T-03): registration
// adaptation, request-entry helper invocation, context mounting and
// log-channel adaptation only. All assembly/degradation/forensics
// semantics live in the helper — nothing is re-implemented here.
//
// Version range: tested against mars 0.3.x (walkthrough + integration run
// against mizchi/mars 0.3.12, upstream commit ff4485e0309a8532d03002eb588a
// b06dcd252848). See README.mbt.md.

name = "vicoproplus/moon_ua_parser_mars"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/vicoproplus/moon_ua_parser"

license = "Apache-2.0"

keywords = [ "user-agent", "middleware", "mars", "http" ]

description = "mars framework middleware adapter for vicoproplus/moon_ua_parser: mounts parsed UA families on the typed request context and emits degradation forensics"

// Canonical mbti backend (mirrors mizchi/mars itself, whose moon.mod also
// sets preferred_target = "native"; this module is native-scoped — see
// supported_targets in moon.pkg).
preferred_target = "native"

import {
  "mizchi/mars@0.3.12",
  "moonbitlang/x@0.5.5",
  "mizchi/x@0.6.1",
  "moonbitlang/async@0.21.3",
  "vicoproplus/moon_ua_parser@0.2.0",
  "vicoproplus/moon_ua_parser_middleware_core@0.1.0",
}
