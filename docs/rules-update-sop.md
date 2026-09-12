# 规则更新 SOP（uap-core 快照刷新 → 再生成 → 差分门禁 → 归因登记 → 回滚）

- 文档落点（spec §3 契约）：`docs/rules-update-sop.md`
- 适用对象：moon_ua_parser 仓库的 uap-core vendored 快照（`uap-core/`）与生成物（`moon_ua_parser_lib/src/ua_parser/rules/`、`moon_ua_parser_lib/tests/differential/`）
- 读者：下次执行规则更新的维护者。所有命令按小节标注的 CWD 逐字复制即可执行（Git Bash / bash 语法）。
- 当前基线（2026-09-13 复验通过）：uap-core@`73e7340`（快照日期 2026-08-24）；regexes.yaml 规则 1270 条（ua 433 / os 204 / device 633，65 条 device 规则带 flag i）；差分用例 18213 条（ua 1601 / os 483 / device 16129）；三域通过率 100%（门禁 ≥99%/≥97%/≥97% 全 MET）。
- 事实源（本 SOP 全部命令与判定均以这些实测记录为依据）：
  - `docs/evidence/snapshot-bump-2026-09-13.md`（T-01 上游核实与决策门实测）
  - `docs/evidence/regex-compat-2026-09-13.md`（T-02 兼容性 spike，1270/1270 可编译）
  - `docs/evidence/regen-2026-09-13.md`（T-03 再生成幂等实测，含 EOL 机制取证）
  - `docs/evidence/diffstats-2026-09-13.txt`（T-04 差分门禁完整 stdout）
  - `docs/regex-migration.md`（归因台账现行结构）、`moon_ua_parser_lib/README.mbt.md`「Snapshot provenance」节、`moon_ua_parser_lib/src/ua_parser/rules/rules_version.mbt`（版本常量）、`.github/workflows/ci.yml:59-64`（门禁权威形态）

## 0. 流程总览

```
[1 前置条件检查] → [2 快照刷新：上游核实 → 决策门]
                                    │
              ┌─────────────────────┴──────────────────────┐
        HEAD == vendored commit                    HEAD 有新 commit
        （「已是最新」路径，增量 0）                  （刷新路径）
              │                                            │
              │                              仓库外备份 → 覆盖 uap-core/
              │                              → 更新生成器快照常量
              └─────────────────────┬──────────────────────┘
                                    ↓
              [3 再生成与幂等（生成器 + 幂等门禁 + 公开 API 零漂移）]
                                    ↓
              [4 差分门禁（diffstats 三域阈值 + 三后端复核）]
                                    ↓
              [5 归因登记（如有新增偏差）] → [7 证据落盘与收尾清单]
              （任一门禁失败且无法归因时 → [6 回滚] 后重来）
```

两条路径都要走完 §3-§4；区别只在 §2 是否执行覆盖刷新、§3.2 是否改生成器常量、README 是改写还是核对。**2026-09-13 单元走的是「已是最新」完整路径（T-01..T-04），本 SOP 即按该实测沉淀。**

约定：

- `# CWD: 仓库根` = worktree checkout 根目录（含 `uap-core/`、`scripts/`、`docs/` 的那一层）；`# CWD: moon_ua_parser_lib/` = 仓库根下的 `moon_ua_parser_lib/`。
- 每个命令块开头 `set -euo pipefail`：任何一步非零退出立即中止，避免带病继续。
- 跨命令块的 `$WORK` 变量在同一 shell 会话内持续有效；换会话后须重新赋值。
- 仓库外临时区指 `mktemp -d` 生成的系统 TEMP 目录（Git Bash 下 `/tmp` 即映射系统 TEMP）。**禁止任何备份、clone、scratch 留在仓库内。**

## 1. 前置条件

### 1.1 工具与环境

| 工具 | 要求 | 核查命令 |
|------|------|----------|
| git | 任意近期版本；`core.autocrlf=true` 是本机现状，**不要改**（见 §3.4 EOL 机制） | `git config core.autocrlf` |
| python | 3.12.x + PyYAML 6.x（生成器依赖） | `python --version && python -c "import yaml; print(yaml.__version__)"` |
| moon | ≥ 0.1.20260904（本单元实测版本） | `moon version --all` |
| 网络 | 可达 github.com（不可达见下方 LOCAL_DEAD_LINK 处置） | §2.1 的 ls-remote 本身即探针 |

### 1.2 起点状态门禁（内容级干净）

```
set -euo pipefail
# CWD: 仓库根
git status --porcelain
git diff --exit-code && echo "START: content-clean"
```

- **预期输出/判定**：`git diff --exit-code` 退出 0（打印 `START: content-clean`）即内容级干净，可开工。
- `git status --porcelain` **允许出现 M 旗标**：本仓库 `core.autocrlf=true` 且无 `.gitattributes`，EOL-only 伪脏（HEAD blob LF、worktree 检出 CRLF）会让 porcelain 显示 M 而 `git diff` 无内容行。以内容级 `git diff --exit-code` 为准，porcelain 旗标不是阻断项，也不要去"修复"它（§3.4）。
- 若 `git diff --exit-code` 非 0：存在真实未提交改动，先处理（提交或按 §6 还原）再继续。

