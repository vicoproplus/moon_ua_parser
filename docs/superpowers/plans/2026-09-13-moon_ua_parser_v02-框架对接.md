# moon_ua_parser v0.2 框架中间件对接 Implementation Plan

## Goal
以证据裁决选定 1-2 个 mooncakes Web 框架，交付生产级 UA 解析中间件包（共享 helper + 薄适配层 + 集成测试 + 示例 + 文档），发布到 mooncakes，并完成主库 README 生态节与 CI 集成测试步骤的增量合入。

## Architecture
本仓库改造为 moon workspace（机制经 T-01 探针验证）：`moon_ua_parser_lib`（既有库）+ `moon_ua_parser_middleware_core`（共享 helper：UaInfo 组装、降级判定、取证记录格式）+ 每框架一个薄适配包（T-02 裁决：`moon_ua_parser_crescent`、`moon_ua_parser_mars`：注册签名 + 上下文挂载 + 日志通道适配）。业务语义零内联框架分支（设计文档 PS-1/PS-2）。

## Tech Stack
- MoonBit 工具链 moon（ci.yml:13 锁定 0.1.20260904）
- 依赖库：`vicoproplus/moon_ua_parser`（moon.mod:12 机读；中间件依赖 ≥0.2.0，S2）
- 目标框架：M1 证据裁决前不锁定（U3 走读后定；候选清单见申报书「项目简介」节:12 六框架）
- Python 3.12（如集成测试需要驱动脚本；预期不需要）

> 溯源规则: 每项库名/版本必须溯源 spec 章节号或仓库实际依赖，禁止凭记忆填写。

## Global Constraints
- 只消费库公开 API（pkg.generated.mbti:5-11 四个 pub fn），不改库公开面；`moon info` 零 diff。
- 降级语义：Err 或空兜底结果时挂载空 UaInfo 继续链路，不向响应注入错误；取证记录 `{ua_summary(≤64 字符截断), reason}` 落框架日志通道（spec §3 降级/取证行）。
- CI 只增量合入步骤，不改既有 job（PRD 10.6 S3）。
- 框架版本区间锁定 + 区间内集成测试（spec NFR 兼容性）。

## Granularity & Consensus Declaration (MANDATORY)

- **Spec 层级**: v0.2 拆分 4 份之一（批次 4/4）；spec `docs/superpower/SPEC/202609130033-moon_ua_parser_v02-框架对接-spec.md`；设计文档 `docs/superpower/DESIGN/202609130033-moon_ua_parser_v02-框架对接-design.md`（D1-D5 决策权威）
- **Plan 颗粒度**: 仅执行 task，不含实现代码
- **同级 plan 共识点**: | 共识点 | 值 | 出处 |
  | 公开 API 冻结 | 消费侧对齐：4 个 pub fn 不变 | 各 PRD 10.6 S1 |
  | 版本线依赖 ≥0.2.0 | 本单元发版任务排在平台完备 T-09（版本收口）之后 | 各 PRD 10.6 S2 |
  | CI 增量合入 | 集成测试步骤追加进 ci.yml，冲突上报不绕行 | 各 PRD 10.6 S3 |
  | 生成物边界 | 中间件包不触 rules/differential | 各 PRD 10.6 S4 |
  | README 分节 | 生态节归本单元；性能节归性能基准 | 平台完备 spec S5 |
  | 执行顺序 | T-01 workspace 探针先行；T-07 发版依赖平台完备 T-09；与性能基准并行（合并后一次整库集成验证） | 各 spec 批次完成定义 |

## Environment Assumptions & Verification (MANDATORY)

