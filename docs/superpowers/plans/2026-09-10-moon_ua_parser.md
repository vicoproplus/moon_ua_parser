# moon_ua_parser Implementation Plan

## Goal
将已确认的 PRD/design/spec 链落地为 MoonBit UA 解析库：uap-core@73e7340 规则快照构建期转换为 MoonBit 数据源码，匹配引擎语义对齐 uap-python@6dd8c39，18213 条上游差分用例达标（browser ≥99% / os·device ≥97%），发布 mooncakes v0.1.0 并附框架中间件示例。

## Architecture
纯库（无 daemon/端点/页面）。构建期：Python 脚本（PyYAML）读 `uap-core/regexes.yaml` 与 `uap-core/tests/*.yaml`，生成 `src/ua_parser/rules/*.mbt`（规则数据）与 `tests/differential/*.mbt`（差分用例）。运行时：`rules` 包顶层预编译全部 1270 条 Regexp（fail-loud）；engine 按域顺序首条命中；template 求值 $1-$4（strip、空串→None）；api 暴露 parse/parse_browser/parse_os/parse_device（可选规则编号）。布局照抄 spec §2 架构图（types/template/matcher/engine/api 五文件 + rules 生成目录 + examples）。

## Tech Stack
- MoonBit 工具链 moon 0.1.20260904（94521db）— `moon version` 实测（E2 证据）
- moonbitlang/regexp@0.3.5 — spec §3（moon.mod 已锁定，`moon.mod:28-30` import 块实测存在）
- Python 3.12.10 + PyYAML（构建期转换器宿主）— spec V14
- 上游快照：uap-core@73e7340（规则+用例）、uap-python@6dd8c39（语义权威，仅供回读对齐，非运行时依赖）

> 溯源规则: 每项库名/版本已溯源 spec 章节号或仓库实际依赖；regexp@0.3.5 已写入 `moon_ua_parser_lib/moon.mod` import 块并 `moon add` 落地成功（实测 exit 0）。

## Global Constraints
- 运行时零 YAML/网络依赖（spec §2 数据流、FR-05）
- 生成目录禁手改：`src/ua_parser/rules/`、`tests/differential/`（spec §2 GO 登记；修改一律改生成源后重跑权威命令）
- 引擎语义以 uap-python 为唯一权威（spec §3 五条契约；权威位见 spec V12 与本计划 Authority Alignment Table）
- 差分门槛：browser ≥99% / os ≥97% / device ≥97%（PRD G-02、FR-11）；未达标用例逐条归因三分类（spec §3 D6），禁止改引擎、禁止静默跳过
- 三后端测试：native/js/wasm（PRD NFR-兼容性；wasm 为 moon 默认 preferred_target）

## Granularity & Consensus Declaration (MANDATORY)
- **Spec 层级**: N/A — this plan is based on a single spec（PRD 附录 10.6「单份 PRD，无需拆分」；spec 为该 PRD 唯一 spec）
- **Plan 颗粒度**: 本 plan 仅含具体执行 task（步骤/接口/验收命令），不含实现代码
- **同级 plan 共识点**: N/A — 无兄弟 PRD/plan

## Environment Assumptions & Verification (MANDATORY)
- **E1 构建入口**: 唯一规范入口 = moon 工具链（`moon build`/`moon check`/`moon test`/`moon run`），工作目录 `moon_ua_parser_lib/`（moon.mod 所在目录）。核实：read `moon_ua_parser_lib/moon.mod:12`（name=vicoproplus/moon_ua_parser）+ `moon test` 实测 exit 0（0 测试）。构建期转换脚本为第二类入口（`python scripts/gen_rules.py` / `gen_tests.py`），其输出物入 moon 工程，不与 moon 入口竞争——moon 为编译/测试权威入口，gen 脚本为数据生成权威入口（spec §2 GO 登记表）→ ✅ 双入口各司其职、均有登记。
- **E2 工具链版本**: moon 0.1.20260904（`moon version` 实测输出 `0.1.20260904 (94521db 2026-09-04)`）；moonbitlang/regexp@0.3.5（`moon_ua_parser_lib/moon.mod:28-30` import 块 + `moon add` 成功）；Python 3.12.10 + PyYAML（`python --version` 实测 3.12.10；`python -c "import yaml"` OK）。CI 需固定 moon 0.1.20260904（PRD NFR）。→ ✅ 全部实测。
- **E3 运行环境**: moon 三后端（wasm 默认/native/js）本机实测可用（spec V11：探针 native/js 测试通过）；运行目标无其他依赖。→ ✅
- **E4 验收命令可移植性**: 全部验收命令为相对路径 + 规范入口（`cd moon_ua_parser_lib && moon …`、`python scripts/gen_rules.py`），无机器绑定绝对路径；脚本用相对路径引用 `../uap-core/regexes.yaml`（脚本内以仓库根为 cwd 假定，路径守卫：文件不存在即报错退出）。→ ✅
- **E5 编译探针 Task 0**: `moon_ua_parser_lib/` 为已验证构建目标（`moon add moonbitlang/regexp` 后 `moon check` 实测 exit 0，2026-09-10），T-01 仍列最小编译探针作为第一任务（跑通含 regexp 依赖的最小目标 + 一条真实规则编译），探针失败触发决策门。→ ✅ 探针为 Task 0。

