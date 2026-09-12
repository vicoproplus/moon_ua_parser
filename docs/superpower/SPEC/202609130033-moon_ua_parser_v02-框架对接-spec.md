# Spec —— moon_ua_parser v0.2 框架中间件对接

> PRD（what/why 权威）：`docs/superpower/PRD/202609130033-moon_ua_parser_v02-框架对接-prd.md`
> 设计文档（which/why 权威）：`docs/superpower/DESIGN/202609130033-moon_ua_parser_v02-框架对接-design.md`（D1-D5 决策与 UNVERIFIED U1-U3）
> 拆分声明：承接 PRD 附录 10.6（4 份拆分之一）；本 spec 覆盖 S5 中「README 生态/集成节归本单元」条目，并对 S1/S2 作消费侧对齐。

## 0. Verified facts（基线扫描，2026-09-13 实测）

事实源命令与结果（可复跑）：

- 库依赖字面量：`grep -n "^name" moon_ua_parser_lib/moon.mod` → :12 `name = "vicoproplus/moon_ua_parser"`。
- 库公开 API（中间件唯一消费面）：`grep -n "pub fn" moon_ua_parser_lib/src/ua_parser/pkg.generated.mbti` → :5 `parse(String, with_rule_index? : Bool) -> Result[UaInfo, UaError]`、:7/:9/:11 三个单域函数。
- 错误类型：`UaError { RegexpCompileError(String) }`（pkg.generated.mbti:14-16）——运行期 Err 仅源于规则编译失败（预编译初始化 fail-loud，T-04），请求期解析正常路径不产生 Err。
- 结果结构：`UaInfo { browser, os, device }`；`Browser/OS` 含 family/major/minor/patch/patch_minor/rule_index，`Device` 含 family/brand/model/rule_index（pkg.generated.mbti 结构体定义段）。
- 现有中间件示例：`moon_ua_parser_lib/examples/middleware/{main.mbt, moon.pkg}`（T-10 交付，风格示例非框架集成）。
- 候选框架（申报书点名）：Crescent、mars（Hono 风格）、pony（Chi 风格）、mbit（Gin 风格）、Halo（Koa 洋葱）、moonapi（FastAPI 风格）（moon_ua_parser_申报书.md「项目简介」节:12）——其 mooncakes 统计与中间件 API 形态均未走读（U1/U3）。

### 缺口表

| 条目 | 源侧证据 | 目标侧状态 | 标签 |
|------|----------|------------|------|
| 框架选型证据报告 | 申报书候选清单；零证据材料 | missing | [EXT] not an alignment item, product-decision driven |
| 1-2 个框架中间件包 | examples/middleware/ 仅为风格示例 | missing | [EXT] not an alignment item, product-decision driven |
| 共享 helper（组装+降级） | 无（零集成代码） | missing | [EXT] not an alignment item, product-decision driven |
| 集成测试与示例 | 无 | missing | [EXT] not an alignment item, product-decision driven |
| mooncakes 发版 | 无中间件包 | missing | [EXT] not an alignment item, product-decision driven |

## 1. PRD 回链表

| spec 条目 | PRD 来源 | 覆盖关系 |
|-----------|----------|----------|
| 选型证据报告 | FR-01 / US-03 / G-01 | 全覆盖 |
| 中间件包工程 | FR-02 / US-01 / G-02 | 全覆盖 |
| 上下文挂载 + 降级 | FR-03 / US-01 / G-02 | 全覆盖 |
| 文档与示例（含主库 README 生态节） | FR-04 / US-02 / G-03 + PRD 10.6 S5 | 全覆盖 |
| mooncakes 发版 | FR-05 / US-01 / G-03 | 全覆盖 |
| CI 集成测试增量合入 | PRD 10.6 S3 | 全覆盖（S3 共享边界交付） |

PRD P0/P1 全部覆盖；无 spec 外新增需求。

## 2. 红线分界

本单元为新增包（greenfield），无迁移/改造/批量变更单元 → 红线为新增门：新增代码 `moon check` 0 errors 0 deprecated（基线 44 个 `[pre-existing]` 弃用警告归「平台完备」单元，见其 spec §2 R2，不计入本单元门禁）。

## 3. 契约（字面量均带证据等级）

| 契约项 | 字面值 | 证据等级与指针 |
|--------|--------|----------------|
| 库依赖声明 | `vicoproplus/moon_ua_parser`（依赖版本 ≥0.2.0） | A：moon.mod:12 机读；版本下限 = S2 边界 |
| 包命名模式 | `moon_ua_parser_crescent`（Crescent）、`moon_ua_parser_mars`（mars）——T-02 加权裁决入选前二（crescent 9.06 / mars 8.36），逐字登记于 `docs/framework-selection.md` §④/§⑤ | A：T-02 裁决报告 2026-09-13（来源指针 ≥6，权重计算可复核） |
| 包落位 | 本仓库 moon workspace 子模块（根清单 `moon.work`，members=["./moon_ua_parser_lib"]；T-01 探针 2026-09-13 实测：双模块构建+跨模块依赖解析+`moon test --target native` 全绿，证据 `docs/evidence/workspace-probe-2026-09-13.log`；wasm-gc 本地测试运行为既有环境限制，行0 固定 native 目标） | A：T-01 探针实测（D2 反向裁决未触发） |
| 共享 helper 模块 | `moon_ua_parser_middleware_core`（组装 UaInfo 挂载值 + 降级判定 + 取证记录格式定义；不含框架 API） | B：设计文档 D3 |
| 降级语义 | Err 或三域 family 均为空兜底值（"Other"/"Spider" 语义沿用 uap-python）时挂载空结果继续链路；取证记录 = `{ua_summary(截断≤64字符), reason}` 写入框架日志通道 | A：pkg.generated.mbti 结构 + README「uap-python-compatible semantics」节 |
| 取证记录格式 | UA 摘要与失败原因两字段，由 helper 统一定义，各框架薄层只做通道适配 | B：设计文档 D4/PS-2 |
| 选型证据报告 | `docs/framework-selection.md`：候选对比表（下载量 40%/活跃度 30%/API 兼容 20%/文档 10% 加权）+ 裁决结论 + 每项证据来源指针 | B：设计文档 D1 权重 |
| 主库 README 生态节 | `README.mbt.md` 新增「Ecosystem」节：列出已发布中间件包、安装命令与框架适配说明（S5 归属交付，PRD 10.6 S5） | B：PRD 10.6 S5 + 本 spec 锁定结构 |
| CI 集成测试增量合入 | `.github/workflows/ci.yml` 增量合入中间件集成测试步骤（workspace 构建后逐包运行集成测试；不改既有 job 结构，S3 归属「平台完备」、本单元只追加步骤） | B：PRD 10.6 S3 + 设计文档 §3 约束 |
| 错误展示责任分型 | 请求入口自动触发语境 = 静默降级（不向响应注入错误、不阻断），替代可观察结果 = 上下文空结果 + 日志取证记录；豁免机制 = 不适用（本包不设统一弹错层）；同型反证 = 不适用（无先例类推） | B：PRD NFR 安全性/失败可诊断性 + ED1-ED3 分型 |

