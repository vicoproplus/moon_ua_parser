# 产品需求文档（PRD）

> **文档编号**：PRD-2026-001
> **状态**：📝 草稿
> **最后更新**：2026-09-10

---

## 文档信息

| 字段 | 内容 |
|------|------|
| 文档标题 | moon_ua_parser——User-Agent 解析库（ua-parser 的 MoonBit 移植）产品需求文档 |
| 产品版本 | v0.1.0 |
| 作者 | vicoplus |
| 创建日期 | 2026-09-10 |
| 评审日期 | 2026-09-10 |
| 上线日期 | 2026-10-07（暂定） |
| 关联需求 | moon_ua_parser 申报书 |

---

## 修订历史

| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| v0.1 | 2026-09-10 | vicoplus | 初始版本（基于申报书与探索阶段成果） |
| v0.2 | 2026-09-10 | vicoplus | 探索校订：正则引擎 spike 已完成（1274 条规则 100% 编译通过，moonbitlang/regexp@0.3.5 选定）；差分门槛沿用 browser ≥99% / os·device ≥97% |

---

## 一、问题陈述

MoonBit 生态已有 Crescent、mars、pony、mbit、Halo、moonapi 等 10 余个 Web 框架，其公共下游需求是 User-Agent 解析：访问统计按浏览器/设备聚合、响应按移动端/桌面端适配、安全审计识别爬虫。MoonBit 开发者目前没有可用的 UA 解析库，只能手写脆弱的字符串匹配，或放弃设备维度分析——每种框架的作者都在重复解决同一问题，且准确率无法对齐业界口径。

数据支撑：

- 项目自查（2026-09）：mooncakes.io 全量 2363 个包、GitHub 371 个 MoonBit 仓库关键词查重，UA 解析方向**零命中**（来源为项目自查，赛前建议复跑使数字可复现）；
- 跨语言事实标准 uap-core 含 1274 条规则、上游测试资源共 31327 条用例（本仓库实测：`uap-core/regexes.yaml` 1274 条规则；`tests/` 三文件 18213 条 + `test_resources/` 五文件 13114 条），Java/PHP/Python/Rust/Go 均有实现，MoonBit 缺位；
- 技术可行性已实测验证（2026-09-10，本机 spike）：moonbitlang/regexp@0.3.5 对 uap-core 全量 1274 条规则 **0 条编译失败**（探针：native/js 双后端跑通，逐条编译），大小写不敏感折叠双向对称——此前移植不可行的主因（缺正则引擎）已消除。

---

## 二、目标

| 目标编号 | 目标描述 | 衡量指标 | 当前值 | 目标值 | 衡量时间 |
|----------|----------|----------|--------|--------|----------|
| G-01 | parse 主 API 可用并发布到 mooncakes | mooncakes 可安装版本；三组信息可解析 | 无 | v0.1.0 发布且示例可运行 | W4 末（2026-10-07） |
| G-02 | 与 uap-core 语义对齐（质量基线） | 差分测试通过率（对比 uap-python） | 未测 | browser ≥99%；os/device ≥97% | W3 末（2026-09-30） |
| G-03 | 工程完整（比赛首位得分点） | CI 构建与测试；快照版本标注；README 要素 | 无 | CI 全绿 + 版本标注 + 文档要素齐备 | W4 末 |
| G-04 | 生态演示 | 可运行的框架中间件示例数 | 0 | ≥1 个 | W4 末 |
| G-05 | 性能基线（亮点项，非门槛） | 基准脚本与基线数字 | 无 | 建立且可复现，不设优化阈值 | W4 末 |

---

## 三、非目标

| 非目标 | 排除原因 |
|--------|----------|
| UA 伪造检测/设备指纹 | 依赖行为信号与设备库，超出静态规则解析范畴 |
| 设备能力库（屏幕、性能参数） | 需独立数据源与维护线，与 UA 解析无关 |
| 规则实时同步/在线更新 | 快照式发版在比赛周期内更可靠，更新走版本发布 |
| 其余 HTTP 头（Referer、Accept-Language 等）解析 | 聚焦单一请求头，边界清晰 |
| 超越基线记录的性能优化 | 比赛定位为工程完整 > 生态演示 > 性能，性能只建基线 |

