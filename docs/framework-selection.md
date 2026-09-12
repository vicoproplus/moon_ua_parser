# 框架选型证据与裁决（T-02 / v02 框架对接）

- 采集日期：2026-09-13（网络实测可用；mooncakes.io HTTP 200，GitHub API/clone 正常）
- 裁决权重（设计文档 D1 逐字）：mooncakes 下载量 40% / 维护活跃度 30% / 中间件 API 形态兼容性 20% / 文档完善度 10%
- 源码走读快照：系统临时 scratch `F:\Temp\fw-probe\<repo>`（Git Bash `/tmp/fw-probe`），`git clone --depth 1` 于 2026-09-13，未写入仓库
- 六候选清单（申报书「项目简介」逐字）：Crescent、mars（Hono 风格）、pony（Chi 风格）、mbit（Gin 风格）、Halo（Koa 洋葱）、moonapi（FastAPI 风格）——均为 mooncakes.io 上的 MoonBit Web 框架

---

## ① 候选对比表（四项得分 × 权重 + 加权计算式）

得分均为 0–10。计分公式（事前声明，逐项可复核）：

- 下载量 = 模块累计下载 ÷ 最大值（crescent 24 078）× 10。数据来源：mooncakes registry 统计接口 `https://mooncakes.io/api-new/v0/modules/statistics?raw=true`（zip 内 `statistics.csv`，2026-09-13 下载实测）。
- 活跃度 = GitHub `pushed_at` 距今分档：≤7 天→10；≤30 天→9；≤60 天→6；≤90 天→4；≤180 天→2；>180 天→1。数据来源：GitHub API `/repos/{owner}/{repo}`（2026-09-13 实测，未认证 6 次调用）。
- API 兼容 = 三子项均值（注册回调 / 上下文挂载 / 日志通道，各 0–10，判据见 §③，均出自源码走读）。
- 文档 = README/示例/文档站走读（判据随行注明）。

| 候选 | mooncakes 包名（逐字） | 最新版 | 累计下载 | 下载量40% | pushed_at（距今） | 活跃度30% | API兼容20% | 文档10% | 加权计算式 | 加权总分 | 排名 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Crescent | `bobzhang/crescent` | 0.11.1 | 24 078 | 10.0 | 2026-09-10（3天） | 10 | 6.3 | 8 | 0.4×10.0+0.3×10+0.2×6.3+0.1×8 | **9.06** | 1 |
| mars（Hono 风格） | `mizchi/mars` | 0.3.12 | 15 708 | 6.5 | 2026-09-12（1天） | 10 | 9.3 | 9 | 0.4×6.5+0.3×10+0.2×9.3+0.1×9 | **8.36** | 2 |
| moonapi（FastAPI 风格） | `Lfan-ke/moonapi` | 0.8.0 | 16 201 | 6.7 | 2026-08-30（14天） | 9 | 4.0 | 7 | 0.4×6.7+0.3×9+0.2×4.0+0.1×7 | **6.88** | 3 |
| mbit（Gin 风格） | `RabitLogic/mbit` | 0.3.0 | 12 263 | 5.1 | 2026-08-01（43天） | 6 | 9.7 | 9 | 0.4×5.1+0.3×6+0.2×9.7+0.1×9 | **6.68** | 4 |
| pony（Chi 风格） | `jaredzhou/pony` | 0.4.0 | 5 250 | 2.2 | 2026-08-04（40天） | 6 | 7.0 | 6 | 0.4×2.2+0.3×6+0.2×7.0+0.1×6 | **4.68** | 5 |
| Halo（Koa 洋葱） | `wflixu/Halo` | 0.6.0 | 4 853 | 2.0 | 2026-05-01（135天） | 2 | 4.7 | 7 | 0.4×2.0+0.3×2+0.2×4.7+0.1×7 | **3.04** | 6 |

补充实测（包页展示的"最新版本下载量"，与上表累计值口径不同，仅作旁证，来源均为各包页，见 §⑤）：mars 6K、moonapi 532、pony 62、Halo 32、mbit 24；crescent 包页正文经 HTTP 不可渲染（见 §⑦ U1）。

