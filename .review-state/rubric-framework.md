# Rubric — v0.2 审查 / Reviewer B（框架适配层：middleware_core / crescent / mars / 发布基建）

> 审查范围：`git diff a56a85c..4ff2544` 中属于 moon_ua_parser_middleware_core、moon_ua_parser_crescent、
> moon_ua_parser_mars、scripts/framework-cache-patches/、moon.work、.github/workflows/publish-manual.yml、
> ci.yml 中间件步骤、docs/framework-selection.md 的部分。
> 判定格式要求：每条 R 在报告中给出 pass / fail / na + 一行可核查证据。

- [ ] R1: middleware_core 纯度 — helper 包无框架 API、无 IO、无全局可变状态；assemble 为纯函数；降级三分支（Err / 全 fallback / 健康）齐全且各有锁定测试
- [ ] R2: 截断与常量契约 — truncate_ua_summary 64 字符截断边界正确（空串/恰好 64/超长）；REASON_PARSE_ERROR / REASON_EMPTY_FALLBACK 常量与 forensics 记录一一对应且有测试
- [ ] R3: crescent 薄层 — 中间件闭包只做：读 User-Agent header → 单次 assemble(ua, parse(ua)) → mount 到 res.headers → forensics 转发 sink → next()；零内联组装/降级/取证逻辑
- [ ] R4: crescent JSON 往返 — ua_info_to_json/from_json 对 UaInfo 全字段类型化往返有测试；malformed/缺字段 JSON 的 from_json 行为有测试且不 panic
- [ ] R5: mars 挂载机制 — 三 family 以原生 Var::String 挂载 ctx.vars，零序列化；「不为 UaInfo 实现 Var（orphan rule）」的裁决有注释/文档记录
- [ ] R6: 集成测试断言用户可见结果 — crescent/mars 各自：健康 UA 可取回（browser/os/device 断言）、malformed UA → 200 + 空 mount（== empty_ua_info）+ 恰一条 forensics；golden UA 样本来源标注（uap-core tests 引用或等价权威）
- [ ] R7: 跨边界 API 外部权威 — crescent 0.11.1 与 mars 0.3.12 每个被调用的框架 API（中间件注册签名、Variables set/get、logger_simple、res.headers 语义）对照外部权威（.mooncakes vendored 源码 file:line 或官方文档），执行同源三方全绿质询并记录共同假设来源
- [ ] R8: 缓存补丁可复现且自述 — 两个 patch 头部路径与 pin 版本（crescent@0.11.1、mizchi/x 对应版本）匹配；README.md 说明每个 patch 的触发条件、作用、上游修复后的移除条件；CI 顺序 fetch→patch→编译 正确（patch 落在首次编译前）
- [ ] R9: workspace/mod 接线一致 — moon.work 成员齐全；middleware_core/crescent/mars 的 moon.mod 名称、版本、依赖（vicoproplus/moon_ua_parser@0.2.0、crescent@0.11.1、mars@0.3.12）相互一致且与 README 安装说明一致
- [ ] R10: publish-manual.yml 安全与语义 — 凭据经 base64 环境变量注入不回显日志；隔离模块副本发布的理由（workspace 上下文 verify 拉未打补丁 crescent）有注释；发布目标版本与 moon.mod 一致
- [ ] R11: mbti 零漂移 — 各 adapter 包已提交的 pkg.generated.mbti 与当前 `moon info` 输出一致（dry-run gen.log 的 EXIT_MBTI_DIFF=0 覆盖 workspace 全体，reviewer 抽查 adapter 包）
- [ ] R12: 降级输出有具名消费方 — degraded 标志与 ForensicsRecord 的每个输出通道（headers mount、forensics sink、默认 println）有具名下游消费方；sink 可注入（测试替换）且默认实现明确
- [ ] R13: 示例可运行且最小 — 两个 examples/ua_echo 无密钥、无网络副作用、README 有运行命令；moon.pkg 的 target 声明与文档一致（native）
- [ ] R14: 错误路径行为归属唯一 — 「UA 解析失败 → 用户收到 200 + 空 mount + 一条取证」这条端到端失败路径有唯一 owner（middleware_core 裁决 + adapter 透传的分工写明）并有测试锁定

## 范围外新发现
- [ ] R15: 上述条目未覆盖、但审查中发现的真实问题（若有，逐条列出新编号 R16+ 或记入 Issues）
