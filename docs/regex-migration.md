# 正则迁移与差分归因登记（T-08）

状态：差分套件 **三域 0 断言失败**（native/js）；分域通过率 browser **98.75%**（门槛 99%，
**NOT-MET**，见 §6 升级记录）/ os **100%** / device **100%**。
引擎与 uap-python 在全部 **18213/18213** 用例上输出一致（三栏审计，§4）。

- 快照：uap-core@73e7340（regexes.yaml 规则 1270 条生效：ua 433 / os 204 / device 633，
  65 条 device 规则带 flag i）；差分用例 18213 条（ua 1601 / os 483 / device 16129）。
- 语义权威：uap-python（只读快照，`uap-python/src`，modern matcher `Parser(Resolver(load_yaml(...)))`）。
- 工具链：moon 0.1.20260904；moonbitlang/regexp@0.3.5；Python 3.12.10 + PyYAML 6.0.2。
- 生成器：`scripts/gen_tests.py`（差分套件）、`scripts/gen_rules.py`（规则，本轮**零改动**）；
  豁免：`scripts/test_exemptions.json`；统计：`moon run --target native --release tests/diffstats`。

## 1. 生成器缺陷根因修复（本轮第 0 项）

**缺陷**：T-05 生成的差分断言把期望值（`String?`）直接插值进断言串，
实际值（引擎 `family:String` + `String?`）按原始串插值，两侧渲染不对称：
每个用例第一个断言即失败 `"0|Luminary/1.0|family=Some(Luminary)" != "0|Luminary/1.0|family=Luminary"`，
三个域全红、且与语义无关。

**修复（根因修复，`scripts/gen_tests.py`）**：期望与实际两侧统一经
`<domain>_render_opt` 渲染为**纯字符串**（`Some(s)`→`s`；`None`→`<none>`），
重新生成三份差分文件。修复后真实失败集首次可见：**ua 域 20 条，os/device 域 0 条**。

## 2. 测试宿主重构：collect-all-then-assert

原"每域一个 test 块 + 逐用例 assert_eq"在首个失败处中止，其后全部失败被掩盖。
重构为（`scripts/gen_tests.py`，根因修复）：

- 每域生成 `pub fn <domain>_failures() -> Array[String]`：遍历**全部**用例，
  逐字段收集失配消息 `<domain>[<i>] field=<f> expected=<e> got=<g> input=<ua>`；
  豁免用例跳过（计入 `<domain>_exempted_count`）。
- test 块仅在失败列表非空时打印（绿运行静默），随后断言列表为空 ——
  一次失败运行列出该域**全部**失配，支撑按"失败模式"分组归因。
- `tests/diffstats`（可执行包）复用同一数据输出分域通过率与失败分组计数（§5/附录 A）。

## 3. 修复轮验收表（Fix Round Acceptance）

| 缺陷实例 | 本轮处置 | 实证证据 | 同类排查结果（检索式+清单/处置/豁免） | 修复性质 |
|----------|----------|----------|---------------------------------------|----------|
| 断言格式缺陷：期望侧 `Option` 包装泄入断言串，三域全红 | 生成器改纯字符串渲染（`<none>` 哨兵）+ 全量重生成 | 修复前首断言 `"family=Some(Luminary)" != "family=Luminary"`；修复后真实失败集 = ua×20、os×0、device×0 | 三域共用同一渲染路径，一处修复覆盖全部；无其他插值点（检索 `assert_eq`/`\{c.` 于 gen_tests.py） | 根因修复 |
| 失败可见性缺陷：首个失败即中止，无法按模式归因 | collect-all-then-assert 宿主重构 + `<domain>_failures()` 数据钩子 | 重构后单次运行列出全部 20 条 ua 失配（全为 `field=patch_minor`） | 三域统一生成同一宿主结构；豁免跳过与 exempted_count 保留 | 根因修复 |
| ua×20 `field=patch_minor expected=<none> got=<值>`（唯一真实失败模式，2 轮观察稳定） | 豁免登记（`scripts/test_exemptions.json`，逐条证据 §4）；引擎**零改动** | 三栏审计：同一 20 例上 uap-python 与本引擎输出**逐字段一致**、与 golden 矛盾（uap-core#562；uap-python 自家测试对该 YAML pop 掉 patch_minor，test_core.py:94-97） | 三栏审计覆盖全部 18213 用例（§4）：golden-vs-uap 冲突**恰好且仅**这 20 个字段；os/device 零冲突 → 无漏网同类 | 根因=上游数据不一致（非本仓代码）；处置=症状零修复、证据豁免+登记 |

