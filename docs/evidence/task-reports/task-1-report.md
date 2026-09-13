# T-01 Report — moon workspace 双模块探针 (E5 Task 0), attempt 3

Date: 2026-09-13. Worktree: `F:\moonbit比赛\moon_ua_parser_wt_framework`, branch `feat/v02-framework-middleware`.
Commit: `16dd600` "T-01: moon workspace dual-module probe (E5 Task 0)" — exactly 2 files staged by explicit path (`moon.work`, `docs/evidence/workspace-probe-2026-09-13.log`), **no deletions in the staged set** (hello/ was untracked, so its deletion leaves no git trace).

## Rubric judgement (all items judged)

- R1 **pass** — 清单实测文件名 `moon.work`（内容 `members = ["./moon_ua_parser_lib"]`，commit 16dd600 引入）；hello 删除后 `moon build --target native` 0 errors（"ran 14 tasks … 0 errors"）。
- R2 **pass** — 三件套全绿: 顶层 `moon build --target native` 0 errors；`moon test --target native -p vicoproplus/hello` 1/1（hello 经 moon.pkg import `vicoproplus/moon_ua_parser/src/ua_parser` 调 `@ua_parser.parse`）；顶层 `moon test --target native` 32/32；全部命令与输出落盘 `docs/evidence/workspace-probe-2026-09-13.log`。
- R3 **pass** — `hello/` 已删除；`git status` 除 moon.work（已提交）与 evidence log（已提交）外仅余任务开始前已存在的未跟踪项（`.mooncakes/`、`_build/`、`docs/superpower/`、`docs/superpowers/plans/*.md`），无任何本任务新增残留。
- R4 **pass** — 实际清单文件名 = `moon.work`；顶层命令字面量 = `moon build --target native` / `moon test --target native`（见下方"回填字面量"）。
- R5 **na** — 探针一次通过（第 1 轮即全绿），未触发两轮失败门，无需 D2 反向裁决。
- R6 **pass** — hello 删除后: `cd moon_ua_parser_lib && moon check` 0 errors（44 warnings 均为基线 deprecation 提示）；`moon test --target native` 31/31；`moon info` 后 `git diff --exit-code -- '*.mbti'` exit 0。
- R7 **pass** — 无静默回退；假设清单见下节，3 条探针期修正均记录在 evidence log §1。
- R8 **pass** — hello 仅调用 `pkg.generated.mbti:5-11` 的 pub fn `parse`；未改库公开面，`moon info` 零 diff。
- R9 **na** — 降级语义/取证格式属后续中间件任务（T-02+）验收项，本探针不涉及。
- R10 **na** — 本任务未改 `.github/**`（CI 增量合入属 T-06）。
- R11 **na** — 框架版本区间锁定属后续集成任务验收项。
- R12 **pass** — 共享文件 `moon.work` 仅由本任务写入（单点）；未创建任何中间件包目录。
- R13 **pass** — V2 dry-run: 清单加入 hello 后立即顶层构建全 workspace（"ran 20 tasks … 0 errors"），删除后再次构建验证（"ran 14 tasks … 0 errors"）。
- R14 **na** — 无集成测试失败需要 D1 归因（探针测试失败为期望值书写错误，按实际库输出修正，非框架/适配层问题）。
- R15 **pass** — `moon version` = 0.1.20260904 (94521db 2026-09-04)，与 ci.yml:43 一致。
- R16 **pass** — 验收命令全部相对路径（`moon build --target native`、`cd moon_ua_parser_lib && moon check` 等）。
- R17 **pass** — 库名/版本溯源: `vicoproplus/moon_ua_parser@0.1.0` 取自 `moon_ua_parser_lib/moon.mod`（version = "0.1.0"）；测试期望值溯源 examples/middleware/main.mbt 头注释 + 库实际输出。
- R18 **na/pass（指针项）** — spec 文件存在（`docs/superpower/SPEC/202609130033-moon_ua_parser_v02-框架对接-spec.md`），本任务未修改；spec §3 回填由控制器按 R4 字面量完成。
- R19 **na/pass（指针项）** — design 文件存在（`docs/superpower/DESIGN/202609130033-moon_ua_parser_v02-框架对接-design.md`），未修改。
- R20 **na/pass（指针项）** — plan 文件存在（`docs/superpowers/plans/2026-09-13-moon_ua_parser_v02-框架对接.md`），未修改。
- R21 **pass** — 库公开 API 文件 `moon_ua_parser_lib/src/ua_parser/pkg.generated.mbti` 存在且被消费（4 个 pub fn），`moon info` 后零 diff。
- R22 **pass** — 实现前已读 `C:\Users\Administrator\.agents\skills\moonbit-agent-guide\SKILL.md`（blocks 用 `///|`、包导入走 moon.pkg、pub 面、增量验证等约定均已遵循）。

Coverage: judged 22 / 22.

## W2 残留核对结论

`moon.work` 内容 = `members = ["./moon_ua_parser_lib"]`，有效；`hello/` 无残留；与前两轮超时中断后的预期状态完全一致。核对通过。

## 回填字面量（R4，供控制器回填 plan E1/行0 与 spec §3）

- 实际清单文件名: **`moon.work`**（不是 `moon.workspace`）
- 顶层构建: **`moon build --target native`**
- 顶层测试: **`moon test --target native`**
- 库内检查/测试: **`cd moon_ua_parser_lib && moon check`** / **`cd moon_ua_parser_lib && moon test --target native`**
- 接口零 diff: **`cd moon_ua_parser_lib && moon info`** + **`git diff --exit-code -- '*.mbti'`**

