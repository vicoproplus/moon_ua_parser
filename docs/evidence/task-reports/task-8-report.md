# Task T-08 报告 — mooncakes 发版（预期阻塞登记 + dry-run 实测）

日期: 2026-09-13 | 会话 worktree: `F:\moonbit比赛\moon_ua_parser_wt_framework` | branch `feat/v02-framework-middleware`
状态: **DONE（阻塞登记型完成——按控制器预置事实，前置断言不通过即本任务的预期产物，未执行任何真实发布）**

## 1. 前置断言（步骤 1）

```
$ grep -n "version" moon_ua_parser_lib/moon.mod
14:version = "0.1.0"
```

结论: `moon_ua_parser_lib/moon.mod:14` → version = **0.1.0**；0.1.0 < 0.2.0 → 平台完备 T-09 未收口 → **前置断言不通过（与控制器预置事实一致，属预期结果）**。阻塞登记落盘如下（第 3 节）。正式 `moon publish` 未执行、被禁止执行。

## 2. 逐包 dry-run 结果表（步骤 2，E6 实测）

CLI: moon 0.1.20260904 (94521db 2026-09-04)；dry-run 旗标字面量经 `moon publish --help` 确认为 `--dry-run`（帮助原文 "Do not actually run the command"）。每次运行外层 `timeout 60` 护栏，三包均正常退出、无卡死、护栏未触发。原始输出（含退出码）已逐包分节落盘: `docs/evidence/publish-dryrun-mw-2026-09-13.log`。

| 包 | 命令 | 退出码 | 结果 | 失败点（原始输出摘录） |
|---|---|---|---|---|
| moon_ua_parser_middleware_core | `cd moon_ua_parser_middleware_core && moon publish --dry-run` | 127 | FAIL | 提取包依赖解析: `Failed to resolve registry dependency 'vicoproplus/moon_ua_parser' ... module was not found in the registry`（缺 1 个生产者模块） |
| moon_ua_parser_crescent | `cd moon_ua_parser_crescent && moon publish --dry-run` | 127 | FAIL | 同上 + `vicoproplus/moon_ua_parser_middleware_core`（缺 2 个生产者模块） |
| moon_ua_parser_mars | `cd moon_ua_parser_mars && moon publish --dry-run` | 127 | FAIL | 同上 + `vicoproplus/moon_ua_parser_middleware_core`（缺 2 个生产者模块） |

三包共同形态: 本包 zip 打包成功（`_build/publish/vicoproplus-<pkg>-0.1.0.zip`）→ 本包 moon check 通过（44 warnings, 0 errors）→ 提取包 moon check 在依赖解析阶段失败。失败早于任何登录/凭证交互。

失败归因交叉验证（证据日志 [5] 节）:
- 排除「本地 index 过期」: mooncakes index 最后提交 2026-09-13 10:15:03 +0800（当日）；第三方依赖（bobzhang/crescent@0.11.1 等）全部解析成功。
- 排除「上游已发布、仅本地未同步」: 线上 API 直测 `GET https://mooncakes.io/api/v0/modules/vicoproplus/moon_ua_parser` → HTTP 404；`.../vicoproplus/moon_ua_parser_middleware_core` → HTTP 404；对照 `.../bobzhang/crescent` → HTTP 200（端点形状有效）。
- 排除「凭证/登录态」: 三包 dry-run 全程未出现认证提示或凭证报错。

## 3. 阻塞登记块（步骤 1 产物）