## Execution Design Declaration (MANDATORY)
- **W1 worker 允许修改文件清单**: 本计划为单一执行者顺序执行（无并行 worker）→ N/A — no parallel workers.（如执行期改为并行派发，必须先为每个 worker 声明互斥 `[允许修改文件清单]` 并在并行批后插 V1 集成验证。）
- **W2 重派前残留核对**: 计划为全新执行（无前次失败实例）→ N/A — no re-dispatch in this plan.（如某任务失败后重派，先 `git status`/`git log` 核对残留并清理列为重派第一步。）
- **V1 并行批后整变更集成验证**: 无并行批 → N/A — no parallel batches.（每批末的集成验证由唯一执行者本人在 V3 检查点执行，满足单一执行者语义。）
- **V2 配置/路由改动后 dry-run 验证**: T-03（gen_rules 生成配置）与 T-05（gen_tests 生成配置）均为生成产物配置改动 → 各任务内紧跟 dry-run：运行生成命令 + 读生成产物（规则条数 = 1270 分节核对、用例条数 = 1601/483/16129 核对、`moon check` 编译通过）。→ ✅ 已挂。
- **L1 机械类任务执行上限**: gen_rules/gen_tests 为单命令确定性脚本（非收集/轮询类）→ N/A — no mechanical tasks（上限不适用；脚本单次执行，失败即失败，无轮询循环）。
- **D1 构建/校验失败诊断路径**: 每个验证门（T-01/03/05/06/08/10/12）预设诊断路径：先归因（`moon check`/`moon test` 错误输出定位到文件与行）→ 定位责任任务（生成物错→T-03/05；引擎错→T-06；用例错→T-08 归因三分类）→ 再处置（修复生成源/修复引擎/登记豁免）。禁止先猜原因。→ ✅ 已挂。
- **V3 增量审查检查点**: 计划改动量大（多模块多文件），按 4 批交付（B1 生成器、B2 引擎与 API、B3 差分修复、B4 发布与示例），每批末一个增量审查检查点（R-1～R-4，单一审查者=主执行者自查+按批验收命令），通过后进下一批。→ ✅ 已挂。

## Surface Coverage Matrix Declaration (MANDATORY)
本计划交付的是**库 API 表面**（非页面/路由）。可寻址表面 = 对外公开函数（.mbti 接口面）：

| Surface | 归属任务 | 证据 |
|---------|----------|------|
| `parse(ua) -> Result[UaInfo, Error]` | T-06 | 差分 18213 用例（T-08）+ robust 用例（T-07） |
| `parse_browser(ua) -> Browser` | T-06 | tests/semantics 单域断言 |
| `parse_os(ua) -> OS` | T-06 | tests/semantics 单域断言 |
| `parse_device(ua) -> Device` | T-06 | tests/semantics 单域断言 |
| `with_rule_index?~` 选项（规则编号） | T-09 | tests/semantics 编号断言（默认关闭时结构不变） |
| mooncakes 包条目（`moon add vicoproplus/moon_ua_parser` 可安装） | T-12 | `moon publish --dry-run` exit 0 [LOCAL_DEAD_LINK 正式发布] |
| examples/middleware 可运行入口 | T-11 | `moon run` exit 0 + 打印解析结果 |
| README quickstart | T-12 | 文档核对（快照版本/通过率/安装三要素） |

M2 结构化归属断言：本库表面清单的机读枚举处 = `.mbti` 接口文件（`moon info` 生成）→ tests/semantics 断言每个公开函数可调用；CI 跑 `moon info` 检测接口面变更。骨架遗产：`moon_ua_parser_lib/` 为脚手架（17 分钟前 moon new 生成），**默认未完成**——其 stub 文件（moon_ua_parser.mbt 141B、test/wbtest stub）将在 T-02 重写，不信任任何预置内容。→ ✅ 矩阵 8 行 = 8 表面，每行有归属与验收。

