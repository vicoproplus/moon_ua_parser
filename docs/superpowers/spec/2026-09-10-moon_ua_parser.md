# moon_ua_parser 技术规格（SPEC）

> 需求权威：`PRD.md`（PRD-2026-001）· 方案权威：`design-moon_ua_parser.md`
> 拆分声明承接：PRD 附录 10.6 = 单份 PRD，无需拆分；本文档为唯一 spec。
> 日期：2026-09-10 · 状态：待评审

---

## 0. 已验证事实（Verified Facts）

基线扫描命令与结果（可重放）：

| # | 事实 | 证据（命令 + 结果） |
|---|------|---------------------|
| V1 | uap-core 规则快照 commit `73e7340`（2026-08-24） | `git -C uap-core rev-parse --short HEAD` → `73e7340`；`git -C uap-core log -1 --format=%cd --date=short` → `2026-08-24` |
| V2 | uap-python 差分对照 commit `6dd8c39`（2026-05-27） | `git -C uap-python rev-parse --short HEAD` → `6dd8c39` |
| V3 | 规则总数 1274（ua 433 / os 207 / device 634） | Python 正则统计 `- regex:` 于 `uap-core/regexes.yaml` 分节 |
| V4 | 上游 tests 用例 18213 条：test_ua.yaml 1601 / test_os.yaml 483 / test_device.yaml 16129 | Python 逐文件统计 `- user_agent_string:` 行 |
| V6 | 规则集零 lookaround/原子组/possessive/POSIX 类/{,n}；非捕获组 944 处 | Python 扫描 `uap-core/regexes.yaml`：`(?=`/`(?!`/`(?<=`/`(?<!`/`(?>`/`(?P<` 均为 0 |
| V7 | `regex_flag: 'i'` 仅存在于 device 节（65 条） | Python 扫描：ua/os 节 0 条、device 节 65 条 |
| V8 | moonbitlang/regexp@0.3.5 全量 1274 条编译 0 失败（native 后端实测，2026-09-10 本机） | 探针程序 `moon run --target native cmd/main` 输出 `total rules: 1274` / `compile failures: 0`；探针脚本已按 spike 纪律清理 |
| V9 | regexp compile 支持 `flags="i"` 且大小写折叠双向对称（ASCII） | 探针测试：`compile("HUAWEI", flags="i").execute("huawei")` 与 `compile("huawei", flags="i").execute("HUAWEI")` 均命中 |
| V10 | regexp@0.3.5 匹配为 leftmost-first（PCRE 风格） | mooncakes.io 官方文档 `Regexp::execute`：「Uses a leftmost-first matching strategy」（https://mooncakes.io/docs/moonbitlang/regexp/） |
| V11 | moon 工具链 0.1.20260904 本机可用，native/js 双后端测试通过 | `moon version` → `0.1.20260904 (94521db)`；探针 `moon test --target native`、`--target js` 均 passed |
| V12 | uap-python 语义权威的关键实现位点 | `uap-python/src/ua_parser/basic.py:55-81`（逐 matcher 顺序、首条命中）、`matchers.py:32-56,93-129,150-175`（三类 matcher 替换语义）、`utils.py:8-33`（replacer：$N 替换、strip、空串→None）、`user_agent_parser.py:32-56`（UA 家族 $1 语义 + lastindex 防越界） |
| V13 | uap-core tests YAML 用例字段 | `uap-core/tests/test_ua.yaml:1-63`（family/major/minor/patch）、`test_os.yaml:1-43`（+patch_minor）、`test_device.yaml:1-58`（family/brand/model） |
| V14 | Python 3.12.10 + PyYAML 可用（转换器宿主环境） | `python --version` → 3.12.10；`python -c "import yaml"` OK |
| V15 | regexp `execute` 为非锚定 search 语义；空可选组 `(?:\.(\d+)|)` 参与态 Some/缺态 None 均正确 | 本机探针（native 后端）：`(Chrome)/(\d+)\.` 于 `Mozilla/5.0 … Chrome/120.0 …` 中段命中取组；`Firefox/120.0` → `Some(0)`、`Firefox/120` → `None`，`moon test` 全绿 |