### 1.3 基线身份确认

```
set -euo pipefail
# CWD: 仓库根
grep -n "UAP_CORE" moon_ua_parser_lib/src/ua_parser/rules/rules_version.mbt
```

- **预期输出/判定**：`UAP_CORE_COMMIT : String = "73e7340"`、`UAP_CORE_DATE : String = "2026-08-24"`（随快照推进而变化；关键是你知道当前 vendored 基线，供 §2.1 决策门比对）。该常量由 `scripts/gen_rules.py`（约 65-66 行）在生成时写入，三处（gen_rules.py 常量 → rules_version.mbt → README「Snapshot provenance」节）必须始终一致，§6.4 回滚后也要核对。

### 1.4 证据落盘纪律（每次执行必做）

- 每次执行本 SOP，在 `docs/evidence/` 落一份日期化记录，命名 `<kind>-YYYY-MM-DD.md`（数据表用 `.txt`）。kind 取：`snapshot-bump`（§2）、`regex-compat`（§3.6）、`regen`（§3）、`diffstats`（§4）、`final-gate`（收尾）。
- 格式参照既有 evidence 文件：结论先行、命令与原始输出摘录、判定对照、scratch 与仓库卫生声明（仓库内仅新增证据文件本身）。
- **演练模式（replay）**：按 kind 拆分是**真实执行**的要求；复演/演练（replay）运行允许把全部证据**合并为一份日期化文件**（命名 `sop-replay-<date>.md`，各 kind 的内容作为其小节承载），不因未按 kind 拆分而判失败。先例：`docs/evidence/sop-replay-2026-09-13.md`。
- 回滚（§6）同样落盘，不因"失败回滚"而免记。

### 1.5 预期输出/判定（本节）

- §1.2 打印 `START: content-clean`；
- §1.3 两条常量与 README「Snapshot provenance」节一致；
- 工具版本齐备。任一不满足，停在 precondition，不开工。

## 2. 快照刷新

快照来源 URL（spec §3 契约字面）：`https://github.com/ua-parser/uap-core`（regexes.yaml 于 master）。

### 2.1 步骤 1：上游核实与「已是最新」决策门（T-01 实测命令）

```
set -euo pipefail
# CWD: 仓库根
git ls-remote https://github.com/ua-parser/uap-core HEAD
git ls-remote --tags https://github.com/ua-parser/uap-core | tail -5
```

- **预期输出**：第一行形如 `73e7340c3ed8055051607b296bf46ead7aa5f19e<TAB>HEAD`；`--tags` 列出 release tag（2026-09-13 实测最新 tag v0.9.0 → 9394685，上游 HEAD 位于其后未被 tag 覆盖——`--tags` 用于佐证 release 节奏，决策门本身比对 HEAD）。
- **决策门（机制知识，逐字执行）**：

```
set -euo pipefail
# CWD: 仓库根
UP_HEAD=$(git ls-remote https://github.com/ua-parser/uap-core HEAD | cut -c1-7)
echo "upstream HEAD = $UP_HEAD"
```

将 `upstream HEAD` 与 §1.3 读到的 `UAP_CORE_COMMIT` 比对：

- **相等 → 「已是最新」路径**：在证据文件中记录「已是最新」+ 增量 0，**跳过覆盖刷新（§2.4 不执行）**，直接转入 §3 再生成复验。2026-09-13 实测即此路径（上游 HEAD `73e7340` == 基线 `73e7340`，增量为 0，`uap-core/` 零改动）。
- **不等 → 刷新路径**：继续 §2.2 → §2.3 → §2.4。
- ls-remote 网络失败：标 `[LOCAL_DEAD_LINK]`，记入证据；本 SOP 无法在无网环境执行上游核实，状态未解决，回补触发 = 网络可用。

### 2.2 步骤 2：上游 clone 到仓库外临时区

```
set -euo pipefail
WORK=$(mktemp -d)   # 仓库外临时区；$WORK 在同一会话内持续有效
echo "scratch: $WORK"
git clone --depth 1 https://github.com/ua-parser/uap-core "$WORK/uap-core-upstream"
# 若目标 commit 不是 clone 到的 HEAD，补取目标 commit：
git -C "$WORK/uap-core-upstream" fetch --depth 1 origin <目标commit完整40位哈希>
git -C "$WORK/uap-core-upstream" checkout <目标commit短哈希>
git -C "$WORK/uap-core-upstream" log -1 --format='%h %cd %s' --date=short
```