## Fixture Provenance Declaration (MANDATORY)
- **F1 金样本捕获**: 本计划的外部行为真值源 = uap-core/uap-python 仓库快照（已入库 `./uap-core`、`./uap-python`），非运行时服务端。金样本 = `uap-core/tests/*.yaml`（18213 条，期望值内嵌于用例）与 `uap-core/regexes.yaml`（1270 条规则）。捕获已完成（git 快照固定），无需网络抓取。→ ✅
- **F2 fixture 溯源标注**: 差分用例全部 `golden:uap-core/tests/<file>.yaml`（生成脚本逐条搬运期望值，无手工编造）；robust 用例（空串/超长/控制字符）标注 `synthetic:畸形输入构造`（上游无现成畸形用例清单；其期望语义=确定结果不崩溃，取自 spec V12 uap-python 行为而非臆造输出）。→ ✅
- **F3 合成豁免登记**: robust 用例输入为合成（三类别各 ≥3 例），登记原因：上游 tests YAML 不含专门畸形输入样本；期望值语义来自权威源行为定义（不崩溃、Other fallback），非按本实现反推。→ ✅ 已登记。

## Fix Loop Discipline Declaration (MANDATORY)
B3 批（差分修复）为显式修复轮。验收含 Fix Round Acceptance 表（附于 T-08 验收标准）：
- R1 实证升级：同一缺陷两轮未愈 → 第三轮必须运行时取证（moon test 失败输出 + 最小复现 UA 逐条调试），禁止继续推断式改写。
- R2 类灭绝：每个失败用例类（如「空可选组取组错」「flag-i 失效」「模板 strip 边界」）→ 全量差分集内检索同类失败（按失败模式分组统计），逐个处置或豁免登记 `docs/regex-migration.md`。
- R3 根因追问：每条修复标注 `根因修复`（规则改写/引擎修正）或 `症状修复`（登记根因假设与后续计划）。
→ ✅ 三原则已挂。

## Runtime Acceptance Declaration (MANDATORY)
- **A1 特权状态验收路径**: 本计划无特权状态表面（纯库，无凭证/登录/受保护页面）→ N/A — no privileged-state surfaces.
- **A2 凭证供给协议**: mooncakes 正式发布需账号凭证 → T-12 声明：`moon publish --dry-run` 本机先行；正式 `moon publish` 由用户执行（凭证供给 = 用户 mooncakes 登录态），未发布前该项标 [LOCAL_DEAD_LINK] 不阻塞其余验收。→ ✅
- **A3 批次末运行时走查**: 多批次计划 → 每批末以「运行时走查」替代页面巡览：B1 末跑生成物冒烟（moon check + 规则数核对）、B2 末跑 parse 真实 UA 三例（Chrome/iPhone/Googlebot）、B3 末跑全量差分三后端、B4 末跑 examples + dry-run 发布。→ ✅ 已挂。

## Interface Alignment (MANDATORY)
N/A — this plan touches no endpoints（纯库，无 HTTP 端点/路由；spec §0 运行时环境矩阵已声明 N/A）。

## Spec vs Code Discrepancies (MANDATORY)
| # | spec 值 | plan/仓库现状 | 裁决 |
|---|---------|---------------|------|
| 1 | spec §2 模块路径 `src/ua_parser/`（含 rules 子目录） | 仓库现状：moon 工程位于 `moon_ua_parser_lib/`（moon new 脚手架已建、moon.mod name=vicoproplus/moon_ua_parser 已核实） | ALIGN-REPO：包目录采用 `moon_ua_parser_lib/src/ua_parser/…`（moon.mod 在 moon_ua_parser_lib/ 根，src 为包目录约定）；模块内五文件布局照抄 spec §2 不变。需回写 spec 修订路径前缀（B1 执行时同步） |
| 2 | spec §2 生成目录 `tests/differential/` | 同上，实际为 `moon_ua_parser_lib/tests/differential/`（包内测试目录） | ALIGN-REPO（同 #1，一并回写 spec） |

> 裁决理由：spec 写于 moon 工程创建前，路径无 moon.mod 根上下文；仓库现状（moon.mod 位置）是权威事实。spec 布局的**相对结构**（rules 独立包、differential 生成目录、五文件分层）完全保留。