---

## 四、用户故事

### 用户角色：MoonBit Web 框架开发者（中间件作者）

**US-01**（P0）：作为 MoonBit Web 框架开发者，我想要调用一次 parse 得到浏览器名称与版本，以便做响应适配与内容协商。

验收标准：
1. 输入 Chrome 桌面 UA 时，返回 family="Chrome" 及正确的 major/minor/patch；
2. 输入仅含 OS 信息的 UA 时，browser 字段按上游语义返回 Other。

**US-02**（P0）：作为 MoonBit Web 框架开发者，我想要解析结果包含操作系统信息，以便按平台做灰度分流。

验收标准：输入 Windows/Android UA 时，os 各字段与 uap-python 输出一致。

**US-03**（P0）：作为 MoonBit Web 框架开发者，我想要解析结果包含设备信息，以便区分移动端与桌面端。

验收标准：输入 iPhone UA 时 device 各字段与 uap-python 输出一致；桌面 UA 按上游语义标记。

### 用户角色：数据/日志工程师

**US-04**（P1）：作为数据工程师，我想要对任意输入（含畸形 UA）都得到确定结果而不崩溃，以便批处理管道稳定运行。

验收标准：空串、超长（>4096 字符）、含控制字符的输入下，parse 返回确定结果或 Error，不崩溃、不超时。

**US-05**（P0）：作为数据工程师，我想要字段结构与 uap-core 数据模型一致，以便复用现有报表口径。

验收标准：返回结构含 browser/os/device 三组字段，语义与 uap-python 对齐。

### 用户角色：风控/安全工程师

**US-06**（P1）：作为风控工程师，我想要从 UA 识别爬虫类别，以便获得爬虫判定的辅助信号。

验收标准：输入 Googlebot UA 时，device.family 输出 Spider（与 uap-python 一致）。

**US-07**（P2）：作为安全审计员，我想要可选地获得命中规则编号，以便审计解析结论来源。

验收标准：启用审计选项后，Chrome UA 的解析结果携带命中规则编号；未启用时结构不变。

### 用户角色：mooncakes 消费者（下游库用户）

**US-08**（P0）：作为 mooncakes 消费者，我想要通过 moon add 安装并开箱即用，以便零配置接入。

验收标准：`moon add vicoproplus/moon_ua_parser` 后 import 即用，运行时无 YAML 解析、无网络、无额外依赖。

---

## 五、需求详细说明

### 5.1 功能需求（FR）

| 需求ID | 需求描述 | 所属用户故事 | 优先级 | 验收标准 |
|--------|----------|--------------|--------|----------|
| FR-01 | 提供 `parse(ua) -> Result[UaInfo, Error]` 主函数，返回 browser/os/device 三组 family/major/minor/patch 字段（device 另含 brand/model） | US-01, US-02, US-03, US-05 | P0 | Chrome 桌面 UA 三组字段与 uap-python 输出逐字段一致 |
| FR-02 | 匹配引擎按 uap-core 语义执行：三组规则各自按序尝试、首条命中生效、未命中返回 Other（browser/os）或 Other（device family 默认 Other） | US-01, US-05 | P0 | uap-core tests/test_ua.yaml 抽样用例通过；未命中 UA 返回 Other |
| FR-03 | 命中规则的替换模板语义对齐 uap-python：family_replacement/os_replacement/device_replacement 及 v1-v4_replacement 的 $1-$4 组替换、strip 后空串归 None | US-01, US-02, US-03, US-05 | P0 | 带替换模板的规则（如 ArcGIS 系列规则）输出与 uap-python 一致 |
| FR-04 | device 规则的 regex_flag: 'i'（65 条）按大小写不敏感语义执行 | US-03 | P0 | 对应规则用例大小写变体输入输出一致 |
| FR-05 | 规则库以构建期转换的 MoonBit 源码数据结构内置，标注快照版本（uap-core commit 73e7340，2026-08-24） | US-08 | P0 | 运行时零 YAML 依赖；README/代码内可查快照版本号 |
| FR-06 | 1274 条规则在库初始化时逐条成功编译（spike 已证 100% 可编译），任一编译失败时给出可定位错误 | US-05, US-08 | P0 | 初始化无 RegexpError；人为损坏一条规则时错误信息含规则定位 |
| FR-07 | 对空串、>4096 字符、含控制字符的输入返回确定结果，不崩溃不超时 | US-04 | P1 | 上述三类输入全量回归通过 |
| FR-08 | 可选返回命中规则编号（编号 = 域内规则序号），默认关闭 | US-07 | P2 | 启用后 Chrome UA 结果含命中规则编号；默认模式结构不变 |
| FR-09 | 提供浏览器/OS/设备单域解析函数（parse_browser/parse_os/parse_device） | US-01, US-02, US-03 | P1 | 单域函数与 parse 对应子域输出一致 |
| FR-10 | 提供≥1 个 Web 框架中间件示例（仓库 examples/ 目录） | US-01 | P2 | 示例可 moon run 跑通并打印解析结果 |
| FR-11 | 上游差分测试：uap-core tests/ 三文件（test_ua/test_os/test_device，18213 条）转为 moon test 用例，通过率达标（browser ≥99%，os/device ≥97%）并写入 README | US-01, US-02, US-03, US-05 | P0 | moon test 全绿；README 记录分域通过率 |
| FR-12 | 发布 mooncakes：moon.mod 元数据完整（name/version/license/repository/readme/keywords） | US-08 | P0 | moon publish --dry-run 通过；mooncakes 页面可安装 |