**运行时环境矩阵**：

| 项 | 形态 |
|----|------|
| 服务启动方式 / 鉴权 / 端口 / 前端部署 / 浏览器状态 | N/A — 纯库，无 daemon 无端点 |
| 运行目标 | wasm（moon 默认 preferred_target）、native、js 三后端 |

**平台运行时原语可用性矩阵**（A=本机实测，B=官方文档指针）：

| 原语/语言特性 | wasm | native | js | 证据 |
|---------------|------|--------|----|------|
| regexp.compile 全量 1274 条规则 | B（同 VM 内核，moon 默认目标；发布前 wasm 后端回归覆盖） | A | A | V8/V11 |
| 命名捕获组 `(?<name>…)` + `groups()` | B | B | B | mooncakes.io/docs/moonbitlang/regexp 语法表与示例 |
| flags 参数（"i"） | B | A | A | V9 |
| search 语义 + 空可选组取组两态 | B | A | A | V15 |
| 多行字符串 `#|` 与插值 `\{}` | B | A | A | V8 探针全程使用 |
| Python 3.12 + PyYAML（构建期转换器宿主） | N/A（构建机） | N/A | N/A | V14 |

**UNVERIFIED 表**：无（V1-V15 全部落证；alternation 优先级真实影响面为探索变量，按 D6 归因处置，不构成本表项）。

## 1. 背景（D1）

PRD C1：MoonBit 生态缺 UA 解析库（mooncakes 2363 包零命中），10 余个 Web 框架的公共下游需求无解。本项目将跨语言事实标准 uap-core（规则源）+ uap-python（语义权威）移植为 MoonBit 库并发布 mooncakes。目标用户与价值回链 PRD C4（US-01～US-08）。

## 2. 架构（D2）

```
uap-core/regexes.yaml ──(构建期: scripts/gen_rules.py)──▶ src/ua_parser/rules/*.mbt（生成物）
uap-core/tests/*.yaml ──(构建期: scripts/gen_tests.py)──▶ tests/differential/*.mbt（生成物）
                                    │
                                    ▼
src/ua_parser/  ├─ types.mbt      （Browser/OS/Device/UaInfo 数据模型）
               ├─ template.mbt   （$N 模板求值：构建期已预解析为组号序列）
               ├─ matcher.mbt    （单条规则 = 正则 + 模板 + flag；三域列表）
               ├─ engine.mbt     （逐域顺序匹配、首条命中、fallback Other）
               └─ api.mbt        （parse / parse_browser / parse_os / parse_device + 规则编号选项）
examples/       └─ middleware/    （中间件示例，FR-10）
```

- 数据流：规则与用例一律**构建期转换**（生成物，禁止手改），运行时纯查表 + 正则执行，零 YAML/网络依赖（FR-05）。
- 模块边界：types / template / matcher / engine / api 五文件分层；`rules` 生成目录独立包。
- 初始化：`rules` 包顶层 let 预编译全部 1274 条 Regexp（进程一次），失败 fail-loud 抛含规则序号的错误（FR-06，设计 D8）。
- 生成目录所有权登记（GO1-GO3）：

| 目录 | 生成工具 | 权威命令 | 覆盖行为 | 禁手改 |
|------|----------|----------|----------|--------|
| `src/ua_parser/rules/` | `scripts/gen_rules.py` | `python scripts/gen_rules.py`（读 `uap-core/regexes.yaml`，写 `rules_data.mbt` + `rules_version.mbt`） | 全量重建（整文件覆盖） | 是（全部 .mbt） |
| `tests/differential/` | `scripts/gen_tests.py` | `python scripts/gen_tests.py`（读 `uap-core/tests/*.yaml`） | 全量重建 | 是（生成 .mbt） |

  修改一律改生成源（脚本/上游 YAML），重跑权威命令。

## 3. 范式（D3）