## Acceptance & Verification Commands (MANDATORY)
```bash
# 全局：所有 moon 命令在 moon_ua_parser_lib/ 下执行
cd moon_ua_parser_lib

# 生成物一致性（B1 末 + CI）
python ../scripts/gen_rules.py && python ../scripts/gen_tests.py && moon check && echo GEN-OK

# 差分测试三后端（B3 门槛）
moon test --target native && moon test --target js && moon test && echo TEST-OK

# 生成物可复现（幂等）
python ../scripts/gen_rules.py && git diff --exit-code -- src/ua_parser/rules/ && echo IDEMPOTENT

# 发布元数据（本机 dry-run）
moon publish --dry-run && echo PUBLISH-READY   # 正式 publish：用户执行 [LOCAL_DEAD_LINK — mooncakes.io 账号凭证]

# 示例运行
moon run --target native examples/middleware && echo EXAMPLE-OK
```

> 门槛数字：browser ≥99%（差分 diff_ua 通过率）、os ≥97%、device ≥97%（差分通过率，统计脚本随 T-08 交付，输出分域通过率表；未达标用例逐条入 docs/regex-migration.md）。CI（T-12）固定 moon 0.1.20260904，跑 moon check + 三后端 moon test + 生成物一致性。

## Spec Coverage Map（FR/US → 任务）

| spec 条目（回链） | 归属任务 |
|-------------------|----------|
| FR-01 ← US-01/02/03/05（parse 主 API） | T-02 types + T-06 engine/api |
| FR-02 ← US-01/05（顺序匹配 + Other） | T-06 |
| FR-03 ← US-01/02/03/05（模板求值） | T-03 预解析 + T-06 求值 |
| FR-04 ← US-03（flag-i） | T-03 标记 + T-04 编译 + T-06 应用 |
| FR-05 ← US-08（构建期转换+版本标注） | T-03 |
| FR-06 ← US-05/08（预编译 fail-loud） | T-04 |
| FR-07 ← US-04（畸形输入） | T-07 |
| FR-08 ← US-07（规则编号选项） | T-09 |
| FR-09 ← US-01/02/03（单域函数） | T-06 |
| FR-10 ← US-01（中间件示例） | T-10 |
| FR-11 ← US-01/02/03/05（差分测试门槛） | T-05 转换 + T-08 修复达标 |
| FR-12 ← US-08（mooncakes 发布） | T-11 元数据 + T-13 发布 |
| G-02/G-03 衍生（归因登记 / README） | T-08 / T-11 |
| US-02（os 信息解析） | FR-02/FR-09 覆盖：T-06（os 域）+ T-05（test_os 483 用例） |
| US-06（爬虫识别 Spider） | FR-02 覆盖：device 规则内置 + T-08 差分（test_device 16129 条含 Spider 期望）+ R-2 走查抽查 |

# Tasks

## B1 — 生成器与数据基线

### T-01 最小编译探针（E5 Task 0）

**Files**: `moon_ua_parser_lib/src/ua_parser/probe.mbt`（临时，探针通过后并入 T-02 清理）

**Steps**
1. 在 `moon_ua_parser_lib/src/ua_parser/` 建 moon.pkg（import moonbitlang/regexp）+ 最小探针：编译 1 条真实 uap-core 规则 `(Chrome)/(\d+)\.(\d+)\.(\d+)\.(\d+) Mobile(?:[ /]|$)` 并 execute 一条 Chrome Mobile UA。
2. 运行 `moon check` + `moon test --target native`，探针绿才进 T-02；失败触发决策门（环境补全/替代方案/问用户），禁止继续。
3. 验收：`moon test --target native` exit 0，探针用例打印/断言 matched()=true。日志：终端输出（探针一次性，无需落盘文件）。

**时长上限**: 15 分钟。

### T-02 types 与包骨架

**Files**: `moon_ua_parser_lib/src/ua_parser/moon.pkg`、`types.mbt`、删除脚手架 stub（`moon_ua_parser.mbt`、`moon_ua_parser_test.mbt`、`moon_ua_parser_wbtest.mbt`、`cmd/`）

**Interfaces**（spec §3 命名约定 + PRD 10.3 数据字典）
- `Browser { family : String; major : String?; minor : String?; patch : String?; patch_minor : String? }`
- `OS { family : String; major : String?; minor : String?; patch : String?; patch_minor : String? }`
- `Device { family : String; brand : String?; model : String? }`
- `UaInfo { browser : Browser; os : OS; device : Device }`
- `UaError`（含 RegexpCompileError(String) 等变体；Show/Eq derive）

（注：T-09 落地时为三域类型末位补 `rule_index : Int?` 字段，交付形态与 PRD 10.3 数据字典一致；T-02 先不写该字段。）

