# Task T-09 Report — 单元收口核对

- 日期: 2026-09-13
- Worktree: `F:\moonbit比赛\moon_ua_parser_wt_framework`，分支 `feat/v02-framework-middleware`，起始 HEAD `fc26bd9`
- moon: `0.1.20260904 (94521db 2026-09-04)`（与 ci.yml:43 锁定一致）
- Closure 文档: `docs/evidence/mw-closure-2026-09-13.md`
- 提交: `c4fd9e5`（三个 evidence 文件，详见 §4）

---

## 1. Rubric 判定（acceptance R1–R5）

- **R1 — pass**: 行0/行1/行2/行4 逐条实跑并登记原始输出进 closure 文档（§一 各节，含退出码与输出尾）；行2 的 plan 字面量 `moon test -p moon_ua_parser_crescent` / `-p moon_ua_parser_mars` 被本 CLI **原样接受**（EXIT=0，7/7 与 6/6），已作正面 CLI 行为登记、无需等价替换；行3 按 brief 以 T-07（final-gate §项3/§项6）+ T-04（mw1 log:53）+ T-05（mw2 log:57）引用，三处降级取证记录交叉一致。诚实登记: 行0 实跑约 3 分钟（超 ~90s 预期，自动转后台后续跑至完成，EXIT=0；归因=T-08 dry-run 工件致缓存部分失效，`ran 7 tasks` 非 "no work to do"）。
- **R2 — pass**: 7 项清单逐项复核（现状/触发/回补目标批次）落 closure 文档 §二 表格 #1–#7；另按授权从 task-7-report 新增 2 项（#8 Show→Debug 44 条弃用告警基线、#9 全量 native 首跑静默退出执行协议），新增项均经行0/行2 实测旁证（44/0 无新增、crescent 7/7 绿）。
- **R3 — pass**: `docs/evidence/mw-closure-2026-09-13.md` 含日期、moon 版本、行0–行4 逐行结果表（PASS/引用证据）、[LOCAL_DEAD_LINK]/pending 表（9 项）、总体结论 = **已交付待发版** + 4 组阻塞项清单。
- **R4 — pass**: 显式路径 `git add` 三文件；提交前 `git diff --cached --name-status` 列出暂存集 = **A×3（1464 insertions, 0 deletions, 0 modifications）**；commit message 前缀 `T-09:`；提交后 `git status --porcelain` 仅剩其他单元既有的 untracked spec/plan 文档，无任何已跟踪文件被动。
- **R5 — pass**: 本报告含逐项结果（§1/§2）、pending 清单（§3）、提交 SHA + 暂存集（§4）。

## Global Constraints（R6–R20，逐项判定）

