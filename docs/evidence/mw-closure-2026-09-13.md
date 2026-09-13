# 单元收口核对 — mw-closure-2026-09-13.md（任务 T-09 / plan B4）

- 日期: 2026-09-13
- moon 版本: `moon 0.1.20260904 (94521db 2026-09-04)`（feature flags: rr_moon_mod, rr_moon_pkg；与 ci.yml:43 锁定版本一致）
- 执行位置: worktree `F:\moonbit比赛\moon_ua_parser_wt_framework`，分支 `feat/v02-framework-middleware`，HEAD `fc26bd9`
- 执行时 git 状态: 工作树除既登记 untracked 项（`docs/evidence/final-gate-mw-2026-09-13.log`、`docs/evidence/publish-dryrun-mw-2026-09-13.log`、其他单元的 spec/plan 文档）外干净；无已跟踪文件改动。
- 性质: 收口核对（只验不修）。全量测试套件不在本轮复跑——引用 T-07 执行记录 `docs/evidence/final-gate-mw-2026-09-13.log`（7/7 门禁、native 54/54、js 31/31）。

---

## 一、验收命令逐行结果（原始输出登记）

### 行0 — workspace 构建+测试管线（廉价部分实跑；全量测试部分引用 T-07）

命令（仓库根，相对路径）:

```
moon build --target native && cd moon_ua_parser_lib && moon check
```

原始输出尾（分号分隔两条命令的实测尾行；44 条弃用告警全文与 T-07 项2 基线一致，不重复誊录）:

```
$ moon build --target native
Finished. moon: ran 7 tasks, now up to date (6 warnings, 0 errors)
EXIT_BUILD=0

$ cd moon_ua_parser_lib && moon check
Finished. moon: ran 5 tasks, now up to date (44 warnings, 0 errors)
EXIT_CHECK=0
```

- 判定: **PASS** — 两段退出码均 0，0 errors；44 warnings 与 T-03/T-07 基线 44 持平（无新增）。
- 全量测试套件部分（本行完整性所需）: **引用** `docs/evidence/final-gate-mw-2026-09-13.log` §项3/项4 — `Total tests: 54, passed: 54, failed: 0.`（native）+ js 逐包 4+3+9+15 = 31/31（wasm 本地跳过为登记预期，CI 门禁覆盖）。
- 诚实登记（时长）: 行0 实测墙钟约 3 分钟，超出简报「缓存热应数十秒、>90s 终止」的预期——该命令在第 120s 被会话自动转后台后**继续执行至完成**（未人工终止、退出码 0）。归因: 构建缓存非完全 no-op（`ran 7 tasks` 而非 T-07 时的 "no work to do"；lib check 重跑 5 tasks），最可能因 T-08 dry-run 在 `_build/publish/` 写入打包校验工件部分失效了缓存。按「如实记录」要求登记，不计失败。

### 行1 — 选型证据

命令:

```
test -f docs/framework-selection.md && grep -c "来源" docs/framework-selection.md   # ≥6
```

原始输出:

```
$ test -f docs/framework-selection.md
（test 静默通过）

$ grep -c "来源" docs/framework-selection.md
12
```

- 判定: **PASS** — 文件存在；`来源` 计数 12 ≥ 6。

### 行2 — 中间件行为（两包）

命令（plan 回填字面量原样执行）:

```
moon test -p moon_ua_parser_crescent
moon test -p moon_ua_parser_mars
```

原始输出尾:

```
$ moon test -p moon_ua_parser_crescent
（44 条 lib 弃用告警，同基线，略）
Total tests: 7, passed: 7, failed: 0.
EXIT_CRES_LITERAL=0

$ moon test -p moon_ua_parser_mars
moon_ua_parser_mars.internal_test.c
ua_echo.internal_test.c
ua_echo.blackbox_test.c
moon_ua_parser_mars.blackbox_test.c
（44 条 lib 弃用告警，同基线，略）
--> Get /probe
Total tests: 6, passed: 6, failed: 0.
EXIT_MARS_LITERAL=0
```

