# moon_ua_parser 设计文档

> 状态：已确认（PRD 校验通过后撰写）
> 上游权威：`PRD.md`（PRD-2026-001，validate_prd.py exit 0）
> 日期：2026-09-10

---

## 1. 用户当前理解（认知校准结果）

用户（MoonBit 黑客松参赛者）要把跨语言事实标准 ua-parser 移植到 MoonBit：以 uap-core@73e7340 的 1270 条规则为规则源、uap-python@6dd8c39 为语义权威，产出可发布 mooncakes 的 `moon_ua_parser` 库。正则引擎不确定性已通过本机 spike 消除（moonbitlang/regexp@0.3.5 全量 1270 条编译 0 失败、native/js 双后端通过、大小写折叠双向对称），剩余风险集中在匹配语义细节（alternation 优先级、替换模板边界）与差分通过率门槛达成。交付导向比赛评分：工程完整 > 生态演示 > 性能基线。

## 2. 目标（引用 PRD C2）

本设计服务于 PRD 五个目标：G-01 主 API 与发布、G-02 语义对齐门槛（browser ≥99% / os·device ≥97%）、G-03 工程完整、G-04 生态演示、G-05 性能基线。本设计不重述目标定义。

## 3. 关键约束

- **技术**：moon 0.1.20260904 工具链；moonbitlang/regexp@0.3.5（alpha，API 可能变，moon.mod 锁版本）；uap-core 规则为 PCRE 风格但实测零 lookaround/backref（除语义兼容的空可选组），1270 条全部落在 regexp 支持面内。
- **快照纪律**：规则与测试用例从本地固定 commit 生成，构建期转换、运行时零 YAML 依赖（PRD FR-05）。
- **比赛周期**：四周排期（PRD C8），任何方案不得引入长周期工程。

## 4. 非目标（引用 PRD C3）

伪造检测、设备能力库、规则在线更新、其余 HTTP 头、性能优化超基线——见 PRD 三章，本设计不再展开。

## 5. 验收场景（回链 PRD US-XX）

设计层验收以 PRD 四章 8 个用户故事为准：中间件作者（US-01/02/03）、数据工程师（US-04/05）、风控（US-06）、审计（US-07）、mooncakes 消费者（US-08）。本设计的选择必须让每个 US 的验收标准可被对应 FR 的验收标准直接判定。

## 6. 设计决策追溯表