轮次纪律说明：失败模式仅 1 类（patch_minor），第 1 轮即完成模式分组全量排查 +
uap-python 对照取证；无需进入第 3 轮运行时取证。

## 4. 归因登记（spec §3 D6 三分类，逐用例）

**类别统计**：(a) 引擎语义差 = **0**；(b) 上游笔误 = **20**；(c) 已知难点 = **0**。

**类别 (b) 判定依据（对所有 20 例同一证据链）**：

1. 以权威实现复算（与生成规则同一 `uap-core/regexes.yaml`）：
   `Parser(Resolver(load_yaml('uap-core/regexes.yaml')))`（`uap-python/src`）。
2. 例证 ua[1543]（`...Chrome/116.0.5845.114 Safari/537.36 115Browser/35.2.0.3`）：
   golden `patch_minor` 缺省，uap-python 返回
   `UserAgent(family='115 Browser', major='35', minor='2', patch='0', patch_minor='3')`，
   本引擎输出完全一致（其余 19 例同理，见下表，第 5 列即权威输出）。
3. 权威自身放弃对该 YAML 断言 patch_minor——`uap-python/tests/test_core.py:94-97`：
   ```python
   # there seems to be broken test cases which have a patch_minor
   # of null where it's not, as well as the reverse, so we can't
   # test patch_minor (ua-parser/uap-core#562)
   res.pop("patch_minor", None)
   ```
4. 反向核对：golden 中 41 条**非空** patch_minor 期望本引擎全部通过 →
   引擎 group-5 回退语义正确；20 条 golden 缺省但权威产出非空 → 数据矛盾，
   类别 (b) 成立。上游快照按 R8 冻结，不修改 uap-core/uap-python。

**逐用例登记**（期望列 golden；权威列 uap-python 输出 `family/major/minor/patch[ /patch_minor]`；
本引擎输出与权威逐字段一致）：