舍入约定：四项得分先四舍五入到 0.1 再加权（上表"加权计算式"即按显示值计算）；若以原始下载量全精度复算，总分差 ≤ 0.02（如 mars 8.37 / moonapi 6.89 / pony 4.67 / Halo 3.05），排名不变。

---

## ② 入选前二源码走读（file:line + 上游 commit SHA）

快照根：`F:\Temp\fw-probe\`（各仓库独立目录，HEAD SHA 如下）。

### 2.1 crescent — 快照 `F:\Temp\fw-probe\crescent`，上游 HEAD `d99287ae409d198e1f7c1fd606e4883188d97c02`（github.com/moonbit-community/crescent）

**中间件注册 API**（洋葱模型，接受 async 回调/闭包）：
- `pub fn App::use_middleware(self : App, middleware : Middleware, base_path? : String) -> Unit` — `middleware.mbt:62-72`（实现：`self.middlewares.push((base_path, middleware))`）；公开签名亦见 `pkg.generated.mbti:82`
- `pub(all) struct Middleware(async (Event, MiddlewareNext) -> &@core.Responder noraise)` — `middleware.mbt:8`；`pub(all) struct MiddlewareNext(async () -> &Responder noraise)` — `middleware.mbt:3`；类型声明亦见 `pkg.generated.mbti:104-106`
- 链式执行（洋葱）：`execute_middlewares(...) -> &Responder` — `middleware.mbt:76-102`，按 `base_path` 过滤后递归包裹 final handler

**请求上下文 API**：
- `pub(all) struct Event { req : @core.HttpRequest, res : @core.HttpResponse, params : Map[String, StringView] }` — `pkg.generated.mbti:86-90`。**无原生自定义键值存储**（字段封闭）
- 旁路挂载通道（brief 明示允许的两类形态）：① per-request map——`pub fn Event::request_id(self : Event) -> String?` — `event.mbt:29`（`pkg.generated.mbti:96`），配套官方 `request_id() -> Middleware` 中间件（`middleware/pkg.generated.mbti:11`）；② header 扩展——`HttpResponse.headers : Map[String, String]` 可变（`core/pkg.generated.mbti:74`）+ `HttpResponse::header(Self, String, String) -> Self`（`core/pkg.generated.mbti:85`）

**日志通道 API**：
- 框架**未提供** logger 中间件/门面；官方中间件仅 rate_limit / request_id / security_headers（`middleware/pkg.generated.mbti:9-13`）
- 内部诊断输出走 `&Logger` 参数（如 `HttpMethod::output(Self, &Logger)` `core/pkg.generated.mbti:40`；`StatusCode::output(Self, &Logger)` `core/pkg.generated.mbti:174`），即 moonbitlang/core 的 Logger 作为输出汇——适配层取证记录可经 `@logger`/stderr 落地，非框架约定通道

### 2.2 mars — 快照 `F:\Temp\fw-probe\mars.mbt`，上游 HEAD `ff4485e0309a8532d03002eb588ab06dcd252848`（github.com/mizchi/mars.mbt）

**中间件注册 API**（Hono 风格，接受 async 回调/闭包）：
- `pub fn Server::middleware(self : Server, handler : Handler) -> Unit` — `src/mars.mbt:61-63`（实现：`self.middlewares.push(handler)`）；公开签名亦见 `src/pkg.generated.mbti:133`
- `pub(all) struct Handler(async (Context) -> Unit)` — `src/pkg.generated.mbti:107`；`Server.middlewares : Array[Handler]` — `src/pkg.generated.mbti:127`

**请求上下文 API**（自定义键挂载，两套）：
- 字符串键：`pub fn Context::set(self : Context, key : String, value : String) -> Unit` — `src/context.mbt:64`；`pub fn Context::get(self : Context, key : String) -> String?` — `src/context.mbt:70`（公开签名 `src/pkg.generated.mbti:66/80`）
- JSON 值存储：`Context.vars : Variables`（`src/context.mbt:13`；`src/pkg.generated.mbti:53`），`pub fn[V : Var] Variables::set(Self, String, V) -> Unit` / `Variables::get(Self, String) -> Json?`（`src/pkg.generated.mbti:149-154`），`Var` trait 已实现 Bool/Double/String/Json（`src/pkg.generated.mbti:169-176`）
- 框架自身 logger 中间件即用此模式挂载：`ctx.set("_log_start", start.to_string())` — `src/middleware/logger.mbt:122`

**日志通道 API**：
- `pub fn logger(_options? : LoggerOptions) -> @mars.Handler` — `src/middleware/logger.mbt:114-116`（公开签名 `src/middleware/pkg.generated.mbti:113`）；`logger_simple() -> @mars.Handler` — `logger.mbt:162`（`pkg.generated.mbti:115`）；`log_response(ctx, status, options?) -> Unit` — `logger.mbt:132`（`pkg.generated.mbti:111`）；`pub(all) enum LogLevel` / `LoggerOptions{ level }` — `src/middleware/pkg.generated.mbti:410-422`。输出汇为 `println`（`logger.mbt:145/166`）

---

## ③ 可挂载性判定表（每候选；判据 = brief 三问，出处为源码走读）

| 候选 | ① 注册签名接受回调 | ② 上下文可挂自定义键 | ③ 可用日志/输出通道 | 判定 |
|---|---|---|---|---|
| Crescent | ✔ `use_middleware(Middleware)`，Middleware = async(Event, Next)->Responder（middleware.mbt:62/8） | △ 无原生存储；可经 `Event::request_id`（event.mbt:29）+ per-request map 或 `res.headers` 扩展旁路（brief 允许形态） | △ 无框架 logger；仅 `&Logger` 内部输出参数与 request_id 通道 | 可挂载（②③走旁路，成本记入适配层） |
| mars | ✔ `Server::middleware(Handler)`，Handler = async(Context)->Unit（src/mars.mbt:61） | ✔ `Context::set/get`（context.mbt:64/70）+ `vars : Variables` JSON 存储（pkg.generated.mbti:146-154） | ✔ `logger()`/`logger_simple()`/`log_response()`（logger.mbt:114/162/132） | 可挂载（三项全满足） |
| pony | ✔ `Router::use_mw(Middleware)`，Middleware = (Handler)->Handler（pkg.generated.mbti:400/347） | ✔ 类型化 `ExtStore`：`Context::set_ext/get_ext/try_get_ext`（pkg.generated.mbti:274/262/278） | ✗ mbti 无任何 log API | 可挂载（③缺失→适配层自带 stderr/@logger） |
| mbit | ✔ `Engine::use(Handler)`（core/mbit.mbt:224） | ✔ `Context::set(key, Json)`/`get`（core/context.mbt:582/588）+ 类型化 getter | ✔ 结构化 `Logger::debug..fatal` + `structured_logger() -> Handler`（core/logger_ext.mbt:173-225/284） | 可挂载（三项全满足；总分离 TOP2 差距来自活跃度/下载量） |
| Halo | ✔ `App::mount((Context, ()->Unit)->Unit)`（halo/pkg.generated.mbti:31） | △ 仅 `state : Map[String, String]` 公开字段（String 值，halo/pkg.generated.mbti:37），UaInfo 需 JSON 序列化塞入 | ✗ 无日志 API | **否决**：上下文仅 String map（弱）+ 无日志通道 + 上游停滞 135 天 |
| moonapi | ✔ `App::middleware(((Request)->Response)->(Request)->Response)`（pkg.generated.mbti:344） | ✗ `Context{ request, params }` 字段封闭（pkg.generated.mbti:426-429），无自定义键存储 | ✗ mbti 中 log 命中数为 0 | **否决**：无请求级挂载点且无日志通道，取证行无处落地 |

---

## ④ 加权裁决结论

**入选 2 个框架（加权前二）：Crescent、mars。**包名字面量逐字（小写、`moon_ua_parser_<framework>` 模式，后续任务按此建包，禁止改写）：

1. `moon_ua_parser_crescent`（对应 mooncakes 包 `bobzhang/crescent`，仓库 moonbit-community/crescent）
2. `moon_ua_parser_mars`（对应 mooncakes 包 `mizchi/mars`，仓库 mizchi/mars.mbt）

裁决理由（无事后合理化，全部可回溯 §①②③）：
- 两框架包名/下载/活跃度证据齐备且为前二（9.06 / 8.36）；mars 三项挂载判据全满足，crescent 以下载量第一 + 活跃度并列第一入选，其 ②③ 旁路成本（request_id per-request map、@logger 取证）在适配层任务中显式处理。
- moonapi（6.88）与 mbit（6.68）分列 3/4：moonapi 因挂载判据 ②③ 不满足被否决（§③）；mbit API 最优（9.7）但活跃度（43 天）与下载量（12 263）拖累加权分，未入选，保留为后续备选。
- pony（4.68）、Halo（3.04）差距明显；Halo 另因维护停滞被否决（§③）。
- 版本区间锁定基线（供后续 spec §3 回填）：crescent `0.11.1`、mars `0.3.12`（均 2026-09 实测最新发布）。

---

## ⑤ 每候选来源指针清单

| 候选 | mooncakes 包页 | GitHub 仓库 | registry 统计指针 |
|---|---|---|---|
| Crescent | https://mooncakes.io/docs/bobzhang/crescent （包名 `bobzhang/crescent` v0.11.1 经 search API 逐字确认；页面正文 HTTP 不可渲染，见 §⑦） | https://github.com/moonbit-community/crescent （search API `repository` 字段逐字） | statistics.csv 行 `crescent,bobzhang/crescent,0.11.1,24078,…`；旁证 `hnlyxiaobing/crescent,0.10.7,24188`（同名框架的另一发布命名空间，未计入本包） |
| mars | https://mooncakes.io/docs/mizchi/mars/ （v0.3.12，页面示 6K 下载，"Updated yesterday"） | https://github.com/mizchi/mars.mbt （包页 repository 逐字） | statistics.csv 行 `mars,mizchi/mars,0.3.12,15708,…` |
| pony | https://mooncakes.io/docs/jaredzhou/pony （v0.4.0，页面示 62 下载） | https://github.com/jaredzhou/pony （包页 repository 逐字） | statistics.csv 行 `pony,jaredzhou/pony,0.4.0,5250,…` |
| mbit | https://mooncakes.io/docs/RabitLogic/mbit （v0.3.0，页面示 24 下载；文档站 https://skills.mooncakes.io/docs/RabitLogic/mbit@0.3.0 ） | https://github.com/RabitLogic/mbit （包页 repository 逐字） | statistics.csv 行 `mbit,RabitLogic/mbit,0.3.0,12263,…` |
| Halo | https://mooncakes.io/docs/wflixu/Halo （v0.6.0，页面示 32 下载） | https://github.com/wflixu/Halo （包页 repository 逐字） | statistics.csv 行 `Halo,wflixu/Halo,0.6.0,4853,…` |
| moonapi | https://mooncakes.io/docs/Lfan-ke/moonapi （v0.8.0，页面示 532 下载） | https://github.com/Lfan-ke/moonapi （包页 repository 逐字） | statistics.csv 行 `moonapi,Lfan-ke/moonapi,0.8.0,16201,…` |

统计接口来源：`https://mooncakes.io/api-new/v0/modules/statistics?raw=true`（GET 返回 zip，内含 `statistics.csv`，列为 name,module,version,downloads,?,timestamp；2026-09-13 下载解析）。GitHub 活跃度来源：`https://api.github.com/repos/{owner}/{repo}`（2026-09-13，每仓库 1 次，共 6 次：pushed_at/star/open_issues，原始值见 §① 表与 task-2-report）。