## 4. 验收分层表（任一行失败 = 整体失败）

| 维度 | 验证命令 | 通过标准 |
|------|----------|----------|
| 0 运行时链路（workspace 构建+测试管线） | 仓库根 `moon test --target native`（T-01 探针确定字面量）+ `cd moon_ua_parser_lib && moon check` | 全模块构建通过；库公开面零变化（`moon info` diff 为空） |
| 1 功能对齐（选型） | `test -f docs/framework-selection.md && grep -c "来源" docs/framework-selection.md` ≥ 6（§0 六候选逐行有来源指针） | 对比表 + 加权裁决 + 六候选来源指针齐备 |
| 2 功能对齐（中间件行为） | 每集成包集成测试：构造请求断言上下文/响应含 browser/os/device 三组结果；注入畸形 UA（synthetic 标注）断言降级 | 三组结果可观察；请求不 5xx 且上下文为空结果 |
| 3 失败取证 | 注入畸形 UA 的集成测试中检索框架日志通道输出 | 可检索到 `{ua_summary, reason}` 记录（通道可用性在 M2 实测登记） |
| 4 集成/交付 | 每集成包 README 命令一条跑通示例；主库 README 生态节含已发布包清单（grep 包名命中）；CI 集成测试步骤在 ci.yml 可检索；mooncakes 包页可检索 | 四项齐备（包页项 [LOCAL_DEAD_LINK — 网络可用后人工核录]） |

## 5. 测试对齐

无源侧测试迁移需求。测试种子证据分级：正常 UA 用例抽自 uap-core 测试用例快照 = **B 级**（vendored 快照回读，file:line 随测试注释标注）；畸形/边界 UA 为刻意构造 = **synthetic**（用于失败注入，非金样本替身，注入目的在注释声明）；无 C 级形态冒充 A/B。

## 6. 批次完成定义

批次：B1 选型证据与裁决（FR-01）→ B2 helper + 首个框架包 + 集成测试（FR-02/03）→ B3 第二框架包（若裁决为 2）+ 文档示例（FR-04）→ B4 发版（FR-05）。每批完成由单一独立执行者运行 §4 行 0 与对应行并清零，方进下一批；自报无效。与「性能基准」单元可并行；两单元合并后须一次整库集成验证（workspace 全构建 + ci.yml 全镜像）。

## 7. UNVERIFIED 与环境依赖行

| 编号 | 内容 | 处置 |
|------|------|------|
| U1 | mooncakes 下载量/统计可获取性（包页 JS 渲染，2026-09-13 抓取失败） | M1 证据采集（浏览器人工核录或 registry API）；不可得则降权并记录（设计文档 D1） |
| U2 | moon workspace 多模块机制 | M1 最小探针（hello-world 双模块构建）；失败回退独立仓库并修订 §3 落位行 |
| U3 | 入选框架中间件 API 形态（注册签名/上下文挂载/日志通道） | M1/M2 源码走读，对比表入选型报告；API 不满足挂载条件的候选在裁决中被否决 |
| U4 | GitHub/mooncakes 网络可达性 | `[LOCAL_DEAD_LINK]`：发版与证据采集依赖；回补触发 = **网络可用**；核验方法 = git ls-remote + mooncakes 包页检索 |

## 8. 挂载点判定

- 生成物所有权：本单元无生成物（helper 与薄层均为手写源码）；若 B2 引入代码生成（不预期），须先回本节登记。
- 响应契约门：N/A — no server-response consumption（中间件消费请求头，测试自产自断言响应；畸形 UA 为 synthetic 已在 §5 分级）。
- 共享状态/生产者-消费者：N/A — 中间件为无状态逐请求处理，上下文挂载值生命周期限于单请求。
- 平台接缝：PS-1（框架 API 薄层）/PS-2（日志通道适配）见设计文档 §8；共享语义（降级判定、取证格式）零内联框架分支。
- 失败取证通道（FO 门）：取证通道 = 框架日志通道，其可用性是环境事实——M2 集成测试实测登记（§4 行 3），未验证前不作为唯一取证手段（兜底：helper 返回的空结果本身即上下文可观察降级证据）。
- 环境事实清单（EC 门）：mooncakes 包页 JS 渲染（2026-09-13 实测）→ §4 行 4 的包页核对以人工核录为准；GitHub 网络受限 → U4 登记。

---

**Spec 结束**