**Steps**
1. read_file spec §3 + PRD 10.3 数据字典，逐字段核对类型与默认值语义（family 未命中="Other"、版本字段 None）。
2. 写 types.mbt 四结构体 + Error 变体；删脚手架 stub 与 cmd/。
3. `moon check && moon fmt`（增量门）；`moon info` 生成 .mbti 骨架。
4. 验收：`moon check` exit 0；.mbti 含四类型定义。日志：终端输出。

**时长上限**: 30 分钟。

### T-03 gen_rules.py 规则转换器 + 生成物

**Files**: `scripts/gen_rules.py`（新，仓库根 scripts/）、`moon_ua_parser_lib/src/ua_parser/rules/`（生成目录：`rules_data.mbt`、`rules_version.mbt`、`moon.pkg`）

**Interfaces**
- 输入：`uap-core/regexes.yaml`（YAML 解析：user_agent_parsers/os_parsers/device_parsers 三节）
- 输出：`rules_data.mbt` — 每条规则一行结构化数据：正则原文 + flag(i) + 预解析模板（family/brand/model/v1-v4 各为 `Array[TemplatePart]`，TemplatePart = Literal(String) | Group(Int)）；`rules_version.mbt` — 快照标注常量（uap-core commit 73e7340 + 日期 2026-08-24）
- 模板预解析语义（spec §3.2）：$1-$4 → Group(n)，其余字面量；转换期校验组号 ≤ 规则捕获组数（越界报错）

**Steps**
1. read_file `uap-python/src/ua_parser/utils.py:8-33`（replacer 语义）+ `uap-python/src/ua_parser/matchers.py:32-56`（UA 模板仅 $1）核对模板形态。
2. 写 gen_rules.py：PyYAML 解析 → 模板预解析 → 生成 MoonBit 数据源码；路径守卫（`../uap-core/regexes.yaml` 不存在即 sys.exit(1) 带信息）；失败日志落盘 `scripts/gen_rules.error.log`。
3. 运行生成；**V2 dry-run**：统计生成规则数（ua 433 / os 204 / device 633，合计 1270，spec V3 核对）；`moon check` 编译生成物。
4. 生成 `rules/moon.pkg`（顶层 let 预编译：lazy init 或 init 块逐条 `@regexp.compile`，flag 规则传 `flags="i"`；失败抛含规则序号的 UaError）。
5. 验收：`python scripts/gen_rules.py && cd moon_ua_parser_lib && moon check` exit 0；生成文件头含「GENERATED — DO NOT EDIT」标记与快照版本。日志：脚本 stdout 规则计数。

**时长上限**: 2 小时（含模板预解析边界调试）。

### T-04 rules 预编译初始化

**Files**: `moon_ua_parser_lib/src/ua_parser/rules/`（T-03 生成 + init 逻辑文件 `rules_init.mbt`——注：此文件为手写，放 rules 包内非生成物，GO 登记表补充注明）

**Steps**
1. 写预编译：三域各 `Array[Regexp]` 顶层构建（spec §2 D8：进程一次、fail-loud）；错误消息含「域 + 规则序号 + 原文片段」。
2. 临时破坏一条规则（本地实验，验证后还原）验证 fail-loud 消息可定位。
3. `moon test --target native`（初始化在测试装载时执行，隐式验证）。
4. 验收：moon test exit 0（1270 条全编译，spec V8 预证 0 失败）；人为损坏实验的错误输出含规则定位（附入任务记录）。日志：终端输出。

**时长上限**: 45 分钟。

### T-05 gen_tests.py 差分用例转换器

**Files**: `scripts/gen_tests.py`（新）、`moon_ua_parser_lib/tests/differential/`（生成目录：`diff_ua.mbt`、`diff_os.mbt`、`diff_device.mbt`、`moon.pkg`）

**Steps**
1. read_file `uap-core/tests/test_ua.yaml:1-63` / `test_os.yaml:1-43` / `test_device.yaml:1-58`（V13 字段清单）核对用例字段。
2. 写 gen_tests.py：YAML → 三文件 moon test 用例（每域一 test 块内循环断言：输入 UA → 期望 family/版本/brand/model 逐字段比对；None 语义 = 空字段）；UTF-8 与特殊字符转义处理（YAML 单引号 '' → '）；用例数核对 1601/483/16129。
3. **V2 dry-run**：生成后 `moon check`（用例引用 T-06 API，此时以最小桩先占位编译——桩在 T-06 被真实现替换，桩仅签名无逻辑，标记 // STUB for compile）。
4. 验收：生成用例总数 = 18213；`moon check` exit 0。日志：脚本 stdout 分域计数。