- CLI 行为登记（R1 要求）: **plan 字面量 `-p moon_ua_parser_crescent` / `-p moon_ua_parser_mars` 在本 CLI（0.1.20260904，workspace 模式）被原样接受**，未出现拒绝/歧义，无需等价形式替换——此处为正面登记，非静默替换。裸 `-p <短包名>` 按 workspace 成员解析并以默认 target（native）运行；未触碰本地已损坏的 wasm 目标。
- 判定: **PASS** — crescent 7/7、mars 6/6，与 T-07 全量套件构成核对（31+10+7+6=54）中的 7/6 完全一致。

### 行3 — 失败取证（引用，不重跑）

- 引用 `docs/evidence/final-gate-mw-2026-09-13.log` §项6（smoke）: 两示例均含畸形 UA 降级行
  `[moon_ua_parser] degraded user-agent parse: reason=empty_fallback ua_summary="SomethingWeNeverKnewExisted"`，且 `done: 4 requests dispatched (3 healthy, 1 degraded synthetic)`。
- 引用 T-04 证据 `docs/evidence/mw1-example-2026-09-13.log:53` 与 T-05 证据 `docs/evidence/mw2-example-2026-09-13.log:57`: 同一取证记录（`{ua_summary, reason}` 落框架日志通道；ua_summary 为 UA 串截断 ≤64 字符），响应侧 status=200、handler 以空 UaInfo 继续链路（spec §3 降级语义）。
- 行2 实跑的 mars 输出中 `--> Get /probe` + 6 tests 即含畸形 UA 断言的集成测试套件（T-07 §项3 构成核对一致）。
- 判定: **PASS（引用证据）** — 三处证据交叉一致。

### 行4 — 集成/交付（四项）

命令:

```
test -f moon_ua_parser_crescent/README.mbt.md
test -f moon_ua_parser_mars/README.mbt.md
grep -c "moon_ua_parser" moon_ua_parser_lib/README.mbt.md
grep -n "middleware\|集成\|patch" .github/workflows/ci.yml
```

原始输出:

```
$ test -f moon_ua_parser_crescent/README.mbt.md
EXIT_README_CRES=0

$ test -f moon_ua_parser_mars/README.mbt.md
EXIT_README_MARS=0

$ grep -c "moon_ua_parser" moon_ua_parser_lib/README.mbt.md
10
EXIT_GREP_LIB_README=0

$ grep -n "middleware\|集成\|patch" .github/workflows/ci.yml
50:      # v0.2 framework middleware (T-06) — INSERTED before the first moon
60:      # therefore adapted from the committed patch files below, before any
65:      # dependency-fetch trigger) forces the fetch here so the patch lands
67:      - name: Apply framework cache patches (post-fetch, pre-build)
72:          git -c core.autocrlf=false apply --check scripts/framework-cache-patches/*.patch
73:          git -c core.autocrlf=false apply scripts/framework-cache-patches/*.patch
120:      # The new workspace-level middleware steps are standardized on
125:      - name: Workspace build (middleware)
EXIT_GREP_CI=0
```

- 判定: **PASS ×4** — 两包 README.mbt.md 存在；lib README 生态节含包名 10 处；ci.yml 中间件步骤命中 8 行（含 `Apply framework cache patches` 与 `Workspace build (middleware)` 两个新步骤），均为 T-06 增量插入。

### 汇总

| 行 | 内容 | 结果 | 证据 |
|---|---|---|---|
| 行0 | workspace 构建 + lib check（廉价部分） | **PASS** | 本文档 §行0（EXIT_BUILD=0 / EXIT_CHECK=0, 0 errors, 44 warnings=基线）；全量测试引用 final-gate log §项3/项4（54/54 native, 31/31 js） |
| 行1 | 选型证据存在 + 来源指针计数 | **PASS** | 本文档 §行1（`grep -c "来源"` = 12 ≥ 6） |
| 行2 | 两中间件包测试（plan 字面量原样） | **PASS** | 本文档 §行2（crescent 7/7 EXIT=0; mars 6/6 EXIT=0; 字面量被 CLI 接受） |
| 行3 | 失败取证（畸形 UA 降级记录） | **PASS（引用）** | final-gate log §项3/项6 + mw1-example log:53 + mw2-example log:57 |
| 行4 | 交付物四项（两 README / lib README 生态节 / CI 步骤） | **PASS ×4** | 本文档 §行4（EXIT=0×2; 计数 10; ci.yml 命中 8 行） |