- 语言/工具链：MoonBit（moon 0.1.20260904），运行时依赖仅 `moonbitlang/regexp@0.3.5`（moon.mod 锁定）。
- 引擎语义契约（对齐 uap-python，位点见 V12）：
  1. 三域各自**按数组顺序**尝试，**首条命中生效**，全不命中 → family="Other"（brand/model=None、版本字段=None）；
  2. 替换模板：UA 族 family 仅 `$1` 替换或字面量；OS/Device 族 family/brand/model 与版本字段用 `$1-$4` 模板，求值后 **strip 两端空白、空串归 None**（uap-python `utils.py:33`）；
  3. UA 版本字段 v1-v3：模板字面量直接用；无模板时取捕获组 2/3/4，**可选组未参与匹配即 None**（`lastindex` 语义：组号 ≤ 实际最后参与组才取值，`user_agent_parser.py:45-54`）；可选组 `(?:\.(\d+)|)` 参与与否两态已探针实测（`Firefox/120.0` → Some("0")，`Firefox/120` → None）。
  4. device flag-i（65 条）：`compile(..., flags="i")`；UA/OS 无 flag；
  5. 匹配位置：`search` 语义（非锚定），regexp `execute` 天然满足——本机探针实测：无锚定模式 `(Chrome)/(\d+)\.` 于长 UA 中段命中并取组（probe native 后端全绿）。
- 命名约定：`UaInfo/Browser/OS/Device`、`parse/parse_browser/parse_os/parse_device`、规则编号 = 域内 0 起序号。
- 差分修复范式（设计 D6）：失败用例逐条归因三分类——引擎语义差（改写规则，记 `docs/regex-migration.md`）/ 上游规则笔误（改写并记录）/ 上游已知难点（豁免登记，计入通过率分母）。禁止改引擎、禁止静默跳过。

## 4. 解决方案（D4）

### 4.1 PRD 回链表（先于一切设计结论）

| spec 条目 | 类型 | 回链 |
|-----------|------|------|
| S-01 parse 主 API（`parse(ua) -> Result[UaInfo, Error]`） | 需求 | FR-01 ← US-01/02/03/05 |
| S-02 顺序匹配引擎 + Other fallback | 需求 | FR-02 ← US-01/05 |
| S-03 $N 替换模板求值（strip/空串→None） | 需求 | FR-03 ← US-01/02/03/05 |
| S-04 device flag-i（65 条） | 需求 | FR-04 ← US-03 |
| S-05 规则构建期生成 + 快照版本标注 | 需求 | FR-05 ← US-08 |
| S-06 预编译初始化 + fail-loud 定位错误 | 需求 | FR-06 ← US-05/08 |
| S-07 畸形输入确定性（空串/超长/控制字符） | 需求 | FR-07 ← US-04 |
| S-08 可选命中规则编号 | 需求 | FR-08 ← US-07 |
| S-09 单域解析函数 ×3 | 需求 | FR-09 ← US-01/02/03 |
| S-10 examples 中间件示例 | 需求 | FR-10 ← US-01 |
| S-11 差分测试转换（18213 条）+ 通过率门槛 | 需求 | FR-11 ← US-01/02/03/05 |
| S-12 mooncakes 发布元数据 | 需求 | FR-12 ← US-08 |
| S-13 差分修复与豁免登记（docs/regex-migration.md） | 需求 | G-02 / FR-11 |
| S-14 README（快照版本、通过率、quickstart） | 需求 | G-03 ← US-08 |

PRD P0/P1 全覆盖；P2 项（FR-08/FR-10）全部承接；无 spec 新增 PRD 之外需求。

### 4.2 交付物清单（[ALIGN]=对齐 uap-python 语义 / [EXT]=本项目产品决策）

