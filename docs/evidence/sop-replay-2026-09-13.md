# SOP Replay Evidence — rules-update-sop.md（2026-09-13，G-02 独立复演）

- **性质**：由未接触过本 SOP 的独立维护者按文档逐字从头到尾复演（replay），工作目录为专用 worktree `F:\moonbit比赛\moon_ua_parser-sdd`，分支 `v02-rules-update`（HEAD `e89bd33`）。
- **结论先行**：SOP 全部七节走完，所有门禁按文档判定标准通过；实况路径 = §2.1 决策门裁定的「已是最新」路径（上游 HEAD `73e7340` == vendored `73e7340`，增量 0）。§6 回滚两粒度均实测演练成功并全部复原。发现 6 处 SOP 文档层面偏差（均不阻断执行）+ 1 处控制器授权的范围裁剪，见文末 DEVIATIONS。
- **证据落盘声明**：按本次复演控制器约束，全部证据合并落盘于本文件（含 §1.4 要求的 snapshot-bump / regen / diffstats / final-gate 内容与 §6 回滚留痕）；未按 kind 拆分为多个日期化文件（D3）。

## 0. 环境基线

- Windows 10 / Git Bash；仓库 `core.autocrlf=true`，无根级 `.gitignore`/`.gitattributes`（排除项在 `.git/info/exclude`，含 `.superpowers/`）。
- 起点 porcelain：8 个 EOL-only M 旗标（`src/ua_parser/pkg.generated.mbti` + rules/ 4 文件 + tests/differential/ 4 文件）；`git diff --exit-code` 退出 0。与已知裁定一致。

## 1. 前置条件 — PASS

- §1.1 工具核查（实测）：`git config core.autocrlf` → `true`；`python --version` → `Python 3.12.10`，PyYAML `6.0.2`；`moon version --all` → `moon 0.1.20260904 (94521db 2026-09-04)`、`moonc v0.10.12+1634b282e`。全部满足 §1.1 表格要求（moon 版本与 SOP 基线完全一致）。
- §1.2 起点门禁（逐字执行）：
  - `git status --porcelain` → 上述 8 个 M 旗标（按 §1.2 规则不作为阻断、不去"修复"）；
  - `git diff --exit-code && echo "START: content-clean"` → 打印 **`START: content-clean`**，退出 0。PASS。
- §1.3 基线身份（逐字执行）：
  - `grep -n "UAP_CORE" moon_ua_parser_lib/src/ua_parser/rules/rules_version.mbt` →
    `10:pub const UAP_CORE_COMMIT : String = "73e7340"`、`15:pub const UAP_CORE_DATE : String = "2026-08-24"`；
  - README「Snapshot provenance」节：`73e7340`、`1270 rules`、`2026-08-24`；`scripts/gen_rules.py:65-66` 同值。三处一致。PASS。

## 2. 快照刷新 — PASS（「已是最新」路径）

- §2.1 上游核实（逐字执行）：
  - `git ls-remote https://github.com/ua-parser/uap-core HEAD` →
    `73e7340c3ed8055051607b296bf46ead7aa5f19e<TAB>HEAD`（与 SOP 预期输出逐字符一致）；
  - `git ls-remote --tags ... | tail -5` → 末两条 `refs/tags/v0.9.0` → `57535a3…` / `9394685…^{}`（v0.9.0 → 9394685，与 SOP 记载一致）。
  - 决策门：`upstream HEAD = 73e7340` == §1.3 的 `UAP_CORE_COMMIT` → **「已是最新」路径，增量 0，§2.4 不执行**。
- §2.2 上游 clone 到仓库外临时区（作为 §2.3 维持证明的前置，逐字执行）：
  - `WORK=/tmp/tmp.ZwYh7LKBNF`（系统 TEMP，仓库外）；clone --depth 1 exit 0；
  - `git -C "$WORK/uap-core-upstream" checkout 73e7340`（目标==clone HEAD，fetch 分支不触发）exit 0；
  - `log -1 --format='%h %cd %s' --date=short` → **`73e7340 2026-08-24 Clean up errant whitespace in regexes.yaml`**（CommitDate 口径，与 SOP 预期逐字符一致）。