### 5.2 非功能需求（NFR）

| 类型 | 需求描述 | 衡量标准 |
|------|----------|----------|
| 性能 | parse 单次调用无灾难回溯（VM 引擎保证），基准脚本可复现 | 基准脚本输出基线数字；无超时用例 |
| 兼容性 | native/js 双后端测试通过（wasm 为 moon 默认目标） | moon test --target native / --target js 均全绿 |
| 兼容性 | MoonBit 工具链版本窗口：moon 0.1.20260904 | CI 固定该版本 |
| 安全性 | 对畸形输入（超长、控制字符、空串）不崩溃 | FR-07 全量回归 |
| 可用性 | API 文档（.mbti 接口 + README 示例）齐全 | README 含 quickstart 可复制运行 |

---

## 六、成功指标

| 指标类型 | 指标名称 | 目标值 | 当前值 | 衡量周期 | 数据来源 |
|----------|----------|--------|--------|----------|----------|
| 领先指标 | 差分测试通过率（browser 域） | ≥99% | 未测 | W3 末 | moon test 差分用例 |
| 领先指标 | 差分测试通过率（os/device 域） | ≥97% | 未测 | W3 末 | moon test 差分用例 |
| 滞后指标 | mooncakes 可安装版本 | v0.1.0 上线 | 无 | W4 末 | mooncakes.io 页面 |
| 滞后指标 | moon add 后开箱运行 | 示例可运行 | 无 | W4 末 | 独立目录冒烟 |

---

## 七、开放问题

| 问题 | 领域 | 负责人 | 期望答复 | 状态 |
|------|------|--------|----------|------|
| mooncakes 用户名是否最终为 vicoproplus | 发布 | vicoplus | W4 前确认 | 待答复 |
| 基准测试的 UA 样本集选型（uap-python samples/useragents.txt 9.8MB 或抽样） | 性能 | vicoplus | W4 内决定 | 待答复 |
| 比赛后规则快照更新节奏（每 upstream release 跟进 or 手动触发） | 维护 | vicoplus | 赛后决定 | 待答复 |

---

## 八、时间计划

| 里程碑 | 计划日期 | 实际日期 | 交付物 | 状态 |
|--------|----------|----------|--------|------|
| 兼容性 spike 完成并锁定引擎 | 2026-09-10 | 2026-09-10 | 引擎选型记录（1274 条 0 失败） | ✅ |
| 规则转换脚本 + 数据结构源码生成 | 2026-09-14 | | regexes.yaml → .mbt 数据源码 + 快照版本标注 | ⏳ |
| 匹配引擎 + 主 API | 2026-09-21 | | parse/parse_browser/parse_os/parse_device 可用 | ⏳ |
| 差分测试转换与修复达标 | 2026-09-30 | | moon test 差分通过率 ≥ 门槛 | ⏳ |
| 文档/CI/发布/示例 | 2026-10-07 | | mooncakes v0.1.0 + examples | ⏳ |

