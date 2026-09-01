# .devtools 开发辅助脚本

服务本仓库日常开发的跨平台 Python 脚本（Windows/macOS/Linux，仅依赖标准库，Python 3.8+）。
这些工具不参与构建与发布，只辅助验证与排查。

## snapshot_tool.py（快照像素工具）

示例应用经 `cjpm run --run-args "--snapshot x.bmp"` 输出渲染快照；本工具对快照做像素级处理。

```
python .devtools/snapshot_tool.py convert a.bmp a.png             # BMP 转 PNG 便于查看
python .devtools/snapshot_tool.py diff a.bmp b.bmp                # 逐像素对比；退出码 1 表示有差异
python .devtools/snapshot_tool.py diff a.bmp b.bmp --out d.png --tolerance 2
python .devtools/snapshot_tool.py check --baseline .snapbase x.bmp y.bmp   # 基线看护
python .devtools/snapshot_tool.py update --baseline .snapbase x.bmp        # 更新基线
```

diff 输出差异像素数、最大通道差与差异包围盒；`--out` 生成热图（相同处压暗、差异处标红），
定位视觉回归一目了然。`check`/`update` 以文件名为键在基线目录中留存参考图，改动渲染层或
共享组件后重跑快照即可发现视觉漂移。

## shoot_examples.py（示例画廊截图）

为 `examples/` 全部示例生成画廊截图并写入 `examples/.images/<名字>.png`，供
`examples/README.md` 的画廊表格引用。逐示例走真实渲染快照（`--snapshot`），再按整数因子
做面积平均降采样（默认压到 560px 宽以内），缩略清晰且字节量小（47 张约 1.3 MB）。

```
python .devtools/shoot_examples.py                 # 全部示例
python .devtools/shoot_examples.py mail richtext   # 只重拍指定示例
python .devtools/shoot_examples.py --max-width 560
```

改动示例外观后重拍对应几张即可；退出码非零表示有示例拍摄失败（清单在输出末尾）。

## test_examples.py（示例端到端门禁）

把每个示例当成独立的公开 API/端到端用例执行，支持并行 build/test、按 Git 变更筛选、真实窗口
快照、BMP 像素基线，以及机器报告：完整消费者矩阵写入 `examples/.e2e-results/report.json`，普通全量快照写入
`snapshot-report.json`，跨特性 smoke/retained 差分写入 `smoke-report.json`，三类证据不会互相覆盖。

```
python .devtools/test_examples.py                         # 全部示例测试
python .devtools/test_examples.py --action build --jobs 4
python .devtools/test_examples.py contacts planner --snapshot
python .devtools/test_examples.py --smoke-snapshots
python .devtools/test_examples.py --smoke-snapshots --retained-diff
python .devtools/test_examples.py --changed origin/main
python .devtools/test_examples_test.py                  # E2E runner 自测（含进程树超时）
python .devtools/snapshot_tool_test.py                  # BMP 边界/损坏输入自测
```

`--smoke-snapshots` 覆盖自定义绘制、嵌套浮层、虚拟表格、字体度量/分段控件溢出、文本编辑、密集表单、
后台任务和 retained 命令缓冲八条跨特性链路；完整的编译/测试门禁仍覆盖全部示例。每个外部进程都有超时，超时会终止整个编译/窗口进程树；
`--changed` 在无相关变更时生成 0 项成功报告，共享框架变更才展开为全量。`--retained-diff` 会对每个
成功快照再以强制关闭 retained 命中的诊断模式运行一次，比较两张图是否在容差内一致；它用于发现增量
执行遗漏依赖，不用于衡量正常模式性能。普通快照会先构建当前应用，紧随其后的全量模式复用同一二进制，
避免 `cjpm test` 没有刷新应用可执行文件而误用旧产物。

## test_packages.py（包隔离测试门禁）