- §2.3 A5 对账（维持证明复跑）：
  - 文件清单 diff（排除内嵌 .git）→ **空**（exit 0）；
  - `diff -r --exclude=.git "$WORK/uap-core-upstream" uap-core` → **空**（exit 0）；两侧各 26 文件；
  - 三分计数：vendored = upstream = `1270`（ua 433 / os 204 / device 633，与基线一致）；测试用例 `1601 | 1601`、`483 | 483`、`16129 | 16129`（合计 18213）。新增/修改/删除 = 全 0。PASS。
- §2.4 覆盖刷新：**na**（决策门已裁定不覆盖；本步未执行）。其备份规则在本复演中于 §6.2 演练前按 §2.4 原文补演（见 §6 记录）。
- §2.5 判定：决策门有结论且已记录；仓库内零 scratch 残留（porcelain 除既有 8 M 外无新增）。PASS。

## 3. 再生成与幂等 — PASS

- §3.1 生成物备份（逐字执行）：`BAK2="$WORK/moon_ua_regen_20260913"`；`rules.bak` 5 文件（moon.pkg / rules_data.mbt / rules_init.mbt / rules_init_test.mbt / rules_version.mbt）、`differential.bak` 4 文件（diff_ua/diff_os/diff_device/moon.pkg）——与预期 5+4 一致。
- §3.2 更新生成器常量：**跳过**（仅刷新路径）。该步唯一命令（grep gen_rules.py 两常量）已在 §1.3 等价执行，显示 `73e7340` / `2026-08-24`。
- §3.3 运行生成器（两种 CWD 形态均执行）：
  - 仓库根形态 `python scripts/gen_rules.py` → exit 0，stdout 首行 `Reading F:\moonbit比赛\moon_ua_parser-sdd\uap-core\regexes.yaml`，随后：
    ```
    uap-core snapshot: commit 73e7340, date 2026-08-24
    user_agent_parsers  :  433 rules (0 with flag i)
    os_parsers          :  204 rules (0 with flag i)
    device_parsers      :  633 rules (65 with flag i)
    total               : 1270 rules
    wrote ...\rules\rules_data.mbt (257923 bytes)
    wrote ...\rules\rules_version.mbt (465 bytes)
    wrote ...\rules\moon.pkg (378 bytes)
    OK
    ```
  - `python scripts/gen_tests.py` → exit 0：`1601 (0 exempted) / 483 / 16129`，`total = 18213 cases`，`OK`。
  - 双跑比对：`cmp` 两个脚本第二遍 stdout **逐字节相同**（T-03 结论复现）。
  - `moon_ua_parser_lib/` 形态（`python ../scripts/...`）：stdout 与仓库根形态 **逐字节相同**（CWD 无关性实证）。
  - 计数与 §2.3 YAML 计数三方互证一致。
- §3.4 幂等门禁：
  - `# CWD: moon_ua_parser_lib/`：`git diff --exit-code -- src/ua_parser/rules tests/differential` → exit 0，打印 **`IDEMPOTENT (content-level)`**（仅 LF/CRLF stderr 警告，按 SOP 可忽略）。
  - 陷阱一旁证：同 pathspec 在**仓库根**执行 → exit 0 且 `--stat` 空输出（空转通过、0 文件匹配），复现 SOP 所述机制；带 `moon_ua_parser_lib/` 前缀则正常匹配 7 文件。
  - EOL 旁证：`diff -r --strip-trailing-cr src/ua_parser/rules "$BAK2/rules.bak"` 及 differential 侧 → 空（备份与生成物仅 EOL 差异）。
  - porcelain 留痕（仅记录不作判据）：8 个 M 旗标（同起点集合）。
- §3.5 公开 API 零漂移：
  - `moon check` → **`44 warnings, 0 errors`**（SOP 预告"约 44 条既有弃用告警"精确命中）；exit 0。
  - `moon info` → exit 0；`git diff --exit-code -- '*.mbti' '**/*.mbti'` → exit 0，打印 **`API ZERO DRIFT`**。
  - 副产物处置：`git status --porcelain | grep '^??'` 列出 **恰好 7 个** untracked `pkg.generated.mbti`（根目录、examples/middleware、src/ua_parser/rules、tests/differential、tests/diffstats、tests/robust、tests/semantics），与 SOP 清单逐一对应；按 SOP 清单 `rm -f` 删除后复跑 mbti 门禁 exit 0；`??` 清零。`src/ua_parser/pkg.generated.mbti`（被跟踪）未动。