无 FAIL 行。

---

## 二、[LOCAL_DEAD_LINK] 与 pending 清单复核（逐项: 现状 / 触发条件 / 回补目标批次）

| # | 项 | 现状（2026-09-13 复核） | 触发条件 | 回补目标批次 / 动作 |
|---|---|---|---|---|
| 1 | CI run 证据 `[推送后 GitHub run 历史]` | 分支未推送，无 GitHub run URL；本地 V2 dry-run 预检（T-01/T-06）为推送前证据 | 分支推送 GitHub（首次 run 需关注 job timeout-minutes=60 预算，T-06 登记） | 回补批: 核录 run URL |
| 2 | mooncakes 包页可检索 `[人工核录]` | 生产者包未发布: T-08 实测线上 API 404（`vicoproplus/moon_ua_parser`、`vicoproplus/moon_ua_parser_middleware_core`；对照 `bobzhang/crescent` 200） | 回补批正式发布完成 | 回补批: 人工核录三包包页 |
| 3 | T-02 crescent 包页正文通道 | 已回补: statistics.csv + search API（framework-selection.md §⑤，来源指针 12 条，行1 复核通过） | 回补批包页正文可渲染时 | 回补批: 人工核录升级（补页面口径数据） |
| 4 | T-08 mooncakes 登录态 | 未实测: 三包 dry-run 均失败于依赖解析（registry 缺生产者），早于任何认证环节 | 回补批 dry-run/正式发布首次触碰（依赖齐备后） | 回补批: 届时若失败才适用 `[LOCAL_DEAD_LINK — 触发=mooncakes 登录态确认]` |
| 5 | 跨单元终验 pending | 性能基准分支 `feat/v02-perf-bench`（918d864）未合并；T-07 为单元范围全量验证（头部已登记） | 性能基准（feat/v02-perf-bench）合并 | 回补批: 重跑 T-07 全部门禁（native 全量按 30 分钟预算） |
| 6 | T-08 发版阻塞 | `moon_ua_parser_lib/moon.mod:14 version = "0.1.0"`（< 0.2.0）+ registry 缺生产者模块；三包 dry-run 退出码均 127 | 平台完备 T-09 版本收口合并（lib ≥0.2.0）+ 中间件三包依赖版本升级指向收口后版本 + 发布顺序 lib → middleware_core → crescent/mars | 回补批: 重跑 dry-run→publish→A5 对账（顺序据 T-08 实测推导） |
| 7 | 框架缓存补丁上游追踪 | 补丁已提交并由 ci.yml:67-73 post-fetch git-apply；crescent 7/7 绿（行2 复跑确认） | crescent/async 上游新版本 | 回补批: 评估补丁是否可移除（`scripts/framework-cache-patches/` README 已登记；随附: 补丁空上下文行格式与 *.patch CRLF 防护两个 T-6 deferred minor 一并复核） |
| 8 | lib 44 条弃用告警（Show→Debug 技术债）〔新增，源自 task-7-report〕 | 与 T-03 基线 44 持平（行0 复跑实测 44/0，无新增） | 上游 moonbitlang/core 移除 Show 弃用宽限期时将升级为 error | 回补批/平台完备单元: 登记清理任务（本轮只验不修） |
| 9 | 全量 native 测试后台首跑静默退出归因〔新增，源自 task-7-report〕 | T-07 项3 第 1 次后台运行静默退出（无日志），重试一次全绿；根因未定位（环境事实） | 回补批再跑全量 native 测试时 | 回补批: 沿用后台+轮询执行方式并对静默退出自动重跑一次 |

（#1–#7 = plan 清单原文；#8–#9 = 本任务从 task-7-report 发现并经行0/行2 复核证实后新增。）

---

## 三、总体结论

