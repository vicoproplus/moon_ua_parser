# Task T-02 Report — 框架选型证据采集与裁决

日期：2026-09-13 ｜ 分支：`feat/v02-framework-middleware`（未切分支）｜ 交付物：`docs/framework-selection.md`（未提交，留待 controller 复核后提交）

## Rubric 裁决（R1–R8）

- **R1 pass** — `docs/framework-selection.md` 存在，含六候选对比表（40/30/20/10 权重列 + 每候选加权计算式）、裁决结论（§④）、来源指针（§⑤）；实测 `grep -c "来源"` = **12** ≥ 6。
- **R2 pass** — 入选前二 crescent/mars 走读完成：注册/上下文/日志 API 签名均带 file:line（快照 `F:\Temp\fw-probe\` + 上游 SHA d99287a / ff4485e），见选型文档 §②。
- **R3 pass** — 每候选三判据（注册回调/上下文挂载/日志通道）逐项 ✔/△/✗ 判定表见 §③；Halo、moonapi 记录否决理由（无日志通道 + 上下文弱/封闭）；crescent 的 △ 旁路（request_id per-request map、res.headers 扩展）如实记录并计入 API 兼容分（6.3）。
- **R4 pass** — 加权前二入选 + 包名字面量逐字：`moon_ua_parser_crescent`、`moon_ua_parser_mars`；每候选四项得分与计算式可复核（§①，舍入约定已注明：显示值加权，全精度复算差 ≤ 0.02，排名不变）。
- **R5 pass** — U1 实测：**可得**。两通道：包页"最新版本下载量"数字（5/6 取得）+ registry `/api-new/v0/modules/statistics?raw=true` → `statistics.csv` 全模块累计下载（6/6 取得）。详见 §⑦。
- **R6 pass** — 六候选 mooncakes 包名与 GitHub 仓库逐字登记（§⑤ 表 + 逐行指针清单），每行带 URL/registry 指针；全部包名/版本出自实测页面、search API 或 statistics.csv，无凭记忆项。
- **R7 pass** — 环境红线遵守记录在 §⑥：Bash 调用 13 次（含本验证），网络命令 12 条（GitHub API ×6、clone ×6、mooncakes curl ×6——API/curl 均批量）；每框架走读文件数 ≤ 6 ≤ 8；所有 Bash timeout ≤ 120 s、网络命令 --max-time ≤ 15。
- **R8 pass** — 唯一不可得项：`bobzhang/crescent` 包页正文 HTTP 两次抓取仅返回站点框架 → 显式记「包页正文不可得（该通道）」+ 回补（statistics.csv + search API），[LOCAL_DEAD_LINK] 登记于 §⑦；无静默假设。

### Global Constraints（对本证据任务的适用性）

- R9（只消费库公开 API / moon info 零 diff）：na — 本任务未改任何库代码，未运行构建；消费面按 brief 逐字（`parse`/`parse_browser`/`parse_os`/`parse_device`，pkg.generated.mbti:5-11）。
- R10（降级语义）：na — 属后续适配层任务；选型已按"取证记录落框架日志通道"要求将日志通道列为判据③。
- R11（CI 增量）：na — 未触碰 CI。
- R12（版本区间锁定）：partial-移交 — 本任务产出实测版本基线（crescent 0.11.1 / mars 0.3.12，§④），区间锁定与区间内集成测试由后续适配任务回填 spec。
- R13/R14/R15：na — 共享文件/dry-run/集成失败归因均非本任务范围。
- R16（moon 0.1.20260904）：na — 本任务未执行 moon 工具链（纯证据采集 + 文档），未违反。
- R17（验收命令相对路径）：pass — 仓库内命令均相对路径（`cd` worktree 后 `grep -c … docs/framework-selection.md`）。
- R18（溯源）：pass — 见 R6。
- R19/R20/R21（spec/design/plan 文档）：na — brief 第 3 行规定"需求唯一来源 = task-2-brief，禁止读整个 plan"；权重取 brief 第 42 行 D1 逐字。
- R22（库公开 API 文件）：na — 同 R9，按 brief 逐字引用，未改动。
- R23（moonbit-agent-guide）：na — 本任务未编写 MoonBit 代码。

## 裁决摘要

| 候选（mooncakes 包名） | 下载量40% | 活跃度30% | API兼容20% | 文档10% | 加权总分 | 排名 |
|---|---|---|---|---|---|---|
| Crescent（`bobzhang/crescent`） | 10.0 | 10 | 6.3 | 8 | **9.06** | 1 |
| mars（`mizchi/mars`） | 6.5 | 10 | 9.3 | 9 | **8.36** | 2 |
| moonapi（`Lfan-ke/moonapi`） | 6.7 | 9 | 4.0 | 7 | 6.88 | 3 |
| mbit（`RabitLogic/mbit`） | 5.1 | 6 | 9.7 | 9 | 6.68 | 4 |
| pony（`jaredzhou/pony`） | 2.2 | 6 | 7.0 | 6 | 4.68 | 5 |
| Halo（`wflixu/Halo`） | 2.0 | 2 | 4.7 | 7 | 3.04 | 6 |

权重应用：总分 = 0.4×下载量 + 0.3×活跃度 + 0.2×API兼容 + 0.1×文档（逐候选计算式见选型文档 §①）。计分口径：下载量 = statistics.csv 累计下载 ÷ 最大值(24 078)×10；活跃度 = pushed_at 距今分档；API 兼容 = 三判据均值（全部源码走读背书）。

**入选：Crescent + mars。包名字面量（逐字，供 spec §3 与全部 `<framework>` 占位回填）：`moon_ua_parser_crescent`、`moon_ua_parser_mars`。**

## 入选框架三 API 签名（file:line，快照 F:\Temp\fw-probe\ + 上游 SHA）

**crescent**（HEAD d99287ae409d198e1f7c1fd606e4883188d97c02）：
- 注册：`pub fn App::use_middleware(self : App, middleware : Middleware, base_path? : String) -> Unit` — middleware.mbt:62；`struct Middleware(async (Event, MiddlewareNext) -> &Responder noraise)` — middleware.mbt:8（洋葱模型，middleware.mbt:76-102 执行链）
- 上下文：`Event{req,res,params}` 无原生存储（pkg.generated.mbti:86-90）；旁路 = `Event::request_id`（event.mbt:29）+ per-request map，或 `HttpResponse::header`（core/pkg.generated.mbti:85）header 扩展
- 日志：无框架 logger；内部输出汇 `&Logger`（core/pkg.generated.mbti:40/174），官方中间件仅 rate_limit/request_id/security_headers（middleware/pkg.generated.mbti:9-13）→ 适配层取证走 @logger/stderr

**mars**（HEAD ff4485e0309a8532d03002eb588ab06dcd252848）：
- 注册：`pub fn Server::middleware(self : Server, handler : Handler) -> Unit` — src/mars.mbt:61；`struct Handler(async (Context) -> Unit)` — src/pkg.generated.mbti:107
- 上下文：`Context::set(self, key : String, value : String)` — src/context.mbt:64；`Context::get` — src/context.mbt:70；`Context.vars : Variables`（JSON 值，`Variables::set[V : Var]`，src/pkg.generated.mbti:146-154）
- 日志：`pub fn logger(_options? : LoggerOptions) -> @mars.Handler` — src/middleware/logger.mbt:114；`logger_simple` — logger.mbt:162；`log_response` — logger.mbt:132；自身即示范挂载：`ctx.set("_log_start", …)` — logger.mbt:122

## U1 实测结果

**可得**：① 包页展示最新版本下载量（mars 6K / moonapi 532 / pony 62 / Halo 32 / mbit 24）；② registry statistics.csv 累计下载（crescent 24 078 / moonapi 16 201 / mars 15 708 / mbit 12 263 / pony 5 250 / Halo 4 853，计分采用此口径）。**[LOCAL_DEAD_LINK] 登记**：`https://mooncakes.io/docs/bobzhang/crescent` 包页正文 HTTP 渲染不可得（两次尝试，仅站点框架），已经 statistics.csv + search API 回补；后续如需页面数据可回补。无候选触发整体「不可得 + 降权」条款。

