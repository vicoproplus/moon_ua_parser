# Task T-07 报告 — 整库集成验证（单元范围）

- 日期: 2026-09-13；moon `0.1.20260904 (94521db 2026-09-04)`
- 执行位置: worktree `F:\moonbit比赛\moon_ua_parser_wt_framework`，分支 `feat/v02-framework-middleware`（HEAD `fc26bd9`），未切分支、未 `git add`/`git commit`
- 证据日志: `docs/evidence/final-gate-mw-2026-09-13.log`（文件工具写入，含头部跨单元 pending 登记）
- 头部登记: **跨单元终验 pending — 触发=性能基准合并, 负责人=vicoplus, 目标=回补批**
- 总判定: **GREEN WITH REGISTERED EXCEPTIONS**

## 一、逐项结果表（7 项验证清单）

| # | 项目 | 命令（相对路径字面量） | 退出码 | 关键输出尾 | 判定 |
|---|------|------------------------|--------|------------|------|
| 1 | workspace 全构建 | `moon build --target native` | 0 | `Finished. moon: no work to do` | PASS（0 errors；缓存热，工作树与产物一致） |
| 2 | check | `moon check --target native` | 0 | `(44 warnings, 0 errors)` | PASS（0 errors；44 弃用告警与 T-03 基线 44 持平，无新增） |
| 3 | native 测试全量 | `moon test --target native`（后台+轮询） | 0 | `Total tests: 54, passed: 54, failed: 0.` | PASS（31+10+7+6=54 与预期构成逐包核对一致） |
| 4 | js 测试 | `moon test --target js -p <lib 各包>`（5 包逐个，后台+轮询） | 各包 0 | rules 4/4、differential 3/3、robust 9/9、semantics 15/15；ua_parser 本体 0 块 | PASS（js 合计 31/31） |
| 5 | 生成一致性 | `cd moon_ua_parser_lib && python ../scripts/gen_rules.py && python ../scripts/gen_tests.py && git diff --exit-code -- src/ua_parser/rules tests/differential` | 0 | 仅 LF/CRLF warning，无 diff 内容；`git diff --stat` 同路径为空 | PASS（字节级一致；M 标记为 autocrlf 行尾表现，已还原，工作树洁净） |
| 6 | smoke ×2 | `moon run moon_ua_parser_crescent/examples/ua_echo --target native`；`moon run moon_ua_parser_mars/examples/ua_echo --target native` | 0；0 | 三组 browser/os/device 结果 + `[moon_ua_parser] degraded user-agent parse: reason=empty_fallback ua_summary="SomethingWeNeverKnewExisted"` + `done: 4 requests dispatched (3 healthy, 1 degraded synthetic)` | PASS ×2（有界运行自行退出） |
| 7 | 生成物边界核对 | `git diff main...HEAD --stat -- uap-core/ scripts/gen_rules.py scripts/gen_tests.py` | 0 | 输出为空 | PASS（生成链未被中间件单元触碰） |

登记例外（非失败）:
- 项 4 中 crescent/mars 的 js 跳过为预期：`moon test --target js -p ...` 实测报 `Selected package(s) do not support target backend 'js': ... ([native, wasm])` / `([native])`，exit 127（moon.pkg `supported_targets` 决定）。
- wasm 本地未跑：moonrun 损坏为既有环境事实，登记「CI 门禁覆盖，本地跳过」。

## 二、验收标准 R1–R4 判定

- **R1 — 判定: pass**。7 项逐项执行全 PASS（含两项登记例外），命令+退出码+输出尾逐项落盘 `docs/evidence/final-gate-mw-2026-09-13.log`（文件工具写入），日志头部含跨单元 pending 登记原文。证据: 上表 + 日志 §项1–项7。
- **R2 — 判定: pass**。无测试/构建失败项；过程中唯一异常（项 3 第 1 次后台运行静默退出）已按 D1 归因记录为环境事实并在日志中如实登记（见「三、FAIL/异常与归因」）；验证者未修改任何代码/测试（仅还原了自身验证动作在盘上产生的行尾/未跟踪产物）。
- **R3 — 判定: pass**。日志含 moon 版本行 `moon 0.1.20260904 (94521db 2026-09-04)`，每项均记录相对路径命令字面量（`moon build --target native`、`moon check --target native`、`moon test --target native`、`moon test --target js -p ...`、`python ../scripts/gen_rules.py`、`moon run moon_ua_parser_crescent/examples/ua_echo --target native` 等）。
- **R4 — 判定: pass**。本报告含逐项 PASS/FAIL 表与总判定 `GREEN WITH REGISTERED EXCEPTIONS`。

## 三、FAIL 项与归因（D1）

无 FAIL 项。过程异常登记一条：

- 项 3（native 全量测试）第 1 次后台运行：moon 进程在编译/依赖检查阶段静默消失，日志仅 3 行 `.blackbox_test.c` 编译行、无 EXIT_CODE（临时快照留存于验证者临时目录，日志已如实记载）。
  - 归因: **环境事实**（本机后台任务/工具链静默退出，非本单元代码——同一命令、同一代码第 2 次完整跑通且 54/54 全绿；项 1/2 等其它 moon 命令同环境正常）。非上游依赖（依赖解析在两次运行中一致完成）。
  - 处置: 按「一次重试」规则原样重跑一次，结果全绿；未修改任何文件。

## 四、Rubric 全量自评（R1–R19）