每个 `src/` 包各用一个 `cjpm test` 进程执行，设置硬超时并汇总到
`target/test-package-results/report.json`。这隔离了 SDL/运行时全局资源的退出状态：一个包若挂起会被明确归因和
终止，不会让整模块聚合运行无期限滞留。覆盖率模式还为每次运行、每个包设置独立 `GCOV_PREFIX`；不同测试
二进制不会再向根目录同名 `.gcda` 合并不兼容计数器，原始计数保存在报告目录下的独立子目录。随后按仓颉
1.0.5 在 Windows 上的约束，把当前包匹配的 `.gcno` 和隔离 `.gcda`（排除 `$test` 图）平铺到短 staging
目录，再生成逐包 HTML/JSON，并对生产源码命中行取并集。`--min-line-coverage` 可把当前可观测基线变成 CI
下限，例如 `45`；它不是质量目标。1.0.5 可能把内联生产代码的命中归入 `$test` 图，因此报告中的零命中或
总百分比是保守的工具观测，必须与功能、真实窗口和 examples E2E 结果一同判断。
coverage 会话开始前只删除 `target/release` 和根 `cov_output` 两个可再生生成目录，并拒绝符号链接或错误目录名；
`target/cross-platform`、性能/测试报告与 toolchain 缓存不在清理范围。这样既强制 coverage binary/graph 同代，
也避免 `cjpm clean` 遍历整个 `target` 时误删供应链证据，或被异平台归档链接阻断。跨包候选仍要求逐字节相同，
不会因主动清理而放宽非同代图拒绝规则。
每包又分成 `--no-run` 构建和 `--skip-build` 执行两个进程，使编译失败与运行超时分别归因，并保证执行的就是
刚完成构建的测试二进制。真实窗口不放进单测 runner 工作线程，而由下面的主线程 E2E fixture 负责。

```text
python .devtools/test_packages.py
python .devtools/test_packages.py --coverage
python .devtools/test_packages.py --coverage --min-line-coverage 45
python .devtools/test_packages.py core testing
python .devtools/test_packages_test.py
python .devtools/test_desktop_lifecycle_test.py
```

真实窗口生命周期另由 `python .devtools/test_desktop_lifecycle.py` 执行。它把窗口创建、跨线程 API 拒绝、
Frame 关闭、异常资源清理与实例复用拒绝放在独立可执行程序的主线程，而不是交给单测运行器工作线程；还用
真实 Renderer 证明显式 retained 的局部/全帧 BMP 零像素差、相交外 draw 被裁掉；另以不含
`RetainedSubtree` 的复杂普通 builder 验证框架自动晋升边界，并覆盖持久目标接受与后端拒绝回退两种
DesktopApp 自动 damage 分支。四种契约各自在独立子进程运行、共享一次构建，避免 SDL/并发运行时的全局状态
互相污染；`--repeat N` 可压力复跑而不重复编译，`--timeout` 限制每个已构建场景，独立的
`--build-timeout` 防止收紧场景上限时误杀冷构建。阶段协议、每轮及每个子场景结果都写入
`target/test-package-results/desktop-lifecycle.json`。

```text
python .devtools/test_desktop_lifecycle.py
python .devtools/test_desktop_lifecycle.py --repeat 20 --timeout 30
```

## cjcheck / cjfmt（质量门禁）

仓库根的 `cangjie-format.toml` 是唯一格式策略；`cjfmt` 不会自动发现它，修改生产 `.cj` 后必须显式传入：

```text
cjfmt -f src/core/example.cj -c ./cangjie-format.toml
node .agents/skills/cangjie-rules/tools/cjcheck/src/main.js . --tier 2 --no-tools --strict --baseline .cjcheck-baseline.json --summary
node .agents/skills/cangjie-rules/tools/cjcheck/src/main.js . --tier 1 --checks cjlint,cjfmt --json
```

严格 L2 基线负责“新增 0”的合并门禁；外部 cjlint/cjfmt 报告仍单独保留为存量治理视图，不能用重写基线冒充修复。
`.cjcheck.json` 只移除了两个由更精确项目检查替代的 cjlint 规则：`G.VAR.03` 会把顶层不可变 `let` 常量也当成
全局可变状态，实际禁令由 L2 `global-var` 只拦截顶层 `var`；`G.FUN.01` 的实现只是固定“参数不超过 5 个”，与
本项目经评审设为 7 的 `param-count` 重复且冲突。测试文件只额外豁免 `G.ERR.01`，因为故障注入桩中的预期
`throw` 不是公共 API 异常契约；未使用参数等编译器可确定问题仍照常报告。

## check_docs.py（文档链接门禁）

检查 README、API、指南、bench 与 examples 中全部本地 Markdown 链接；缺失目标以退出码 1 报出文件、
行号与解析后的路径。外部 URL 不在本地门禁范围内。