逐候选来源指针（每行一条，防漏登）：
- Crescent 来源：mooncakes 包页 https://mooncakes.io/docs/bobzhang/crescent + search API `/api-new/v0/search?kw=crescent`（name/version/repository/downloads=476）+ GitHub https://github.com/moonbit-community/crescent + statistics.csv `bobzhang/crescent,0.11.1,24078`。
- mars 来源：mooncakes 包页 https://mooncakes.io/docs/mizchi/mars/ + GitHub https://github.com/mizchi/mars.mbt + statistics.csv `mizchi/mars,0.3.12,15708`。
- pony 来源：mooncakes 包页 https://mooncakes.io/docs/jaredzhou/pony + GitHub https://github.com/jaredzhou/pony + statistics.csv `jaredzhou/pony,0.4.0,5250`。
- mbit 来源：mooncakes 包页 https://mooncakes.io/docs/RabitLogic/mbit + 文档站 https://skills.mooncakes.io/docs/RabitLogic/mbit@0.3.0 + GitHub https://github.com/RabitLogic/mbit + statistics.csv `RabitLogic/mbit,0.3.0,12263`。
- Halo 来源：mooncakes 包页 https://mooncakes.io/docs/wflixu/Halo + GitHub https://github.com/wflixu/Halo + statistics.csv `wflixu/Halo,0.6.0,4853`。
- moonapi 来源：mooncakes 包页 https://mooncakes.io/docs/Lfan-ke/moonapi + GitHub https://github.com/Lfan-ke/moonapi + statistics.csv `Lfan-ke/moonapi,0.8.0,16201`。