**单元交付状态 = 已交付待发版（DELIVERED, PENDING RELEASE）。**

- 验收命令行0/行1/行2/行4 全部 PASS（行0 全量测试部分与行3 为 T-07/T-04/T-05 证据引用）；无 FAIL。
- 中间件单元在库公开 API 零变更（4 个 pub fn，T-07 附加验证 `moon info` 零 diff）前提下交付 crescent/mars 两框架包 + middleware_core 共享包，44 warnings 技术债与基线持平。

**阻塞项清单（发版前必须清空，均为回补批动作，本单元内不可解）:**

1. 发版链阻塞（#6 → #2 → #4）: 平台完备 T-09 版本收口（lib ≥0.2.0）→ 升级中间件依赖 → 按序发布三包 → 包页可检索与登录态实测才可进行。
2. 跨单元终验（#5）: 性能基准合并后回补批复跑全部门禁。
3. 证据回补（#1、#3）: CI run URL 与包页人工核录（依赖推送与发布）。
4. 上游跟踪（#7）: 框架缓存补丁在 crescent/async 上游新版后评估移除。

**登记的诚实偏差:** 行0 实跑约 3 分钟（超 ~90s 预期，自动转后台后续跑至完成，退出码 0）——缓存部分失效（T-08 dry-run 工件）所致，已归因、不计失败。

---

*执行: T-09 单元收口核对，2026-09-13。只验不修；本文件 + final-gate log + publish-dryrun log 为 T-09 提交的三个 evidence 文件。*

---

## 四、回补前状态核查（2026-09-13 第二次，遗留问题处理轮）

对第三节阻塞项清单的逐项世界状态复查（命令与输出就地记录，诚实登记）：

| 项 | 核查结果 | 状态变化 |
|----|----------|----------|
| #6 版本收口（发版链阻塞头） | **已解除**：`git show feat/v02-platform-complete:moon_ua_parser_lib/moon.mod` → `version = "0.2.0"`（分支 9997fcc，已推送 origin/feat/v02-platform-complete）。剩余动作 = 各单元分支合并决策（用户）→ 中间件依赖 @0.1.0 升级 → dry-run → 发布 | 🟢 阻塞源已就绪，待合并 |
| #5 跨单元终验 | `feat/v02-perf-bench` 918d864 **仍未合并**（main 与 origin/main 均无） | ⏳ 不变 |
| #7 上游跟踪 | registry index 已刷新（`moon update` + `moon search`）：crescent 最新**仍 0.11.1**、mars **仍 0.3.12**——无共存修复版，**补丁仍必需**。GitHub 仓库已迁移：`bobzhang/crescent` → **`moonbit-community/crescent`**（pushed 2026-09-10，未归档；registry 包名不变）。已登记入补丁目录 README 上游节 | 🟡 有新事实，补丁保留 |
| #3 通道核录 | mooncakes `statistics?raw=true` 本次经纯 HTTP 返回 JS 渲染壳（T-02 期为可用通道）——**通道回归观察**已登记；下载量复核需浏览器人工路线 | ⏳ 不变（新观察） |
| #1 CI run / #2 包页 / #4 登录态 | 依赖推送与发布动作，未变 | ⏳ 不变 |

**本轮已完成的终审建议项（原 Minor/建议 → 已处置）:**

1. ✅ 警告基线门禁：ci.yml 追加「Warning baseline gate」步骤（workspace `moon check --target native`；total ≤ 44 可缩不可涨 + lib 之外 deprecated 必须 = 0；awk 按 `╭─[path]` 块关联路径）。本地 dry-run：正例 total=44/dep_out=0 PASS，反例注入 crescent 路径 deprecated 警告检出=1。
2. ✅ crescent `supported_targets` 收敛：`-all+native+wasm` → `-all+native`（wasm 无任何本包证据——本地 wasm 运行时损坏、CI wasm 门禁仅覆盖 lib；`moonbitlang` 社区 crescent_wasm_demo 存在仅证明框架族 wasm 可行性）。README 版本区间节同步改写；收敛后 crescent check 0 errors / 测试 7/7 / workspace build 绿。
3. ✅ 根 `.gitattributes`：`*.patch -text`（Windows autocrlf 检出破坏补丁字节的防护）。
4. ✅ `moon install` 无参弃用形式：**保留**（`moon fetch` = unstable、`moon update` = 仅索引，无稳定显式 fetch 等价物；工具链锁定 0.1.20260904 下该形式可用）——理由已在本步骤既有注释与本轮记录。