| # | 交付物 | 标签 | 证据/依据 |
|---|--------|------|-----------|
| S-01 | `src/ua_parser/api.mbt`：parse 全域函数 | [ALIGN] | uap-python `__init__.py:156` / `user_agent_parser.py:213` |
| S-02 | `src/ua_parser/engine.mbt`：三域顺序首条命中 | [ALIGN] | uap-python `basic.py:55-81` |
| S-03 | `src/ua_parser/template.mbt`：$N 求值 + strip + 空串→None | [ALIGN] | uap-python `utils.py:8-33`、`matchers.py:43-56` |
| S-04 | rules 生成数据含 flag 字段 + engine 应用 `flags="i"` | [ALIGN] | uap-python `matchers.py:150-152,180-181` |
| S-05 | `scripts/gen_rules.py` + `rules_data.mbt` + `rules_version.mbt`（commit 73e7340 标注） | [EXT]（构建期转换决策，设计 D4） | — |
| S-06 | rules 包顶层预编译 + 定位错误消息 | [EXT]（预编译决策，设计 D8） | — |
| S-07 | `tests/robust.mbt` 畸形输入回归（空串/>4096/控制字符各 ≥3 例） | [ALIGN]（上游语义：畸形输入得 None 族字段不崩溃） | uap-python 解析语义 |
| S-08 | `parse(ua, with_rule_index?~)` 可选规则编号 | [EXT]（产品决策 FR-08） | — |
| S-09 | `parse_browser/parse_os/parse_device` | [ALIGN] | uap-python `__init__.py:175/184/193` |
| S-10 | `examples/middleware/` 示例 | [EXT]（产品决策 FR-10） | — |
| S-11 | `scripts/gen_tests.py` + `tests/differential/diff_{ua,os,device}.mbt` | [EXT]（转换范式，设计 D5）；期望值逐条对齐上游 YAML | `uap-core/tests/*.yaml` |
| S-12 | `moon.mod` 元数据 + `moon publish --dry-run` | [EXT]（产品决策 FR-12） | — |
| S-13 | `docs/regex-migration.md` 差分修复登记 | [EXT]（修复范式，设计 D6） | — |
| S-14 | `README.md`（快照版本/通过率/quickstart） | [EXT]（产品决策 G-03） | — |

### 4.3 验收标准（分层，任一失败 = 总体失败）

| 维度 | 验证命令 | 通过判据 |
|------|----------|----------|
| 0 运行时链路（环境预检） | `moon check && echo OK` | exit 0（纯库无 HTTP 端点，row 0 以编译链路代替 curl 链路；编译断 = 一切断） |
| 1 功能对齐（差分） | `moon test --target native` && `moon test --target js` | 全绿；分域通过率 browser ≥99% / os ≥97% / device ≥97%（未达标用例逐条在 `docs/regex-migration.md` 归因登记） |
| 2 生成物一致性 | `python scripts/gen_rules.py && git diff --exit-code -- src/ua_parser/rules/`；同法 gen_tests 对 `tests/differential/` | diff 为空（生成物与上游快照可复现） |
| 3 畸形输入健壮性 | `moon test --target native`（含 tests/robust 用例） | 全绿，>4096 字符用例无超时 |
| 4 交付形态 | `moon publish --dry-run` | exit 0 |
| 5 运行时目标形态 | `moon test --target native && moon test --target js && moon test` | 三后端全绿 |
| 6 生态示例 | `moon run --target native examples/middleware/main`（或等价入口） | exit 0 且打印解析结果 |

CI 接入：维度 0/1/2/5 进 `.github/workflows/ci.yml`（moon 0.1.20260904 固定）；4/6 本机执行记录。

### 4.4 测试套件对齐（源侧 ↔ 目标侧）

| 源侧测试 | 目标侧对应 |
|----------|-----------|
| `uap-core/tests/test_ua.yaml`（1601） | `tests/differential/diff_ua.mbt`（生成） |
| `uap-core/tests/test_os.yaml`（483） | `tests/differential/diff_os.mbt`（生成） |
| `uap-core/tests/test_device.yaml`（16129） | `tests/differential/diff_device.mbt`（生成） |
| `uap-python/tests/` 7 文件（语义单元测试） | `tests/semantics/*.mbt`（手写：替换模板/Other fallback/flag-i/畸形输入，覆盖 S-02/03/04/07） |
| `uap-core/test_resources/*.yaml`（13114 条） | [EXT] W3 补充差分源（`tests/differential/extended/`，非门槛用例集） |