```
[阻塞登记 — B4/T-08 mooncakes 发版（依赖衔接点）]
- 状态:     BLOCKED（前置断言不通过 = 预期结果；正式发布禁止）
- 触发条件: 平台完备 T-09 版本收口合并
- 负责人:   vicoplus
- 恢复动作: 版本收口后重跑本任务
- 目标:     回补批
- 断言记录: moon_ua_parser_lib/moon.mod:14 → version = "0.1.0"，0.1.0 < 0.2.0
- 补充实测（2026-09-13 dry-run 证据）: 三包 dry-run 统一失败于 registry 缺上游生产者模块
  （vicoproplus/moon_ua_parser、vicoproplus/moon_ua_parser_middleware_core，线上 API 404 实证），
  与版本未收口同源；回补批顺序: T-09 收口（lib ≥0.2.0）→ 发布 moon_ua_parser →
  发布 moon_ua_parser_middleware_core → 重跑本任务 dry-run（届时才可能触及登录态）→ 全绿后 A5 对账。
```

## 4. 元数据预检（R3 适用性说明 + 静态表）

R3 两个分支均未触发:
- 「dry-run 全绿 → A5 对账预检」: 不适用——dry-run 未到达元数据/包页校验环节（更未到包页）。
- 「凭证失败 → [LOCAL_DEAD_LINK — 触发=mooncakes 登录态确认]」: 不登记——失败点在依赖解析，早于任何认证环节，登记凭证类 DEAD_LINK 会是错误归因。mooncakes 登录态因此**仍为未实测项**，留待回补批。

实际失败类别 = 依赖解析失败（上游生产者未发布），逐包具体错误已按「可行动证据」要求原样落盘（见第 2 节与证据日志）。作为回补批输入，补充静态文件级元数据预检（非 A5 正式对账；A5 需 dry-run 全绿后与 mooncakes 包页逐字段对账）:

| 字段 | middleware_core | crescent | mars | 静态检查 |
|---|---|---|---|---|
| name | vicoproplus/moon_ua_parser_middleware_core | vicoproplus/moon_ua_parser_crescent | vicoproplus/moon_ua_parser_mars | pass（格式 user/module） |
| version | 0.1.0 | 0.1.0 | 0.1.0 | pass（回补批需按发布计划复核目标版本） |
| readme | README.mbt.md | README.mbt.md | README.mbt.md | pass（三文件均存在于包目录） |
| repository | https://github.com/vicoproplus/moon_ua_parser | 同左 | 同左 | pass（三包一致） |
| license | Apache-2.0 | Apache-2.0 | Apache-2.0 | pass（根目录 LICENSE 存在） |
| keywords | user-agent, middleware, ua-parser, http | user-agent, middleware, crescent, http | user-agent, middleware, mars, http | pass（均非空） |
| description | 均已填写且指向各包职责 | 同左 | 同左 | pass |
| deps（registry 可解析性） | vicoproplus/moon_ua_parser@0.1.0（**404，dry-run 实测失败点**） | bobzhang/crescent@0.11.1 ✓ / moonbitlang/async@0.20.3 ✓ / vicoproplus/moon_ua_parser@0.1.0 **404** / vicoproplus/moon_ua_parser_middleware_core@0.1.0 **404** | mizchi/mars@0.3.12 ✓ / moonbitlang/x@0.5.5 ✓ / mizchi/x@0.6.1 ✓ / moonbitlang/async@0.21.3 ✓ / vicoproplus 两模块 **404** | **fail（仅生产者依赖缺失；本批无包内元数据字段错误）** |

## 5. Rubric 自审