*执行: 遗留问题处理轮（用户指令），2026-09-13。合并/推送决策仍待用户。*

---

## 五、跨单元终验回补（2026-09-13，四单元合并后）

用户批准合并后，四个 v0.2 单元已全部合入 main（merge-base a56a85c）：
- `7f549ee` Merge feat/v02-platform-complete（版本收口 0.2.0、弃用清理）
- `05eb742` Merge v02-rules-update（规则 SOP、replay 证据）
- `6aa945b` Merge feat/v02-perf-bench（三后端时钟探针、bench 套件；ci.yml 冲突按「双步骤保留」解决）
- `c661bc7` Merge feat/v02-framework-middleware（workspace + 中间件三包；ci.yml 冲突同上）
- `42f2f91` 集成加固：mizchi-x-windows-fd.patch 固化（合并后主树在 Windows 原生复现 T-05 已知 4 错误——cfg 门控补丁跨平台安全，`*.patch` 通配一并应用）；警告基线 44→**18** 重校准（platform-complete 清理后：9 deprecated + 8 deprecated_syntax + 1 unused_constructor，全在 lib 内）
- `5ef6d69` 中间件依赖升级 @0.1.0→**@0.2.0**（moon.mod ×3 + README ×2）

**终验结果（`docs/evidence/cross-unit-gate-2026-09-13.log`，全绿）：**
构建 0 errors；警告门禁 18/0 PASS；全量 native **54/54**；js 31/31（rules 4 + robust 9 + semantics 15 + differential 3）；生成一致性 byte-identical（日志 exit 标记因脚本相对路径缺陷缺位于第 5 步，已单独补验 exit 0）；集成测试 crescent 7/7 + mars 6/6 + helper 10/10；双示例 smoke 退出 0；bench smoke 退出 0；mbti 零 diff。wasm 门禁仍归 CI（本地 wasm 运行时损坏，既有环境事实）。

**第三节阻塞项清单状态更新：** #5 跨单元终验 ✅ 已完成；#6 版本收口 ✅ 已合并 + 依赖升级完成。剩余：#1 CI run（推送后）、#2 包页核录、#3 通道人工核录、#4 登录态（dry-run/发布时实测）。

---

## 六、发版回补（2026-09-13，用户批准发布）

**已发布并核录（`docs/evidence/publish-final-2026-09-13.log`）：**
- `vicoproplus/moon_ua_parser` **0.2.0** — Server 200，registry+包页 HTTP 200 ✓
- `vicoproplus/moon_ua_parser_middleware_core` **0.1.0** — Server 200，包页 200 ✓
- `vicoproplus/moon_ua_parser_crescent` **0.1.0** — Server 200，包页 200 ✓（回补 `preferred_target = "native"` 后过沙箱 wasm 校验）

**阻塞登记（mars 0.1.0）：** 发布沙箱（本机 fresh 环境）check 命中上游 mizchi/x@0.6.1 Windows fd() 类型错误 ×4（workspace 补丁不可达沙箱；registry 无新版；WSL 路线被 CDN 403 阻断）。恢复条件 = mizchi/x 上游修复后 `moon publish`，或经 Linux CI/机器发布。证据链见 publish-final log 第 4 节。

**遗留清单终态：** #2 包页核录 = 已发布三包 ✅（mars 待发布）；#4 登录态 ✅（vicoproplus）；#6 版本收口+依赖升级 ✅；#5 跨单元终验 ✅；#1 CI run 与推送 = 待用户推送；#3 statistics 通道人工核录 = 浏览器路线待人工；#7 上游追踪 = 补丁仍必需（crescent 仍 0.11.1）+ mizchi/x fd bug 新增登记。
