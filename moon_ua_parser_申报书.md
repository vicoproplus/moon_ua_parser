# moon_ua_parser 项目申报书

## 基本信息

- **项目名称**：moon_ua_parser —— User-Agent 解析库，ua-parser 的 MoonBit 移植
- **项目方向**：MoonBit Web 基础设施 / HTTP 请求分析库。通用性：Web 服务器、日志统计、安全审计等一切需要理解客户端身份的场景，不绑定具体框架
- **项目类型**：移植项目（uap-core 规则库快照移植 + 匹配引擎重写）
- **GitHub 仓库**：https://github.com/vicoproplus/moon_ua_parser

## 项目简介

mooncakes.io 上已有 Crescent、mars（Hono 风格）、pony（Chi 风格）、mbit（Gin 风格）、Halo（Koa 洋葱）、moonapi（FastAPI 风格）等 10 余个 Web 框架，它们的公共下游需求是 User-Agent 解析：访问统计按浏览器/设备聚合、响应按移动端/桌面端适配、安全审计识别爬虫。我对 mooncakes.io 全量 2363 个包与 GitHub 371 个 MoonBit 仓库做了关键词查重并经 web 搜索交叉验证：**UA 解析方向零命中**，开发者目前只能手写脆弱的字符串匹配或放弃设备维度分析。其他语言由 ua-parser 项目解决（uap-core 规则库为跨语言事实标准，Java/PHP/Python/Rust/Go 均有实现）。此前移植不可行的原因是缺正则引擎，如今官方 moonbitlang/regexp（VM 执行、复杂度可预期，抗 ReDoS）与 yj-qin/regexp 已可用——技术窗口已开，这是现在做的最佳时点。

## 预期使用场景

1. **Web 框架中间件**：Crescent/mars/pony 中间件层在请求入口解析 UA，将 browser/os/device 挂到请求上下文，供响应适配、内容协商与灰度分流。
2. **日志与访问统计**：离线管道按 UA 维度聚合成浏览器份额、操作系统分布、设备型号报表；纯函数 API 天然适配批处理与全量回归测试。
3. **爬虫识别辅助**：uap-core 规则内置 bot/crawler 设备分类，风控系统以其作辅助信号（非唯一判据）区分搜索引擎爬虫与伪装客户端。

## 核心功能与边界

- 主 API：`parse(ua) -> Result[UaInfo, Error]`，含 browser/os/device 三组 family/major/minor/patch 字段，结构对齐 uap-core 数据模型；
- 规则库：regexes.yaml 构建期转换为 MoonBit 数据结构源码，运行时零 YAML 依赖，注明规则快照版本；
- 引擎语义对齐 uap-core：三组规则按序尝试、首条命中生效、命名捕获组替换模板输出；
- 可选返回命中规则编号供审计；
- **明确不做**：UA 伪造检测/指纹（依赖行为信号）、设备能力库、规则实时同步（快照式发版更新）、其余 HTTP 头解析、运行时 YAML 依赖。

## 实现路径

核心风险是 uap-core 的 PCRE 风格正则与 MoonBit 正则引擎的兼容性——第一周先做兼容性 spike：规则集抽样跑 moonbitlang/regexp 与 yj-qin/regexp，统计不可编译比例，决定引擎选型，不兼容模式人工改写为语义等价形式并记录成文档。这是工作量主要不确定源，故放在最前面而非留到最后。规则采用构建期转换（一次性脚本生成源码数据），运行时零依赖。测试直接把 uap-core 自带 test_resources 转为 moon test 用例，形成与上游的差分测试，通过率写入 README。四周排期：W1 兼容性验证与转换脚本；W2 匹配引擎与主 API；W3 测试转换与差分修复；W4 文档、CI、mooncakes 发布与框架中间件示例。

## 移植与参考说明

- 规则来源：ua-parser/uap-core（./uap-core），Apache-2.0
- 接口参考：ua-parser/uap-python（./uap-python），Apache-2.0
