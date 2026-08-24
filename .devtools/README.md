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
快照、BMP 像素基线，以及 `examples/.e2e-results/report.json` 机器报告：

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
互相污染；`--repeat N` 可压力复跑而不重复编译，`--timeout` 对构建和每个子场景分别设硬上限。阶段协议、每轮
及每个子场景结果都写入 `target/test-package-results/desktop-lifecycle.json`。

```text
python .devtools/test_desktop_lifecycle.py
python .devtools/test_desktop_lifecycle.py --repeat 20 --timeout 30
```

## check_docs.py（文档链接门禁）

检查 README、API、指南、bench 与 examples 中全部本地 Markdown 链接；缺失目标以退出码 1 报出文件、
行号与解析后的路径。外部 URL 不在本地门禁范围内。

```
python .devtools/check_docs.py
```

## 约定

- `.devtools/` 负责正确性、E2E、快照、文档与进程生命周期诊断；耗时字段只用于超时归因和测试报告，
  不作为性能结论或回归阈值。所有可重复性能测量、A/B、基线和架构压力实验统一放在 `bench/`。
- `.devtools/process_runner.py` 是两类入口共用的跨平台子进程/进程树基础设施，不定义测试场景或性能语义。
- 子进程以字节捕获并按“严格 UTF-8，失败后平台代码页”解码；这兼容 Windows 仓颉/`cjpm` 的 cp936 输出，
  同时保证落盘 JSON 和报告统一为 UTF-8。编码路径由 `process_runner_test.py` 看护。
- 脚本只读仓库与指定输入，除明示的输出文件外不落盘、不改动源码。
- Python 自身输出使用 UTF-8（脚本内部已 `reconfigure`）；不支持 UTF-8 的外部终端仍可设
  `PYTHONIOENCODING=utf-8` 或查看 UTF-8 JSON 报告。
- 一次性代码改写（codemod）不放这里，用完即弃；这里只放可重复使用的工具。