```
python .devtools/check_docs.py
```

## 跨平台 runtime staging 与干净交付 smoke

`cross_platform_artifacts.json` 固定仓颉 1.0.5 四种官方 SDK，以及与 `CangjieSDL` 配套的 SDL 3.4.12、
SDL_ttf 3.2.2 源码归档 URL、字节数和 SHA-256。`bootstrap_cross_platform.py` 对缓存也重新计算大小与摘要，下载
使用同目录临时文件并在验证后原子提升；解包拒绝路径穿越、越界链接和设备节点，并给提取目录写来源标记。
合法的相对 Framework 链接只在解析后仍位于解包根内时允许。下列命令会生成
`target/cross-platform/bootstrap-<profile>.json`，并在 GitHub Actions 中输出唯一 SDK/源码根：

```text
python .devtools/bootstrap_cross_platform.py --profile linux-x86_64
python .devtools/bootstrap_cross_platform_test.py
```

SDK 定位不以第一个 `envsetup` 为准：根目录必须同时拥有 `bin/cjc[.exe]`、`tools/bin/cjpm[.exe]` 与
`runtime/lib`，并按 profile 输出唯一
`windows_x86_64_cjnative`、`linux_x86_64_cjnative`、`linux_aarch64_cjnative` 或 `darwin_aarch64_cjnative` 目录；
工作流只注入这一目标 runtime 与 `tools/lib`，不会把归档中附带的其它平台目录混入 loader path。

Linux/macOS 的全新托管 runner 从固定源码构建 shared-only SDL runtime；SDL_ttf 强制找到 FreeType/HarfBuzz，
关闭样例、vendored 在线取依赖和 portability lane 不需要的 PlutoSVG，任一步失败即停止。该 lane 的目标是证明
干净环境下载、链接、编译和无头测试可重复，不把共享虚拟机耗时当性能证据：

```text
python .devtools/build_sdl_runtime.py --profile linux-x86_64 \
  --sdl-source target/toolchains/linux-x86_64/sdl/SDL3-3.4.12 \
  --sdl-ttf-source target/toolchains/linux-x86_64/sdl_ttf/SDL3_ttf-3.2.2
python .devtools/build_sdl_runtime_test.py
```

新 checkout 不允许依赖某个开发目录里碰巧残留的 SDL 动态库。三平台 runner 必须把与目标系统/架构匹配的
SDL3、SDL3_ttf 放在工作区外的受管目录，并设置 `CUI_SDL_RUNTIME_DIR`；staging 工具只复制当前平台准确命名的
两个库家族到兄弟 `CangjieSDL/.sdl3`，缺失、错平台别名或 SDL/TTF 家族混淆都会失败：

```text
python .devtools/stage_sdl_runtime.py
python .devtools/stage_sdl_runtime_test.py
```

`verify_release_bundle.py` 随后重建真实 `desktop_lifecycle` fixture，在临时干净目录只部署 executable、仓颉 runtime、
SDL3/SDL3_ttf；Windows 还强制重建并部署 `cui_uia.dll`。四个场景均直接执行 `target/release/bin/main[.exe]`，
不通过 `cjpm run`，从而验证动态库搜索、真实窗口、文本光栅、后台唤醒、异常清理、关闭，以及 retained
增量/全量截图零像素差。报告和两张证据图按平台写到 `target/cross-platform/`：

```text
python .devtools/verify_release_bundle.py --expected-profile windows-x86_64
python .devtools/verify_release_bundle_test.py
```