- **E1 构建入口**: workspace 顶层 `moon build --target native` / `moon test --target native`（T-01 探针确立：清单文件名 `moon.work`，members=["./moon_ua_parser_lib"]；证据 docs/evidence/workspace-probe-2026-09-13.log。本机 wasm-gc 测试运行损坏为既有环境事实，行0 固定 `--target native`）；过渡期沿用 moon_ua_parser_lib/ 单模块入口（ci.yml:50-92 机读）
- **E2 工具链版本**: moon 0.1.20260904（ci.yml:43；reviewer 2026-09-13 实测本机同版本）；workspace 机制版本要求以 T-01 探针实测为准
- **E3 运行环境**: Windows + Git Bash（会话实测）；node 经 js 目标实测可用（native 31/31 全绿会话实测；js 由 ci.yml:74 门禁覆盖）
- **E4 验收命令可移植性**: 全部相对路径；workspace 字面量在 T-01 后回填本 plan
- **E5 编译探针 Task 0**: T-01 = moon workspace 双模块 hello-world 探针（新构建机制未验证——设计文档 U2）；探针绿前不建包
- **E6 既存状态假设**: mooncakes 登录态/发布凭证——未实测，T-08 以 `moon publish --dry-run` 实测；GitHub 网络——2026-09-13 实测受限（T-02 证据采集与 T-08 发版的依赖，[LOCAL_DEAD_LINK] 登记回补）
- **E7 验收观测通道**: moon test/构建输出通道实测可用；mooncakes 包页通道 JS 渲染 + 网络受限（2026-09-13 实测）→ 包页验收以人工核录为准并标 [LOCAL_DEAD_LINK]

> 通用化要求: 未核实的环境事实禁止写成断言；T-01/T-02 承担 U1（mooncakes 统计可得性）与 U2（workspace 机制）核实。

## Execution Design Declaration (MANDATORY)

- **W1 worker 写范围**: 单线为主；B2 起如并行：T-03 worker 允许改 `moon_ua_parser_middleware_core/`，T-04 worker 允许改 `moon_ua_parser_crescent/`（首包），互不重叠；共享文件（根 workspace 清单、ci.yml）由 T-01/T-06 单点完成
- **W2 重派残留核对**: 重派第一步 `git status --porcelain` + 半途包目录核对清理，结果附任务记录
- **V1 并行批后集成验证**: 与性能基准并行时，合并后单一执行者跑整库集成验证（T-09），worker 自报无效
- **V2 配置改动 dry-run**: T-01 建 workspace 清单后立即构建全部模块验证；T-06 改 ci.yml 后本地镜像执行新步骤
- **L1 机械任务上限**: T-02 证据采集：命令 ≤ 20、轮次 ≤ 15（含走读文件数上限 8 个/框架）
- **D1 失败诊断路径**: 集成测试失败按「归因（适配层 vs helper vs 框架 API 假设）→ 定位 → 处置」，禁止先假设框架有错
- **V3 增量审查检查点**: B1 末 R-1（含选型裁决复核）、B2 末 R-2、B3 末 R-3
- **V4 排序自洽性**: T-01 → T-02 → R-1 → T-03 → T-04 →（T-05 若裁 2 包）→ T-06 → T-07 → T-08 → T-09 → R-3；T-07 依赖平台完备 T-09 完成版本收口（跨 plan 共识，引用同向）
- **V5 终验门禁终局性**: T-09 整库门禁位于全部改码任务后；workspace 清单/ci.yml 变更强制复跑

> 九条护栏逐项声明如上。

## Surface Coverage Matrix Declaration (MANDATORY)

| 表面 | 归属任务 | 状态/证据要求 |
|------|----------|---------------|
| workspace 构建清单（根） | T-01 | 探针构建全绿记录 |
| 选型证据报告 docs/framework-selection.md | T-02 | 对比表 + 裁决 + 六候选来源指针 |
| helper 包（moon_ua_parser_middleware_core） | T-03 | check/test 绿 |
| 首个框架中间件包 + 集成测试 + 示例 | T-04 | 集成测试全绿 + 示例命令运行记录 |
| 第二框架包（若裁决 2 个） | T-05 | 同上 |
| 主库 README「Ecosystem」节 | T-06 | grep 包名命中 |
| 各包 README | T-06 | 安装/注册/配置说明核对 |
| ci.yml 集成测试步骤 | T-06 | 本地镜像运行记录 +（网络恢复后）CI run [LOCAL_DEAD_LINK] |
| mooncakes 包页可检索 | T-08 | 人工核录记录 [LOCAL_DEAD_LINK — 网络可用后] |

## Dependency Contract Declaration (MANDATORY)