**时长上限**: 2 小时。

### R-1 B1 增量审查检查点（V3）

- 审查项：spec 覆盖（FR-05/06 对应 T-03/04 完整）/ 可执行（无占位）/ 一致性（types 与 rules 数据结构自洽）/ 测试（探针+生成物编译绿）。
- 走查（A3）：`moon check` + 生成物计数核对 + gen 脚本幂等（`python scripts/gen_rules.py && git diff --exit-code` 对生成目录）。
- 通过后进 B2。失败项回 B1 对应任务修复（修复轮纪律生效）。

## B2 — 引擎与 API

### T-06 匹配引擎 + 主 API

**Files**: `moon_ua_parser_lib/src/ua_parser/template.mbt`、`matcher.mbt`、`engine.mbt`、`api.mbt`

**Interfaces**
- `parse(ua : String) -> Result[UaInfo, UaError]`
- `parse_browser(ua : String) -> Browser`
- `parse_os(ua : String) -> OS`
- `parse_device(ua : String) -> Device`

**Steps**
1. **回读门（Authority Re-Read）**：逐条 read_file 权威源（见 Authority Alignment Table 五行）核对语义后再实现——basic.py 顺序首条命中、utils.py replacer、user_agent_parser.py 三 Parser、matchers.py flag-i。
2. template.mbt：预解析模板求值（组号取值 + strip 两端空白 + 空串→None）；组未参与匹配 → None（对齐 lastindex 语义）。
3. engine.mbt：三域循环 rules、首条命中生效、全不命中 → Other fallback（family="Other"、版本/brand/model=None）。
4. api.mbt：parse 聚合三域；单域三函数；`with_rule_index?~` 选项（T-09 前先不含选项，T-09 加；该任务同时在三域类型末位补 `rule_index : Int?` 字段）。
5. 增量门：`moon check && moon fmt && moon test --target native`（此时差分用例大部分红——正常，B3 修复；本任务验收只看编译绿 + semantics 用例绿）。
6. 验收：`moon check` exit 0；tests/semantics 手写用例（Chrome 桌面三域、Other fallback、模板替换 ArcGIS 例）绿。日志：终端输出。

**时长上限**: 3 小时。

### T-07 语义与健壮用例（tests/semantics + robust）

**Files**: `moon_ua_parser_lib/tests/semantics/*.mbt`（手写）、`tests/robust.mbt`

**Steps**
1. semantics：替换模板（$1/$2 组合、strip、空串→None）、Other fallback（`fakeLuminary/1.0`→Other，golden:uap-core/tests/test_ua.yaml:62）、flag-i 大小写变体、单域函数与 parse 一致性、同输入多次 parse 确定性（spec §4.9 B2）。
2. robust（synthetic 登记，见 Fixture 节）：空串、>4096 字符构造串、含控制字符 \x00-\x1f 样本，各 ≥3 例；断言：不崩溃、返回确定结果（Other 或 Err）。
3. 验收：`moon test --target native tests/semantics robust` 全绿；超长用例完成 <1s。日志：终端输出。

**时长上限**: 1.5 小时。

### R-2 B2 增量审查 + 走查

- 走查：真实 UA 三例手跑（Chrome 桌面 / iPhone / Googlebot → device.family=Spider）通过 `moon run` 临时入口或单测打印；types/API/引擎一致性复查。
- 通过后进 B3。

## B3 — 差分修复

### T-08 差分执行与归因修复

**Files**: `docs/regex-migration.md`（新，归因登记）、`scripts/gen_rules.py`（规则改写表，如需）、`uap-core` 快照**不改**（改写只发生在生成源）

**Steps**
1. 跑 `moon test --target native` 全量差分；统计脚本（并入 gen_tests.py 或独立 `scripts/diff_stats.py`）输出分域通过率表。
2. 失败用例逐条归因三分类（spec §3 D6）：引擎语义差（改写规则入 gen_rules.py 改写表）/ 上游笔误（改写+记录）/ 已知难点（豁免登记，计入分母）。
3. 修复轮纪律（R1/R2/R3）：同类失败按模式分组全量排查；两轮未愈第三轮运行时取证（最小复现 UA + 失败断言逐条调试）。
4. 循环至门槛：browser ≥99% / os ≥97% / device ≥97%；未达标不进 B4。
5. **Fix Round Acceptance 表**（每缺陷类一行）：

| 缺陷实例 | 本轮处置 | 实证证据 | 同类排查结果（检索式+清单/处置/豁免） | 修复性质 |
|----------|----------|----------|---------------------------------------|----------|
| <逐条填写> | <改写/引擎修正/豁免> | <moon test 输出+最小复现> | <失败模式分组统计+逐项处置> | <根因/症状+登记> |

