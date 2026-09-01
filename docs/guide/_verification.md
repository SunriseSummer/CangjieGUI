<!-- kind: reference; audience: contributor -->

# 文档与框架验证报告

本页记录文档中“已验证”的含义和贡献者应执行的门禁，避免把能编译、能截图和交互正确混为一谈。

## 自动门禁

在仓库根目录执行：

```text
cjpm build
node .agents/skills/cangjie-rules/tools/cjcheck/src/main.js . --tier 2 --no-tools --strict --baseline .cjcheck-baseline.json --summary
node .agents/skills/cangjie-rules/tools/cjcheck/src/main.js . --tier 1 --checks cjlint,cjfmt --json
python .devtools/test_packages.py
python .devtools/test_packages.py --coverage --min-line-coverage 45
python .devtools/test_desktop_lifecycle.py
python .devtools/check_docs.py
python .devtools/test_packages_test.py
python .devtools/test_examples_test.py
python .devtools/snapshot_tool_test.py
python .devtools/process_runner_test.py
python .devtools/stage_sdl_runtime_test.py
python .devtools/verify_release_bundle_test.py
python .devtools/cross_platform_workflow_test.py
python .devtools/verify_release_bundle.py
python bench/run_test.py
python bench/run.py
python bench/run_all.py --display --samples 5 --check --timeout 240
python bench/phase3_probe_test.py
python bench/phase3_probe.py
python .devtools/test_examples.py --jobs 4 --timeout 300
python .devtools/test_examples.py --smoke-snapshots --timeout 300
python .devtools/test_examples.py --smoke-snapshots --retained-diff --timeout 300
```

- `cjpm test` 覆盖状态、布局、事件、保留子树、Renderer 值命令缓冲和无窗口帧宿主；真实 GPU/damage 由桌面 fixture 验证。
- 严格 L2 以审阅过的增量 baseline 拦截新增问题；外部 cjlint/cjfmt 是独立的存量治理视图。项目规则差异必须在
  `.devtools/README.md` 给出失配证据和更精确的替代门禁，不允许仅为减少数量关闭规则。
- CangjieGUI 与 CangjieSDL 的完整 `cjpm test` 都包含原生窗口/事件等待用例，必须串行执行；两个仓库并行测试会
  争用进程级 SDL/窗口系统资源，使唤醒测试失去有效时限。无窗口的 Python 工具自测可以并行。
- 包隔离工具给每个测试进程设置硬超时；覆盖率模式还隔离各包 `.gcda`，避免不同测试二进制把同名 SDL
  计数文件损坏合并，再以匹配 `.gcno` staging 生成逐包报告并合并生产源码命中行。原始计数、HTML 和 JSON
  汇总位于 `target/test-package-results/`。仓颉 1.0.5 可能把内联生产代码归因到 `$test` 图，因此可观测行
  覆盖率门禁用于防回退，不替代下面的功能、真实窗口与 examples E2E 门禁。新 coverage generation 会精确清理
  `target/release` 与根 `cov_output`，不调用会遍历并删除其它 `target` 证据的 `cjpm clean`；非同代图仍失败闭合。
- examples 门禁把每个案例作为独立公开 API/E2E 消费者；烟测会短暂打开代表性真实窗口；retained 差分
  还会比较默认增量执行与强制全量执行的最终像素，防止缓存命中掩盖依赖遗漏。
- benchmark 报告是同机 A/B 和回归线索；跨机器原始耗时不能直接判定代码回归。
- 活动性能基线只能经 `--capture-baseline-candidate` 采集、人工/机器审阅后再由独立
  `--promote-baseline-candidate` 晋升；候选摘要绑定数值与来源，旧 `--save-baseline` 仅是不会覆盖活动门禁的
  兼容采集别名。晋升后必须用另一批样本执行 `--check`。
- 跨平台验证分成两层。GitHub 托管 Ubuntu x64/macOS arm64 runner 从固定 URL、大小和 SHA-256 的官方仓颉/SDL
  发布物开始，安全解包并源码构建 SDL 后执行无头包测试、文档和示例编译，用来证明新环境可重复；它不能证明
  真实窗口或稳定性能。三平台 qualification 仍必须在带真实交互式图形会话的 runner 上执行；
  `stage_sdl_runtime.py` 要求外置、明确的目标平台 SDL runtime，`verify_release_bundle.py` 再从临时干净目录直接
  运行 executable。平台标签、能编译或 `cjpm run` 成功都不能替代动态库/窗口/截图证据。Windows x64 沿用
  历史 baseline 路径，Linux/macOS 使用独立 `bench/baselines/<profile>`，禁止跨平台原始耗时比较。
- phase3 probe 与普通性能基线隔离，用阶段访问数、同进程 A/B 和规模曲线判断更新粒度是否构成架构瓶颈，并
  看护已实现的层次化状态所有权是否维持近似常数命中成本。
- Markdown 门禁验证本地链接目标存在；外部 URL 的可达性仍由发布流程或人工检查。

## 人工边界

原生文件对话框、输入法候选窗位置、窗口管理器行为、不同 GPU 后端和不同平台字体仍需目标系统人工确认。
像素基线只应在确认视觉变化符合预期后更新，不能用批量更新掩盖未知差异。

## 最近一次加固基线

阶段一、二加固验收要求 GUI、SDL、examples、工具自测、严格增量 `cjcheck` 和文档链接检查全部通过；
实际数量和性能数据以当前命令输出及忽略目录中的机器报告为准，不在文档中固化易过期数字。
跨平台完成状态、最近一次完整要求—证据矩阵与未完成项见[下一代 GUI 框架完成度审计](../next-generation-completion-audit.md)。