---

## ⑥ 命令预算与走读文件数记录

**命令预算**（红线 ≤ 20）：
- Bash 调用合计 **11** 次；其中网络命令合计 **12** 条：GitHub API curl ×6（1 次批量调用）、`git clone --depth 1` ×6（1 次批量调用）、mooncakes 接口 curl ×6（3 探测 + 1 statistics.zip 下载 + 1 search，全部 `--max-time ≤ 15`）。其余 5 次为本地 grep/find/ls。
- 每次 Bash 调用 timeout ≤ 120000 ms（实测最高为 clone 批量 120 s 上限内完成）。

**每框架走读文件数**（红线 ≤ 8/框架，含 Read 全文与 grep 定位检视）：
- crescent：5（pkg.generated.mbti、middleware/pkg.generated.mbti、core/pkg.generated.mbti、middleware.mbt、event.mbt）
- mars：6（src/pkg.generated.mbti、src/middleware/pkg.generated.mbti、src/mars.mbt、src/context.mbt、src/middleware/logger.mbt、README.md）
- pony：1（pkg.generated.mbti）；mbit：3（core/mbit.mbt、core/context.mbt、core/logger_ext.mbt）；Halo：2（halo/halo 与 halo/http 的 pkg.generated.mbti）；moonapi：2（pkg.generated.mbti、moon.pkg）

