# v0.2 审查报告 — Reviewer A（moon_ua_parser_lib + 基建 + 文档）

**审查范围**：`git diff a56a85c..4ff2544`（v0.1.0 → main HEAD），本 rubric 范围 = moon_ua_parser_lib / scripts/gen_bench_samples.py / ci.yml（lib 步骤）/ .gitattributes / .gitignore / CHANGELOG.md / docs。所有结论基于本人独立核查（命令原样输出见各条证据）。

**Git State 核验（与 STATE_CHECK 的差异，以现实为准）**：
1. `git status` 显示 11 个 tracked 文件 M 旗标（含 `moon_ua_parser_lib/src/ua_parser/rules/rules_data.mbt` 等生成物），但 `git -c core.autocrlf=false diff` 输出为**空**（原样执行，EXIT=0）——纯 EOL 伪脏（PF-06），内容级干净，与简报"tracked 干净"的实质一致、与字面不符。`docs/rules-update-sop.md:65` 精确记载了该机制。
2. **简报所附三份计划文件在给定路径不存在**：`F:\moonbit比赛\moon_ua_parser-sdd\docs\superpowers\plans\` 与 `..._wt_platform\docs\superpowers\plans\` 下仅有 `2026-09-10-moon_ua_parser.md`（find 全树检索 v02 计划名零命中）。审查锚定改为简报明示的五条硬边界 + 仓内承诺文档（CHANGELOG/SOP/bench docs/MANIFEST/README）。
3. 门禁在派发时在跑；本审查收尾前全部完成：**GATE-1..7 全绿，DONE.flag 已出现**（详见 Gate evidence）。

### Rubric 判定

未达标（rubric not met）：R10
未覆盖（rubric not covered / 新发现）：R16（fmt_fixed2 负数格式化，Minor）、R17（SOP 与 .gitattributes 时代矛盾，Minor）

- **R1: pass** — `git diff a56a85c..4ff2544 -- moon_ua_parser_lib/src moon_ua_parser_lib/pkg.generated.mbti | wc -l` = 0；`samples.mbt` 首行 `// GENERATED — DO NOT EDIT.`，再生器路径唯一（scripts/gen_bench_samples.py）。
- **R2: pass** — 逐行核对两文件全量 diff：semantics.mbt 仅新增 `opt_str`/`opt_int` 助手（渲染 `None`/`Some(v)`，注释声明与原 Show 插值输出逐字节一致）+ 既有断言插值改经助手，golden 字符串零改动；robust.mbt 另含 `StringBuilder::new()`→`StringBuilder()` 一处（R2 明示允许的构造形式迁移）。被断言语义不变；`deprecated-2026-09-13.log:161-162` 记录 17+9=26 处 [0020] 告警→0，check.log 现状两文件零告警。措辞瑕疵一处：CHANGELOG 写 "26 call sites"，证据日志载明 26 是**告警数**（改动行数更多），实质准确。
- **R3: pass** — moon.mod diff 仅 `version = "0.1.0"` → `"0.2.0"` 一行；`git diff a56a85c..4ff2544 -- moon_ua_parser_lib/pkg.generated.mbti moon_ua_parser_lib/src` = 0 行。
- **R4: pass** — `clock_pair_diff_us` 唯一定义于 tests/bench/main.mbt:117-121，是包内唯一命名时钟 API 处；clock_native/js/wasm.mbt 各仅含 `backend_label()` 常量（经 moon.pkg `options(targets:)` 选择）；main.mbt 统计逻辑零后端分支（文件头 57-62 行声明并经通读核实）。
- **R5: pass** — 本人在**临时目录**（/tmp/rev-samples，未触碰 tracked 树）独立重跑 `python scripts/gen_bench_samples.py`：输出与 `git show HEAD:...samples.mbt` 逐字节一致（diff 静默），分层计数与 MANIFEST.md 表格逐值一致（android 7566/bot 30/ios 1586/linux 145/macos 342/other 17/windows 314）；生成器固定种子 `SEED=20260913`（:52）、纯标准库（:37-43 imports）、无时钟/网络/时序依赖。
- **R6: pass** — ①四字段报告行 main.mbt:293（`bench-result backend= ops_per_sec= ns_per_parse= sample_set_hash=`，另附 checksum/consistency）；②--smoke 以 `SMOKE_NS_PER_PARSE_LIMIT`（main.mbt:93）判约，报告先打印、`abort` 非零退出（main.mbt:488-495）；③--profile 有界（PROFILE_WARMUP_PASSES=1、PROFILE_TIMED_REPS=3，全部 for 为固定区间，无无界循环）；④三后端一致性有断言：运行器内 rounds_consistent/reps_consistent/index_matches_full 断言 + 跨后端 sample_set_hash（编译期常量，结构性相等）与 samples_checksum=15142 三后端一致的**已提交转录证据**（docs/evidence/bench-{native,js,wasm}-2026-09-13.txt，README 引用）。残项：CI 无自动化三后端 diff 步骤（见 Recommendations）。
- **R7: pass** — ci.yml 全量 diff 逐 hunk 归类：toolchain latest+硬断言（`moon version | grep -F "0.1.20260904"`）、moon update 前置、wasm 显式 7 包、wasm diffstats 报告、smoke step（纯追加）、警告基线门、中间件三步——均登记；Static check/Interface drift/Generation consistency/Tests(native)/Tests(js)/Build(wasm)/Differential report 七个既有 lib 步骤均为上下文行未改写；ulimit（PF-09）、latest 传输（PF-08）、`git -c core.autocrlf=false apply`（PF-06）三处 hack 均有注释+证据指针（docs/evidence/final-gate-2026-09-13.log 等）；lib 步骤 working-directory 均为 moon_ua_parser_lib（PF-11）。
- **R8: pass** — check.log:133 `(18 warnings, 0 errors)`、:134 `EXIT_CHECK=0`、:135 `TOTAL_WARNINGS=18 (baseline 18…)`、:136 `DEP_OUTSIDE_LIB=0`；本人手数 18 条 Warning 块（types.mbt 12 + tests/differential 6）与之吻合，全部位于 moon_ua_parser_lib 内。
- **R9: pass** — `git diff a56a85c..4ff2544 -- docs/regex-migration.md` = 28 insertions / 0 deletions（唯一 `^-` 为 `--- a/` diff 头）；该单元净效果 = docs/rules-update-sop.md（新增）+ regex-migration.md 台账追加 + docs/evidence/*（snapshot-bump/sop-replay/regen 记录），`git diff -- uap-core` = 0（快照未动，与 snapshot-bump-2026-09-13.md"已是最新、零改动"结论一致）。
- **R10: fail** — wasm 收缩登记 ✓（CHANGELOG "Changed" 节与 ci.yml 7 包步骤逐一对应）、README 三后端表述 ✓（"7 non-differential packages (28 tests)"与 ci.yml 注释、test-wasm.log `Total tests: 28, passed: 28` 吻合）、Ecosystem 声称 ✓（ci.yml 有 Middleware integration tests 步骤）；**但 Publishing 表述过时**：CHANGELOG.md:78-82 仍称"no publish has occurred"、:88-89 令消费者"只在注册表出现 0.2.0 后 moon add"，README.mbt.md:45-53 同样声称"registry has no published version…currently pending"——而同仓 `docs/evidence/publish-final-2026-09-13.log:7-10` 记录 lib 0.2.0 已发布（200 OK，moon search 验证，页 200），HEAD 提交 4ff2544 亦称 "all four packages live"。同一仓库内自相矛盾的消费者面文档，R10"无过时表述"不成立。
- **R11: pass** — SMOKE_NS_PER_PARSE_LIMIT=150_000_000（main.mbt:93 = smoke-calibration-2026-09-13.txt:13）；corpus_size=10000（samples.mbt 头 + MANIFEST）；stride=20（main.mbt:76）；warmup=2（:66）；timed=7（:70）；profile stride=50/reps=3（:100,:110）与 docs/profile-2026-09-13.md 一致；smoke-config 行实测 `sample_count=200 stride=50` 与文档吻合。
- **R12: pass** — .gitattributes 仅 `*.patch -text`（不触及 .mbti/.mbt，mbti 漂移闸 `git diff --exit-code -- '*.mbti'` 不受归一化影响）；.gitignore 仅根级 `/_build/`、`/.mooncakes/`（均非门禁 diff 路径）；两闸作用的 tracked 源文件无任何新忽略/属性覆盖。
- **R13: pass** — tests 全目录 `^-` 逐文件清点：semantics.mbt 76（75 行内容删除 = R2 迁移对）、robust.mbt 45（44 = 43 迁移对 + StringBuilder 构造形式）、diffstats/moon.pkg 4（4 行过时注释"wasm cannot launch on this host"改写为三后端矩阵登记，非断言）、bench 新文件各 1（`--- /dev/null` diff 头）。无其他既有断言删改；tests/differential 零改动。
- **R14: pass** — tests/bench/moon.pkg imports 仅 `core/bench`、`core/env`、`@ua_parser`（依赖方向 bench→lib 单向）；`grep -rn "bench" moon_ua_parser_lib/src --include=moon.pkg` 零命中（无反向依赖）；bench 绑定无 `pub`（MANIFEST.md:97 "same-package visibility; no pub"），R3 已证模块接口面（src+mbti）零变化 → 发布 API 面未被污染。
- **R15（范围外新发现）**：R16 = fmt_fixed2 负数格式化畸变（Minor，见 Issues）；R17 = SOP 与 .gitattributes 的时代性矛盾（Minor，见 Issues）。
- **R15: pass** — 已按条目执行：新发现以 R16/R17 编号记入 Issues，无遗漏

### Strengths

- **API 冻结是真实且被门禁固化的**：src+mbti 零 diff、GATE-2a mbti 零漂移（EXIT_MBTI_DIFF=0）、publish 前 moon.mod 版本唯一变化——"bench 基建只进 tests/" 的硬边界完全成立。
- **生成物纪律出色**：samples.mbt 幂等性经本人独立异地再生逐字节复现；gen_rules/gen_tests 幂等（GATE-2b EXIT_GEN_DIFF=0）；MANIFEST 把种子、分层配额、异常计数、失败契约全部写成可核查常量。
- **范围收缩诚实且登记完整**：wasm 差分门收缩（PF-01 结构性根因 125,840 locals > V8 50,000 cap）在 ci.yml 注释、CHANGELOG、README、diffstats/moon.pkg、wasm-differential-blocker 证据五处口径一致，Followup-1 登记在案；收缩同时补了 wasm --release diffstats 报告步作补偿性覆盖。
- **计时 seam 设计干净**：单点 `clock_pair_diff_us`、统计层零后端分支、checksum 防 DCE、跨轮/跨 rep 一致性断言、profile 的 template 成本显式标注为上界估计——基准方法论自洽且可复现（本次 GATE-7 smoke checksum=6122 与 2026-09-13 校准证据完全一致）。
- **CI 每处 hack 有据可查**：ulimit/latest 传输/关 autocrlf apply 三处均有根因注释 + 证据文件指针；警告基线门用 `╭─[` 路径关联 awk，失败方向安全（计数偏高方向误报而非漏报），基线 44→18 的重校准在 deprecated-2026-09-13.log 留痕。
- **SOP 质量高**：EOL 伪脏机制（porcelain M 旗标 vs 内容级 diff）与本人实测现象逐字吻合；内嵌 .git 双态、CWD 纪律、2>&1（PF-10）全部规则化。

### Issues

**Critical**（合并前必须修）：无。

**Important**（应修，阻塞合并）：
- **CHANGELOG.md:78-82, 88-89 与 README.mbt.md:45-53 的发布状态声称已过时并与仓内证据矛盾**。三处均断言注册表无已发布版本、`moon add` 会失败、发布"pending"，而 `docs/evidence/publish-final-2026-09-13.log:7-10`（lib 0.2.0，200 OK，moon search 与包页 200 验证）与 HEAD 提交信息（"all four packages live"）证明 lib 0.2.0 已上线。为什么重要：这是库的唯一消费者接入路径文档——按文档行事的真实用户会错误放弃 `moon add vicoproplus/moon_ua_parser`；同时仓库对同一事实并存两个矛盾断言，违反 R10"无过时表述"。修复建议：两处改为"0.2.0 已发布（2026-09-13，mooncakes 200、页验证）"，保留 dry-run 202 记录为历史；顺带把 CHANGELOG "26 call sites -> 0" 精确为 "26 处弃用告警 -> 0"（deprecated-2026-09-13.log:161 的口径）。

**Minor**（建议修）：
- **tests/bench/main.mbt:233-239 `fmt_fixed2` 对负数产生畸变输出**（如 -1.5 → "-1.0-50"：`scaled % 100L` 保留负号且 `frac < 10L` 分支拼出 "0-50"）。:397 的 `template_est_ns_per_call`/`template_est_pct` 按代码自身注释（:47-48,397）**可为负**（"noise can make it negative"），届时 profile 报告关键行格式损坏。已提交的 profile 证据中未实际出现负值（三处均为正），故仅 Minor。修复：先取符号 `let neg = v < 0.0`，对绝对值格式化后前置 "-"。
- **docs/rules-update-sop.md:65、:303 与本 diff 新增的 .gitattributes 矛盾**：SOP 两处仍写"本仓库…且无 `.gitattributes`"，:306 更规定"禁止通过添加 .gitattributes…来修 EOL"。.gitattributes（`*.patch -text`，commit 8385034）晚于 SOP 落地、目的不同（保 patch 字节、不波及生成物 EOL），但 SOP 的环境事实陈述已失真。修复：在 SOP 两处追加一句带日期的注记（"2026-09-13 起仓库根有仅覆盖 `*.patch` 的 .gitattributes，与本节 EOL 规则不冲突"）。

### Recommendations

- 在 ci.yml 现有 native/wasm 两条 diffstats 报告步之后加一行机械比对（对报告节做 `diff` 或 md5 断言，md5 `bff7fc84866a9ad4b6ac8a79299788f9` 已在 CHANGELOG 固定），把"三后端一致性"从文档级断言升级为 CI 级断言；可同理扩展一条 js diffstats 步。
- 考虑为 tests/bench 增补一个最小 wasm 冒烟（CI 已有 wasm --release 运行能力，diffstats 步已证明 moonrun 在 ubuntu 可用），使 B15 矩阵中 bench×wasm 格从"本地转录证据"升级为 CI 证据。
- Followup-1（gen_tests.py 拆分 tests/differential 恢复 wasm 差分测试门）与 Followup-3（生成文件 derive(Show) 残留）建议在 v0.3 计划中显式排期——当前登记状态合规，但这是 wasm 门完备性的唯一缺口。

### Blind-Spot Coverage

- **Response/contract-field evidence**: N/A — 本范围无外部 API/消息载荷字段读取；唯一外部导出值 sample_set_hash 源自仓内语料 sha256，判级 A（本人独立重算复现，原样输出见 R5）。
- **Shared state container update semantics**: N/A — diff 无 store/hook/状态容器；bench 为单进程顺序执行，`samples` 等为不可变编译期常量。grep 证据：`grep -rnE "Ref\[|MutMap|MutableMap|Store|store\(" moon_ua_parser_lib/tests/{bench,semantics,robust,diffstats} --include="*.mbt"` 命中 0（exit 1）；可变状态仅限 tests/bench 函数局部 Array/Int 累加器（main.mbt 逐行核实），跨模块共享容器命中 0 处。
- **Silent-degradation observability**: verified — grep 改动文件无空 catch/静默吞错；smoke 违约路径先打完整报告再 `abort`（main.mbt:488-495，"报告永远先于非零退出"）；生成器失败走 stderr + scripts/gen_bench_samples.error.log + exit 1（gen_bench_samples.py:93-111）。
- **Scaffold/placeholder legacy**: N/A — diff 无骨架/占位文件；bench 单元完成证据 = MANIFEST.md 验证记录节（:109-121）+ 本人独立再生。
- **Coverage-table reconciliation**: verified — lib 交付面逐面对账：差分套件→native/js CI 测试步（54/54、41/41）；semantics/robust→wasm 7 包门（28/28）；diffstats 报告→native+wasm 两 CI 步；bench smoke→CI Perf smoke 步；警告基线→CI 门。唯一无答案面 = wasm 上的差分**测试**模块，属已登记收缩（Followup-1 开单 + wasm --release 报告补偿），非孤儿放行。
- **Pitfall list cross-check**: 12 条逐条结论 — **PF-01**（wasm debug codegen 超 V8 locals）已对照：本 diff 的结构性根因与规避即 ci.yml 7 包显式门 + PF-01 登记完全一致，GATE-6 EXIT_WASM7=0 实证；**PF-02**（moonrun GetTempPath2W）不直接命中本 diff 代码，但 README.mbt.md:109-112 的 wasm 运行措辞如实披露该约束，判定"已对照"；**PF-03/PF-04/PF-05**（crescent/mars 补丁与 Windows publish）不相关——属另一位 reviewer 范围（ci.yml patch 步骤存在且 `git -c core.autocrlf=false apply --check` 前置，与本 rubric 的 lib 步骤无交集）；**PF-06**（autocrlf 失真）命中环境非代码：本审查的 git 状态差异即其现象，所有幂等比较均按其要求用内容级/关 autocrlf 执行；**PF-07**（registry 索引）已对照：ci.yml:58-64 `moon update` 前置存在；**PF-08**（toolchain 403）已对照：latest 传输 + `moon version | grep -F "0.1.20260904"` 硬断言在 ci.yml，GATE-1 实测版本 0.1.20260904；**PF-09**（moonc wasm 栈溢出）已对照：ci.yml wasm 测试步内 `ulimit -s unlimited`，GATE-6 绿；**PF-10**（diffstats stderr）已对照：SOP 登记，CI 捕获形式无需改动（moon run 输出直透）；**PF-11**（git 门禁 CWD）已对照：ci.yml 全部 lib 步骤 `working-directory: moon_ua_parser_lib`；**PF-12**（uap-core 内嵌 .git）已对照：SOP §2.3/§3.3 规则化（`--exclude=.git`），本审查 `git diff -- uap-core` = 0 未依赖其 git 状态。本轮无新确认陷阱需追加。
- **Platform-branch evidence matrix**: verified — 本 diff 唯一平台条件机制 = tests/bench/moon.pkg:28-34 `options(targets:)` 三分支（clock_js/clock_native/clock_wasm），每分支仅返回常量标签、无能力调用；真实平台风险收敛于 moonbitlang/core/bench 时钟对，其三后端可用性由 bench-{native,js,wasm} 转录 + GATE-7 实测背书。ci.yml 注释级平台证据（wasm 收缩、moonrun Win10 约束、ulimit）逐处有证据指针。
- **Preset-state provenance**: verified — bench 预置状态 = 固定种子分层语料样本，生产方 = gen_bench_samples.py 对仓内 uap-python 语料的确定性变换，契约锁定点 = MANIFEST.md（种子/配额/哈希全常量化）+ 本审查独立再生逐字节复现；无身份类/租户类 seed。
- **Evidence-grading spot-check**: verified — sample_set_hash=sha256:3640d3b7… **A 级**（独立重算复现）；跨后端 samples_checksum=15142 一致 **B 级**（docs/evidence/bench-{native,js,wasm}-2026-09-13.txt 已提交转录，README 引用）；wasm "28 tests" **B 级**（wasm-differential-blocker-2026-09-13.md + 本次 test-wasm.log `Total tests: 28, passed: 28` 实证）；"26→0" **B 级**（deprecated-2026-09-13.log:161-162）；无门控主路径的 C 级证据。唯一曾为 C 级的 README/CHANGELOG 发布状态声称已因后续事实变化失真 → 记 Important。
- **End-to-end behavior ownership**: verified — smoke 门唯一 owner = tests/bench 运行器本体（main.mbt:488-499 判定 pass/fail 并决定退出码），CI "Perf smoke (native)" 步（ci.yml:169-172）为红绿承接方；无跨模块组合行为。
- **Behavior-equivalence baseline**: verified — BASE=a56a85c 基线记录：wasm 测试步为裸 `moon test`（结构性红，CHANGELOG 0.1.0 节自证）、警告基线 44（deprecated log + ci.yml 注释）、semantics/robust 断言经 Show 插值渲染。改动后：断言 golden 字符串逐字节不变（opt_str 注释声明 + GATE-3 54/54 实证）、警告 44→18（只减不增，方向合规）、wasm 步从红改 7 包绿——均为显式登记的行为变更，无未声明偏离。规则回溯：警告基线门规则（≤18）不许可任何基线偏离（只许收缩）。
- **Degradation-path completeness**: verified — ①smoke 能力分支：else = 超限打 fail 行 + abort，消费方 = CI 退出码；②--profile template_est 负值分支：else = "按实测报告"（消费方 = 报告读者；格式化缺陷见 Minor R16）；③wasm 差分测试不可用分支：else = 7 包测试门 + wasm --release diffstats 报告步（消费方 = CI 门与 CHANGELOG md5 断言），非静默空转。
- **Stub fidelity**: N/A — 改动测试无任何 stub/mock/替身；全部针对真实引擎 + 真实语料执行。grep 证据：`grep -rniE "mock|stub|fake_|monkeypatch|patch\(" moon_ua_parser_lib/tests/{bench,semantics,robust} --include="*.mbt"` 命中 0（exit 1）——改动测试文件内 mock/stub/patch/替身零命中，全部断言针对真实引擎与真实语料。
- **Global side-effect implicit contract**: verified — 本 diff 全局副作用安装点 = CI 的 `moon update` 与 cache-patch apply（进程级，波及后续所有步骤，含绕过 lib 封装直连 workspace 图的中间件步骤）；波及方向为修复性（PF-03/04/07），后果已在 ci.yml 注释披露；库代码无全局拦截器/注册表新增。绕过封装层调用方枚举：GATE-2b 生成器直接写 tracked 文件（门禁内合法），无未声明波及。
- **Native-capability call matrix**: verified — 调用点×目标矩阵：①`@core_bench.monotonic_clock_start/end`（main.mbt:118-120）×native=CI GATE-7 实测绿 / js=bench-js 转录 / wasm=bench-wasm 转录（本地 PF-02 补丁 moonrun，CI 无 wasm bench 运行——该格处置 = 已提交本地捕获 + 建议升 CI，见 Recommendations）；②`@env.args()`（main.mbt:442）×三后端同上（js/wasm 转录含 --smoke 无 args 正常路径）；③stdout println×三后端全部有转录。无空 catch 吞能力失败。
- **Cross-boundary implicit-contract authority**: verified — 跨边界调用 = core/bench 时钟对与 moon.pkg options(targets:) 机制。外部权威：(A) 参照用法 = moonbitlang/core/bench 自身单调时钟实现（moon.pkg:10-11 注释声明同机制）+仓内 v0.1.0 已上线的 js/native 全量测试面；(C) 目标运行时探针 = 三后端 bench 转录（时钟读数非零、rounds_consistent=true）。无同源三方全绿闭环（时钟实现来自 core，非本改动书写）。无被替换参照实现（增量演进，REFERENCE_IMPL 语境 N/A）。
- **Upstream-claim triple reconciliation**: verified — 逐条重跑：①"快照 73e7340 已是最新" → `git diff a56a85c..4ff2544 -- uap-core` = 0、gen.log:135 `uap-core snapshot: commit 73e7340`、snapshot-bump 文档载 `git ls-remote` HEAD=73e7340 原样输出；②"toolchain latest 解析为 0.1.20260904" → check.log:2 `moon 0.1.20260904 (94521db 2026-09-04)`；③"语料 10,280,676 字节/75,158 行/sha256 3640d3b7…" → 本人再生原样输出逐值吻合；④"注册表无已发布版本" → **失配**：publish-final-2026-09-13.log:9-10（200 OK + moon search 0.2.0）→ Issue（Important）。
- **Adjudication-residue sweep**: verified — 裁决提取与全仓 grep：①Show→Debug 迁移：关键词 `Show` 于 tests/semantics+robust 命中 0（仅注释）；`derive(.*Show` 全 lib 命中 8（types.mbt×5 + differential×3，均为登记残留 Followup-3/接口契约保留）；②wasm 门收缩：`wasm cannot` 于 docs/tests/ci 命中 0（仅证据文件内历史记录）；③快照维持裁决：无"已 bump"残留（snapshot-bump 文件内容即"零改动"核实记录）；④stride 子采样裁决：docs/README 无"全量 10000 轮"残留。唯一残留 = SOP "无 .gitattributes"×2（Minor R17，:306 的规范与后到的 .gitattributes 存在时代张力）。
- **Acceptance-state gate**: verified — 简报所引三份计划文件不存在于给定路径（见 Git State 核验 2），无可挂未验证标记的验收行可查；仓内验收面（CHANGELOG 0.2.0 节、task-reports、closure 记录）中未回填标记 = Followup-1/Followup-3（已开单的登记型 follow-up，非死链占位）；发布 pending 标记已被 publish-final 证据回填，但 CHANGELOG/README 文字未随回填更新（→ Important issue，即本报告唯一阻塞项）。
- **Gate evidence**: verified — 派发方门禁在本审查收尾前全部完成并经本人读日志核验，真实退出码：GATE-1 `EXIT_CHECK=0`（18 warnings ≤ 基线 18，DEP_OUTSIDE_LIB=0，check.log:133-136）；GATE-2a `EXIT_INFO=0`/`EXIT_MBTI_DIFF=0`、GATE-2b `EXIT_GEN=0`/`EXIT_GEN_DIFF=0`（gen.log:129-162）；GATE-3 `Total tests: 54, passed: 54` / `EXIT_NATIVE_ROOT=0`；GATE-4 10/10+7/7+6/6 三 EXIT 均 0；GATE-5 `41/41` / `EXIT_JS=0`；GATE-6 wasm 7 包 `28/28` / `EXIT_WASM7=0` + `EXIT_WASM_BUILD=0`；GATE-7 `smoke-verdict result=pass … limit=150000000.00` / `EXIT_SMOKE=0`（checksum=6122 与 smoke-calibration 证据一致）。DONE.flag 已出现。基线分离：本仓门禁基线为绿（无 BASE 既有红），警告基线 44→18 的收缩历史单独登记于 deprecated log，不与本轮混淆。
- **Test-diff purity**: verified — 删除行逐文件清单（B21）：semantics.mbt 76（其中 75 行内容 = Show 插值断言 → opt_str 版成对替换，golden 不变）；robust.mbt 45（43 行成对替换 + 1 行 StringBuilder::new→StringBuilder() 构造形式 + diff 头）；diffstats/moon.pkg 4（过时注释 4 行，理由 = wasm --release 已可运行、旧陈述失真，属登记性改写）；bench 新文件各 1（`--- /dev/null` 头，非删除）。tests/differential 与其余测试文件删除行 = 0。无未解释删改。
- **Rename reference sweep**: verified — 关键词/范围/命中数：`StringBuilder::new`（全仓 *.mbt，排除 .mooncakes/_build/uap-python）= 1 命中，位于 `.worktrees/feat-v02-perf-bench`（开发 worktree，非 main 树）；Show 路由插值残留（semantics/robust，排除 opt_str/opt_int 行）= 0；`derive(Show)` 残留 8 处 = 登记保留（src 接口契约 5 + 生成物 3）；`--target` 默认语义变更（wasm 步显式化）旧引用扫描：docs/README/CHANGELOG 中"裸 moon test 为 wasm 门"的表述 = 0 残留，三后端运行命令均写显式 `--target`。

### Render Surface Coverage

N/A — 无渲染面受影响。机械证据：`git diff --name-only a56a85c..4ff2544 | grep -icE "\.css|\.html|\.vue|\.jsx|\.tsx|template|style|layout|viewport|widget|component"` = **0**。本范围为纯后端库 + Python 生成器 + CI YAML + Markdown 文档，无模板/样式/类名/布局/视口/单位/渲染产物改动。

### Assessment

**With fixes**

唯一阻塞项为 Important 级文档失真（CHANGELOG.md:78-82,88-89 与 README.mbt.md:45-53 的发布状态与仓内发布证据矛盾），修复为纯文档改动、不影响已合入代码与已验证门禁；两处 Minor（fmt_fixed2 负数格式化、SOP .gitattributes 注记）建议随同修订。代码、生成物纪律、CI 受控登记、三后端基准与全部门禁（GATE-1..7 全绿、DONE.flag 已出现）均通过独立核查。
