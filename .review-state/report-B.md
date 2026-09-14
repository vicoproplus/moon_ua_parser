# Code Review Report — moon_ua_parser v0.2 框架对接单元（Reviewer B：middleware_core / crescent / mars / 发布基建）

## Git State Verification（实核记录）

- `git status`：branch main，up to date with origin/main，HEAD=4ff2544 —— 与 STATE_CHECK 一致。
- **偏差**：STATE_CHECK 称「tracked 工作树干净」，实测 11 个 tracked 文件呈 modified（3 个 adapter 包 pkg.generated.mbti 在我范围内，另有 moon_ua_parser_lib 侧 8 个文件在另一 reviewer 范围）。逐文件核查 `git diff`：**内容级差异全部为空**，仅 CRLF 行尾伪差异（PF-06 现象，由 dry-run 门禁 GATE-2 的 `moon info`/gen 重写触发，gen.log EXIT_GEN_DIFF=0 证实内容幂等）。结论：STATE_CHECK 的「干净」在内容级成立，EOL 噪声为门禁副作用，无实质偏差。
- untracked 与描述一致（`.review-state/` + 若干 pkg.generated.mbti）。审查全程只读，未运行任何会写树的 moon 命令。

## Stage 1 — Spec Compliance

PASS。计划六条硬边界逐条落实：①crescent 薄层零内联（adapter.mbt:92-106 闭包仅 get_header→assemble→mount→sink→next()）；②双 pin 逐字（crescent moon.mod:31、mars moon.mod:34）；③helper 无框架 API 无 IO（moon.pkg 仅 import ua_parser）；④三重断言两包齐备（200 + 空 mount == empty_ua_info + 恰一条 `{ua_summary, reason}`）；⑤golden UA 全部标注 uap-core 快照 file:line（抽查 8 处全部命中）；⑥包测试 10/7/6 与 GATE-4 日志一致。规则符合≠行为等价回溯：全新包无改动前行为基线（diff 全新增，见 B11）。

### Rubric 判定