| 字段/接口 | 读方 | 写方 | 生产方归属任务 | 断链处置 |
|-----------|------|------|----------------|----------|
| 4 个 pub fn + UaInfo 结构字段 | helper + 适配层 | 既有实现 | 显式豁免：本计划外既有实现 + 证据 pkg.generated.mbti:5-11（字段面 reviewer B 已逐项核实） | 无断链 |
| 库版本 ≥0.2.0 | 中间件包依赖声明 | 平台完备 plan T-09 | 跨 plan 衔接点（生产任务=平台完备 T-09，交付批次=其 B3，等待策略=T-08 发版前检查 `grep -n 'version' moon_ua_parser_lib/moon.mod`） | 未收口则 T-08 阻塞登记 |
| 框架请求上下文 API | 适配层薄层 | 入选框架 | T-02 走读产出（API 形态表） | API 不满足挂载 → 候选在裁决中被否决 |
| ua_summary/reason 取证字段 | 适配层日志调用 | helper（T-03 定义） | T-03 | 无断链（薄层只做通道适配） |

## Fixture Provenance Declaration (MANDATORY)

- 正常 UA 测试种子：抽自 uap-core 测试用例快照 = `golden:uap-core-tests-<域>-<用例id>`（B 级，vendored 快照回读，用例旁注释标注 file:line）。
- 畸形/边界 UA = `synthetic:失败注入专用（非金样本替身；用于验证降级与取证链路）`（spec §5 分级已登记）。
- 无 mock/桩替身（真实框架 + 真实库）→ F4/F5：N/A — no test doubles in this plan.
- 框架日志取证通道为真实环境通道：M2 集成测试实测登记可用性（spec §8 FO 门；不可用时兜底 = 上下文空结果本身为降级证据，登记为替代通道）。

## Error Scenario Matrix Declaration (MANDATORY)

被消费外部端点：mooncakes registry（发版/统计）、GitHub（证据采集）、入选框架上游（API 稳定性）。

| 错误维度 | 端点 | 期望形态断言 | 归属任务 |
|----------|------|--------------|----------|
| 端点未就绪（网络不可达） | mooncakes/GitHub | 采集/发版命令显式失败；处置 = [LOCAL_DEAD_LINK] 回补登记（禁止静默假设可用） | T-02/T-08 |
| 端点未就绪（统计页 JS 渲染不可抓取） | mooncakes 包页 | 采集显式记「不可得」；处置 = 降权（设计文档 D1/U1）或人工核录 | T-02 |
| 时序类（库 v0.2.0 未收口先发版） | mooncakes | 发版前断言库版本 ≥0.2.0（grep moon.mod），否则阻塞（消费方先于生产方 = 禁止） | T-08 |
| 业务失败（畸形 UA） | 中间件 | 请求不 5xx + 上下文空结果 + 日志取证可检索（三重断言，集成测试承载） | T-04/T-05 |
| 退化载荷（框架 API 版本漂移） | 框架 | 锁定版本区间内集成测试全绿；区间外升级触发适配修复轮 | T-06 |

就绪后复验安排：网络恢复 → T-02/T-08 回补项执行落档（触发=网络可用，目标批次=回补批）。

## Fix Loop Discipline Declaration (MANDATORY)

- 适用：集成测试缺陷与框架 API 适配修复轮。
- 实证升级（R1）：同一缺陷两轮未愈，第三轮运行时取证（框架调试日志 + 最小复现工程）落档。
- 类灭绝（R2）：适配层缺陷完成定义 = 全部适配包同模式排查（检索薄层调用点）。
- 根因追问（R3）：`根因修复`/`症状修复` 标注必填；框架 API 误判类缺陷必须登记到选型报告勘误。
- 连续复验（R8）：N=3（缺陷关闭 = 连续 3 次集成测试全绿，逐次附输出）。
- 靶向回归比对（R10）：既有回归失败集合 = 空（当前全绿，native 31/31 会话实测）→ 显式记录 "N/A — no pre-existing regression failures."，每轮更新。

## Runtime Acceptance Declaration (MANDATORY)

