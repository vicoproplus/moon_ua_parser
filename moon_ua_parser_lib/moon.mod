// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "vicoproplus/moon_ua_parser"

version = "0.2.0"

readme = "README.mbt.md"

repository = "https://github.com/vicoproplus/moon_ua_parser"

license = "Apache-2.0"

keywords = ["user-agent", "ua-parser", "http", "parser"]

preferred_target = "wasm"

description = "User-agent parser library ported from uap-core rules with uap-python-compatible semantics"

import {
  "moonbitlang/regexp@0.3.5",
}
