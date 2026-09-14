# moon_ua_parser 目标环境陷阱清单（v0.2 审查轮初始化）

> 由 v0.2 四单元会话中已确认的环境事实按 `pitfall-list-template.md` 格式固化。
> 维护流程：审查轮逐条判定与本 diff 的相关性（已对照 / 不相关+理由 / 命中+Issue）；
> 新确认陷阱按 PF-NN 递增追加；resolved 条目保留防回归。

### PF-01: tests/differential 的 wasm debug codegen 超出 V8 locals 硬上限
- **触发条件**: 对 `tests/differential` 以 debug/test 模式做 wasm codegen（`moon test --target wasm` 包含差分包时）
- **失效模式**: 生成模块包初始化函数声明 125,840 个 locals，超 V8 50,000 硬上限，moonrun 静态拒绝：`CompileError: local count too large`；release codegen 折叠为 26,857 locals 不触发。任何平台本地跑裸 `moon test`（默认 wasm）必炸
- **检测方法**: `cd moon_ua_parser_lib && moon test -p tests/differential --target wasm` 观察失败签名；合规门禁 = CI 的显式 7 包测试列表（不含 differential）
- **规避方案**: wasm 差分验证只走 `moon run --target wasm --release tests/diffstats`；测试门用显式包列表；根治 = Followup-1（gen_tests.py 拆分差分包后再生）
- **状态**: **resolved**（2026-09-14，Followup-1 落地：`scripts/gen_tests.py` 改为分块函数（每块 ≤3000 例）+ 顺序连接，任意单函数 debug wasm locals < 50,000；裸 `moon test`（默认 wasm）跑差分 3/3 绿，native 55/55、js 41/41、三后端 diffstats 报告不变，再生幂等；证据 `docs/evidence/wasm-differential-blocker-2026-09-13.md` §5。保留防回归——检测方法行仍可用于回归核对）

### PF-02: Windows 10 上 moonrun.exe 静态导入 GetTempPath2W 无法加载
- **触发条件**: 在 Win10 / Server 2022 以下版本启动官方 moonrun（0xc0000139 ENTRYPOINT NOT FOUND）
- **失效模式**: wasm 测试/运行全部不可用；开发机（Win10）无法复现 CI（Linux）行为
- **检测方法**: `moonrun --help` 退出码 0 即已补丁；补丁 = 本地导入表 2 字节改写 GetTempPath2W→GetTempPathW（登记于 `.probe-wasm` 与平台完备 T-01 证据）
- **规避方案**: 使用已补丁的本地 moonrun；上游修复后回退
- **状态**: resolved（本地工具链补丁，可回退）

### PF-03: bobzhang/crescent@0.11.1 与 moonbitlang/async@0.21.3 不兼容
- **触发条件**: workspace 依赖图 MVS 统一把 async 抬到 0.21.3（mizchi/mars@0.3.12 的 pin）后编译 crescent
- **失效模式**: crescent 的 `Map[String, String]` request-header 代码编译失败；无任何已发布版本对可共存（T-02/T-05 registry 矩阵）
- **检测方法**: `git -c core.autocrlf=false apply --check scripts/framework-cache-patches/*.patch`（CI 在 fetch 后、编译前断言，apply 失败即 CI 红）
- **规避方案**: 缓存补丁 `scripts/framework-cache-patches/crescent-async-compat.patch`；crescent 上游发版后移除
- **状态**: confirmed（上游未修复；CI patch 步骤即门禁）

### PF-04: mizchi/x（mars 依赖链）Windows fd 缺陷
- **触发条件**: Windows 上运行经 mizchi/x 的文件描述符路径（mars 运行时 / moon publish 沙箱）
- **失效模式**: fd 泄漏/耗尽导致运行期失败；Linux 不触发
- **检测方法**: `git -c core.autocrlf=false apply --check scripts/framework-cache-patches/mizchi-x-windows-fd.patch`；本地 `moon test --target native -p moon_ua_parser_mars` 绿即缓存已补丁
- **规避方案**: 缓存补丁 `scripts/framework-cache-patches/mizchi-x-windows-fd.patch`；上游发版后移除
- **状态**: confirmed（上游未修复；CI patch 步骤即门禁）