- **R6 — pass（引用）**: 未改任何代码文件（T-09 只验不修，提交仅 3 个 evidence 文档）；库公开面引用 T-07 附加验证: `moon info` exit 0、`pkg.generated.mbti` 零 diff、4 个 pub fn 不变（本任务复核 `grep -c "pub fn"` = 4）。
- **R7 — pass（引用）**: 降级取证记录 `{ua_summary, reason}` 落框架日志通道——mw1-example-2026-09-13.log:53 / mw2-example-2026-09-13.log:57 / final-gate log §项6 三处一致（`reason=empty_fallback ua_summary="SomethingWeNeverKnewExisted"`，响应 200 继续链路）。
- **R8 — pass（引用）**: ci.yml 只增量——T-07 附加验证 `git diff main...HEAD --stat -- .github/workflows/ci.yml` = 46 insertions / 0 deletions；行4 grep 命中的 2 个新步骤均为 INSERTED 注释标记的增量。
- **R9 — pass**: 框架版本区间锁定实测: crescent moon.mod:29-30 `bobzhang/crescent@0.11.1` + `moonbitlang/async@0.20.3`；mars moon.mod:34/37 `mizchi/mars@0.3.12` + `moonbitlang/async@0.21.3`；区间内集成测试即行2 两包 7/7+6/6（T-05 controller ruling 的 async 双版本共存裁决为既登记约束）。
- **R10 — pass**: 共享文件单点——workspace 清单（moon.work）与 ci.yml 增量分别由 T-01/T-06 提交（本任务提交零触碰）；四个包目录互不重叠（顶层 ls 分列）。
- **R11 — pass（引用）**: T-01 建清单后全模块构建验证 + T-07 项1 复验 + 本任务行0 三次复跑（EXIT=0）。
- **R12 — pass（引用）**: T-08 log [5] 归因纪律范本（三备择假设逐一证伪）；T-07 项3 静默退出按环境事实归因并重试；本任务行0 超时时长同样先归因再登记、未静默。
- **R13 — pass**: 本机 `moon version` = 0.1.20260904；ci.yml:43 `bash -s "0.1.20260904"` 锁定一致（实测 grep 命中）。
- **R14 — pass**: 全部验收命令相对路径（closure 文档 §一 各命令均为仓库根相对形态；`cd` 仅定位 worktree 本身）。
- **R15 — pass**: 选型溯源 = framework-selection.md §⑤ 逐候选来源指针（行1 实测 `grep -c "来源"` = 12 ≥ 6）；版本溯源 = moon.mod 实测 pin（R9）与 T-08 log registry API 实测（crescent 0.11.1 / 200）。
- **R16 — pass**: spec 路径存在（`test -f` EXIT=0）: `docs/superpower/SPEC/202609130033-moon_ua_parser_v02-框架对接-spec.md`。
- **R17 — pass**: design 路径存在（EXIT=0）: `docs/superpower/DESIGN/202609130033-moon_ua_parser_v02-框架对接-design.md`。
- **R18 — pass**: plan 路径存在（EXIT=0）: `docs/superpowers/plans/2026-09-13-moon_ua_parser_v02-框架对接.md`。
- **R19 — pass**: `moon_ua_parser_lib/src/ua_parser/pkg.generated.mbti` 存在（EXIT=0），`pub fn` 计数 = 4（parse/parse_browser/parse_device/parse_os，与 T-07 一致）。
- **R20 — na**: T-09 为只读收口核对任务，无 MoonBit 实现动作（提交仅 evidence 文档）；MoonBit agent 约定适用于实现类任务，本任务无可适用动作。

## 2. 验收命令逐行结果

| 行 | 命令（原样） | 原始结果（关键行） | 判定 |
|---|---|---|---|
| 行0a | `moon build --target native` | `Finished. moon: ran 7 tasks, now up to date (6 warnings, 0 errors)` / EXIT_BUILD=0 | **PASS** |
| 行0b | `cd moon_ua_parser_lib && moon check` | `Finished. moon: ran 5 tasks, now up to date (44 warnings, 0 errors)` / EXIT_CHECK=0（44=基线无新增） | **PASS** |
| 行0全量 | （不复跑）`moon test --target native` 等 | 引用 `docs/evidence/final-gate-mw-2026-09-13.log` §项3/项4: native `Total tests: 54, passed: 54, failed: 0.`；js 4+3+9+15=31/31 | **REFERENCE** |
| 行1 | `test -f docs/framework-selection.md && grep -c "来源" …` | 文件存在；`12`（≥6） | **PASS** |
| 行2a | `moon test -p moon_ua_parser_crescent`（plan 字面量） | `Total tests: 7, passed: 7, failed: 0.` / EXIT=0；字面量被 CLI 接受（正面登记） | **PASS** |
| 行2b | `moon test -p moon_ua_parser_mars`（plan 字面量） | `Total tests: 6, passed: 6, failed: 0.` / EXIT=0（含 `--> Get /probe` 集成测试输出）；字面量被接受 | **PASS** |
| 行3 | （引用）畸形 UA 失败取证 | final-gate §项6 + mw1:53 + mw2:57: `[moon_ua_parser] degraded user-agent parse: reason=empty_fallback ua_summary="…"` | **REFERENCE** |
| 行4a | `test -f moon_ua_parser_crescent/README.mbt.md` | EXIT_README_CRES=0 | **PASS** |
| 行4b | `test -f moon_ua_parser_mars/README.mbt.md` | EXIT_README_MARS=0 | **PASS** |
| 行4c | `grep -c "moon_ua_parser" moon_ua_parser_lib/README.mbt.md` | `10`（生态节含包名） | **PASS** |
| 行4d | `grep -n "middleware\|集成\|patch" .github/workflows/ci.yml` | 8 行命中（50/60/65/67/72/73/120/125，含 `Apply framework cache patches` 与 `Workspace build (middleware)` 步骤） | **PASS** |

