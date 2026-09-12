# uap-core 快照上游核实记录（snapshot bump evidence）

- 日期：2026-09-13
- 任务：T-01 上游核实与快照刷新（plan: `docs/superpowers/plans/2026-09-13-moon_ua_parser_v02-规则更新.md`，批次 B1）
- 执行分支：`v02-rules-update`（仓库根）。任务开始时仓库根实际停留在 `feat/v02-framework-middleware`；两分支同指 a56a85c、树完全一致，`git switch v02-rules-update` 为内容等价操作。
- **结论（决策门）：已是最新 — 上游无新 commit（HEAD == 基线 73e7340），快照维持，增量为 0。** 未执行任何刷新写操作，`uap-core/` 零改动。按 brief step 5，T-02 转为对现快照的抽样验证，本单元转为「SOP 交付 + 快照维持」。

## 1. 前置实测（brief step 1，E6 探针）

命令（仓库根执行）：

```
git ls-remote https://github.com/ua-parser/uap-core HEAD
```

原始输出（退出码 0，未触发 `[LOCAL_DEAD_LINK]`，任务继续）：

```
73e7340c3ed8055051607b296bf46ead7aa5f19e	HEAD
```

佐证 release 节奏（`git ls-remote --tags https://github.com/ua-parser/uap-core`，尾部节选）：

```
27f729d0ce859b0109746ff2f51b13cf27619846	refs/tags/v0.7.3
c24767a7b478571e6d8ce3644e7a42347bb05526	refs/tags/v0.8.0
57535a35355d3d8ff252241df8121b42595636d5	refs/tags/v0.9.0
93946855b68e9b708d1fafdd5e4f8a25a6c2d50b	refs/tags/v0.9.0^{}
```

最新 tag 为 v0.9.0（→ 9394685）；上游 HEAD（73e7340）位于 v0.9.0 之后、未被 tag 覆盖。

## 2. 上游 clone 与 HEAD 记录（brief step 2）

上游 clone 到仓库外临时区（`git clone --depth 1 https://github.com/ua-parser/uap-core /tmp/tmp.usATWutIyf/uap-core-upstream`，`/tmp` 为 Git Bash 映射的系统 TEMP）。

- 上游 HEAD 全哈希：`73e7340c3ed8055051607b296bf46ead7aa5f19e`
- 上游 HEAD 短哈希：`73e7340`
- 提交信息：`Clean up errant whitespace in regexes.yaml`
- AuthorDate `2026-05-15 12:20:43 +0100`；CommitDate `2026-08-24 13:09:38 +0100`（vendored 基线标注的 2026-08-24 即 CommitDate）
- vendored `uap-core/` 内嵌 `.git` 的 HEAD 同为 `73e7340c3ed8055051607b296bf46ead7aa5f19e`

实测备注：控制器上下文称 `uap-core/` 内无 `.git`，实测存在一个内嵌 `.git`（基线遗留、未被父仓库跟踪、父仓库 `git status` 不可见）；本任务未触碰。父仓库以普通文件形式跟踪 `uap-core/` 下 26 个文件（非 gitlink，无 `.gitmodules`）。

HEAD == 基线（73e7340）→ 决策门走「已是最新」分支；brief step 3 的覆盖式刷新及其仓库外备份步骤不适用（未执行）。

## 3. 增量统计（R2）

对比对象：vendored `uap-core/` 与上游 checkout（73e7340）。两侧为同一 commit，预期与实测增量均为 0。

### 3.1 regexes.yaml

- 文件级：SHA-256 两侧一致 `2b87343ff8477dbb80e19cc4cd651ca39d258432c5836199deef561b93b07a15`；`git diff --no-index --stat uap-core/regexes.yaml <upstream>/regexes.yaml` 输出为空（零 diff）。
- 规则数（方法：awk 按顶层 section 统计列表项，`/^[A-Za-z_]+:/` 切节、`/^[[:space:]]*- /` 计数）：

| section | vendored | upstream | 增量 |
|---|---|---|---|
| user_agent_parsers | 433 | 433 | 0 |
| os_parsers | 204 | 204 | 0 |
| device_parsers | 633 | 633 | 0 |
| 合计 | 1270 | 1270 | 0 |

交叉验证：`grep -c "^  - regex:"` 两侧均为 1270，与合计一致。

新增 / 修改 / 删除规则数：**0 / 0 / 0**。

### 3.2 tests 用例数

方法：`grep -c '^[[:space:]]*- user_agent_string:'` 逐文件统计（每条用例以 `- user_agent_string:` 开头）。

| 文件 | vendored | upstream | 增量 |
|---|---|---|---|
| tests/test_ua.yaml | 1601 | 1601 | 0 |
| tests/test_os.yaml | 483 | 483 | 0 |
| tests/test_device.yaml | 16129 | 16129 | 0 |
| 合计 | 18213 | 18213 | 0 |

新增测试用例数：**0**。

## 4. A5 对账（R3）

上游 checkout（73e7340）与 `uap-core/` 递归对比，排除 `.git`。命令与结果：

```
# 文件清单对比（两侧各 26 个文件）
diff <(cd UPSTREAM && git ls-files | sort) \
     <(cd VENDORED && find . -type f -not -path "./.git/*" | sed 's|^\./||' | sort)
→ 输出为空：文件清单两端一致

# 内容递归 diff
diff -r --exclude=.git /tmp/tmp.usATWutIyf/uap-core-upstream uap-core
→ 输出为空，退出码 0：内容完全一致，对账通过
```

## 5. 决策门结论与零改动证明（R5）

- 决策门：上游 HEAD（`73e7340`）== vendored 基线（`73e7340`）→ **已是最新，增量为 0**。
- 零改动证明：`git status --porcelain uap-core/` 输出为空（加 `-uall` 亦为空）；本任务对 `uap-core/` 无任何写操作。
- 刷新分支（brief step 3/4：覆盖 vendor 目录、`git diff --stat uap-core/` 显示增量）未触发，na。

## 6. scratch 与仓库卫生（R6）

- 克隆、文件清单、探针原始输出全部位于仓库外临时区 `/tmp/tmp.usATWutIyf/`（`mktemp -d` 生成，映射系统 TEMP）。
- 仓库内无 `.bak`、克隆目录或临时文件残留；本任务在仓库内仅新增本文件 `docs/evidence/snapshot-bump-2026-09-13.md`。

## 7. 对后续任务的移交

- T-02：按决策门转为「对现快照（73e7340）的抽样验证」。
- T-03：`moon_ua_parser_lib/README.mbt.md` 的 Snapshot provenance 节可引用：上游 HEAD `73e7340c3ed8055051607b296bf46ead7aa5f19e`（核实日期 2026-09-13，快照已是最新）。