6. 验收：三后端 `moon test` 全绿至门槛；`docs/regex-migration.md` 每条失败用例有归因行；分域通过率写入（B4 转 README）。日志：`scripts/diff_stats.py` 输出留存 `docs/regex-migration.md` 附录。

**时长上限**: 6 小时（可分多轮，每轮后保存进度）。

### T-09 规则编号选项

**Files**: `moon_ua_parser_lib/src/ua_parser/api.mbt`、tests/semantics

**Steps**
1. `parse(ua, with_rule_index?~ : Bool)`：启用时结果携带三域命中规则序号（域内 0 起，落为 `Browser`/`OS`/`Device` 末位的 `rule_index : Int?` 字段，未启用为 `None`）；默认关闭调用签名不变（.mbti 兼容检查：默认调用签名不变）。
2. semantics 断言：Chrome UA 启用选项返回编号；不启用时 UaInfo 结构与之前一致。
3. 验收：`moon check && moon test --target native` 绿；`moon info` diff 确认无破坏性接口变更（新增可选参数为向后兼容）。日志：终端输出。

**时长上限**: 45 分钟。

### R-3 B3 审查 + 三后端门槛验收

- 全量 `moon test --target native && moon test --target js && moon test`；分域通过率达标核对；regex-migration.md 归因完整性审查。通过后进 B4。

## B4 — 发布与示例

### T-10 examples/middleware 示例

**Files**: `moon_ua_parser_lib/examples/middleware/`（moon.pkg executable + main.mbt）

**Steps**
1. 写最小中间件风格示例：模拟请求入口数组（3 条真实 UA），逐条 parse 并打印 browser/os/device 摘要（含一条 Spider 判定展示）。
2. 验收：`moon run --target native examples/middleware` exit 0 且打印三例解析结果。日志：终端输出。

**时长上限**: 1 小时。

### T-11 moon.mod 元数据 + README

**Files**: `moon_ua_parser_lib/moon.mod`、`README.mbt.md`

**Steps**
1. moon.mod 补全：description（UA 解析库，uap-core 快照移植）、repository（github.com/vicoproplus/moon_ua_parser）、keywords（user-agent、ua-parser、http、parser）、version 0.1.0 已有。
2. README：quickstart（moon add + parse 示例，可复制运行）、快照版本标注（uap-core@73e7340）、分域差分通过率（取自 T-08 统计）、致谢与 Apache-2.0/NOTICE（uap-core/uap-python 参考，申报书 §移植说明）。
3. 验收：`moon publish --dry-run` exit 0；README 三要素齐（安装/版本/通过率）。日志：终端输出。

**时长上限**: 45 分钟。

### T-12 CI 工作流

**Files**: `.github/workflows/ci.yml`（仓库根 .github/——注意当前 .git 在仓库根，moon 工程在 moon_ua_parser_lib/ 子目录）

**Steps**
1. CI：checkout → 安装 moon 0.1.20260904 → `cd moon_ua_parser_lib && moon check && moon test --target native && moon test --target js && moon test` + 生成物一致性（gen 脚本 + git diff --exit-code 生成目录）。
2. Python 步骤：装 pyyaml → 跑 gen 脚本（幂等核对）。
3. 验收：本机模拟命令序列全绿（CI 线上首跑由用户观察，[LOCAL_DEAD_LINK 不适用——命令本机可全跑]）。日志：终端输出。

**时长上限**: 45 分钟。

### T-13 正式发布（用户执行）

**Files**: 无新文件

**Steps**
1. 用户登录 mooncakes（`moon login` 或 credentials）→ `cd moon_ua_parser_lib && moon publish`。
2. 验证：mooncakes.io 页面出现 vicoproplus/moon_ua_parser@0.1.0；独立目录 `moon add` + import 冒烟。
3. `[LOCAL_DEAD_LINK — mooncakes 账号凭证]`：正式 publish 与页面可见性由用户在有凭证环境执行并回报；本机已 dry-run 达标。

### R-4 终审（Self-Review 第二视角）

- 表面覆盖矩阵逐行确认（8 表面×归属任务×证据）；抽样 2 个表面真实走查：`parse`（差分全量）+ `moon run examples`。
- spec↔plan 逐条比对 + Authority/Traceability 表复核（见文末两表）。
- 通过率数字与 README 一致性核对；全部验收命令复跑一遍留最终证据。

---

# Authority Alignment Table