- **适用性（两条路径都执行）**：本步在「已是最新」与刷新两条路径**都执行**——`$WORK` 内的 upstream clone 是 §2.3 A5 对账/维持证明的对照侧，两条路径都需要。其中 `fetch <目标commit完整40位哈希>` 与 `checkout <目标commit短哈希>` 两子步为**刷新路径专用**（目标 commit ≠ clone HEAD 时才需要）；「已是最新」路径目标即 clone HEAD，这两行逐字执行亦无害（checkout 同一 commit，exit 0）。
- **预期输出**：clone exit 0；末行打印目标 commit 短哈希、**CommitDate（快照日期的权威来源，格式 YYYY-MM-DD）** 与提交信息。2026-09-13 基线实测：`73e7340 2026-08-24 Clean up errant whitespace in regexes.yaml`（标注的快照日期取 CommitDate，非 AuthorDate）。
- **破坏性操作规则（总则）**：clone 只落在 `$WORK`。**禁止任何备份/克隆/scratch 留在仓库内**；结束后 `$WORK` 可留待系统 TEMP 自清，仓库内不得有残留。

### 2.3 步骤 3：A5 对账与增量统计（刷新路径必做；「已是最新」路径可作为维持证明复跑）

> **内嵌 .git 警告（机制知识，务必先读）**：vendored `uap-core/` 目录可能内嵌一份 `.git`（基线遗留；**未被父仓库跟踪，对父仓库 `git status` 不可见**）。它的存在性分两种形态，**均为预期、不是异常**：**主检出（canonical main tree）→ 在场**，原样保留、当普通文件处理（勿删勿提交）；**worktree 检出（`git worktree add`）→ 缺席**（untracked 文件不随 worktree 传播），无需补建、不得当作缺陷去"修复"。刷新与备份都把它当普通文件处理——`cp -r` 会在场时把它一并带走，这是正确行为；但一切递归 diff / 文件清单对比**必须排除它**（`--exclude=.git` 在其缺席时同样无害），否则两侧各自的 `.git` 会制造无意义差异。worktree 走刷新路径时注意：§2.4 的 `cp -r "$WORK/uap-core-upstream" uap-core` 会把上游 clone 的 `.git` 带入新 vendor 目录，属预期，照常勿删勿提交。

```
set -euo pipefail
# CWD: 仓库根（bash 进程替换需 bash；Git Bash 即是）
# 文件清单对比（排除内嵌 .git）
diff <(cd "$WORK/uap-core-upstream" && git ls-files | sort) \
     <(cd uap-core && find . -type f -not -path "./.git/*" | sed 's|^\./||' | sort)
# → 输出为空 = 两侧文件清单一致

# 内容递归 diff（排除内嵌 .git）
diff -r --exclude=.git "$WORK/uap-core-upstream" uap-core
# → 输出为空、退出码 0 = 内容一致，对账通过
```

- **预期输出/判定**（「已是最新」路径）：两个 diff 均为空（2026-09-13 实测：两侧各 26 个文件、内容逐字节一致，对账通过）。
- **刷新路径**：diff **必然非空**——它就是增量清单。逐文件记录变更，再做规则/用例级增量统计：

```
set -euo pipefail
# CWD: 仓库根
echo "--- vendored ---"
grep -c "^  - regex:" uap-core/regexes.yaml
awk '/^[A-Za-z_]+:/{s=$1} /^[[:space:]]*- /{c[s]++} END{for(k in c) print k, c[k]}' uap-core/regexes.yaml
echo "--- upstream ---"
grep -c "^  - regex:" "$WORK/uap-core-upstream/regexes.yaml"
awk '/^[A-Za-z_]+:/{s=$1} /^[[:space:]]*- /{c[s]++} END{for(k in c) print k, c[k]}' "$WORK/uap-core-upstream/regexes.yaml"
echo "--- test cases: vendored | upstream ---"
for f in test_ua test_os test_device; do
  printf "%s: %s | %s\n" "$f" \
    "$(grep -c '^[[:space:]]*- user_agent_string:' uap-core/tests/$f.yaml)" \
    "$(grep -c '^[[:space:]]*- user_agent_string:' "$WORK/uap-core-upstream/tests/$f.yaml")"
done
```

- **预期输出/判定**：基线值 1270（ua 433 / os 204 / device 633）与 1601/483/16129（合计 18213）。两侧相减得**新增/修改/删除规则数与新增测试用例数**，写入证据（「已是最新」路径三项全 0）。这些数字随后用于核对 §3.3 生成器 stdout（三方互证：YAML 计数 = 生成器计数 = 差分套件规模）。

### 2.4 步骤 4：覆盖刷新（破坏性操作，先备份后动手）

> **破坏性操作规则**：覆盖前先备份到**仓库外**临时区并**确认副本存在**；禁止把备份放进仓库。vendored 内嵌 `.git` 随 `cp -r` 一并备份（普通文件处理）。

```
set -euo pipefail
# CWD: 仓库根
BAK="$WORK/uap-core.bak-$(date +%Y%m%d)"
cp -r uap-core "$BAK"
ls "$BAK/regexes.yaml"                # 确认副本存在
diff -r --exclude=.git uap-core "$BAK" # 副本与原件一致（退出 0）

# —— 以下为覆盖点，确认备份无误后再执行 ——
rm -rf uap-core
cp -r "$WORK/uap-core-upstream" uap-core
git status --porcelain uap-core/
git diff --stat uap-core/
```