| 用例 | 字段 | golden | golden(fam/maj/min/patch) | uap-python（=本引擎） | 类别 | 处置 |
|------|------|--------|---------------------------|------------------------|------|------|
| ua[32] | patch_minor | `<none>` | `Baidu Explorer`/`6`/`12`/`3` | `Baidu Explorer`/`6`/`12`/`3`/`32` | (b) 上游笔误 | 豁免登记 |
| ua[33] | patch_minor | `<none>` | `Baidu Explorer`/`15`/`8`/`0` | `Baidu Explorer`/`15`/`8`/`0`/`10` | (b) 上游笔误 | 豁免登记 |
| ua[53] | patch_minor | `<none>` | `VivoBrowser`/`11`/`1`/`0` | `VivoBrowser`/`11`/`1`/`0`/`1` | (b) 上游笔误 | 豁免登记 |
| ua[55] | patch_minor | `<none>` | `HiBrowser`/`2`/`10`/`1` | `HiBrowser`/`2`/`10`/`1`/`2` | (b) 上游笔误 | 豁免登记 |
| ua[56] | patch_minor | `<none>` | `HiBrowser`/`2`/`25`/`7` | `HiBrowser`/`2`/`25`/`7`/`1` | (b) 上游笔误 | 豁免登记 |
| ua[1543] | patch_minor | `<none>` | `115 Browser`/`35`/`2`/`0` | `115 Browser`/`35`/`2`/`0`/`3` | (b) 上游笔误 | 豁免登记 |
| ua[1544] | patch_minor | `<none>` | `Avira`/`131`/`0`/`0` | `Avira`/`131`/`0`/`0`/`0` | (b) 上游笔误 | 豁免登记 |
| ua[1545] | patch_minor | `<none>` | `CCleaner`/`131`/`0`/`0` | `CCleaner`/`131`/`0`/`0`/`0` | (b) 上游笔误 | 豁免登记 |
| ua[1546] | patch_minor | `<none>` | `Norton`/`131`/`0`/`0` | `Norton`/`131`/`0`/`0`/`0` | (b) 上游笔误 | 豁免登记 |
| ua[1558] | patch_minor | `<none>` | `Atom Browser`/`26`/`0`/`0` | `Atom Browser`/`26`/`0`/`0`/`0` | (b) 上游笔误 | 豁免登记 |
| ua[1564] | patch_minor | `<none>` | `AOL Shield Browser`/`123`/`0`/`6312` | `AOL Shield Browser`/`123`/`0`/`6312`/`6` | (b) 上游笔误 | 豁免登记 |
| ua[1571] | patch_minor | `<none>` | `Sber Browser`/`21`/`0`/`0` | `Sber Browser`/`21`/`0`/`0`/`0` | (b) 上游笔误 | 豁免登记 |
| ua[1574] | patch_minor | `<none>` | `HeyTap Browser`/`45`/`13`/`4` | `HeyTap Browser`/`45`/`13`/`4`/`1` | (b) 上游笔误 | 豁免登记 |
| ua[1575] | patch_minor | `<none>` | `HeyTap Browser`/`45`/`13`/`5` | `HeyTap Browser`/`45`/`13`/`5`/`0` | (b) 上游笔误 | 豁免登记 |
| ua[1576] | patch_minor | `<none>` | `HeyTap Browser`/`45`/`13`/`6` | `HeyTap Browser`/`45`/`13`/`6`/`1` | (b) 上游笔误 | 豁免登记 |
| ua[1577] | patch_minor | `<none>` | `Honor Browser`/`9`/`6`/`0` | `Honor Browser`/`9`/`6`/`0`/`4` | (b) 上游笔误 | 豁免登记 |
| ua[1578] | patch_minor | `<none>` | `Honor Browser`/`9`/`6`/`0` | `Honor Browser`/`9`/`6`/`0`/`4` | (b) 上游笔误 | 豁免登记 |
| ua[1579] | patch_minor | `<none>` | `Honor Browser`/`3`/`0`/`9` | `Honor Browser`/`3`/`0`/`9`/`303` | (b) 上游笔误 | 豁免登记 |
| ua[1580] | patch_minor | `<none>` | `Honor Browser`/`3`/`1`/`3` | `Honor Browser`/`3`/`1`/`3`/`303` | (b) 上游笔误 | 豁免登记 |
| ua[1585] | patch_minor | `<none>` | `Odin`/`111`/`5563`/`5` | `Odin`/`111`/`5563`/`5`/`1` | (b) 上游笔误 | 豁免登记 |

豁免登记：`scripts/test_exemptions.json`
`{"ua":[32,33,53,55,56,1543,1544,1545,1546,1558,1564,1571,1574,1575,1576,1577,1578,1579,1580,1585],"os":[],"device":[]}`
（0-based YAML 下标；生成的 diff_ua.mbt 头部列出同一下标，`ua_exempted_count = 20`）。

## 5. 三栏审计（golden × uap-python × 本引擎）

方法：对 uap-core 全部 18213 用例，用权威实现逐域复算并与 golden 逐字段比对
（脚本同 §4 判定依据；等价于对齐 uap-python `test_core.py` 的做法但**保留** patch_minor）。

| 域 | 用例数 | golden-vs-uap 字段冲突 | 本引擎-vs-uap 冲突 | 结论 |
|----|--------|------------------------|--------------------|------|
| ua | 1601 | 20（恰为 §4 表） | 0 | 引擎==权威 1601/1601 |
| os | 483 | 0 | 0 | 引擎==权威 483/483 |
| device | 16129 | 0 | 0 | 引擎==权威 16129/16129 |

即：差分红集与"golden 违背权威"的集合**完全重合**，不存在被 golden 掩盖的引擎分歧。