### 4.5 范围内/外

- **In**：S-01～S-14；`docs/regex-migration.md`；三后端测试。
- **Out**：PRD C3 非目标全部；规则在线更新；非 ASCII 大小写折叠深度优化（仅抽验记录，见设计文档 §7 未知项）。

### 4.6 批次完成定义（多 Agent 并行时）

| 批 | 内容 | 完成定义 |
|----|------|----------|
| B1 | 生成器脚本 + 生成物（S-05/S-11） | 单一独立执行者：维度 2 + `moon check` 清零 |
| B2 | 引擎与 API（S-01/02/03/04/06/07/08/09） | 单一独立执行者：维度 0/1/3/5 全量清零（含三后端） |
| B3 | 差分修复（S-13） | 单一独立执行者：维度 1 至门槛并归因登记清零 |
| B4 | 发布与示例（S-10/12/14） | 单一独立执行者：维度 4/6 + 全量回归复跑清零 |

各 worker 自检不作批完成依据；每批由一名独立执行者整变更集成验证清零后才进下一批。

### 4.7 红线范围（R1-R4）

新建移植（greenfield + 上游快照转换），无既有代码迁移/改造单元：**N/A — no migration/refactor units.**（若 W3 需改写 uap-core 规则，改写发生在生成源——脚本内规则改写表——不属既有代码红线。）

### 4.8 响应契约（RC1-RC8）

**N/A — no server-response consumption.**（纯库，不消费服务端响应；无 mock。测试期望值 = 上游 YAML 内嵌字段，证据等级 B（上游仓库代码回读 `uap-core/tests/*.yaml`），非臆造。）

### 4.9 行为等价断言（适用子集）

无页面/共享状态/请求链，适用面收敛为**数据流层（B1-B5）+ 负向轴子集**：

- B1 字段完备性：每差分用例断言全字段（family + 版本，或 brand/model）逐字段等于上游期望（生成用例即断言载体）；
- B2 批处理确定性：同输入多次 parse 结果相同（tests/semantics 断言）；
- B3 回调链：无回调，N/A；
- B4 失败降级：畸形输入返回确定结果而非崩溃（维度 3 覆盖）；
- B5 入口函数副作用枚举：parse 为纯函数，无网络/存储/全局态副作用（moon test 全绿即证，逐副作用断言不适用——零副作用）；
- NE 负向轴：未命中 → family="Other" 且版本字段 None（非空串/非垃圾值；生成用例含未命中样本，如 `fakeLuminary/1.0` → Other，`uap-core/tests/test_ua.yaml:62` 起）；超长输入 → 不抛异常不产垃圾字段。

### 4.10 错误展示分型（ED1-ED4）

**N/A — no unified error-display rule.**（纯库 API：失败语义 = 返回 `Result::Err`，调用方自决展示；无统一弹错层、无静默语境迁移。）

### 4.11 环境与调试可观测性（EX1-EX3）

**N/A — no environment state rules, no platform debugging contract.**（无端口/代理/监视器；错误面 = moon 编译器与 moon test 输出，V11 实测可观测。）

### 4.12 [LOCAL_DEAD_LINK] 登记

无依赖本机不可关环境的验收行（三后端均本机实测可用，V8/V11）。**mooncakes 发布（维度 4）需 mooncakes 账号凭证，属环境依赖行**：

| 行 | 依赖 | 标签 | 状态 | 处置 | 回补触发 |
|----|------|------|------|------|----------|
| 维度 4 `moon publish --dry-run` | mooncakes 账号 | [LOCAL_DEAD_LINK] | unresolved | 本机 dry-run 先行；正式 publish 由用户执行 | 凭证可用（用户登录后观察 publish 成功与 mooncakes 页面可见） |

---

**文档结束**