- **预期输出/判定**：备份两步均静默通过（ls 列出文件、diff 退出 0）才允许覆盖。覆盖后 `git status` 列出快照变更文件（与 §2.3 增量清单一致）；`git diff --stat` 即快照增量，抄入证据。
- 新 vendor 目录携带上游 clone 的内嵌 `.git`——未被父仓库跟踪、status 不可见，照常当普通文件处理，勿删勿提交。覆盖前基线形态两处皆可能：主检出本有内嵌 `.git`，worktree 本无（见 §2.3 警告块）；覆盖后统一变为「携带 clone 的 `.git`」，两种起点下均为预期。
- **「已是最新」路径本步 na**（决策门已裁定不覆盖；备份步骤同样不适用，2026-09-13 实测即如此）。

### 2.5 预期输出/判定（本节）

- 决策门有结论且已记录：「已是最新」+ 增量 0，或新 commit 短哈希 + CommitDate + 三分计数增量；
- 刷新路径：备份确认 → 覆盖 → status 与增量清单吻合；
- 仓库内零 scratch 残留（`git status --porcelain` 除 `uap-core/` 预期变更外无新增杂项）。

## 3. 再生成与幂等

### 3.1 步骤 1：生成物备份（破坏性操作规则，同样适用）

```
set -euo pipefail
# CWD: 仓库根
BAK2="$WORK/moon_ua_regen_$(date +%Y%m%d)"
mkdir -p "$BAK2"
cp -r moon_ua_parser_lib/src/ua_parser/rules "$BAK2/rules.bak"
cp -r moon_ua_parser_lib/tests/differential "$BAK2/differential.bak"
ls "$BAK2/rules.bak" "$BAK2/differential.bak"   # 确认副本存在（5 + 4 个文件）
```

- **预期输出/判定**：`rules.bak` 5 个文件（moon.pkg / rules_data.mbt / rules_init.mbt / rules_init_test.mbt / rules_version.mbt），`differential.bak` 4 个文件（diff_ua.mbt / diff_os.mbt / diff_device.mbt / moon.pkg）。注意备份副本携带 worktree 的 CRLF，而再生成写出 LF——对比备份与生成物要用 `diff -r --strip-trailing-cr`（T-03 实测），见 §3.4。

### 3.2 步骤 2：更新生成器快照常量（仅刷新路径；「已是最新」路径跳过）

```
set -euo pipefail
# CWD: 仓库根
grep -n "UAP_CORE_COMMIT\|UAP_CORE_DATE" scripts/gen_rules.py
```

将 `scripts/gen_rules.py`（约 65-66 行）两处常量手工改为 §2.2 记录的新值：

```python
UAP_CORE_COMMIT = "<新 commit 短哈希>"
UAP_CORE_DATE   = "<新快照日期 YYYY-MM-DD，取上游 CommitDate>"
```

- `scripts/` 是手写层，允许编辑；该常量经生成流入 `rules_version.mbt`，是 README/常量/生成器三处一致的源头。
- **预期输出/判定**：改后 grep 显示新值；§3.3 生成器 stdout 首行同步显示新值。

### 3.3 步骤 3：运行生成器（权威命令，spec §3 契约字面）

生成器权威命令：`python scripts/gen_rules.py`、`python scripts/gen_tests.py`（仓库根执行；路径字面以 ci.yml:62-63 为准）。生成器 **CWD 无关**（内部按脚本自身位置定位仓库根，stdout 首行打印的绝对路径可核对），以下两种形态等价：

```
set -euo pipefail
# CWD: 仓库根（契约字面形态）
python scripts/gen_rules.py
python scripts/gen_tests.py
```

```
set -euo pipefail
# CWD: moon_ua_parser_lib/（ci.yml:62-63 字面形态：working-directory = moon_ua_parser_lib）
python ../scripts/gen_rules.py
python ../scripts/gen_tests.py
```

- **预期输出/判定**（2026-09-13 基线逐字实测；刷新路径应为 §2.3 的新计数。`wrote` 行为**逐文件一行、绝对 Windows 路径 + 字节数**，路径前缀与字节数随机器/快照而变，**不作为判据**）：

`python scripts/gen_rules.py`：

```
Reading <仓库根绝对路径>\uap-core\regexes.yaml
uap-core snapshot: commit 73e7340, date 2026-08-24
user_agent_parsers  :  433 rules (0 with flag i)
os_parsers          :  204 rules (0 with flag i)
device_parsers      :  633 rules (65 with flag i)
total               : 1270 rules
wrote <仓库根绝对路径>\moon_ua_parser_lib\src\ua_parser\rules\rules_data.mbt (257923 bytes)
wrote <仓库根绝对路径>\moon_ua_parser_lib\src\ua_parser\rules\rules_version.mbt (465 bytes)
wrote <仓库根绝对路径>\moon_ua_parser_lib\src\ua_parser\rules\moon.pkg (378 bytes)
OK
```

