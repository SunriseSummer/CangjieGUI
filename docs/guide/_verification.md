<!-- kind: reference; audience: contributor -->

# 文档与框架验证规则

本页说明各种“已验证”分别代表什么。构建、无窗口测试、真实窗口和性能测试回答的问题不同，不能互相替代。

## 证据层级

| 证据 | 能证明 | 不能证明 |
|---|---|---|
| 构建通过 | 语法、类型、依赖和公开签名可用 | 交互和视觉结果正确 |
| 无窗口测试通过 | 状态、布局、事件和帧事务符合断言 | GPU、窗口系统和平台行为正确 |
| 真实窗口测试通过 | 动态库、窗口、输入和截图链路可用 | 所有目标平台都可用 |
| 性能测试通过 | 同机、同条件下没有超过基线阈值 | 跨机器绝对耗时可直接比较 |

## 基础门禁

在仓库根目录执行：

```text
cjpm build
cjpm test
node .agents/skills/cangjie-rules/tools/cjcheck/src/main.js . --tier 2 --no-tools --strict --baseline .cjcheck-baseline.json --summary
node .agents/skills/cangjie-rules/tools/cjcheck/src/main.js . --tier 1 --checks cjlint,cjfmt --json
python .dev/cli.py test tools
python .dev/cli.py check docs
python .dev/cli.py check snippets --timeout 600
python .dev/cli.py test examples --action build --jobs 4 --timeout 300
```

- `check docs` 验证本地链接，并将公开类型、成员、函数、重载、包索引和 `cui` 统一导出与源码对照。
- `check snippets` 编译 API 与指南中所有带 `verify` 的完整程序；指南不接受无法独立编译的仓颉片段。
- `test examples` 把每个示例当作独立的公开 API 使用者，避免统一构建掩盖包配置或依赖问题。
- 严格 L2 只允许审阅过的存量基线，不允许新增问题。外部 `cjlint`、`cjfmt` 是补充视图；若规则与项目不匹配，
  必须在 `.dev/README.md` 记录原因和替代门禁。

需要隔离包进程或采集覆盖率时，再执行：

```text
python .dev/cli.py test packages
python .dev/cli.py test packages --coverage --min-line-coverage 45
```

包测试必须串行运行 CangjieGUI 与 CangjieSDL 的原生窗口用例，避免两个进程争用 SDL 的进程级状态。覆盖率报告位于
`target/dev/test-package-results/`；当前仓颉工具链可能把部分内联代码归到测试目标，因此覆盖率用于防回退，不代替功能测试。

## 真实窗口与交付

在可交互图形会话中执行：

```text
python .dev/cli.py test desktop
python .dev/cli.py test examples --smoke-snapshots --timeout 300
python .dev/cli.py test examples --smoke-snapshots --retained-diff --timeout 300
```

桌面测试验证窗口线程、事件等待、增量绘制、唤醒、退出和资源释放。`--retained-diff` 还会比较默认增量模式和强制全量
模式的最终图像，避免缓存命中掩盖依赖遗漏。逐示例结果写入 `target/dev/examples/report.json`。

发布验证必须使用明确的目标平台运行库。先用 `release stage-runtime` 建立干净交付目录，再用 `release verify` 从该目录
直接启动可执行文件。只运行 `cjpm run` 不能证明交付包完整。

GitHub 托管的 Linux x64 和 macOS arm64 任务验证全新环境中的下载、解包、构建、无窗口测试和示例编译。Windows、
Linux 和 macOS 的真实窗口、输入法、文件对话框、无障碍桥、GPU 后端和字体仍需对应平台的交互式 runner 或人工检查。

## 性能验证

```text
python .dev/cli.py bench run
python .dev/cli.py bench suite --display --samples 5 --check --timeout 240
python .dev/cli.py bench probe
```

性能数据只能在平台、架构、电源状态、构建配置和样本协议一致时比较。Linux 与 macOS 使用各自的
`.dev/bench/baselines/<profile>`，不能复用 Windows 基线。

新基线先通过 `--capture-baseline-candidate` 生成候选，审阅后再用 `--promote-baseline-candidate` 提升；提升后必须用
另一批样本运行 `--check`。`bench probe` 使用阶段访问次数、同进程 A/B 和规模曲线判断更新粒度，不与普通耗时基线混用。

## 需要人工确认的边界

原生文件对话框、输入法候选窗位置、窗口管理器行为、不同 GPU 后端和跨平台字体必须在目标系统确认。像素基线只能在确认
视觉变化符合预期后更新，不能用批量更新隐藏未知差异。外部链接可达性也由发布流程或人工检查。

验证报告不固化容易过期的用例数量和耗时；这些数据以当前命令输出及 `target/dev/` 下的机器报告为准。
