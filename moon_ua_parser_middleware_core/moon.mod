// Shared middleware helper module for the moon_ua_parser library (T-03).
//
// Pure functions only: no framework API, no IO. Framework adapter packages
// (crescent / mars, later tasks) call into this module and adapt the
// results to their own logging channels.

name = "vicoproplus/moon_ua_parser_middleware_core"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/vicoproplus/moon_ua_parser"

license = "Apache-2.0"

keywords = ["user-agent", "middleware", "ua-parser", "http"]

description = "Shared pure helper for framework middleware adapters of vicoproplus/moon_ua_parser: UaInfo assembly, degradation judgment and forensics record construction"

import {
  "vicoproplus/moon_ua_parser@0.2.0",
}