`python scripts/gen_tests.py`：

```
Reading <仓库根绝对路径>\uap-core\tests
test_ua.yaml      :   1601 cases (0 exempted)
test_os.yaml      :    483 cases (0 exempted)
test_device.yaml  :  16129 cases (0 exempted)
total             :  18213 cases
wrote <仓库根绝对路径>\moon_ua_parser_lib\tests\differential\diff_ua.mbt (342278 bytes)
wrote <仓库根绝对路径>\moon_ua_parser_lib\tests\differential\diff_os.mbt (103272 bytes)
wrote <仓库根绝对路径>\moon_ua_parser_lib\tests\differential\diff_device.mbt (3542364 bytes)
wrote <仓库根绝对路径>\moon_ua_parser_lib\tests\differential\moon.pkg (305 bytes)
OK
```

- 判定：两脚本 exit 0、结尾 `OK`；规则计数与 §2.3 一致。连续跑第二遍 stdout 应逐字节相同（T-03 双跑实测）。

### 3.4 步骤 4：幂等门禁（CWD 陷阱 + EOL 机制，两条机制知识必读）

**陷阱一（CWD）**：生成器 CWD 无关，但 **git 幂等门禁必须在 `moon_ua_parser_lib/` 下执行**：

```
set -euo pipefail
# CWD: moon_ua_parser_lib/   ← 必须在此目录，见下
git diff --exit-code -- src/ua_parser/rules tests/differential && echo "IDEMPOTENT (content-level)"
```

- 在**仓库根**执行同 pathspec（`git diff --exit-code -- src/ua_parser/rules tests/differential`）会因 pathspec 落空匹配 0 个文件而**空转通过**（exit 0 但什么都没验证）——2026-09-13 实测确认。仓库根执行时必须带 `moon_ua_parser_lib/` 前缀。ci.yml:59-64 的该步骤 working-directory 即 `moon_ua_parser_lib`。

**陷阱二（EOL）**：本仓库 `core.autocrlf=true` 且无 `.gitattributes`；HEAD blob 为 LF、worktree 检出为 CRLF、生成器以 `newline="\n"` 写 LF。因此再生成后 `git status --porcelain` 很可能显示生成文件 `M` 旗标，而内容零变化（git 转换安全性 dirtying，T-03 实测 9/9 文件 blob-id 与 HEAD 一致）。规则：

- **幂等判据 = 内容级 `git diff --exit-code`（上面的命令）。禁止用「porcelain 为空」作幂等判据**——porcelain 只会误报。
- **禁止**通过添加 `.gitattributes` 或修改 `core.autocrlf` 来"修"EOL（会波及全仓库行为）。
- EOL 脏位如需清场，用 `git checkout -- <files>` 还原——还原即消除 M 旗标，内容不变。

- **预期输出/判定**：
  - 「已是最新」路径：exit 0（无输出行，仅 git 的 LF/CRLF stderr 警告可忽略）= 再生成复验通过（同一输入 ⇒ 同一输出）。旁证（可选）：`diff -r --strip-trailing-cr src/ua_parser/rules "$BAK2/rules.bak"` 为空。
  - 刷新路径：diff **非空且全部可由快照变更解释**（规则/用例计数变化、对应域的数据文件变化）= 预期内，通读 diff 后进入 §3.5；**diff 非空且无法用快照变更解释 = 新增违规（spec §2 R3），阻断合并，走 §6 回滚**。
  - 留痕：`git status --porcelain` 输出照抄进证据（仅作记录，不作判据）。

### 3.5 步骤 5：公开 API 零漂移门禁（moon check + moon info + mbti）

```
set -euo pipefail
# CWD: moon_ua_parser_lib/
moon check            # 预期 0 errors
moon info
git diff --exit-code -- '*.mbti' '**/*.mbti' && echo "API ZERO DRIFT"
```

- **预期输出/判定**：`moon check` 0 errors（现存约 44 条 warnings 为手写测试文件既有弃用告警，非生成文件，不判失败）；`moon info` exit 0；mbti diff exit 0 = 公开 API（含 `src/ua_parser/pkg.generated.mbti`）零漂移。**这是硬门禁：规则更新绝不允许公开 API 变化。**

**moon info 副产物处置（机制知识）**：`moon info` 会在**从未提交过 .mbti 的包**下生成约 7 个 untracked `pkg.generated.mbti` 副产物（2026-09-13 实测：根目录、examples/middleware、src/ua_parser/rules、tests/differential、tests/diffstats、tests/robust、tests/semantics）。处置 = 记录后删除，**勿提交、勿残留**：