**Clone SHA 登记**（深度 1，2026-09-13）：crescent `d99287a…`、mars.mbt `ff4485e…`、pony `f070ef7…`、mbit `32b9598…`、Halo `174d6b1…`、moonapi `5699f13…`（完整 SHA 见 §②及 task-2-report）。

---

## ⑦ U1 实测结论（mooncakes 下载量可获取性）

**结论：可得（两通道）。**
1. 包页通道：`https://mooncakes.io/docs/<user>/<pkg>` 服务端渲染含"最新版本下载量"数字，HTTP 可直接提取——5/6 候选实测取得（mars 6K、moonapi 532、pony 62、Halo 32、mbit 24）。
2. registry 统计通道：`/api-new/v0/modules/statistics?raw=true` 返回 zip 内 `statistics.csv`，含**全模块累计下载量**，六候选全部取得（§① 列"累计下载"即出于此，作为计分口径）。
3. 例外与回补登记：`bobzhang/crescent` 包页正文两次 HTTP 抓取（带版本号与不带）均只返回站点框架、无包数据——按 R5/R8 记「包页正文不可得（该通道）」，已通过 statistics.csv + search API（`/api-new/v0/search?kw=crescent` 返回 name/version/repository/downloads=476）完成回补，非静默假设；登记 [LOCAL_DEAD_LINK]：mooncakes 包页 `bobzhang/crescent` 的 HTTP 渲染问题（浏览器端可能正常，后续任务如需页面数据可回补）。
4. 降权记录：本任务最终**无候选**因下载量整体不可得而触发「不可得 + 降权（权重转入维护活跃度）」条款；crescent 的下载量计分采用 registry 累计口径，未降权。
