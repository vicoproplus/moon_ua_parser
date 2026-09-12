# 正则兼容性 spike 证据 — 现快照抽样验证（T-02）

- **日期**：2026-09-13
- **快照**：uap-core@**73e7340**（vendored，date 2026-08-24；`rules_version.mbt` 常量与
  `scripts/gen_rules.py` 头部常量一致）。T-01 决策门（`docs/evidence/snapshot-bump-2026-09-13.md`）
  裁定「上游无新 commit（HEAD=73e7340=vendored baseline）」→ 按 plan T-01 step 5，本 spike
  从「验证新快照」改为**抽样验证现快照**。
- **工具链**：moon 0.1.20260904；moonbitlang/regexp@0.3.5；Python 3.12.10 + PyYAML 6.0.2（Windows x64）。
- **结论先行**：可编译率 **1270/1270 = 100.00%**（与 v0.1 基线完全一致）；不可编译清单：**空**；
  改写方案清单：**空**；决策门：0.00% ≤ 2% → **无需改写、无需上报**。

## 1. 方法（两翼互证）

1. **静态翼（生成器编译路径镜像）**：在仓库外临时目录用 Python+PyYAML 解析
   `uap-core/regexes.yaml`，对全部 pattern 逐条执行与 `scripts/gen_rules.py` 相同的
   `re.compile(pattern, import_flags)` 校验与 `$N` 模板引用越界检查，并按语法特征类清点。
   脚本位于系统临时区（`%LOCALAPPDATA%\Temp\regex-compat-spike-20260913\feature_scan.py`），
   未入仓库；特征类的判定正则已收录在 §3.5 表中，可复现。
2. **真编译翼（rules init 层全量触发）**：`rules_init.mbt`（手写层）在运行时用
   moonbitlang/regexp@0.3.5 对 `rules_data.mbt` 中全部 1270 条 pattern 逐条 `mapi` 编译；
   任一失败即 `abort` 并输出 domain+index+pattern（FR-06 fail-loud）。`rules_init_test.mbt`
   访问三个预编译数组即强制全量初始化，因此该测试运行 **= 全量 1270 条的真编译验证**。
3. **差分抽样翼**：os 域差分块单跑（483 用例），交叉证明编译产物在真实匹配语义上仍然正确。

## 2. 命令与输出摘录

### 2.1 真编译验证（触发 rules init 层）

```
$ cd moon_ua_parser_lib && moon test --target native -p src/ua_parser/rules
Total tests: 4, passed: 4, failed: 0.
（real 0m9.9s；4 个 test 块 = ua_regexps 433 / os_regexps 204 / device_regexps 633
  三数组长度断言 + ua_regexps[0] 可用性检查）
```

判定语义：`inspect` 断言三数组长度恰为 433/204/633，且数组初始化对每条 pattern 调用
`compile_rule`；任何一条编译失败会以
`ua_parser: failed to compile <domain> rule[<index>]: …` abort 使运行失败。
**通过 ⟺ 1270/1270 全部可编译。**

### 2.2 差分域抽样（os 域）

```
$ cd moon_ua_parser_lib && moon test --target native -p tests/differential -f "differential os*"
Total tests: 1, passed: 1, failed: 0.
（real 0m6.2s；即 test_os.yaml 483/483 用例全绿，0 豁免）
```

（取证注记：首次尝试用 `-f diff_os.mbt` 过滤——本版 moon 的 `-f` 是**测试名 glob** 而非
文件过滤——0 用例执行、无判定意义，已改用测试名 glob `differential os*` 重跑。）

### 2.3 静态特征清单（生成器编译路径镜像，scratch 脚本）

```
$ python <scratch>/feature_scan.py
per-domain counts: {'user_agent_parsers': 433, 'os_parsers': 204, 'device_parsers': 633}
total patterns: 1270
flag-i patterns: 65
longest pattern: 2495 chars (user_agent_parsers[51])
python-re compile failures: 0
$N group-bound violations: 0
```

（完整特征类计数见 §3.5。）

### 2.4 生成器试运行 + 幂等断言（取证；T-02 不要求再生）

```
$ python scripts/gen_rules.py
uap-core snapshot: commit 73e7340, date 2026-08-24
user_agent_parsers  :  433 rules (0 with flag i)
os_parsers          :  204 rules (0 with flag i)
device_parsers      :  633 rules (65 with flag i)
total               : 1270 rules
OK
```

幂等断言：`git status --porcelain moon_ua_parser_lib/src/ua_parser/rules
moon_ua_parser_lib/tests/differential` 首查**非空**（三个生成文件被标 `M`）→
按 brief 规定停下查因，取证结论为**非内容漂移**，恢复现场后复查为**空**：