```
set -euo pipefail
# CWD: moon_ua_parser_lib/
git status --porcelain | grep '^??' || true   # 记录 untracked 清单进证据
rm -f pkg.generated.mbti \
      examples/middleware/pkg.generated.mbti \
      src/ua_parser/rules/pkg.generated.mbti \
      tests/differential/pkg.generated.mbti \
      tests/diffstats/pkg.generated.mbti \
      tests/robust/pkg.generated.mbti \
      tests/semantics/pkg.generated.mbti
git diff --exit-code -- '*.mbti' '**/*.mbti'  # 删除后复跑门禁，仍应 exit 0
```

- 注意：`src/ua_parser/pkg.generated.mbti` 是**被跟踪的**真接口文件，不在删除清单；删除动作只针对 `git status` 里 `??` 的 untracked 副产物，删除前逐个核对清单。

### 3.6 步骤 6：编译兼容复验（刷新路径必做；「已是最新」路径可作抽样维持验证）

```
set -euo pipefail
# CWD: moon_ua_parser_lib/
moon test --target native -p src/ua_parser/rules
# 预期: Total tests: 4, passed: 4, failed: 0.
```

- **判定语义**（T-02 实测机制）：4 个 test 块断言 ua/os/device 三数组长度（433/204/633），数组初始化对每条 pattern 以 moonbitlang/regexp@0.3.5 真编译，任一失败即 abort。**通过 ⟺ 1270/1270 全部可编译。**
- **决策门**：不可编译率 > 2%（基线 1270 条即 >25 条）→ **停下交用户裁决**（升级 regexp 依赖 vs 改写量评估），裁决前不继续；≤ 2% → 按不可编译清单走 §5 归因（R4 改写）后重跑本步。
- 已知陷阱：`moon test -f` 的参数是**测试名 glob 而非文件过滤**（T-02 实测：`-f diff_os.mbt` 匹配 0 用例、无判定意义），勿用文件名当 `-f` 参数。

### 3.7 步骤 7：快照版本记录一致性（README「Snapshot provenance」）

快照版本记录字段（spec §3 契约）：**commit 短哈希 + 快照日期 + 规则计数（user-agent/OS/device 三分计数）**，写入 README 的 **「Snapshot provenance」节（节名字面保留）**。

```
set -euo pipefail
# CWD: 仓库根
grep -n "UAP_CORE" moon_ua_parser_lib/src/ua_parser/rules/rules_version.mbt
sed -n '/## Snapshot provenance/,/^## /p' moon_ua_parser_lib/README.mbt.md
```

- 刷新路径：再生成后 `rules_version.mbt` 已自动携带新常量；手工把 README「Snapshot provenance」节改写为新 commit 短哈希、新快照日期、新三分计数（含差分用例数，若变）。节名与其他字段风格保持字面结构。
- 「已是最新」路径：逐项核对 README 现值 == 生成器 stdout == rules_version.mbt 常量（T-03 R5 用同样七行核对表实测全 match），**无需改动**。
- **预期输出/判定**：三处（README / rules_version.mbt / gen_rules.py 常量）同一 commit、同一日期、同一计数。

### 3.8 预期输出/判定（本节）

- 幂等门禁 exit 0（维持路径）或 diff 可归因（刷新路径）；moon check 0 errors；mbti 零漂移 exit 0；副产物已删净（`git status --porcelain` 无 `??`）；
- 编译兼容 4/4（刷新路径，或已裁决处置）；
- README/常量三处一致。任一不满足 → §5 归因或 §6 回滚。

## 4. 差分门禁

### 4.1 分域通过率（diffstats）

```
set -euo pipefail
# CWD: moon_ua_parser_lib/
moon run --target native --release tests/diffstats
```

- **预期输出**（2026-09-13 实测，即 `docs/evidence/diffstats-2026-09-13.txt` 全文）：

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

- **三域阈值**：ua（browser）≥99% / os ≥97% / device ≥97%——diffstats 内建 9900/9700/9700 bps 门禁，未达标行 `status=NOT-MET`、末行非 `GATES: ALL MET`。判定：`GATES: ALL MET` = 门禁过；任一 NOT-MET → 失败分组（failure groups）输出失败模式，进 §5 归因（修引擎或 R4 改写）后重跑；无法归因 → §6 回滚。
- 口径：`rate = passed / total`，exempted 计入分母（既非通过也非失败）；豁免钩子 = `scripts/test_exemptions.json`（文件不存在 = 零豁免）。
- **patch_minor 政策（延续，spec §3 契约）**：差分比对**排除 patch_minor 期望列**，豁免依据 uap-core#562（golden 的 patch_minor 列与权威实现矛盾；uap-python 自家测试协议即 pop 掉该列，`tests/test_core.py:93-97`）。browser 域比较列 = family/major/minor/patch。该政策为台账现行政策条目（`docs/regex-migration.md` §4.1），新快照**直接沿用，无需逐例豁免**，patch_minor 失配不登记为新偏差。
- 耗时参考（T-04 实测量级）：native release 约 5-6 分钟（debug 全量差分约 17 分钟，结果与 release 一致，门禁用 release）。