- 用户可达表面 = 各包示例应用（可运行程序）：打开态检查（A6）= 示例启动零报错 + 请求响应含三组解析结果 + （畸形 UA 时）空结果降级可观察，证据（运行输出）落档——并入 T-04/T-05/T-06 验收。
- 批次末走查（A3）：B1 末复核裁决报告；B2 末跑首包集成测试 + 示例；B3 末跑全部集成测试 + 示例。
- 外部端点就绪登记（A7）：mooncakes（未知，JS 渲染 + 网络受限实测）/ GitHub（未知，网络受限实测）/ 框架上游（未知，走读后更新）→ 处置 = 登记回补（A4：网络可用自动生成回补任务）。
- 平台敏感出口门：T-07/T-08 依赖（v0.2.0 收口、网络、发布凭证）未解决时标「阻塞」并阻塞 B4 关闭，登记解决动作/负责人 vicoplus/恢复条件/目标批次（回补批）；无法解决则交付范围显式收缩（包不发版，README 标注「待发布」），CHANGELOG 登记。
- 部署对账（A5）：`moon publish` 以 dry-run 输出与包元数据比对 + 发版后包页检索核对（人工核录）。

## Interface Alignment (MANDATORY)

N/A — this plan touches no endpoints（中间件消费框架请求 API 与库函数 API，均为进程内调用，无 HTTP 端点声明面）

## Spec vs Code Discrepancies (MANDATORY)

| # | spec 值 | 仓库现状 | 裁决 |
|---|---------|----------|------|
| 1 | spec §3 包落位 = workspace 子模块 | 仓库根无 workspace 清单 | ALIGN-SPEC：T-01 探针确立；失败则修订 spec 该行（回退独立仓库，D2 反向裁决留痕） |
| 2 | spec §3 包命名模式 `moon_ua_parser_<framework>` 具体字面待 M1 | 无中间件包 | ALIGN-SPEC：T-02 裁决后逐字回填 spec §3（证据等级升 A）与本 plan |
| 3 | reviewer B 勘误：申报书六候选清单位于「项目简介」节:12 | 已复核 | ALIGN-SPEC（spec §0 已于 2026-09-13 修订采纳） |

## Acceptance & Verification Commands (MANDATORY)

```bash
# 行0 workspace 构建+测试管线（spec §4 行0；T-01 后回填 workspace 字面量，此处为确立后形态）
moon test --target native && cd moon_ua_parser_lib && moon check
# 行1 选型证据（spec §4 行1 逐字）
test -f docs/framework-selection.md && grep -c "来源" docs/framework-selection.md   # ≥6
# 行2 中间件行为（spec §4 行2；每集成包执行，包名 T-02 裁决回填：crescent + mars）
moon test -p moon_ua_parser_crescent
moon test -p moon_ua_parser_mars
# 行3 失败取证（spec §4 行3；畸形 UA 集成测试内断言日志通道输出，运行上述测试即覆盖）
# 行4 集成/交付（spec §4 行4 逐字；包页项 [LOCAL_DEAD_LINK — 验证地点/方式: 网络可用后 mooncakes 包页人工核录]）
test -f moon_ua_parser_crescent/README.mbt.md
test -f moon_ua_parser_mars/README.mbt.md
grep -c "moon_ua_parser" moon_ua_parser_lib/README.mbt.md   # 生态节含包名
grep -n "middleware\|集成" .github/workflows/ci.yml         # CI 步骤命中
```

## Spec Coverage Map（FR/US → 任务）

| spec/PRD 条目 | 任务 |
|---------------|------|
| FR-01 选型证据报告（US-03/G-01） | T-02 |
| FR-02 中间件包工程（US-01/G-02） | T-01、T-03、T-04/T-05 |
| FR-03 上下文挂载 + 降级（US-01/G-02） | T-04/T-05 |
| FR-04 文档与示例 + README 生态节（US-02/G-03 + 10.6 S5） | T-06 |
| FR-05 mooncakes 发版（US-01/G-03） | T-08 |
| CI 集成测试增量合入（10.6 S3） | T-06 |
| 版本依赖收口对账（10.6 S2） | T-08 |

# Tasks

## B1 — workspace 探针与选型裁决

### T-01 moon workspace 双模块探针（E5 Task 0）

**Files**: 根 `moon.workspace`（或探针确认的实际清单文件名）；临时探针模块（探针后删除）