- 诊断：本机 `core.autocrlf=true` 且仓库无 `.gitattributes`。HEAD blob 为 LF，git 检出时把
  工作区文件物化为 CRLF；生成器以 `newline="\n"` 写出 LF → 仅行尾翻转触发 status 的 `M` 标记。
- 内容级证明：`git diff` 无任何内容行；且三个新写出文件与 HEAD blob 的 sha256 **逐字节一致**
  （`sha256sum` 直读文件 vs `git cat-file -p HEAD:<path>`，不经任何过滤）：
  - `moon.pkg`          `97166f6b2ff06c324a1fe2597f002f4f190e425518bd84650956427e5f5a6ed1`
  - `rules_data.mbt`    `6dbb4d6fa95bc0b655fd842096c249b7b60338da75cc10b7c5e3364f5bafe176`
  - `rules_version.mbt` `6399c2b1a54739e05166c35b04e6fc2bb721035cfdda4a64212a015c4fa6e7b6`
- 处置：`git restore` 三个文件回到检出态（撤销本次试运行引入的行尾翻转），复查
  `git status --porcelain`（rules + differential 范围及全树）均为空。**仓库零改动。**
- 与 v0.1 台账「幂等性：byte-identical（git 干净）」的口径差异 = 上述 autocrlf 环境伪差，
  非 `regexes.yaml → rules_data.mbt` 内容漂移。

## 3. 数据

### 3.1 规模核对（快照一致性）

| 域 | 规则数 | flag i | 来源核对 |
|----|-------:|-------:|----------|
| ua (`user_agent_parsers`) | 433 | 0 | 静态扫描 = 生成器 = `rules_data.mbt` = v0.1 台账 |
| os (`os_parsers`) | 204 | 0 | 同上 |
| device (`device_parsers`) | 633 | 65 | 同上 |
| **合计** | **1270** | **65** | 一致，无漂移 |

### 3.2 可编译率（对比 v0.1 基线）

| 验证翼 | 口径 | 结果 | 可编译率 |
|--------|------|------|---------:|
| 真编译（rules init 层，moonbitlang/regexp@0.3.5） | 全量 1270 条逐条编译，失败即 abort | 4/4 test 通过，无 abort | **1270/1270 = 100.00%** |
| 静态（Python `re`，生成器同款调用） | 全量 1270 条逐条编译 + `$N` 越界检查 | 0 失败、0 越界 | 1270/1270 = 100.00% |
| **v0.1 基线**（`docs/regex-migration.md` 头部） | 同上双翼 + 18213 差分全绿 | 100% 编译 1270 条 | **100.00%** |

结论：现快照可编译率与 v0.1 基线**完全一致（100.00%，1270/1270）**，无退化。

### 3.3 不可编译清单（预期空，实测空）

| # | domain | index | pattern | 错误 |
|---|--------|------:|---------|------|
| （无） | | | | |

依据：§2.1 真编译翼 0 abort；§2.3 静态翼 0 失败。

### 3.4 改写方案清单（预期空，实测空）

| # | domain | index | pattern | 拟定改写 | 落点（生成器 R4） |
|---|--------|------:|---------|----------|-------------------|
| （无） | | | | | |

依据：§3.3 为空 → 无需任何改写；生成器对 pattern 维持**逐字复制**策略不变
（`scripts/gen_rules.py`：`moonbit_quote(pattern)` 原文拷贝，仅字符串字面量转义）。
与迁移台账 `docs/regex-migration.md` 一致：该台账登记的仅是断言政策（patch_minor，
uap-core#562）与 device 规则 451 空 family 跳过语义两条**非正则改写**项，无任何
pattern 语法改写条目。

### 3.5 静态语法特征清单 × 处置交叉核对（R3）

统一处置路径（对下表全部特征类一体适用，逐字复制、无改写）：

- **生成器**：pattern 原文逐字复制进 MoonBit 字符串字面量（仅字面级转义 `\` `"` 与控制符）；
  生成期以 Python `re.compile` 验证可解析并取捕获组数，约束模板 `$N` 引用不越界。
- **运行时**：`rules_init.mbt` 把原文交 moonbitlang/regexp@0.3.5 编译；上游大小写不敏感
  一律走 YAML 级 `regex_flag: "i"` 键（生成器映射为 `flag_i` 字段，运行时作编译选项
  `compile(pattern, flags="i")`），而非内联 flag。
- 任一特征类若引擎不支持，都会在 §2.1 全量真编译中以 abort 暴露；实测 0 例。