- §3.6 编译兼容复验（维持路径抽样）：`moon test --target native -p src/ua_parser/rules` → **`Total tests: 4, passed: 4, failed: 0.`**（与 SOP 预期一致 ⟺ 1270/1270 可编译）。
- §3.7 快照版本记录一致性：README「Snapshot provenance」== rules_version.mbt 常量 == gen_rules.py 常量 = `73e7340` / `2026-08-24` / 1270（433/204/633）。PASS（无需改动）。
- §3.8 小结：幂等 exit 0；moon check 0 errors；mbti 零漂移；副产物删净（无 `??`）；编译兼容 4/4；三处一致。全 PASS。

## 4. 差分门禁 — PASS

- §4.1 diffstats（`moon run --target native --release tests/diffstats`，实测约 5 分钟，与 SOP 耗时参考一致）。数据表全文（exit 0）：
  ```
  domain	total	exempted	passed	failed	rate	gate	status
  browser	total=1601	exempted=0	passed=1601	failed=0	rate=100.00%	gate>=99.00%	MET
  os	total=483	exempted=0	passed=483	failed=0	rate=100.00%	gate>=97.00%	MET
  device	total=16129	exempted=0	passed=16129	failed=0	rate=100.00%	gate>=97.00%	MET
  browser failure groups: (none)
  os failure groups: (none)
  device failure groups: (none)
  GATES: ALL MET
  ```
  与 SOP 预期块及 `docs/evidence/diffstats-2026-09-13.txt` 基线一致。三域 100%，`GATES: ALL MET`。
- §4.2 三后端复核：
  - `moon test --target js` → **`Total tests: 31, passed: 31, failed: 0.`**（必过门禁，PASS；实测约 2 分钟）。
  - `moon build --target wasm` → exit 0（`18 warnings, 0 errors`）——本地 wasm 门槛 PASS。
  - `moon test`（默认 wasm 运行时）：**未复跑**。复演控制器事先裁定 [LOCAL_DEAD_LINK] 为已知项无需重触（SOP §4.2 亦载明运行失败不判门禁失败、仅须登记跨 plan 依赖——该登记已在既有证据中存在）。记为 D6（范围裁剪，非 SOP 缺陷）。
- §4.3 判定：`GATES: ALL MET` + js 全绿 + wasm 构建通过 = 差分门禁过。全量输出已抄入本文件。

## 5. 归因登记 — PASS（零新增偏差声明）

- 台账结构核验（`docs/regex-migration.md`）：现行结构 = §4 归因登记（三分类统计）+ §4.1 政策采纳条目（patch_minor / uap-core#562，两列表）+ §4.2 三栏审计逐例表（rule id `ua[32]`…、golden 期望、uap-python 实际）+ §4.3 引擎设计偏差（device 空 family 跳过语义）。SOP §5.1 的五要素（rule id / 期望输出 / 实际输出 / 处置 / 上游 issue 链接）在台账中**均有承载但分散于 §4.1/§4.2 的既有表格形态**，并非独立五行字段——判定为格式描述的轻度不精确（D4），不阻断。
- **零新增偏差声明**：本轮三域 failure groups 均为 `(none)`、`exempted=0`、无双跑/幂等/编译失败，无需向台账追加任何行（追加式纪律保持：未改动 `docs/regex-migration.md`）。
- §5.3 可检索性验收：零新增偏差场景，按 SOP 以本声明替代 grep 计数。

## 6. 回滚 — 演练 PASS（两粒度 + 门禁复跑 + 一致性确认）

### 6.0 注入受控脏状态（演练前提）

`printf '\n// SOP-REPLAY-ROLLBACK-MARKER 2026-09-13 ...\n' >> moon_ua_parser_lib/src/ua_parser/rules/rules_data.mbt` → `git diff --stat` 显示 `1 file changed, 2 insertions(+)`，marker grep 计数 1。

### 6.1 粒度 A：仅生成物（逐字执行）

