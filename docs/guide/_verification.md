<!-- kind: reference; audience: contributor -->

# 文档与框架验证报告

本页记录文档中“已验证”的含义和贡献者应执行的门禁，避免把能编译、能截图和交互正确混为一谈。

## 自动门禁

在仓库根目录执行：

```text
cjpm build
python .devtools/test_packages.py
python .devtools/test_packages.py --coverage --min-line-coverage 45
python .devtools/test_desktop_lifecycle.py
python .devtools/check_docs.py
python .devtools/test_packages_test.py
python .devtools/test_examples_test.py
python .devtools/snapshot_tool_test.py
python .devtools/process_runner_test.py
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
- CangjieGUI 与 CangjieSDL 的完整 `cjpm test` 都包含原生窗口/事件等待用例，必须串行执行；两个仓库并行测试会
  争用进程级 SDL/窗口系统资源，使唤醒测试失去有效时限。无窗口的 Python 工具自测可以并行。
- 包隔离工具给每个测试进程设置硬超时；覆盖率模式还隔离各包 `.gcda`，避免不同测试二进制把同名 SDL
  计数文件损坏合并，再以匹配 `.gcno` staging 生成逐包报告并合并生产源码命中行。原始计数、HTML 和 JSON
  汇总位于 `target/test-package-results/`。仓颉 1.0.5 可能把内联生产代码归因到 `$test` 图，因此可观测行
  覆盖率门禁用于防回退，不替代下面的功能、真实窗口与 examples E2E 门禁。
- examples 门禁把每个案例作为独立公开 API/E2E 消费者；烟测会短暂打开代表性真实窗口；retained 差分
  还会比较默认增量执行与强制全量执行的最终像素，防止缓存命中掩盖依赖遗漏。
- benchmark 报告是同机 A/B 和回归线索；跨机器原始耗时不能直接判定代码回归。
- phase3 probe 与普通性能基线隔离，用阶段访问数、同进程 A/B 和规模曲线判断更新粒度是否构成架构瓶颈，并
  看护已实现的层次化状态所有权是否维持近似常数命中成本。
- Markdown 门禁验证本地链接目标存在；外部 URL 的可达性仍由发布流程或人工检查。

## 人工边界

原生文件对话框、输入法候选窗位置、窗口管理器行为、不同 GPU 后端和不同平台字体仍需目标系统人工确认。
像素基线只应在确认视觉变化符合预期后更新，不能用批量更新掩盖未知差异。

## 最近一次加固基线

阶段一、二加固验收要求 GUI、SDL、examples、工具自测、严格增量 `cjcheck` 和文档链接检查全部通过；
实际数量和性能数据以当前命令输出及忽略目录中的机器报告为准，不在文档中固化易过期数字。