## 6. 门槛核算与升级记录（ruling 9）

| 域 | total | exempted | failed | passed | rate | 门槛 | 判定 |
|----|-------|----------|--------|--------|------|------|------|
| browser | 1601 | 20 | 0 | 1581 | **98.75%** | ≥99% | **NOT-MET** |
| os | 483 | 0 | 0 | 483 | **100.00%** | ≥97% | MET |
| device | 16129 | 0 | 0 | 16129 | **100.00%** | ≥97% | MET |

核算口径（ruling 4）：`rate = passed / total`，exempted 计入分母、既非通过也非失败。
因此 20 条证据豁免使 browser 卡在 98.75%：达到 99% 只能靠 (i) 令引擎偏离权威
（违反 R3/R4，且会破坏 semantics 套件中已验证的 group-5 保真），或 (ii) 改动核算口径。
按 ruling 9 **不作假**：登记全部证据、上报 BLOCKED（缺口 4 例 = 0.25pp），由 controller 裁决。
可选项已呈报：(A) 维持现状接受 98.75%（本报告口径）；(B) 采纳 uap-python 自身对
test_ua.yaml 的测试策略（pop patch_minor，见 §4 证据 3），差分即 1601/1601=100% MET，
但会放弃 golden 中 41 条非空 patch_minor 断言（patch_minor 保真仍由 semantics 单测直接覆盖）。

## 7. 验证输出

- 差分（native, release）：`moon test --release --target native -p vicoproplus/moon_ua_parser/tests/differential`
  → `Total tests: 3, passed: 3, failed: 0.`（20 条豁免跳过计入 ua_exempted_count）。
- 分域率表：`moon run --target native --release tests/diffstats`（附录 A）。
- 运行时说明：差分成本由 moonbitlang/regexp 虚拟机主导（18213 用例 × 首中即停的规则扫描）；
  release 约 7 分钟、debug 约 17 分钟（native，全量 27 test 块实测 1015s）。门槛验证采用
  release；debug 全量另行执行、同绿。
- wasm：本机 wasm **运行**被环境阻断（0xc0000139，controller 已裁定 environmental），
  本任务以 `moon build --target wasm` 构建通过为本地门槛；wasm 运行时验证由 CI（T-12）承担。
- js：`moon test --release --target js` 全绿（附录 B）。

## 附录 A：diffstats 输出（留存）

```text
domain	total	exempted	passed	failed	rate	gate	status
browser	total=1601	exempted=20	passed=1581	failed=0	rate=98.75%	gate>=99.00%	NOT-MET
os	total=483	exempted=0	passed=483	failed=0	rate=100.00%	gate>=97.00%	MET
device	total=16129	exempted=0	passed=16129	failed=0	rate=100.00%	gate>=97.00%	MET
browser failure groups: (none)
os failure groups: (none)
device failure groups: (none)
GATES: NOT ALL MET (see rows above)
```

（豁免生效后失败分组为空；豁免前的失败分组清单见 §3 第 3 行与 §4 表：
单一模式 `field=patch_minor expected=<none> got=<值>`，n=20。）

## 附录 B：全量测试（native/js）与 wasm 构建（实测留档）

| 命令（moon_ua_parser_lib/ 下） | exit | 耗时 | 结果 |
|--------------------------------|------|------|------|
| `moon test --release --target native` | 0 | 303s | `Total tests: 27, passed: 27, failed: 0.` |
| `moon test --release --target js` | 0 | 128s | `Total tests: 27, passed: 27, failed: 0.` |
| `moon test --target native`（debug，默认模式） | 0 | 1015s | `Total tests: 27, passed: 27, failed: 0.` |
| `moon build --target wasm` | 0 | 3s | 构建通过（wasm 运行 = 环境阻断 0xc0000139，CI 承担） |
| `moon test --target js`（debug，默认模式） | 0 | 101s | `Total tests: 27, passed: 27, failed: 0.` |

27 = 差分 3 块（ua/os/device）+ semantics + robust + rules 初始化等全部 test 块。