**存在的特征类（17 类）**（计数 = 携带该特征的 pattern 数，ua/os/device 为域拆分）：

| 特征类（判定正则，检测于 pattern 原文） | pattern 数 | ua/os/device |
|------------------------------------------|-----------:|--------------|
| 非捕获组 `(?:`（`\(\?:`） | 622 | 120/57/445 |
| 贪婪 `*`（`\*`） | 15 | 5/5/5 |
| 贪婪 `+`（`\+`） | 559 | 356/127/76 |
| 贪婪 `?`（`\?`） | 684 | 143/62/479 |
| 非贪婪 `*?`（`\*\?`） | 3 | 0/0/3 |
| 非贪婪 `+?`（`\+\?`） | 11 | 1/0/10 |
| 非贪婪 `{m,n}?`（`\}\?`） | 205 | 3/0/202 |
| 有界重复 `{m,n}`（`\{[0-9]+(,[0-9]*)?\}`） | 675 | 67/100/508 |
| 锚 `^`（`\^`） | 381 | 52/8/321 |
| 锚 `$`（`\$`） | 17 | 10/1/6 |
| 词边界 `\b`（`\\b`） | 45 | 10/4/31 |
| 字符类 `[...]` | 546 | 61/42/443 |
| 点 `.` | 296 | 89/111/96 |
| 类简写 `\d`（`\\d`） | 645 | 357/135/153 |
| 类简写 `\w`（`\\w`） | 9 | 2/0/7 |
| 类简写 `\s`（`\\s`） | 21 | 12/5/4 |
| 或 `\|`（`(?<!\\)\|`） | 715 | 158/64/493 |

**不存在的特征类（13 类，各 0 例）**：命名组 `(?P<name>)`、`(?<name>)`；内联 flag `(?i)`、
`(?i:…)`；环视 `(?=`、`(?!`、`(?<=`/`(?<!`；非贪婪 `??`；非词边界 `\B`；POSIX 类 `[:alpha:]`；
反向引用 `\1`–`\9`；十六进制转义 `\xNN`；Unicode 转义 `\uNNNN`。

交叉核对结论：上游对大小写不敏感一律走 YAML 级 `regex_flag` 键（生成器映射 `flag_i`，
运行时编译选项），**结构性地回避了内联 flag**；环视/反向引用/命名组等高风险构造在快照中
零出现。因此「逐字复制、零改写」策略覆盖 1270/1270 全部 pattern，与 v0.1 台账（零正则改写
条目、18213/18213 差分全绿）相互印证。

## 4. 决策门判定（R5）

- 不可编译数 = **0 / 1270** → 不可编译率 = **0.00%**。
- 门槛：>2% 才停下交用户裁决（升级 regexp 依赖 vs 改写量评估）。
- 判定：**0.00% ≤ 2% → 无需改写、无需上报**；快照维持（73e7340）成立，不触发升级/改写评估。

## 5. L1 预算核算

- 抽样命令：5 条 ≤ 10 ✓ —— ① §2.3 静态扫描；② §2.1 真编译；③ §2.2 差分抽样；
  ④ `-f` 过滤参数误用（0 用例执行，无判定意义）；⑤ §2.4 生成器试运行（含幂等断言）。
- spike 相关轮次：10 轮 ≤ 10 ✓ —— 上述抽样 5 轮 + 过滤参数修正 2 轮（查 `moon test --help`、
  检索测试块名）+ §2.4 幂等断言非空的强制诊断 3 轮（diff 诊断、blob sha256 取证、restore 复查）。
  任务级开销（初始目录探索 2 轮、scratch 目录创建 1 轮、报告与提交）不计入 L1。
- 总耗时 ≈ 25 分钟 ≤ 2 小时 ✓

## 6. 复现指引

1. 真编译率：`cd moon_ua_parser_lib && moon test --target native -p src/ua_parser/rules`
   → `Total tests: 4, passed: 4, failed: 0.` 即 1270/1270（机制见 §1.2）。
2. 差分抽样：`cd moon_ua_parser_lib && moon test --target native -p tests/differential -f "differential os*"`
   → `Total tests: 1, passed: 1, failed: 0.`（483/483）。
3. 静态特征：按 §3.5 判定正则在临时目录对 `uap-core/regexes.yaml` 重跑
   `re.compile(pattern, flags)` 逐条校验与特征计数（脚本镜像 `scripts/gen_rules.py` 的
   `convert_entry` 编译路径），应得 `python-re compile failures: 0`、
   `$N group-bound violations: 0`、§3.5 同值计数。