- **R1: pass** — core.mbt 无框架 import/无 IO/无全局可变状态（moon_ua_parser_middleware_core/moon.pkg 仅 1 个 import）；三分支各有锁定测试，GATE-4 `moon test -p moon_ua_parser_middleware_core` 10/10 EXIT=0（.review-state/gates/test-mw.log）。
- **R2: pass** — 截断边界测试 64/65/空串/80 字符（core_tests.mbt:190-280）；`REASON_PARSE_ERROR`/`REASON_EMPTY_FALLBACK` 与 forensics reason 逐测试断言对应（core_tests.mbt:151,175,207,275）。
- **R3: pass** — moon_ua_parser_crescent/adapter.mbt:92-106：闭包仅读 header→单次 assemble→mount→sink→next()，零组装/降级/取证逻辑（全部 `@middleware_core.` 调用）。
- **R4: fail（后半）** — 全字段类型化往返有测试（integration_test.mbt:84,110 结构全等断言）；但 **malformed/缺字段 JSON 的 `parse_mounted_ua_info`/`ua_info_from_json` 行为无任何直接测试**（integration_test.mbt 全文 7 个用例无一喂入畸形 JSON；"no middleware" 用例走的是 header 缺失分支而非 JSON 解析失败分支）。行为本身经逐 match 审查无 panic 路径（adapter.mbt:124-127 catch 全捕获；ua_info_from_json 全 match 返回 Option），缺的是 rubric 明文要求的测试锁定 → 记 Important Issue-4。
- **R5: pass** — mars/adapter.mbt:176-180 原生 `Var::String` 挂载零序列化；orphan rule 裁决记录于 mars/README.mbt.md:76-84（vendored env.mbt 证实 `Var` 仅实现 Bool/Double/String/Json，`UaInfo` 与 `Var` 分属外部包、adapter 包确实无法实现）。
- **R6: pass** — crescent integration_test.mbt:122-148 与 mars integration_test.mbt:321-336 三重断言逐条齐备；golden 标注（文件头 + 逐断言注释）经我抽查 8 处 uap-core 快照行号全部命中（test_ua.yaml:1020/8955/8961、test_os.yaml:710/3302/3309、test_device.yaml:398/80537/80542）。
- **R7: pass** — 每个框架 API 调用点对照 vendored 源码 file:line：`App::use_middleware`（.mooncakes/bobzhang/crescent/pkg.generated.mbti:82）、`Middleware/MiddlewareNext`（同文件:104-106）、`HttpRequest.get_header`/`HttpResponse.headers : Map[String,String]`（core/pkg.generated.mbti:49,72-74）、`Server::middleware`/`Handler`（.mooncakes/mizchi/mars/src/pkg.generated.mbti:133,107）、`Context.vars/header`（同文件:53,67）、`Variables::set/get`（同文件:149-154）、`Var` impl（src/env.mbt）、`logger_simple`→println（src/middleware/logger.mbt:162-168）、`App::dispatch`（crescent mbti:58）。同源三方全绿质询：实现/测试/mbti 的共同假设来源 = **vendored registry 源码 + uap-core 快照（均为外部事实源）**，非同源闭环。
- **R8: pass** — patch 头路径 `.mooncakes/bobzhang/crescent/*` 与 pin 匹配（vendored moon.mod version=0.11.1）；mizchi patch 头 `mizchi/x@0.6.1` 与 mars moon.mod:36 一致；README 含触发条件/作用/移除条件（§Why + §Upstream-tracking + 2026-09-13 recheck）；CI 顺序 fetch→patch→编译正确（ci.yml:84-90 `moon install` → `git -c core.autocrlf=false apply --check` → apply → 才进入 Static check）；我以 `git apply --check --reverse` 双 patch 验证本地缓存已应用且匹配。保留项见 Minor Issue-6/7。
- **R9: pass** — moon.work 4 成员（`grep -c "./moon_ua_parser" moon.work` = 4）；三包 moon.mod 名称/版本互一致，依赖 `vicoproplus/moon_ua_parser@0.2.0` + `middleware_core@0.1.0` 一致；README 安装命令与包名逐字一致。
- **R10: pass** — publish-manual.yml:70-79 凭据经 base64+env 解码落文件、不回显（GitHub secret 掩码 + 无 echo）；隔离副本发布理由有注释（:84-95，workspace 上下文 verify 拉未打补丁 crescent）；发布版本即模块目录 moon.mod（0.1.0，run 34762686652 记录于 mw-closure 第八节）。
- **R11: pass（实质）/ 门禁缺口记 Issue-2** — 抽查三个 adapter 包已提交 pkg.generated.mbti 与 `moon info` 重生成输出内容级一致（`git diff` 零内容差异，仅 EOL 警告）；但 gen.log 的 EXIT_MBTI_DIFF=0 **并不覆盖 workspace 全体**——run-gates.sh:28-34 与 ci.yml 的 mbti 漂移门 cwd 均在 moon_ua_parser_lib，pathspec 匹配不到兄弟目录（R11 括号内「覆盖 workspace 全体」的声称失实），adapter mbti 无常设门禁。
- **R12: pass** — headers mount→下游 handler/客户端（测试断言 res.headers 与 handler 读回）；forensics sink→`console_forensics_sink`（println，adapter.mbt:74-78/68-72）或注入闭包（测试 captured `Ref[Array]`）；degraded→空 mount 即降级证据（crescent README:91-93 记载无日志通道时的替代观测）；sink 可注入且默认实现明确。
- **R13: pass** — 两示例无密钥、无外网副作用（crescent 走内存 `App::dispatch`，mars 走 127.0.0.1:0 回环且 `defer srv.close()` 有界）；README 各有一行运行命令；moon.pkg `supported_targets = "-all+native"` 与文档 `--target native` 一致；运行证据 docs/evidence/mw1/mw2-example-2026-09-13.log 在仓。
- **R14: pass** — 失败路径 owner 分工写明于两 adapter 文件头（语义归 helper、adapter 只透传，零内联）；集成测试锁定（两包 malformed 用例断言 200 + 空 mount + 恰一条取证）。
- **R15: pass — 已按条目执行**：范围外新发现 4 条 Important + 3 条 Minor 已全部记入 Issues（编号 1-8）（均为 rubric 未覆盖或 rubric 声称失实类）。

### Strengths

