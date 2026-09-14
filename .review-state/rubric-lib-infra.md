# Rubric — v0.2 审查 / Reviewer A（moon_ua_parser_lib + 基建 + 文档）

> 审查范围：`git diff a56a85c..4ff2544` 中属于 moon_ua_parser_lib、scripts/（gen_bench_samples.py）、
> .github/workflows/ci.yml（lib 步骤）、.gitattributes/.gitignore、CHANGELOG.md、docs/（bench/rules/SOP/迁移台账）的部分。
> 判定格式要求：每条 R 在报告中给出 pass / fail / na + 一行可核查证据。

- [ ] R1: 生成物零手改 — `git diff a56a85c..HEAD -- moon_ua_parser_lib/src moon_ua_parser_lib/tests/differential` 为空；`moon_ua_parser_lib/tests/bench/samples.mbt` 仅由生成器再生产生（带 GENERATED 标记）
- [ ] R2: Show→Debug 弃用迁移等价 — tests/semantics/semantics.mbt 与 tests/robust/robust.mbt 的每一处改动仅限弃用形式迁移（derive(Show)→derive(Debug)、println/show 调用点、StringBuilder 构造形式），被断言的行为语义不变；非纯增行逐处列举并说明理由
- [ ] R3: 公开 API 冻结 — `git diff a56a85c..HEAD -- moon_ua_parser_lib/pkg.generated.mbti moon_ua_parser_lib/src` 为空；moon.mod 仅版本号 0.1.0→0.2.0 与（如有）依赖行变化
- [ ] R4: 计时单点 seam — 三后端基准计时唯一经 `clock_pair_diff_us`；clock_native/js/wasm.mbt 各自仅实现该 seam，bench 主逻辑无第二计时路径、无后端内联分支
- [ ] R5: samples.mbt 幂等 — 以 `python scripts/gen_bench_samples.py` 再生成后与提交版内容级一致（考虑 PF-06 需内容级比较）；生成器固定种子、纯标准库、无时钟/网络/乱序依赖
- [ ] R6: bench 运行器契约 — 报告行含 backend/ops_per_sec/ns_per_parse/sample_set_hash 四字段；--smoke 以 SMOKE_NS_PER_PARSE_LIMIT 判违约并非零退出；--profile 模式有界终止（warmup 有上限，不存在无界循环）；三后端 sample_set_hash/checksum 一致性有断言
- [ ] R7: CI 变更受控且每处 hack 有据 — ci.yml 相对 BASE 的每处增改可归入登记项（toolchain pin+硬断言、moon update、wasm 显式 7 包、wasm diffstats 报告、smoke step、警告基线门、中间件 patch/build/test 步骤）；既有 lib 步骤无静默改写；ulimit/latest 传输/patch apply 三处 hack 均有注释与证据指针
- [ ] R8: 警告基线门真实成立 — dry-run 日志中 workspace 警告总数 ≤18 且 moon_ua_parser_lib 外 deprecated=0（派发方日志 check.log，reviewer 复核数字来源）
- [ ] R9: 规则更新单元「纯 docs」声称成立 — 该单元合并后净效果仅触 docs（docs/rules-update-sop.md、docs/regex-migration.md、docs/evidence）；regex-migration.md 相对 BASE 纯追加（零改写/删除行，给出 `git diff` 中 `^-` 计数）
- [ ] R10: CHANGELOG/README 声称与 CI 现实一致 — v0.2.0 条目（wasm 收缩登记、publishing 披露）、README 三后端测试门表述（native/js 全量、wasm 7 包 + build）逐条能在 ci.yml 找到对应步骤；无夸大或过时表述
- [ ] R11: bench 文档与代码一致 — docs/bench-baseline-2026-09-13.md、docs/profile-2026-09-13.md、tests/bench/MANIFEST.md 中的常量（SMOKE_NS_PER_PARSE_LIMIT=150_000_000、corpus_size=10000、stride=20、warmup=2、timed=7）与 tests/bench/main.mbt 实际值一致
- [ ] R12: .gitattributes / .gitignore 变更不使门禁失真 — 新忽略/属性规则不会让 CI 的 mbti 漂移闸或生成一致性闸对真实漂移漏报
- [ ] R13: 测试 diff 纯增量 — 除 R2 列举的迁移行外，`git diff a56a85c..HEAD -- moon_ua_parser_lib/tests` 中无其他被删改的既有断言（给出 `^-` 逐处清单）
- [ ] R14: bench 基建不污染库包 — tests/bench 不进入发布产物（moon.pkg 声明、无 src 依赖反转）；bench 对 lib 的依赖方向单一（bench → @ua_parser），无反向

## 范围外新发现
- [ ] R15: 上述条目未覆盖、但审查中发现的真实问题（若有，逐条列出新编号 R16+ 或记入 Issues）