### 4.2 三后端复核（js 必过；wasm 构建必过，运行失败按 LOCAL_DEAD_LINK 登记）

```
set -euo pipefail
# CWD: moon_ua_parser_lib/
moon test --target js      # 必须过
moon build --target wasm   # 本地 wasm 门槛：构建必须通过
moon test                  # 默认 target=wasm：wasm 运行时验证
```

- **预期输出/判定**：
  - js：exit 0，`Total tests: 31, passed: 31, failed: 0.`（约 2 分钟）。**js 是必须过的门禁**。
  - wasm：`moon build --target wasm` exit 0 = 本地 wasm 门槛过。
  - wasm 运行（`moon test` 默认 target）：**本机 wasm 运行时存在已知限制**（实测形态一：`0xc0000139`；形态二：`CompileError ... local count too large`，T-04 实测）。运行失败时：标 **`[LOCAL_DEAD_LINK]`**，在证据与台账登记**跨 plan 依赖**（wasm 运行时验证由 CI 承接），**不算门禁失败但必须登记**；`moon build --target wasm` 失败才算失败。

### 4.3 预期输出/判定（本节）

`GATES: ALL MET` + js 全绿 + wasm 构建通过（运行失败已按 LOCAL_DEAD_LINK 登记）= 差分门禁过。

**采集陷阱（机制知识，务必先读）**：diffstats 的数据表经 **stderr** 中继输出（`moon run` 本身 exit 0，交互终端看不出差别），**仅捕获/重定向 stdout 会得到空文件**。证据落盘必须合并 stderr（`2>&1`）：

```
set -euo pipefail
# CWD: moon_ua_parser_lib/
moon run --target native --release tests/diffstats 2>&1 | tee ../docs/evidence/diffstats-YYYY-MM-DD.txt
# → 文件内容即 §4.1 的数据表全文（含失败分组与 GATES 行）
```

合并捕获的全量输出（stdout+stderr，含失败分组）即 `docs/evidence/diffstats-YYYY-MM-DD.txt` 的内容。

## 5. 归因登记

台账载体：`docs/regex-migration.md`（沿用其现行结构）。**追加式登记：新增偏差逐条追加，不改既有行。**

### 5.1 台账登记五要素（spec §3 契约：必备内容，非字面行格式）

每条新增偏差的登记必须承载以下五要素（**内容要求**）：

| 要素 | 说明 |
|------|------|
| rule id | 域内定位（如 `ua[1577]` / device 规则索引 / YAML 下标），可检索 |
| 期望输出 | golden（uap-core tests）期望值 |
| 实际输出 | 本引擎输出（或权威 uap-python 输出，三栏审计口径注明） |
| 处置 | **改写 或 豁免**（二选一，写明） |
| 上游 issue 链接 | 豁免必附；改写建议附 |

五要素是登记内容的完备性要求，**不是字面行格式**：不要求把偏差写成五字段单行。结构上沿台账 `docs/regex-migration.md` §4 的现行表格形态承载（§4.1 政策采纳条目两列表、§4.2 三栏审计逐例表、§4.3 引擎设计偏差记录）——凡五要素信息齐备、且按 §5.3 可检索，即符合本节。

归因三分类（沿台账 §4 口径）：(a) 引擎语义差 / (b) 上游笔误（权威协议豁免）/ (c) 已知难点。登记前建议做三栏审计（golden × uap-python × 本引擎）定位差异归属。

### 5.2 处置纪律（R4 红线）

- **改写只落在生成器**：不兼容正则的改写发生在 `scripts/gen_rules.py` 的转换逻辑，**不在生成物上**（生成物头注 `GENERATED — DO NOT EDIT`；任何生成物手改都会被下一次再生成抹掉，spec 红线 3）。改写后重跑 §3.3 起全部步骤。
- **修引擎优先于豁免**：能用引擎语义修正覆盖的偏差不做豁免（参考台账 §4.3 device 空 family 跳过语义的设计取舍记录）。
- **豁免必须附上游 issue 链接**；批量豁免（政策类）沿用 §4.1「政策采纳条目」单条登记模式（先例：patch_minor / uap-core#562）。
- patch_minor 期望列排除为**现行政策**，不按新偏差登记。

### 5.3 可检索性验收

```
set -euo pipefail
# CWD: 仓库根
grep -c "<注入或新增偏差的 rule id>" docs/regex-migration.md   # 预期 ≥ 1
```

- **预期输出/判定**：计数 ≥ 1（spec §4 行 3 的失败可诊断性验收）。本轮零新增偏差时，在证据中写明"零新增偏差声明"（三域 failure groups 均为 `(none)`、豁免数为 0 即可支撑）。

## 6. 回滚

spec §3 契约：回滚 = **`git revert`（已提交情形）或还原快照目录（未提交情形）**。区分两种粒度：

### 6.1 粒度 A：仅生成物（快照未动，只回退再生成结果）