---

## 九、依赖与风险

### 9.1 依赖项

| 依赖方 | 依赖内容 | 预计交付 | 当前状态 | 风险等级 |
|--------|----------|----------|----------|----------|
| moonbitlang/regexp@0.3.5 | 正则编译与匹配（VM 执行引擎） | 已发布（alpha，30K 下载） | ✅ 已验证（本机 spike：1274 条 0 失败） | 低（alpha API 可能变） |
| uap-core（commit 73e7340） | regexes.yaml 规则快照 + tests 用例 | 已固定 | ✅ 已固定本地 | 无 |
| moon 工具链 0.1.20260904 | 构建/测试/发布 | 已安装 | ✅ | 无 |
| uap-python（commit 6dd8c39） | 差分对照实现（本地运行取期望值） | 已固定 | ✅ 已固定本地 | 无 |

### 9.2 风险识别

| 风险描述 | 影响 | 概率 | 风险等级 | 应对措施 |
|----------|------|------|----------|----------|
| regexp@0.3.5 为 alpha，未来 API 破坏性变更 | 升级成本 | 中 | 中 | 锁定 0.3.5；moon.mod 固定版本；发布前重跑差分 |
| 匹配语义差异：moonbitlang/regexp 回溯优先级与 uap-core 的 PCRE 语义在 alternation 上存在差异 | 个别规则差分失败 | 中 | 中 | W2 引擎实现时对 alternation 语义抽样验证；差异用例记录并逐条对齐 |
| device 差分通过率不足 97%（16k 用例含大量爬虫/型号） | G-02 不达标 | 中 | 中 | W3 全量差分后逐域修复；上游已知难点用例单列 |
| 规则快照 1274 条全量编译导致库初始化耗时过长 | 首次 parse 延迟 | 低 | 低 | 构建期预编译为数据源码；基准脚本量化初始化耗时 |
| 大小写折叠语义差异（MoonBit 引擎仅 ASCII 折叠 vs uap-core Python full-Unicode 折叠） | 个别 Unicode 大小写用例差分失败 | 低 | 低 | flag-i 规则 65 条已实测双向折叠；W2 抽验非 ASCII 字母 |

---

## 十、附录

### 10.1 术语表

| 术语 | 定义 |
|------|------|
| UA | User-Agent，HTTP 请求头之一，标识客户端软件信息 |
| uap-core | ua-parser 项目的跨语言规则库（regexes.yaml），Apache-2.0 |
| uap-python | ua-parser 的 Python 实现，本项目差分对照的权威口径 |
| 快照 | 构建期从 uap-core 固定 commit 转换生成的规则数据，运行时不变 |
| 差分测试 | 同一 UA 输入下对比本项目输出与 uap-python 输出的回归测试 |
| mooncakes | MoonBit 官方包注册表 mooncakes.io |

### 10.2 参考文档

| 文档名称 | 链接 |
|----------|------|
| ua-parser/uap-core | https://github.com/ua-parser/uap-core |
| moonbitlang/regexp.mbt | https://mooncakes.io/docs/moonbitlang/regexp/ |
| moon 工具链文档 | https://docs.moonbitlang.com/en/latest/toolchain/moon/ |
| moonbit-vibe-coding 技能 | 本仓库 moonbit-vibe-coding 路由 |

### 10.3 数据字典

#### 实体 1: UaInfo（parse 返回结构）

| 字段名 | 类型 | 必填 | 校验规则 | 默认值 | 说明 |
|--------|------|------|----------|--------|------|
| browser | Browser | 是 | 三字段非 None | - | family/major/minor/patch |
| os | OS | 是 | 四字段非 None | - | family/major/minor/patch/patch_minor |
| device | Device | 是 | 三字段非 None | - | family/brand/model |