**无 FAIL 行。** 完整原始输出见 closure 文档 `docs/evidence/mw-closure-2026-09-13.md` §一。

## 3. Pending / [LOCAL_DEAD_LINK] 清单（复核结论）

| # | 项 | 现状 | 触发 | 回补目标 |
|---|---|---|---|---|
| 1 | CI run 证据 | 分支未推送，无 run URL | 分支推送 GitHub（关注 job timeout-minutes=60） | 回补批核录 run URL |
| 2 | mooncakes 包页可检索 | 生产者未发布（T-08 实测 API 404；对照 crescent 200） | 回补批正式发布完成 | 回补批人工核录 |
| 3 | T-02 crescent 包页正文通道 | 已用 statistics.csv + search API 回补（§⑤，来源指针 12 条） | 回补批包页可渲染 | 回补批人工核录升级 |
| 4 | T-08 mooncakes 登录态 | 未实测（dry-run 失败早于认证环节） | 回补批 dry-run/正式发布首次触碰 | 届时失败才适用 [LOCAL_DEAD_LINK] |
| 5 | 跨单元终验 pending | feat/v02-perf-bench（918d864）未合并 | 性能基准合并 | 回补批复跑 T-07 全部门禁 |
| 6 | T-08 发版阻塞 | lib moon.mod:14 = "0.1.0"；registry 缺生产者模块；三包 dry-run 127 | 平台完备 T-09 版本收口（≥0.2.0）+ 中间件依赖升级 + 发布序 lib→middleware_core→crescent/mars | 回补批 dry-run→publish→A5 对账 |
| 7 | 框架缓存补丁上游追踪 | 补丁已提交 + ci.yml:67-73 应用；crescent 7/7 绿（行2 旁证） | crescent/async 上游新版本 | 回补批评估补丁可否移除（含 2 个 T-6 patch 格式 deferred minor） |
| 8（新增） | lib 44 条 Show→Debug 弃用告警 | 与 T-03 基线持平（行0 实测 44/0） | 上游 core 移除 Show 宽限期→升 error | 回补批/平台完备单元清理 |
| 9（新增） | 全量 native 首跑静默退出 | T-07 项3 未定位（重试即全绿，环境事实） | 回补批再跑全量 native | 后台+轮询+一次自动重跑协议 |

## 4. 提交

- **Commit SHA: `c4fd9e5`**（`T-09: unit closure reconciliation — mw-closure doc + final-gate/publish-dryrun evidence logs`）
- 提交前暂存集（`git diff --cached --name-status`，逐条核对）:
  - `A  docs/evidence/final-gate-mw-2026-09-13.log`（174 行）
  - `A  docs/evidence/mw-closure-2026-09-13.md`（184 行）
  - `A  docs/evidence/publish-dryrun-mw-2026-09-13.log`（1106 行）
  - 合计 3 files changed, 1464 insertions(+)，0 deletions, 0 modifications ✓
- 提交后工作树: 仅剩其他单元既有 untracked 文档（DESIGN/PRD/其他单元 SPEC+plan），未触碰。

## 5. Concerns

1. **行0 时长偏差（已登记，不计失败）**: 约 3 分钟（超 ~90s 预期；命令自动转后台后续跑至完成，EXIT=0）。归因 = T-08 dry-run 在 `_build/publish/` 的工件致构建缓存部分失效（`ran 7 tasks`，非 "no work to do"）。回补批重跑门禁时建议预留该余量。
2. **wasm 依旧本地不可用**: 登记预期，行2 未触碰 wasm（默认 native）；CI 门禁覆盖。
3. **发版链阻塞为跨单元依赖**: 本单元「已交付待发版」结论依赖 #6（平台完备 T-09 收口）先清空；在收口前 mooncakes 相关项（#2/#4）物理不可推进。
4. **行4d grep 命中行均来自 "middleware"/"patch" 词**: `集成` 一词在 ci.yml 无独立命中行（增量步骤注释为英文）；不影响验收（CI 步骤命中成立，8 行），如实登记。