| # | 设计决策 | which/why 论证要点（含被否决备选） | 回链 PRD |
|---|----------|--------------------------------------|----------|
| D1 | 正则引擎锁定 moonbitlang/regexp@0.3.5 | 备选 A「官方 regexp」：VM 执行、复杂度可预期、防灾难回溯、官方维护（30K 下载），spike 1270 条 0 失败；备选 B「yj-qin/regexp@0.3.6」：回溯引擎有灾难回溯风险、无 Unicode 支持、上次更新一年前（61 下载）、无 flag-i 支持——四项全部劣于 A；备选 C「自研引擎」：周期不可承受。**否决 B 的决定性证据**：README 特性矩阵明示无 Unicode/lookaround/backref 且设计上有灾难回溯。A 的风险（alpha API 变动）用锁版本 + 差分回归兜底 | G-02, FR-02, FR-04, FR-06 |
| D2 | 匹配语义采用 leftmost-first（PCRE 风格） + 逐域顺序尝试 | uap-core 语义 = 按数组顺序首条命中生效（uap-python basic.py 逐 matcher search、first hit wins）。官方 regexp 的 `execute` 文档明示 leftmost-first，与 PCRE 对齐；**否决** leftmost-longest（POSIX 风格，会导致 alternation 命中分支不同）；**否决** re2 式 Set/Filter 预筛（uap-python re2.py 需 min(matches) 还原顺序，复杂度转嫁且 uap-core 规则量级 1270 条无需） | FR-02 |
| D3 | 替换模板在转换期把 `$1`-`$4` 预解析为结构化字段，运行时按组号取值 | 备选 A「运行时字符串替换 re.sub(r\$(\d))」：每次命中做正则替换，浪费且要在 MoonBit 再实现一遍；备选 B「构建期把模板编译为 (group_idx, literal) 序列」：零运行时正则、类型安全、错误前移到转换期。**否决 A**：性能与健壮性双输；**采纳 B**：模板形态在 uap-core 中仅 $1-$4 与字面量两种（1007/315/55/10 处），转换期穷尽可行 | FR-03 |
| D4 | 规则数据构建期生成为 MoonBit 源码（.mbt），编译期完成 regexp.compile | 备选 A「运行时加载 YAML」：引入 YAML 解析依赖 + 每进程重复解析 223KB 规则，违反 PRD 零依赖边界；备选 B「运行时加载 JSON」：仍需运行时解析与 regexp 编译（1270 条 × 每进程），首次 parse 延迟不可控；备选 C「构建期生成 .mbt 数据源码 + 顶层 let 预编译」：regexp.compile 在模块初始化执行一次，运行时纯查表匹配。**否决 A/B**；**采纳 C**。生成脚本入 `scripts/`，生成物入 `src/ua_parser/rules/`，登记 do-not-hand-edit（GO 纪律） | FR-05, FR-06 |
| D5 | 差分测试用例从 uap-core tests/ 三 YAML 构建期转换为 moon test 数据 + 断言循环，不逐条手写 | 备选 A「手写代表用例」：18213 条人工不可行且易漂移；备选 B「构建期转换为生成测试文件」：与 D4 同范式，快照一致性可机检。**否决 A**；**采纳 B**。test_resources/ 五文件（13114 条）作为 W3 补充差分源，先跑 tests/ 三文件 | FR-11, G-02 |
| D6 | 差分修复策略：语义等价改写规则（记录于迁移文档），禁止改引擎或改用例 | 备选 A「魔改 regexp 引擎」：超出比赛范围且破坏官方依赖；备选 B「跳过失败用例」：静默降低门槛，违背 G-02；备选 C「规则级改写 + 用例级豁免登记」：失败用例逐条归因（引擎语义差 / 规则笔误 / 上游已知问题），规则改写记录进 docs/regex-migration.md，不可修复项单列并计入通过率。**否决 A/B**；**采纳 C** | G-02, FR-11 |
| D7 | API 表面：`parse` 全域 + `parse_browser/parse_os/parse_device` 单域，返回 `Result`，审计规则编号经 options 参数开启 | 备选 A「只提供 parse 全域」：日志场景浪费 2/3 匹配开销（单域需求真实存在，uap-python 亦拆分）；备选 B「审计编号并入默认返回」：多数调用方不需要，徒增字段。**否决 A/B**；**采纳** PRD FR-08/FR-09 的拆分形态。包结构：`src/ua_parser/`（引擎 + 模板替换）、`src/ua_parser/rules/`（生成数据）、`examples/`（中间件示例） | FR-01, FR-08, FR-09 |
| D8 | 初始化策略：顶层 let 预编译全部规则（进程内一次），失败 fail-loud | 备选 A「首次 parse 懒编译」：把编译成本推迟到第一个请求（中间件场景 = 冷启动毛刺），且 1270 条懒编译状态管理复杂；备选 B「预编译」：初始化成本一次付清（spike 实测全量编译秒级），后续零编译开销。**否决 A**；**采纳 B**。编译失败在初始化即抛错（fail-loud），与 FR-06 验收标准一致 | FR-06, NFR-性能 |

## 7. 未知项

| 未知项 | 类型 | 处置 |
|--------|------|------|
| moonbitlang/regexp alternation 优先级在真实 uap-core 规则上的差分影响面 | 探索变量 | W2 引擎实现时以 tests/test_ua.yaml 前 200 条抽验；有差异按 D6 归因处理 |
| 非 ASCII 字母的大小写折叠（flag-i 65 条规则里非 ASCII 字面量占比） | 探索变量 | W2 抽验；预期影响面趋零（device 规则字面量为 ASCII 主体） |
| 全量 1270 条预编译的初始化耗时精确值 | 探索变量 | W2 基准脚本量化；秒级即可接受（D8 已按 spike 预判） |
| device 域 97% 门槛达成度（16k 用例） | 探索变量 | W3 全量差分后按 D6 归因；上游已知难点用例单列 |

## 8. 兄弟 PRD 对齐（拆分声明承接）

PRD 附录 10.6 记录「单份 PRD，无需拆分」——本设计为唯一设计文档，spec 由 P7 单个承接，无兄弟对齐义务。

---

**文档结束**