#### 实体 2: Browser

| 字段名 | 类型 | 必填 | 校验规则 | 默认值 | 说明 |
|--------|------|------|----------|--------|------|
| family | String | 是 | 未命中 = "Other" | "Other" | 浏览器族名 |
| major | String? | 否 | 命中组或替换模板 | None | 主版本 |
| minor | String? | 否 | 同上 | None | 次版本 |
| patch | String? | 否 | 同上 | None | 补丁版本 |

#### 实体 3: OS

| 字段名 | 类型 | 必填 | 校验规则 | 默认值 | 说明 |
|--------|------|------|----------|--------|------|
| family | String | 是 | 未命中 = "Other" | "Other" | 操作系统族名 |
| major/minor/patch/patch_minor | String? | 否 | 命中组或替换模板 | None | 版本四段 |

#### 实体 4: Device

| 字段名 | 类型 | 必填 | 校验规则 | 默认值 | 说明 |
|--------|------|------|----------|--------|------|
| family | String | 是 | 未命中 = "Other" | "Other" | 设备族名（Spider 表爬虫） |
| brand | String? | 否 | 命中组或 device_replacement | None | 品牌 |
| model | String? | 否 | 命中组 | None | 型号 |

### 10.4 需求质量评估

| 功能项 | 独立性 | 可协商性 | 价值 | 可估算 | 小巧 | 可测试 | 总分 |
|--------|--------|----------|------|--------|------|--------|------|
| FR-01 主 API | 高 | 中 | 高 | 高 | 中 | 高 | 5.5 |
| FR-02 匹配语义 | 高 | 低 | 高 | 高 | 中 | 高 | 5.2 |
| FR-03 替换模板 | 高 | 低 | 高 | 高 | 中 | 高 | 5.2 |
| FR-04 flag-i | 高 | 低 | 高 | 高 | 高 | 高 | 5.7 |
| FR-05 内置规则库 | 高 | 低 | 高 | 高 | 高 | 高 | 5.7 |
| FR-06 初始化 | 高 | 低 | 高 | 高 | 高 | 高 | 5.7 |
| FR-07 畸形输入 | 高 | 低 | 高 | 高 | 高 | 高 | 5.7 |
| FR-08 规则编号 | 高 | 中 | 中 | 高 | 高 | 高 | 5.3 |
| FR-09 单域函数 | 高 | 高 | 中 | 高 | 高 | 高 | 5.4 |
| FR-10 中间件示例 | 高 | 高 | 中 | 高 | 高 | 高 | 5.4 |
| FR-11 差分测试 | 高 | 低 | 高 | 中 | 低 | 高 | 4.9 |
| FR-12 mooncakes 发布 | 高 | 低 | 高 | 高 | 高 | 高 | 5.7 |

### 10.5 待确认事项

| 事项 | 类型 | 说明 |
|------|------|------|
| mooncakes 用户名最终确认 | 发布 | 申报书为 vicoproplus，需与账号实际一致 |
| 基准 UA 样本集选型 | 性能 | uap-python samples 9.8MB 全量 vs 抽样，W4 决定 |

### 10.6 PRD 拆分声明（必填，不写「无」）

> **为什么拆**：任务太大 AI 在一个上下文窗口里写不完，写到一半就崩。大需求在 `P5-PRD` 拆成**多份 PRD**（`PRD-<单元名>.md`，每份 = 一个可独立交付的小需求，任务小到「建个数据库表 / 写个注册接口 / 加个登录页面」级，一个一个来）；**每份 PRD 独立走 P6/P7，各自至多产出一份设计文档与一份 spec，spec 不再拆分**。
> **怎么记录**：单份 PRD → 写「单份 PRD，无需拆分」；拆分之一 → 写明归属（共 N 份、本 PRD 覆盖单元）+ 与兄弟 PRD 的共享接口/边界登记清单。

| 归属 | 覆盖单元 | 共享接口/边界（与兄弟 PRD 对齐） | spec 承接 |
|------|----------|----------------------------------|-----------|
| 单份 PRD，无需拆分 | 本 PRD 全部 | 无 | 单个 spec |

---

**文档结束**