`# CWD: 仓库根`：`git checkout -- moon_ua_parser_lib/src/ua_parser/rules moon_ua_parser_lib/tests/differential` → **静默 exit 0**。验证：
- marker grep 计数 0（内容还原）；
- 两目录 pathspec `git diff --exit-code` → exit 0；
- porcelain：**7 个生成物 M 旗标全部消失**（含 EOL 伪脏），仅剩 pathspec 之外的 `src/ua_parser/pkg.generated.mbti` —— 与 §6.1 "EOL 伪脏旗标也会一并消除" 的文档断言完全一致。

### 6.2 粒度 B：含快照目录（备份规则按 §2.4 原文补演后演练）

因「已是最新」路径未执行 §2.4、而 §6.2 的整目录还原依赖 §2.4 的仓库外备份，先按 §2.4 原文补建备份：
- `BAK="$WORK/uap-core.bak-20260913"`；`cp -r uap-core "$BAK"`；`ls "$BAK/regexes.yaml"` → 列出文件；`diff -r --exclude=.git uap-core "$BAK"` → exit 0。备份确认两步全过。
- 事实核查：本 worktree 的 `uap-core/` **不含内嵌 `.git`**（`ls uap-core/.git` → No such file；主检出 `F:\moonbit比赛\moon_ua_parser\uap-core\.git\` 存在）。untracked 文件不随 `git worktree add` 传播所致（D2）。

随后逐字执行 §6.2：
- 第一步 tracked 还原：`git checkout -- uap-core moon_ua_parser_lib/src/ua_parser/rules moon_ua_parser_lib/tests/differential` → 静默 exit 0；`git status --porcelain uap-core/` 为空。
- 第二步整目录还原：`rm -rf uap-core && cp -r "$BAK" uap-core` → `git status --porcelain uap-core/` 为空（干净）。
- 还原后 A5 复核（追加验证）：`diff -r --exclude=.git "$WORK/uap-core-upstream" uap-core` → 空；文件清单 diff → 空；`grep -c "^  - regex:" uap-core/regexes.yaml` → 1270。还原件与上游 HEAD 逐字节一致。

### 6.3 复跑门禁清单（回滚后必做，四步全绿）

1. `# CWD: moon_ua_parser_lib/`：`python ../scripts/gen_rules.py && python ../scripts/gen_tests.py` → 双 OK；幂等 `git diff --exit-code -- src/ua_parser/rules tests/differential` → exit 0（IDEMPOTENT after rollback）。
2. `moon check` → `44 warnings, 0 errors`。
3. `moon info` → exit 0；mbti 门禁 exit 0（API ZERO DRIFT after rollback）；本轮 `??` 副产物 3 个（增量缓存下少于首轮的 7 个；按 §3.5 清单 rm 后 `??` 清零、门禁仍 exit 0）。
4. `moon run --target native --release tests/diffstats` → exit 0，**`GATES: ALL MET`**（三域仍 100%，逐行同 §4.1）。

### 6.4 一致性确认

`grep -n "UAP_CORE" .../rules_version.mbt scripts/gen_rules.py` + README 节 → 三处一致于回滚目标基线 `73e7340` / `2026-08-24` / 433/204/633。
终态：`git diff --exit-code` → **`FINAL: content-clean`**；porcelain 恢复为与起点相同的 8 个 EOL-only M 旗标（§6.3 再生成按 EOL 机制重建伪脏位，属预期）。marker 无残留，演练完整复原。

## 7. 更新节奏声明 — 已读，无执行项

触发锚点 = upstream release（tag）；决策门以 HEAD 为对账基准；本次「已是最新」结论与 §2.1 记录一致。§7.1 final gate 清单逐项核对：

- [x] §2 决策门有结论且已记录（已是最新 + 增量 0）
- [x] §3 幂等门禁 exit 0；EOL 伪脏未误判、未引入 .gitattributes/autocrlf 改动
- [x] moon check 0 errors；mbti 零漂移 exit 0；moon info 副产物已删净
- [x] §4 `GATES: ALL MET`（100%/100%/100%）；js 31/31 全绿；wasm 构建通过（wasm 运行时复验按裁定未重触，[LOCAL_DEAD_LINK] 跨 plan 依赖沿用既有登记）
- [x] 零新增偏差，台账未追加；生成物零手改（marker 已回滚还原）
- [x] README = rules_version.mbt = gen_rules.py 三处一致
- [x] 证据落盘（本文件）；仓库内无备份/克隆/scratch 残留；工作树无计划外内容变更