## 假设清单（网络受限下的本地依据，R7）

1. **清单文件名 `moon.work`**: 以实测为准 — 该文件已存在且此前顶层 `moon build` 成功（前轮残留 + 本轮实测构建/测试均通过）。
2. **moon.mod 成员依赖写法 `"vicoproplus/moon_ua_parser@0.1.0"`**: moon 0.1.20260904 实测拒绝无版本 import（报错原文见 evidence log）；版本号取自库 moon.mod 的 `version = "0.1.0"`；workspace 成员本地解析成功，全程未联网。
3. **moon.pkg 跨模块 import 路径 `vicoproplus/moon_ua_parser/src/ua_parser`（无版本后缀、默认别名 @ua_parser）**: 仿照库内 `examples/middleware/moon.pkg` 的既有写法，实测编译/运行通过。
4. **探针测试期望值**: UA 字符串与 family 值溯源本仓库 examples/middleware/main.mbt 头注释（tests/semantics、tests/differential 用例）；OS family 对 Windows NT 10.0 实测为 "Windows"（首轮写成 "Windows 10" 失败后以实际库输出修正，非猜测）。
5. **match 臂用 `=>`**: 首轮 `->` 触发 parse error，以本仓库 lib 既有代码风格为准修正。

## 测试过程与结果汇总

| 阶段 | 命令 | 结果 |
|---|---|---|
| 探针构建 | `moon build --target native`（含 hello） | exit 0, 0 errors |
| 探针测试 | `moon test --target native -p vicoproplus/hello` | 1/1 |
| 顶层全套 | `moon test --target native`（lib 31 + hello 1） | **32/32** |
| 拆除后构建 | `moon build --target native` | exit 0, 0 errors |
| 库检查 | `cd moon_ua_parser_lib && moon check` | 0 errors |
| 库测试 | `cd moon_ua_parser_lib && moon test --target native` | **31/31** |
| 接口零 diff | `moon info` + `git diff --exit-code -- '*.mbti'` | exit 0 |

## 文件变更记账

- `moon.work` — 交付（新建并提交 16dd600；探针期临时加入 "./hello" 后已恢复原样）。
- `docs/evidence/workspace-probe-2026-09-13.log` — 交付（新建并提交 16dd600）。
- `hello/{moon.mod,moon.pkg,hello.mbt}` — 临时探针模块，验证后**已删除**（untracked，git 无痕）。
- `moon_ua_parser_lib/**`、`.github/**`、`docs/superpower/**`、`docs/superpowers/plans/**` — 未触碰（`moon info` 曾再生 7 个未跟踪 pkg.generated.mbti 临时产物，已全部清理并确认）。

## Self-review 发现与关注点

1. **诊断误判（已修正并留痕）**: 顶层 `moon test --target native` 期间 differential.internal_test.exe 单进程全速运行约 10-13 分钟才结束；初期两次误判为"卡死"而中止（并遗留孤儿测试进程、驻留 moon.exe 守护进程异步再生已删 .mbti 的现象）。最终以进程 CPU 采样确认是长耗时计算，完整跑通两次。**对后续任务的影响**: 任何含 differential 包的顶层 `moon test --target native` 都要预留 10-15 分钟，且不得因"无输出"提前中止。
2. **驻留 moon.exe 守护进程**: moon 0.1.20260904 在 Windows 上有驻留进程，会异步再生存成物；清理生成文件前需先 `taskkill //F //IM moon.exe`（evidence log §6 已记录）。
3. **CRLF 提示**: `git add` 时出现 "LF will be replaced by CRLF" 警告（Windows autocrlf），内容无影响；tracked `pkg.generated.mbti` 曾出现仅行尾的 M 标记，已 `git checkout --` 还原。
4. **moon build 的 18 / moon check 的 44 warnings** 均为库基线既有 deprecation 提示（derive(Show) 等），非本任务引入，未改动库代码。
5. Rubric R9/R10/R11/R14 为后续任务验收项，本任务范围内判 na（非跳过，逐条给了理由）。

## Fix note — hygiene gate: 根目录构建缓存未忽略（2026-09-13 追加）

- **What changed**: 新建根 `.gitignore`，仅含根锚定两条规则 `/_build/` 与 `/.mooncakes/`（附 scope 说明头注释）；包内缓存（如 `moon_ua_parser_lib/.mooncakes/`）不受根文件影响，仍由 lib 自身 `.gitignore` 治理（`git check-ignore -v` 证实: 根文件第 5/6 行分别命中 `_build`、`.mooncakes`，而 `moon_ua_parser_lib/.mooncakes` 不被根文件匹配）。
- **Command run / output**: `git status --porcelain` → `_build/` 与 `.mooncakes/` 从未跟踪列表消失；`git status --porcelain -- moon_ua_parser_lib` → 空（lib 跟踪状态零改动）；`git add .gitignore`（显式路径，staged 集仅 `A .gitignore`）→ commit `dee7eda` "T-01: add root .gitignore for workspace-level build caches"。
- **Post-commit `git status --porcelain`**: 仅余任务开始前即存在的他人所有未跟踪项（`docs/superpower/`、`docs/superpowers/plans/*.md`）。