- 分层架构执行严格：`assemble` 纯函数面把全部降级语义收进 helper，两个 adapter 的闭包体各只有 4 行职责调用——薄层纯度经逐行核实无违例。
- 证据纪律罕见地好：golden UA 逐条标注快照 file:line 且我抽查 8 处全部命中；`FALLBACK_FAMILY` 常量注释点名库源码 engine.mbt:33-65 + uap-core 三域金样本 + 运行时验证三重出处（我复核 engine.mbt 属实）；框架 API 走读记录（docs/framework-selection.md §②）与 vendored 源码逐点吻合。
- 跨边界权威意识强：mars 头部注释连「Context::header 是精确大小写查找、mizchi/x 传输层会小写化」这种隐性契约都给出了上游 file:line（我复核 context.mbt:58-60 与 x/http_native.mbt:538 属实），并配了双拼写查找 + missing-header 降级测试。
- 诚实披露：adapter `supported_targets = "-all+native"` 附 wasm 无证据的明确理由；`UaError` 只读导致 Err 分支经 `assemble_error` 测试的限制写进 API 文档；publish 沙箱缺陷、CDN 403、moonrun 补丁全部留痕。
- mars 集成测试走真实 TCP 回环全链路（含 raw socket 绕开客户端默认 UA 的细节处理），crescent 用框架官方 test_client——零测试替身，无桩面臆造。

### Issues

**Critical**（无）

**Important**（应修）：

1. **CI 从不运行 middleware_core 的 10 条单元测试** — `.github/workflows/ci.yml:187-192`「Middleware integration tests」只跑 `-p moon_ua_parser_crescent` 与 `-p moon_ua_parser_mars`；「Workspace build (middleware)」（:179）只 build 不 test；lib 的 native/js/wasm 测试步 working-directory 均为 moon_ua_parser_lib。后果有加重情节：`REASON_PARSE_ERROR`/`assemble_error` 分支在 CI 中**零执行**——真实 parse 当前从不返回 Err，两包集成测试只覆盖 empty_fallback 分支，Err 分支唯一锁定点是本地才跑的 core_tests.mbt:167-182。这违反测试门禁「Enforced」层（模板第 6 项）。修复：该步骤加一行 `moon test --target native -p moon_ua_parser_middleware_core`（本地 GATE-4 已证明该命令可跑且 10/10 绿）。
2. **mbti 零漂移门不覆盖三个 adapter 包，且 R11 的覆盖声称失实** — ci.yml「Interface drift check」与 run-gates.sh:28-34 都在 moon_ua_parser_lib 子目录执行 `git diff --exit-code -- '*.mbti' '**/*.mbti'`，pathspec 无法匹配兄弟目录的 moon_ua_parser_{middleware_core,crescent,mars}/pkg.generated.mbti。这三个文件是已发布到 mooncakes 的公共 API 快照，漂移将无人拦截。本次我手工抽查三包内容级一致，现状干净，但缺口是结构性的。修复：在 workspace 根增加一步 `moon info` + `git diff --exit-code -- '**/*.mbti'`。
3. **两个 adapter README 的「Pre-release note: not yet published」已失实且随包发布上线** — moon_ua_parser_crescent/README.mbt.md:20 与 moon_ua_parser_mars/README.mbt.md:20 仍写「not yet published to the mooncakes registry」，而 fa86023 + 4ff2544（closure 第八节）记录四包全部在册、包页 200。README.mbt.md 是 mooncakes 包页正文——线上包页正向每个访问者断言「本包未发布、`moon add` 不可用」。修复：删除该注记或改为已发布状态。
4. **R4 后半未达标：malformed/缺字段 JSON 的 `parse_mounted_ua_info` 行为无测试** — 该函数是公共 API、直接消费外部世界的响应头值（客户端可喂任意字符串），rubric 明文要求「malformed/缺字段 JSON 的 from_json 行为有测试且不 panic」。逐 match 审查未发现 panic 路径（adapter.mbt:124-127 catch 全捕获；`ua_info_from_json` 对非对象/缺 family/错型全返回 None），但无测试锁定，回归（如未来重构把 catch 改成 raise）不会被任何用例拦截。修复：crescent integration_test 增 1-2 个用例：`parse_mounted_ua_info("not json") == None`、`parse_mounted_ua_info("{\"browser\":1}") == None`。

**Minor**：