## 命令预算

Bash 调用 13 次（≤ 20）：网络命令 12 条（GitHub API curl ×6 于 1 次批量调用、`git clone --depth 1` ×6 于 1 次批量调用、mooncakes curl ×6：3 探测 + statistics.zip + search kw + 页面抓取经 WebFetch 工具不计 Bash）；本地 grep/find/ls 5 次。每次 Bash timeout ≤ 120000 ms，curl 均 `--max-time ≤ 15`。第三方源码仅存于 `F:\Temp\fw-probe\`（系统临时），未写入仓库。

## 假设与关注点

1. **舍入**：对比表按"得分先舍入到 0.1 再加权"展示；全精度复算差 ≤ 0.02（mars 8.37 / moonapi 6.89 / pony 4.67 / Halo 3.05），**排名与入选结论不变**，已注明于选型文档 §①。
2. **crescent 包名**：mooncakes 存在两个 crescent 命名空间（`bobzhang/crescent` 0.11.1 与 `hnlyxiaobing/crescent` 0.10.7）；以 search API `repository=moonbit-community/crescent` 判定 `bobzhang/crescent` 为官方包（bobzhang = MoonBit 核心开发者账号），计分仅计官方包。适配层 `moon add` 时应使用 `bobzhang/crescent`。
3. **crescent 挂载为旁路**：Event 无原生气可挂存储，适配层需 request_id 旁路表或 header 扩展；该成本已反映在其 API 兼容分（6.3）而非否决（brief 明示 per-request map/header 扩展为可接受形态）。
4. **页面下载量与 CSV 口径差异**：包页数字≈最新版本下载量，CSV 为模块累计；统一采用 CSV 口径计分，页面数字仅旁证。
5. 交付未提交（按指示留待 controller 复核）；仓库内新增仅 `docs/framework-selection.md` 一个文件。