**Steps**
1. 依官方文档结构建最小双模块 workspace（moon_ua_parser_lib + 一个 hello 模块，hello 依赖 lib）；网络受限时按本地 moon 自带模板/既有知识尝试并在假设清单记录依据。
2. 构建验证：workspace 顶层构建 + 跨模块依赖解析 + `moon test` 三件套；记录实际清单文件名与命令字面量，回填本 plan E1/行0 与 spec §3 落位行。
3. 决策门：探针失败（两轮）→ 触发 D2 反向裁决（独立仓库方案），修订 spec §3 落位行并留痕，继续 B1。
4. 验收：探针构建全绿输出落盘 `docs/evidence/workspace-probe-<date>.log`；临时模块删除且 `git status` 无残留。

**时长上限**: 2 小时；轮次 ≤ 10。

### T-02 框架选型证据采集与裁决

**Files**: `docs/framework-selection.md`（新）

**Steps**
1. 采集六候选证据（L1 上限：命令 ≤ 20/走读 ≤ 8 文件每框架）：mooncakes 下载量（可得性 U1 实测：不可得则降权并记录）、GitHub 活跃度（最近提交/issue 响应）、中间件 API 形态（注册签名是否接受回调、请求上下文可否挂载自定义键——源码走读）、文档完善度。
2. 源码走读入选前二：中间件注册 API、上下文 API、日志通道 API 的函数签名与用法（file:line 记录）；产出「可挂载性」判定。
3. 加权裁决（40/30/20/10）出结论：选 1 个或 2 个框架；包名字面量（`moon_ua_parser_<framework>`）逐字确定。
4. 回填：spec §3 包命名字面量（升 A 级）与本 plan 全部 `<framework>` 占位。
5. 验收：报告含对比表 + 裁决 + 六候选来源指针（`grep -c "来源" docs/framework-selection.md` ≥ 6）。网络不可得项显式记「不可得 + 降权」，[LOCAL_DEAD_LINK] 登记回补。

**时长上限**: 4 小时；轮次 ≤ 15。

### R-1 B1 增量审查检查点（V3）

- 单一审查者复核：探针结论与 spec §3 一致性、裁决过程可复现（权重应用无事后合理化）、回填字面量与报告一致。
- 通过后进 B2。

## B2 — helper 与首个框架包

### T-03 共享 helper 包

**Files**: `moon_ua_parser_middleware_core/`（moon.pkg + 源码文件）

**Steps**
1. 实现 helper：UaInfo 组装（消费 parse Result）、降级判定（Err 或空兜底 → 空结果）、取证记录格式定义（ua_summary 截断 ≤64 + reason）、对外暴露「组装 + 判定 + 记录构造」纯函数面（无框架 API、无 IO）。
2. 单元测试：正常 UA（golden:uap-core-tests 快照样本）→ 三组结果；畸形 UA（synthetic）→ 空结果 + 取证记录字段正确。
3. 增量门：`moon check` + `moon test`（包级）。
4. 验收：包测试全绿；`moon info` 生成 helper 包接口文件并入提交。日志：测试输出。

**时长上限**: 3 小时。

### T-04 首个框架中间件包

**Files**: `moon_ua_parser_crescent/`（moon.pkg + 适配层源码 + 集成测试 + examples/ + README.mbt.md；T-04 裁决首包 = crescent）

**Steps**
1. 薄适配层：框架注册签名 + 请求入口调 helper + 上下文挂载 + 框架日志通道适配（PS-1/PS-2，业务语义零内联）。
2. 集成测试：构造请求断言上下文/响应含 browser/os/device；注入畸形 UA（synthetic 标注）断言不 5xx + 空结果 + 日志取证可检索（三重断言，FO 通道可用性实测登记）。
3. 锁定框架版本区间（依赖声明 + 区间记录）；示例应用 + README（安装/注册/配置）。
4. 增量门：`moon check` + 包级 `moon test`；D1 诊断纪律生效。
5. 验收：集成测试全绿（连续 3 次，R8）；示例一条命令运行且输出含三组结果（A6 打开态证据落盘 `docs/evidence/mw1-example-<date>.log`）。

**时长上限**: 6 小时；框架 API 意外偏离走读结论 >2 处时停下复核 T-02 判定。