- R1 步骤 1 断言执行并记录（grep 输出 + 0.1.0 < 0.2.0 结论），阻塞登记落盘: 触发条件、负责人、恢复动作、目标批次 — **pass**: grep 原始输出 `14:version = "0.1.0"` + 结论见本报告第 1 节与证据日志 [1] 节；阻塞登记四要素齐全（第 3 节）。
- R2 三包 dry-run 逐一实测，原始输出（含退出码）以文件工具落盘、逐包分节，失败输出如实落盘 — **pass**: `docs/evidence/publish-dryrun-mw-2026-09-13.log` [2][3][4] 节，各含完整原始输出 + `EXIT_CODE=127`。
- R3 dry-run 全绿→A5 / 凭证失败→[LOCAL_DEAD_LINK] — **pass（按第三类事实处置）**: 两分支前置条件均未出现（失败=依赖解析、早于认证）；已如实记录逐包具体错误（可行动证据）+ 静态元数据预检（第 4 节），并在证据日志 [5][6] 节写明不登记 [LOCAL_DEAD_LINK] 的归因依据。
- R4 不执行真实发布；不改任何文件（除 evidence log）；`git status` 干净（除该 log） — **pass**: 全程仅 dry-run（`--dry-run` 旗标）；仅新增证据日志与本报告（报告位于 .superpowers/sdd 任务目录）；`_build/publish/` 工件被 gitignore `/_build/` 覆盖；终态 `git status --porcelain` 无新增条目（见下）。
- R5 报告含逐包 dry-run 结果表 + 阻塞登记块 + 元数据对账表（若适用） — **pass**: 第 2、3、4 节。

### 全局约束（本任务范围内判定）

- R6 只消费库公开 API / 不改库公开面 — **na**: 本任务未触碰任何源码或接口文件，仅执行检查与 dry-run。
- R7 降级语义 — **na**: 无代码改动（T-03 范围）。
- R8 CI 增量合入 — **na**: 未改 ci.yml。
- R9 框架版本区间 — **na**: 未改版本区间（moon.mod 为既有文件，本任务零改动）。
- R10 W1 共享文件单点 — **na**: 未触碰 workspace 清单 / ci.yml / 他包目录。
- R11 V2 配置 dry-run — **na**: 未改配置；dry-run 期间隐式触发的构建全部通过（44 warnings, 0 errors）。
- R12 D1 集成测试归因纪律 — **na**: 无集成测试执行；dry-run 失败已按「归因→证伪→结论」处理（证据日志 [5] 节）。
- R13 E2 moon 工具链版本 — **pass**: 实测 `moon version` = 0.1.20260904 (94521db 2026-09-04)，与 ci.yml 锁定一致（证据日志 [0] 节）。
- R14 E4 验收命令相对路径 — **pass**: 证据日志记录的命令形态为 `cd <包目录> && moon publish --dry-run`（包目录相对、命令相对）；会话执行因 shell cwd 重置改用绝对 cd，命令本体不变。
- R15 溯源规则 — **pass**: 所引版本均溯源 `*/moon.mod`（仓库实际）与 mooncakes 线上 API 响应原文，无凭记忆填写。
- R16-R19 spec/design/plan/mbti 权威文件 — **na**: 本任务权威来源为 task-8-brief（控制器指定）；未消费上述文件内容做决策。
- R20 moonbit-agent-guide — **na**: 未编写 MoonBit 代码。

judged: 20 / 20（pass 6 / na 14 / fail 0）

## 6. 疑虑与遗留

1. **mooncakes 登录态仍未实测**: dry-run 在认证环节之前失败，E6 的登录态子项保持未知。回补批重跑 dry-run 时将首次触及（届时若失败，才适用 [LOCAL_DEAD_LINK — 触发=mooncakes 登录态确认]）。
2. **退出码 127 的语义**: 为 moon.exe 原生返回值（命令确实执行并失败，非 shell「command not found」——输出完整存在）。已按实测值如实记录，未做归一化。
3. **库 moon.mod 内嵌注释依赖**: `vicoproplus/moon_ua_parser@0.1.0` 依赖与 lib 收口版本（≥0.2.0）的联动属 T-09 范围；回补批重跑前需确认三包 import 已指向收口后版本，否则 dry-run 会再次失败于版本不匹配。
4. **证据日志誊录**: 日志以文件工具按捕获原文誊写（日志头部有誊录说明）；个别框线对齐空白可能存在非信息性微差，所有命令行、文件:行号、警告码、消息与退出码逐字保真。
5. 未提交（按红线）; evidence log 随 T-09 收口入库由控制器决定。