### PF-05: Windows 沙箱上 `moon publish` 上游 mizchi/x fd 缺陷致命
- **触发条件**: 在 Windows 本机执行 `moon publish`
- **失效模式**: 沙箱新进程即触发 PF-04，发布流程致命失败，无本地补救
- **检测方法**: `.github/workflows/publish-manual.yml` 存在且 runs-on 为 Linux；发布记录须来自 GH Actions Linux
- **规避方案**: 发布一律走 GH Actions Linux（publish-manual.yml）
- **状态**: confirmed（CI 工作流即门禁）

### PF-06: Windows core.autocrlf 使字节级 git diff / apply 失真
- **触发条件**: 在 core.autocrlf 开启的 Windows 上做补丁 apply 或幂等性字节比较
- **失效模式**: patch apply 因行尾被改写而失败/污染；`git diff --exit-code` 幂等判断被 CRLF 归一化掩盖
- **检测方法**: 补丁 apply 一律 `git -c core.autocrlf=false apply`；幂等判断用内容级比较（重生成后 `git diff --exit-code` 在关 autocrlf 下进行）
- **规避方案**: 全部生成物一致性门禁统一加 `-c core.autocrlf=false` 或内容级比较
- **状态**: confirmed（CI/命令级规避；规则性陷阱）

### PF-07: 新 runner 缺 mooncakes registry 索引导致解析失败
- **触发条件**: 全新 CI runner 首次执行 `moon check` 前未刷新 registry 索引
- **失效模式**: `Failed to resolve registry dependency moonbitlang/regexp`，exit 255
- **检测方法**: CI 第一个 moon 命令前必须有 `moon update` 步（ci.yml 已有）
- **规避方案**: `moon update` 前置步骤
- **状态**: resolved（CI 步骤）

### PF-08: 上游移除 per-version toolchain 下载路径（403）
- **触发条件**: 安装脚本按精确版本号拉取 binaries/cores 路径
- **失效模式**: S3 403 AccessDenied；仅 `latest` 别名仍可用
- **检测方法**: CI "Verify toolchain" 步骤：latest 传输 + `moon version | grep -F "0.1.20260904"` 硬断言
- **规避方案**: latest 传输 + 精确版本硬断言（防静默漂移）
- **状态**: resolved（CI 断言即门禁）

### PF-09: moonc 链接 wasm 测试驱动在 Linux 默认 8MiB 栈上栈溢出
- **触发条件**: `moon test --target wasm` 触发 moonc link-core 递归过深
- **失效模式**: moonc ICE "Stack overflow"（RUST_MIN_STACK 无效）
- **检测方法**: wasm 测试步骤前 `ulimit -s unlimited`（ci.yml 已有）
- **规避方案**: CI 步骤内置 ulimit
- **状态**: resolved（CI 步骤）

### PF-10: diffstats 报告输出在 stderr
- **触发条件**: 捕获 `moon run ... tests/diffstats` 的报告输出时只收 stdout
- **失效模式**: 报告为空，误判门禁失败/无输出
- **检测方法**: 捕获命令一律 `2>&1`
- **规避方案**: SOP 已登记（docs/rules-update-sop.md）
- **状态**: confirmed（SOP 规则）

### PF-11: git 类门禁必须在 moon_ua_parser_lib/ 子目录执行
- **触发条件**: 在仓库根执行 gen 一致性 / mbti 漂移的 git diff
- **失效模式**: 路径过滤（src/ua_parser/rules 等）不匹配，门禁空转假绿
- **检测方法**: CI 各步 working-directory: moon_ua_parser_lib
- **规避方案**: SOP 已登记
- **状态**: confirmed（SOP 规则）

### PF-12: vendored uap-core 快照内嵌 .git（双态）
- **触发条件**: 对 vendored 快照做上游对账/再生成
- **失效模式**: 快照既像普通目录又像 git 仓库，状态判断歧义
- **检测方法**: 对账一律内容级 diff，不依赖其 git 状态
- **规避方案**: SOP 已登记（docs/rules-update-sop.md）
- **状态**: confirmed（SOP 规则）