## DEVIATIONS（SOP 文档 vs 实况）

- **D1（§3.3 预期输出模板非逐字）**：SOP 模板写 `... wrote src/ua_parser/rules/{rules_data.mbt, rules_version.mbt, moon.pkg}`（单行花括号汇总、相对路径）且 `total               :  1270 rules`（冒号后两空格）；实际生成器逐文件打印 `wrote <绝对 Windows 路径> (N bytes)` 三行、`total               : 1270 rules`（一空格）。门禁判据（exit 0 / OK / 计数）不受影响。建议：以实测 stdout 原文替换模板或标注"节略"。
- **D2（§2.3/§2.4 内嵌 .git 前提在 worktree 不成立）**：SOP 称 vendored `uap-core/` 内嵌一份未被跟踪的 `.git`（"基线遗留"）。实测主检出存在 `uap-core/.git/`，但本复演专用 worktree **无**（untracked 文件不随 worktree 传播）。本路径对账不受影响；若在 worktree 走刷新路径，§2.4 的 `cp -r "$WORK/uap-core-upstream" uap-core` 会引入基线本没有的内嵌 `.git`。建议：§2.3 警告框补 worktree 注意事项。
- **D3（§1.4/§4.3/§6 证据落盘要求 vs 本次单文件约束）**：SOP 要求按 kind 落多份日期化证据（含 §4.3 的 `diffstats-YYYY-MM-DD.txt`、§6 回滚落盘）；本次复演控制器约束"仅提交一份 sop-replay-2026-09-13.md、树内不得有其他新增"。全部证据合并于本文件，未拆分落盘。建议：§1.4 增加"合并/复演模式"可选项。
- **D4（§5.1 五要素与台账现行形态的表述差异）**：SOP 称"每条新增偏差登记以下五要素"；台账现行结构将五要素分散承载于 §4.1 两列政策条目与 §4.2 三栏审计表（§5.2 已对政策类单条模式部分认可）。建议：§5.1 注明五要素可按台账既有表格形态表达。
- **D5（§2.2 在「已是最新」路径的适用性未标注）**：流程图与 §2.4 标注了 na，但 §2.2 未标；其 `fetch <目标commit>`/`checkout <短哈希>` 行面向刷新路径（目标≠clone HEAD）。本次目标==HEAD，逐字执行无害（checkout 73e7340 成功）；§2.3 需要该 clone 才能复跑维持证明。建议：§2.2 标注"已最新路径可选，用于 §2.3 维持证明"。
- **D7（§4.3 "全量 stdout 抄入"口径）**：diffstats 数据表经 `moon run` 走 **stderr** 中继，仅重定向 stdout 会得到空文件（本次 §6.3 步骤4 首次捕获即因此管道失败一次，改用 `2>&1` 全量捕获后正常；`moon run` 本身 exit 0）。交互终端无感知，脚本化采集需 `2>&1`。建议：§4.3 注明采集时合并 stderr。
- **D6（范围裁剪，控制器授权，非 SOP 缺陷）**：§4.2 的 `moon test`（默认 wasm 运行时）未复跑（[LOCAL_DEAD_LINK] 已裁定为已知项）；js 与 `moon build --target wasm` 均按要求执行并通过。

## 复演结论

**SOP 可按文执行：是**（executable as-written: yes）。全部门禁判定与 SOP 预期一致；两处机制性陷阱警告（CWD 空转、EOL 伪脏）与 §6.1 断言均被独立复现证实；回滚两粒度演练成功且完全复原。6 处文档级偏差（D1-D5、D7）均为表述/口径级，建议作者修订，不阻断执行。

## 卫生声明

- scratch 仅有 `/tmp/tmp.ZwYh7LKBNF`（系统 TEMP，仓库外；含 uap-core-upstream clone、uap-core.bak-20260913、moon_ua_regen_20260913、stdout 捕获文件），按 §2.2 总则留待系统自清；仓库内零残留。
- 本轮仓库内唯一新增文件 = 本证据文件；`docs/regex-migration.md`、SOP、生成器、生成物内容零改动；终态 8 个 EOL-only M 旗标与起点相同。