| 决策点 | 权威位置（文件:行号:方法） | plan 结论 | 是否一致 |
|--------|---------------------------|-----------|----------|
| 三域顺序首条命中 | `uap-python/src/ua_parser/basic.py:55-83` `Resolver.__call__` | engine 按域循环 rules，首条命中生效，全不命中 Other | ✅ 一致 |
| OS/Device 模板求值（$N/strip/空→None） | `uap-python/src/ua_parser/utils.py:12-33` `replacer`；`uap-python/src/ua_parser/user_agent_parser.py:126-135` `MultiReplace` | template.mbt 同语义（预解析组号，运行时求值+strip+空串 None） | ✅ 一致 |
| UA 家族仅 $1 + 版本取组 2/3/4/5（lastindex 防越界） | `uap-python/src/ua_parser/matchers.py:41-52` `UserAgentMatcher.__call__`（major/minor/patch/patch_minor 无模板取组 2/3/4/5） | UA 族模板仅 $1 替换或字面量；v1-v4 无模板取组 2/3/4/5（patch_minor ← 组 5），未参与即 None | ✅ 一致 |
| OS 四段版本（含 v4） | `uap-python/src/ua_parser/user_agent_parser.py:95-123` `OSParser.Parse` | OS 版本四段同构（major/minor/patch/patch_minor） | ✅ 一致 |
| device flag-i（65 条） | `uap-python/src/ua_parser/matchers.py:150-152` `DeviceMatcher.__init__`（IGNORECASE） | 生成时标记 flag，编译传 `flags="i"` | ✅ 一致 |
| device brand 无模板时为空串→None | `uap-python/src/ua_parser/matchers.py:153-165` `DeviceMatcher.__call__`（`brand or ""` + replacer） | brand 无模板 → None；有模板求值后空串 → None | ✅ 一致 |
| 未命中 fallback（family=Other） | `uap-python/src/ua_parser/basic.py:60-83`（next(...,None)→None→上层 Other）+ uap-core 测试期望 | 三域全不命中 → family="Other"、版本/brand/model=None | ✅ 一致 |

# Spec-Decision Traceability Table

| 决策点 | spec 位置 | plan 取值 | 仓库现状（文件:行号） | 是否一致 | 裁决 |
|--------|-----------|-----------|----------------------|----------|------|
| 依赖 regexp 版本 | spec §3 / V8 | moonbitlang/regexp@0.3.5 | `moon_ua_parser_lib/moon.mod:28-30` import 块（moon add 落地实测） | ✅ 一致 | — |
| 模块布局（五文件+rules） | spec §2 | types/template/matcher/engine/api + rules 生成目录 | 仓库为脚手架空壳，按 spec 新建（相对结构保留，路径前缀差异见 Discrepancies #1/#2） | ✅ 一致（路径 ALIGN-REPO 回写 spec） | ALIGN-REPO |
| 生成目录与权威命令 | spec §2 GO 登记表 | `python scripts/gen_rules.py` / `gen_tests.py`；全量覆盖重建；禁手改 | scripts/ 尚不存在（T-03/05 新建） | ✅ 一致 | — |
| API 命名（parse/parse_browser/parse_os/parse_device） | spec §3 命名约定 | 同名四函数 + `with_rule_index?~` | 无既有实现（新建） | ✅ 一致 | — |
| 差分门槛 99/97/97 | spec §4.3 维度 1 | 同值（统计脚本输出核对） | 上游 18213 条全量转换 | ✅ 一致 | — |
| 三后端 native/js/wasm | spec §0 运行时矩阵 + §4.3 维度 5 | `moon test --target native/js/默认(wasm)` | moon preferred_target="wasm"（`moon_ua_parser_lib/moon.mod:24`） | ✅ 一致 | — |
| mooncakes 包名 vicoproplus/moon_ua_parser | spec §4.2 S-12 | 同名 | `moon_ua_parser_lib/moon.mod:12` name 已核实 | ✅ 一致 | — |

---

## Execution Handoff
- Spec authority = rules/contracts/architecture（`docs/superpowers/spec/2026-09-10-moon_ua_parser.md`）；Plan authority = execution flow/schedule/checkpoints（本文件）。
- PRD：`docs/superpowers/prd/2026-09-10-moon_ua_parser.md`；设计：`docs/superpowers/design/2026-09-10-moon_ua_parser.md`。
- 契约/架构无未决项；spec 路径差异（Discrepancies #1/#2）已裁决 ALIGN-REPO 并排入 B1 回写 spec 的动作（T-03 完成后同步修订 spec §2 路径，保持文档链一致）。