| 项 | 判定 | 证据（一行） |
|----|------|--------------|
| R1 七项全绿+日志落盘 | pass | 上表 7/7 PASS；`docs/evidence/final-gate-mw-2026-09-13.log` 含头部 pending 登记 |
| R2 失败 D1 归因、只验不修 | pass | 无 FAIL；异常归因见本报告 §三；未改任何库/测试文件 |
| R3 moon 版本行+相对路径命令 | pass | 日志头部版本行；每项命令字面量为相对路径 |
| R4 逐项表+总判定 | pass | 本报告 §一/总判定 GREEN WITH REGISTERED EXCEPTIONS |
| R5 只用公开 API 四 pub fn、moon info 零 diff | pass | `moon info` exit 0，4 个已提交 `pkg.generated.mbti` 内容零 diff（eol-only 已还原）；`moon_ua_parser_lib/src/ua_parser/pkg.generated.mbti` 公开面=4 pub fn 未变 |
| R6 降级语义（空 UaInfo 续链+取证 `{ua_summary,reason}`） | pass | 两 smoke 均见 `reason=empty_fallback ua_summary="..."` 取证行 + 挂载空结果 status 200 续链（`handler saw browser= os= device=`）；spec §3 契约行 |
| R7 CI 只增量合入 | pass | `git diff main...HEAD --stat -- .github/workflows/ci.yml` = 46 insertions / 0 deletions |
| R8 框架版本区间锁定+区间内集成测试 | pass | crescent moon.mod 锁 `bobzhang/crescent@0.11.1`（README「Tested against crescent 0.11.x」）、mars 锁 `mizchi/mars@0.3.12`（README「Tested against mars 0.3.x」）；集成测试（crescent 7 + mars 6 块）在锁定版本上实跑通过（项 3） |
| R9 W1 共享文件单点+目录不重叠 | pass | `git diff main...HEAD --name-only` 按顶层目录分布：crescent 8 / mars 8 / middleware_core 6 / lib 1（仅 README.mbt.md）/ moon.work 1 / ci.yml 1 / scripts 2 / docs 6 / .gitignore 1，包目录互不重叠 |
| R10 V2 配置 dry-run | pass | T-01/T-06 既证（`docs/evidence/workspace-probe-2026-09-13.log` 在库）+ 本次项 1 全模块构建复跑覆盖通过 |
| R11 D1 归因纪律 | pass | 本报告 §三按「归因→定位→处置」记录，未先假设框架有错，未改代码 |
| R12 E2 工具链 0.1.20260904 | pass | 本机 `moon version`=0.1.20260904；ci.yml 安装行锁同一版本 |
| R13 验收命令全相对路径 | pass | 日志中每条命令均为相对路径字面量（绝对路径仅出现在输出引用中） |
| R14 库名/版本溯源 | pass | crescent/mars 版本溯源 moon.mod 实际依赖 + README 节 + spec/设计（中间件单元），未凭记忆填写 |
| R15 spec 文件存在且为规则/契约权威 | pass | `docs/superpower/SPEC/202609130033-moon_ua_parser_v02-框架对接-spec.md` 存在（§3 契约表被 R6 引用） |
| R16 design 文件存在 | pass | `docs/superpower/DESIGN/202609130033-moon_ua_parser_v02-框架对接-design.md` 存在 |
| R17 plan 文件存在 | pass | `docs/superpowers/plans/2026-09-13-moon_ua_parser_v02-框架对接.md` 存在 |
| R18 库公开 API 文件 | pass | `moon_ua_parser_lib/src/ua_parser/pkg.generated.mbti` 存在且经 `moon info` 复核零漂移 |
| R19 MoonBit agent 约定已读 | na | 本任务为只验证不实现（未写任何 .mbt），约定文件的实现前置不适用；约定文件存在于技能库 |

Coverage: 19/19 已判定（0 空缺）。

## 五、假设

1. 项 1 `no work to do` 视为 PASS：构建缓存由本分支前序任务建立，`moon build` 确认工作树与产物一致、exit 0；未用改文件方式强制重建（验证任务禁改文件）。
2. 项 5 生成后 `git status` 的 M 标记判为 autocrlf 行尾表现而非内容漂移：依据 `git diff --exit-code`/`--stat` 均为空；为不留验证足迹已 `git checkout --` 还原盘上行尾（内容未变）。
3. `moon info` 运行产生的 5 个未跟踪 `pkg.generated.mbti`（tests/examples 包此前无此文件）为本次验证副产物，已删除还原；已提交的 4 个 mbti 零内容 diff 才是 R5 的判定依据。
4. wasm 未重试：简报明示为既有环境事实（moonrun 损坏），登记 CI 覆盖；本会话未浪费时长复测。

## 六、关注点（concerns，不计失败）

1. 项 3 第 1 次后台运行静默退出原因未定位（无日志、无 core）：若回补批再遇全量 native 测试，建议沿用后台+轮询并对静默退出做一次自动重跑。
2. native 全量实测墙钟约 25-30 分钟（differential ~14 min + robust/semantics/黑盒等），长于简报的 10-15 分钟估计——回补批排期请按 30 分钟预算。
3. 本地 44 条弃用告警（`Show`→`Debug`）与基线持平，属 lib 侧技术债：若上游 core 移除 `Show` 弃用宽限将升级为 error，建议回补批顺带登记清理任务（本轮未动，符合「只验不修」）。
4. 跨单元终验仍 pending：性能基准分支 `feat/v02-perf-bench`（918d864）合并后需按头部登记回补全量终验。