### R-2 B2 增量审查检查点（V3）

- 走查：helper/薄层职责边界（业务语义零内联框架分支——抽薄层文件核对无组装/降级逻辑）+ 集成测试三重断言覆盖 + 取证通道实测登记。
- 通过后进 B3。

## B3 — 扩展与文档合入

### T-05 第二框架包（仅当 T-02 裁决为 2 个）

**Files**: `moon_ua_parser_mars/`（同 T-04 结构；T-02 裁决第 2 包 = mars）

**Steps**
1. 复制 T-04 模式实现第二适配包；共享语义零复制（调 helper）。
2. 集成测试 + 示例 + README 同 T-04 验收（连续 3 次全绿 + 打开态证据落盘）。
3. 裁决为 1 个时本任务标记 skipped（裁决记录为准）。

**时长上限**: 4 小时。

### T-06 文档与 CI 增量合入

**Files**: `moon_ua_parser_lib/README.mbt.md`（Ecosystem 节）；`.github/workflows/ci.yml`（集成测试步骤）

**Steps**
1. 主库 README 新增「Ecosystem」节：已发布中间件包清单 + 安装命令 + 框架适配说明（spec §3 契约行）。
2. ci.yml 追加集成测试步骤（workspace 构建后逐包运行集成测试；镜像既有步骤形态：timeout-minutes/working-directory）；V2 dry-run 本地执行一次。
3. 验收：`grep -c "moon_ua_parser" moon_ua_parser_lib/README.mbt.md` 生态节命中 + ci.yml 步骤命中；本地镜像运行绿。CI run 证据 `[LOCAL_DEAD_LINK — 推送后 GitHub run 历史]`。

**时长上限**: 1.5 小时。

### T-07 整库集成验证（与性能基准合并后执行）

**Steps**
1. 两单元（性能基准/框架对接）都合并后，单一执行者全量验证：workspace 全构建 + check + native/js 测试 + 生成一致性 + smoke + 全部集成测试。
2. 验收：全绿输出落盘 `docs/evidence/final-gate-mw-<date>.log`。

**时长上限**: 1 小时。

## B4 — 发版

### T-08 mooncakes 发版

**Files**: 无新文件（发布操作）

**Steps**
1. 前置断言（时序类场景行）：`grep -n "version" moon_ua_parser_lib/moon.mod` 确认库已收口 ≥0.2.0（平台完备 T-09 完成）——未收口则阻塞登记（依赖衔接点）。
2. `moon publish --dry-run`（各包）实测（E6）：输出落盘 `docs/evidence/publish-dryrun-mw-<date>.log`。
3. 网络与凭证可用时：正式 `moon publish`（外发动作——执行前 AskUserQuestion 确认）；发版后包页人工核录（A5 对账）。
4. 不可用：任务标 `[LOCAL_DEAD_LINK]`（触发=网络可用+凭证确认），登记回补。
5. 验收：dry-run 落盘 +（可用时）包页核录记录。

**时长上限**: 1 小时（不含等待）。

### T-09 单元收口核对

**Steps**
1. Acceptance 全部行逐条执行记录。
2. [LOCAL_DEAD_LINK] 清单复核（CI run、包页、网络项）——每项含触发条件与回补登记。
3. 验收：核对记录落盘 `docs/evidence/mw-closure-<date>.md`。

**时长上限**: 30 分钟。

### R-3 终审检查点（V3/V5）

- 表面矩阵逐行确认（9 行，证据落档）+ 抽样真实走查（本地复跑首包示例一次）。
- 阻塞项按出口门登记；通过 = 单元交付。

---

**Authority Alignment**: 本 plan 无对齐参考实现的等价性任务——解析语义由库差分套件保证（v0.1 交付），本单元只做集成与挂载。N/A — no authority-equivalence tasks.

**交接声明**: spec = `docs/superpower/SPEC/202609130033-moon_ua_parser_v02-框架对接-spec.md`（规则/契约/架构权威；reviewer 提出的 3 项阻塞已于 2026-09-13 修复）；design = `docs/superpower/DESIGN/202609130033-moon_ua_parser_v02-框架对接-design.md`（D1-D5 决策权威）；本 plan = 执行流程/排期/检查点权威。