仓颉 1.0.5 官方提供 Windows x64、Linux x64/aarch64 和 macOS arm64 SDK；runtime 必须按官方部署说明来自同版
`CANGJIE_HOME/runtime/lib`，不能从另一平台复制：[1.0.5 下载中心](https://cangjie-lang.cn/download/1.0.5)、
[runtime 部署](https://docs.cangjie-lang.cn/en/docs/1.0.0/user_manual/source_en/deploy_and_run/runtime_deploy_cjnative.html)。

`.github/workflows/cross-platform-qualification.yml` 有两类互不替代的 job。`portable` 在 GitHub 托管的 Ubuntu x64
与 macOS arm64 新虚拟机上执行固定源 bootstrap、SDL 源码构建、SDL/GUI 包测试、文档和 48 个示例构建；
`qualify` 使用 Windows x64、Linux x64、macOS arm64 三项 self-hosted 矩阵，负责真实桌面和稳定性能。
每台 self-hosted runner 必须同时拥有默认 OS/arch 标签以及 `cangjie-1.0.5`、`cui-gui`；后者表示交互式图形
会话、Python 3、同版仓颉 SDK、clang（Windows UIA）和外置 `CUI_SDL_RUNTIME_DIR` 都已配置。标签只负责调度，
脚本仍会用实际 host profile、`cjc -v`、直接开窗和 runtime 装载复核，标签写错不能伪通过。qualification
执行 SDL/GUI 测试、48 示例构建、8 场景 retained 像素差分、干净交付、性能环境与 phase3，并上传平台报告。
普通 PR/主分支采 `report`；手工运行可选 `candidate` 或在相应平台 baseline 已评审入库后选 `check`。

## Windows UI Automation provider

`build_windows_uia.ps1` 用严格 C++20、警告即错误和栈保护，从
`platform/windows/accessibility/uia/cui_uia.cpp` 重建 `target/native/windows/<arch>/cui_uia.dll`。桌面后端通过
SDL 从可执行文件目录动态加载并解析 C ABI，因此该依赖不会污染其它目标平台。`check_windows_uia.ps1` 构建一个真实 `DesktopApp` fixture，再从独立 .NET
UIAutomation 客户端按 AutomationId 查找按钮、读取属性、取得 InvokePattern 并验证动作后的 Name 事件结果；
同时对属性查询 P50 和 UI 线程往返设置宽松的回归上限。

加载器在解析业务入口后、调用 `create` 前验证 ABI version 以及 `CuiUiaNode`/`CuiUiaChange` 的 `sizeof` 和
`alignof` 指纹；旧 DLL 或结构布局不匹配时卸载并安全保留无原生 provider 的应用，而不会跨错误布局写内存。
仓颉侧先完成 UTF-8 arena、节点偏移和变更缓冲的全部组装，再固定 arena，并在固定窗口内只调用一次
`cui_uia_update`；native 对偏移和 NUL 边界逐项验证并在返回前深拷贝，避免把托管数组裸指针暴露在对象分配、
哈希更新或异常传播窗口中。

```text
powershell -ExecutionPolicy Bypass -File .devtools/build_windows_uia.ps1
powershell -ExecutionPolicy Bypass -File .devtools/check_windows_uia.ps1
```

provider 不把 COM 回调直接带入仓颉运行时：原生线程只读取不可变快照并写入有界动作队列，SDL 用户事件唤醒
UI 线程后才执行最新 `AccessibilityUpdate` 动作。脚本仅适用于 Windows；其它平台继续使用平台无关语义内核和
公开 adapter 边界。

## 约定

- `.devtools/` 负责正确性、E2E、快照、文档与进程生命周期诊断；耗时字段只用于超时归因和测试报告，
  不作为性能结论或回归阈值。所有可重复性能测量、A/B、基线和架构压力实验统一放在 `bench/`。
- 性能硬裁决会在 `bench/run.py` 中清理旧 profile、固定 Windows 混合核心执行域、预热真实显示、轮转场景并
  对消 A/B 顺序；这些属于测量协议，不能用 `.devtools` 的构建或截图耗时替代。反过来，性能 PASS 也不能替代
  `.devtools` 的像素、生命周期、干净交付和异常归因门禁。
- `.devtools/process_runner.py` 是两类入口共用的跨平台子进程/进程树基础设施，不定义测试场景或性能语义。
- 子进程以字节捕获并按“严格 UTF-8，失败后平台代码页”解码；这兼容 Windows 仓颉/`cjpm` 的 cp936 输出，
  同时保证落盘 JSON 和报告统一为 UTF-8。编码路径由 `process_runner_test.py` 看护。
- 脚本只读仓库与指定输入，除明示的输出文件外不落盘、不改动源码。
- Python 自身输出使用 UTF-8（脚本内部已 `reconfigure`）；不支持 UTF-8 的外部终端仍可设
  `PYTHONIOENCODING=utf-8` 或查看 UTF-8 JSON 报告。
- 一次性代码改写（codemod）不放这里，用完即弃；这里只放可重复使用的工具。