5. **scripts/framework-cache-patches/README.md 内部矛盾（裁决残留同型）** — 中部章节「mizchi/x Windows fd gating — deliberately NOT shipped as a patch file」(:32-44) 声称该 patch 不以文件交付，但 mizchi-x-windows-fd.patch 实际存在、顶部表(:10-13)未列它、底部「Patch files」章节(:92-101)又明确列出并说明「applied by the same CI step」。中部章节是 42f2f91 持久化 patch 之前的旧状态残留，同一文件并存两个矛盾事实。修复：改写「NOT shipped」章节为已持久化状态。
6. **README「How to apply」缺少 PF-06 要求的 `-c core.autocrlf=false`** — README.md:52-55 的手动命令为裸 `git apply`，而 ci.yml:89-90 正确带了 flag；Windows 用户照 README 操作会踩 CRLF apply 失败。一行修复。
7. **middleware_core 未声明 supported_targets 且无 js/wasm 证据即单独发布** — 两个 adapter 都显式 `-all+native` 并附理由；middleware_core 的 moon.pkg/moon.mod 无任何 target 限制（moon.pkg 仅 7 行），GATE-5/6 只覆盖 lib。纯函数层面大概率跨目标安全，但「大概率」不是证据。修复二选一：同样声明 `-all+native`（附注释），或补一次 js 目标包级测试后再维持无限制。
8. （观察）ci.yml:67 补丁步骤注释「INSERTED before the first moon command」不精确——其上已有 `moon update` 步（moon update 不取依赖不编译，功能顺序仍正确）。可改措辞为「before the first workspace compile」。

### Recommendations

- 落地 Issue-1/2 的两行 CI 增量（一行测试、一步 workspace 根 mbti 漂移门），即可使「本地 GATE-4 与 CI 完全同形」。
- crescent 真实 TCP 路径（serve_async）未经网络级测试（测试走 test_client/App::dispatch，与 serve_async 共享同一 dispatch 管线，风险低）；如后续做 ws/生产部署，补一条 loopback 冒烟即可闭环。
- 考虑把 patch README 的 recheck（上游发版后 patch 失效检测）从手记升级为 CI 步骤（fetch 后 `git apply --check` 失败即红，现有步骤已天然承担此责——在 README 点明这一「失败即上游已修复」的正向语义）。
- 追踪上游：crescent 发 >0.11.1 或 mars 弃 async 0.21.3 pin 时按 README 移除条件重新生成/删除补丁（README 已登记，属维护项）。

### Blind-Spot Coverage