```
set -euo pipefail
# CWD: 仓库根
git checkout -- moon_ua_parser_lib/src/ua_parser/rules moon_ua_parser_lib/tests/differential
```

（等价形态：`# CWD: moon_ua_parser_lib/` 下 `git checkout -- src/ua_parser/rules tests/differential`。）

- **预期输出/判定**：静默；`git status --porcelain` 中生成物 M 旗标消失（EOL 伪脏旗标也会一并消除——还原即消除 M 旗标，内容不变，见 §3.4）。

### 6.2 粒度 B：含快照目录（整体还原 vendor + 生成物）

```
set -euo pipefail
# CWD: 仓库根
git checkout -- uap-core moon_ua_parser_lib/src/ua_parser/rules moon_ua_parser_lib/tests/differential
```

- `git checkout` 只还原**被跟踪**文件。若刷新引入过新增/删除文件、或需要还原内嵌 `.git`（untracked，git 管不到），用 §2.4 的仓库外备份整目录还原：

```
set -euo pipefail
# CWD: 仓库根（$WORK 为同一会话的临时区；跨会话时不可用——这也是备份必须在动手前做的原因）
rm -rf uap-core
cp -r "$WORK/uap-core.bak-YYYYMMDD" uap-core     # 用实际备份目录名
git status --porcelain uap-core/                  # 预期与刷新前一致（干净）
```

- **已提交后**的回滚：`git revert <commit>`（还原引入快照变更的提交），随后仍按 §6.3 复跑。

### 6.3 复跑门禁清单（回滚后必做，全部通过才算回滚完成）

```
set -euo pipefail
# 1) 再生成幂等（# CWD: moon_ua_parser_lib/）
python ../scripts/gen_rules.py && python ../scripts/gen_tests.py
git diff --exit-code -- src/ua_parser/rules tests/differential
# 2) moon check（# CWD: moon_ua_parser_lib/）→ 0 errors
moon check
# 3) mbti 零漂移（# CWD: moon_ua_parser_lib/；moon info 副产物按 §3.5 处置）
moon info && git diff --exit-code -- '*.mbti' '**/*.mbti'
# 4) 差分门禁（# CWD: moon_ua_parser_lib/）→ GATES: ALL MET
moon run --target native --release tests/diffstats
```

### 6.4 一致性确认

回滚后核对三处快照记录回到同一（回滚目标）状态：README「Snapshot provenance」节 == `rules_version.mbt` 常量 == `scripts/gen_rules.py` 头部常量（若 §3.2 改过，记得一并还原）。

```
set -euo pipefail
# CWD: 仓库根
grep -n "UAP_CORE" moon_ua_parser_lib/src/ua_parser/rules/rules_version.mbt scripts/gen_rules.py
sed -n '/## Snapshot provenance/,/^## /p' moon_ua_parser_lib/README.mbt.md
```

- **预期输出/判定**：三处一致且等于回滚目标基线（2026-09-13 基线即 `73e7340` / `2026-08-24` / 433/204/633）；§6.3 四步全绿；回滚过程落盘 `docs/evidence/`。

## 7. 更新节奏声明

> **「跟随 ua-parser/uap-core upstream release；release 发布后触发一次更新流程」**（spec §3 契约字面，PRD G-03 裁决）

执行口径：

- **触发锚点 = upstream release（tag）**。release 发布后触发一次本 SOP（从 §1 起完整走一遍）；两次 release 之间不做例行刷新。
- 决策门（§2.1）以**上游 HEAD** 为对账基准：HEAD 可能超前于最新 tag（2026-09-13 实测：HEAD `73e7340` 位于 v0.9.0 之后、未被 tag 覆盖）；`git ls-remote --tags` 用于佐证 release 节奏，HEAD==基线时记「已是最新」。
- 每次执行产出的证据（§1.4）与台账/README 留痕即是节奏执行记录；无网环境按 `[LOCAL_DEAD_LINK]` 登记并回补。

### 7.1 单次更新完成定义（final gate 清单）

- [ ] §2 决策门有结论且已记录（「已是最新」+增量 0，或新 commit + CommitDate + 三分计数增量）
- [ ] §3 幂等门禁 exit 0（或刷新路径 diff 可归因）；EOL 伪脏未误判、未引入 .gitattributes/autocrlf 改动
- [ ] `moon check` 0 errors；mbti 零漂移 exit 0；moon info 副产物已删净
- [ ] §4 `GATES: ALL MET`（≥99%/97%/97%，patch_minor 政策延续）；js 全绿；wasm 构建通过（运行失败已标 `[LOCAL_DEAD_LINK]` 并登记跨 plan 依赖）
- [ ] 新增偏差（如有）已按五要素逐条入 `docs/regex-migration.md`；生成物零手改
- [ ] README「Snapshot provenance」= rules_version.mbt = gen_rules.py 常量三处一致
- [ ] `docs/evidence/` 日期化证据落盘；仓库内无备份/克隆/scratch 残留；工作树无计划外内容变更