- **Response/contract-field evidence**: verified — 新读外部契约仅 `User-Agent` 请求头（HTTP 标准头；框架侧权威 vendored core mbti:49 get_header）；JSON 传输 schema 与 mars mount key 均为本 adapter 自有 schema（自写自读、双向有测试，非外部契约）；uap-core golden = 在仓快照引用（8 处行号实核命中）。
- **Shared state container update semantics**: verified/N/A — 无自建共享状态容器；crescent `Event` 为框架共享可变记录，mount 先于 next() 写入、dispatch 从同一 record 收尾，由集成测试（handler 读回 + res.headers 断言）锁定；mars `ctx.vars` 请求级隔离。
- **Silent-degradation observability**: verified — 降级三通道可观测（空 family headers/vars、`X-Ua-Info` 空 mount、forensics 行）；`parse_mounted_ua_info` 的 catch→None 有文档注释且为 README 记载的设计契约（非静默吞错）；无空 catch。
- **Scaffold/placeholder legacy**: N/A — 全范围为全新文件，无 scaffold/占位遗留。grep 证据：`git diff --name-status a56a85c..4ff2544 -- moon_ua_parser_middleware_core moon_ua_parser_crescent moon_ua_parser_mars scripts/framework-cache-patches moon.work .github/workflows/publish-manual.yml docs/framework-selection.md` 输出全为 A（新增）；`grep -rinE "scaffold|placeholder|TODO|FIXME" moon_ua_parser_middleware_core moon_ua_parser_crescent moon_ua_parser_mars scripts/framework-cache-patches moon.work .github/workflows/publish-manual.yml docs/framework-selection.md` 命中 0 处。
- **Coverage-table reconciliation**: verified — plan 表面矩阵 9 行逐行有归属任务与证据：workspace 清单=T-01 探针 log、选型报告=T-02（来源×12）、helper=T-03、crescent=mw1 证据、mars=mw2 证据、README/CI=T-06（grep 命中）、包页=T-08 closure 第八节（run 34762686652）；无孤儿面。
- **Pitfall list cross-check**（PF-01..PF-12 逐条）： **PF-01** 已对照—本范围包不在 wasm 门（adapters `-all+native` 声明，ci.yml wasm 7 包列表不含 middleware 包）；**PF-02** 不相关—moonrun 为本地工具链补丁，非本 diff 内容；js/wasm 门日志正常产出侧面证实补丁在位；**PF-03 已对照（缓解在 diff 内）**—crescent-async-compat.patch 触发条件/机制/移除条件齐备，CI fetch→patch→编译顺序正确（ci.yml:84-90），我以 reverse-check 证实本地缓存已应用；**PF-04 已对照（缓解在 diff 内）**—mizchi-x-windows-fd.patch reverse-check 通过，5 个 `#cfg(not(platform="windows"))` 分支各带证据注释；**PF-05 已对照**—publish-manual.yml:34 `runs-on: ubuntu-latest`，发布记录来自 GH Actions Linux（run 34762686652）；**PF-06 已对照（CI 合规）**—ci.yml:89-90 带 `-c core.autocrlf=false`；两处残留偏差已记 Minor（README 手动命令缺 flag；本地 GATE-2 用归一化比较、EOL 漂移被屏蔽——CI Linux 上为精确比较，权威门无碍；本次 working tree 的 EOL 伪 modified 即该现象实例）；**PF-07** 已对照—ci.yml 与 publish-manual.yml 均有 `moon update` 前置；**PF-08 已对照**—publish-manual.yml:39-68 pinned 安装 + 6 次重试 + latest 回退 + `moon version` 漂移记录；**PF-09/10/11** 已对照（CI/run-gates 相应步骤在位；PF-11 的教训恰是 Issue-2 的成因——mbti 门 cwd 在 lib，glob 够不到 adapter）；**PF-12** 不相关—本 diff 不触 uap-core 快照对账。
- **Platform-branch evidence matrix**: verified — 唯一平台条件分支族 = mizchi patch 的 5 个 `#cfg(not(platform="windows"))`，逐个带 LOCAL CACHE PATCH 注释 + T-05 报告指针；Linux 上为 no-op（README 说明）；adapter `supported_targets` 排除声明附理由注释。无未注解分支。
- **Preset-state provenance**: verified — 本范围测试无「应由生产方产出的状态」seed：UA 输入是测试自构的请求头（被测链路自身输入），golden 值逐条标注 uap-core 快照 file:line，synthetic 显式标注「失败注入专用」；forensics sink 注入为设计接口。
- **Evidence-grading spot-check**: verified — **golden UA 样本 = uap-core yaml 在仓快照引用**（vendored 只读快照回读，计划自判 B 级；我实核 8 处行号全部命中，快照本身是上游捕获产物的在仓副本）；**框架 API 名 = vendored 源码引用（A 级）**——`.mooncakes/` registry 包即实际编译对象，全部调用点 file:line 核过；`FALLBACK_FAMILY="Other"` = engine.mbt:33-65（A，复核属实）+ uap-core 金样本 + 运行时测试；**无 C 级主路径字段**。唯一 C 级残留 = 上游 commit SHA（crescent d99287ae…/mars ff4485e0…）：本地 registry zip 无 git 元数据不可复核，仅作文档溯源指针，不门控主路径，予以披露。
- **End-to-end behavior ownership**: verified — 「解析失败→用户可见响应」链 owner 明确：middleware_core 裁决降级语义（mount 什么、取证内容），adapter owner 链路延续与响应形态（不 5xx、空 mount 落地、取证转发）——分工写于两 adapter 文件头并被集成测试锁定；forensics 无消费方时仍有空 mount 兜底可观测（crescent README:91-93 显式声明）。
- **Behavior-equivalence baseline**: N/A + 证据 — 全新包无改动前行为：`git diff a56a85c..4ff2544 --name-status` 显示三包全部文件为 A（新增），BASE 上不存在该行为路径，基线=N/A 成立。
- **Degradation-path completeness**: verified — 两个 else 分支齐备且各有具名消费方：Err/全-fallback → `empty_ua_info` mount（消费方=下游 handler 与客户端，测试断言空值）+ forensics record（消费方=sink→console/注入闭包）；missing-header 场景单列测试（crescent:213-222、mars:378-389）；mars 无 next() 由顺序链模型保证 handler 必达（vendored `Server::middleware` push 模型 + 集成测试经真实 dispatch 证实）。
- **Stub fidelity**: N/A — 无测试替身：crescent 用框架官方 `test_client`（vendored 包），mars 用真实回环 TCP（框架自身网络栈）；sink 注入点是产品 API 而非替身。mars 测试内的手写 chunked-body 解析器是测试侧断言工具，其局限（仅识别固定状态码集）已在代码内注释，不影响被测契约。grep 证据：`grep -rinE "mock|stub|monkeypatch|fake|替身" moon_ua_parser_middleware_core/core_tests.mbt moon_ua_parser_crescent/integration_test.mbt moon_ua_parser_mars/integration_test.mbt` 命中 0 处（改动测试文件内 mock/stub/monkeypatch/替身零命中；crescent test_client 与 mars 回环 TCP 均为框架真实组件而非测试替身）。
- **Global side-effect implicit contract**: verified — 唯一全局性输出 = 默认 `console_forensics_sink` 的 println；枚举全部可达调用方：两示例（默认 sink，证据 log 在仓）、两包集成测试（显式注入捕获闭包）、未来按 README 注入的使用者；无进程级钩子/注册表；crescent 无全局 map（README 记载弃 request_id-map 的无界增长理由）。
- **Native-capability call matrix**: verified — 矩阵（调用点 × native / js / wasm）：① println×2（默认 sink）：native 有证据（GATE-4 + 示例 log）；js/wasm 格 = 被 `supported_targets="-all+native"` 声明排除（排除+理由注释=处置）；② mars 测试/示例 TCP 回环（@async_socket/@http.Server）：native 有证据（GATE-4 真实回环 + mw2 log）；js/wasm 同上排除；③ crescent test_client：内存 dispatch，无原生能力；④ middleware_core：无任何原生调用点（纯函数零 IO）；其自身 js/wasm 未测且无排除声明 → 记 Minor Issue-7（处置去向：声明排除或补 js 测试）。
- **Cross-boundary implicit-contract authority**: verified — 逐调用点外部权威见 R7（vendored mbti/源码 file:line，共 10+ 处）；同温层质询结论：实现/测试/生成 mbti 三方共同假设来源 = vendored registry 源码（外部）+ uap-core 快照（外部），无「同一改动自证」形态。
- **Upstream-claim triple reconciliation**: verified（可重跑项全部重跑）— ①「crescent 0.11.1 pin」→ `grep` moon_ua_parser_crescent/moon.mod:31 命中 `"bobzhang/crescent@0.11.1"`；②「mars 0.3.12 pin」→ moon_ua_parser_mars/moon.mod:34 命中 `"mizchi/mars@0.3.12"`；③「mars 传递 pin」→ vendored mars moon.mod 命中 async@0.21.3/x@0.5.5/mizchi/x@0.6.1；④「moon.work 成员」→ `grep -c "./moon_ua_parser" moon.work` = 4；⑤「CI 工具链 0.1.20260904」→ ci.yml:13-15,58 命中；⑥「无共存版本对」= 不可本地重跑（需 registry 版本矩阵查询）——以补丁 reverse-check 仍适用（冲突仍在）+ patch README 2026-09-13 recheck 记录作继承证据披露，按继承证据处理而非既定事实；⑦「统计通道不可得/包页渲染问题」= 历史实测记录，#3 statistics 人工核录为唯一剩余 pending（closure 第八节，登记浏览器回补路线）。
- **Adjudication-residue sweep**: verified — 裁决提取：选 crescent+mars 双适配、mars 弃 JSON-in-Variables 用原生 String、弃「为 UaInfo 实现 Var」、crescent 弃 request_id-map 选 res.headers。grep 证据（全仓、排除 .mooncakes）：被弃四候选包名（jaredzhou/pony、RabitLogic/mbit、wflixu/Halo、Lfan-ke/moonapi）在代码/配置/workflow = **0 命中**；mars adapter 内字符串键 `ctx.set/get` = **0 命中**；三包内 `impl Var for` = **0 命中**；request_id-map 在 crescent README 仅以「已弃用 + 理由」形态出现（合法决策记录）。**命中 1 处**：patch README「NOT shipped」旧状态（= Minor Issue-5）。
- **Acceptance-state gate**: verified — 计划验收命令行 0-4 逐条回填：行0 final-gate-mw log 在仓、行1 `grep -c "来源" docs/framework-selection.md` = **12**（≥6 达标）、行2 与 GATE-4 同形命令 10/7/6 全绿、行3 集成测试内断言覆盖、行4 两 README.mbt.md 存在 + 生态节/CI grep 命中（另一 reviewer 范围的 README 生态节我未判）。[LOCAL_DEAD_LINK] 清单终态：包页核录已回填（run 34762686652 + 包页 200）、CI run 已回填（34755753070 success）；**唯一剩余 = #3 statistics 通道人工核录**——非最高优先级验收行，已登记触发条件与浏览器回补路线，不构成关闭阻塞。
- **Gate evidence**: verified — 全部 7 门禁真实退出码读自日志（DONE.flag 已出现）：GATE-1 `EXIT_CHECK=0`，TOTAL_WARNINGS=18（基线 18 不增），DEP_OUTSIDE_LIB=0；GATE-2a `EXIT_INFO=0`/`EXIT_MBTI_DIFF=0`（覆盖范围缺口见 Issue-2）；GATE-2b `EXIT_GEN=0`/`EXIT_GEN_DIFF=0`；GATE-3 workspace native **54/54** `EXIT_NATIVE_ROOT=0`；GATE-4 **10/10、7/7、6/6** 三 EXIT=0；GATE-5 js **41/41** `EXIT_JS=0`；GATE-6 wasm **28/28** `EXIT_WASM7=0` + `EXIT_WASM_BUILD=0`；GATE-7 smoke `result=pass`（40.7ms << 150ms 校准阈值）`EXIT_SMOKE=0`。基线分离：BASE 上三包不存在（无红基线）；警告基线 18 条全部位于 moon_ua_parser_lib（库外 deprecated=0），本范围包零警告。
- **Test-diff purity**: verified — 本范围测试文件全部为新增（`git diff a56a85c..4ff2544 --name-status` = A）：core_tests.mbt、crescent/mars integration_test.mbt（连同两 adapter.mbt、core.mbt 共 6 文件逐一核过）`grep '^-[^-]'` 删除行 = **0**；T-06 的 ci.yml 插入提交 fc26bd9 对 ci.yml 删除行 = **0**（纯增量；range 内 ci.yml 的 6 处删除行来自其他单元的工具链重写/wasm 步改造，不在本 reviewer scope）。
- **Rename reference sweep**: verified — 本范围无更名（全新包，无旧名可残留）；命名一致性 grep：错误大小写 `UAInfo` 在三包+选型文档 = **0 命中**（统一 `UaInfo`）；`assemble` 调用面三包一致（helper 定义、两 adapter 单调用点）；常量命名 `KEY_UA_*`/`HEADER_UA_*`/`REASON_*` 跨包风格一致；关键词 statistics 仅出现于 mooncakes 统计通道语境（非符号更名）。

### Render Surface Coverage

**N/A — no render surfaces affected.** 本范围为纯后端中间件包（helper 纯函数 + 两框架适配层 + CI/发布工作流），无模板/样式/类名/布局/视口/渲染产物。grep 证据：对范围内全部 29 个 diff 文件 grep 大小写不敏感的 UI 关键词（`css|stylesheet|<template|innerHTML|className|viewport|font-size|background-color|flex-|grid-`），命中数 = **0**。

### Assessment

**With fixes**

无 Critical。4 条 Important（CI 缺失 middleware_core 测试门致 Err 降级分支零 CI 覆盖；mbti 漂移门不覆盖 adapter 包；两包 README 过期发布注记已随包页上线；malformed JSON 读回路径缺 rubric 要求的测试）均为小增量可修复，不推翻架构与证据链——整体工程质量与证据纪律高于常规，修复后即达 Ready。
