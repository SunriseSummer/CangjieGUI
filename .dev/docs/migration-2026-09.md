# .dev 迁移与重构记录

迁移日期：2026-09-02。

## 迁移目标

- 将原 `.devtools` 改名为 `.dev`。
- 将根目录 `bench` 纳入 `.dev/bench`，同时保持 correctness/performance 语义隔离。
- 以统一 CLI 隔离 CI、文档与内部模块路径。
- 集中生成物，消除源码目录中的构建、报告和 Python 缓存。
- 拆分超长性能脚本，建立可测试、低耦合的模块边界。

## 迁移前基线

- Python 工具：13 个脚本套件全部通过。
- 根工程：`cjpm build` 通过；`cjpm test` 为 865/865。
- 包隔离矩阵：6/6 包、865/865 测试通过。
- 文档：219 个 Markdown 文件链接检查通过。
- 示例：48/48 独立构建通过。
- 性能场景契约：3/3 通过。
- 无窗口基准：106 个帧场景；60 FPS 超限 0；120 FPS 达标 106。
- 迁移前动态数据约 245 MB 分散在工具/基准子目录中，另有约 4.4 MB 性能结果。

原始性能报告和迁移基线记录保存在 `target/bench/results` 与 `target/dev/migration`。
迁移前散落的 examples 截图、覆盖率/包报告、跨平台报告和原生探针产物均未删除，分别归档到新分区中的
`pre-migration` 子目录。

## 关键变更

| 旧位置/入口 | 新位置/入口 |
| --- | --- |
| `.devtools/*.py` | `.dev/cui_dev/<domain>/*.py` |
| `.devtools/*_test.py` | `.dev/tests/test_*.py` |
| `.devtools/*.ps1` | `.dev/platform/windows/*.ps1` |
| `bench/<package>` | `.dev/bench/workloads/<domain>/<package>` |
| `bench/*.py` | `.dev/bench/tooling/*.py` |
| `bench/*_test.py` | `.dev/bench/tests/test_*.py` |
| `bench/results` | `target/bench/results` |
| 多个脚本入口 | `python .dev/cli.py ...` |

原 2,145 行性能运行器被拆分为配置、执行、解析、采样、环境、基线、晋升、门禁、JSON 报告、HTML 报告和编排模块；原 764 行合成门禁测试拆为三个关注点文件；架构探针的分析与运行也已分离。迁移后没有 Python 文件超过 500 行。

## 兼容性策略

此次迁移有意不保留旧路径包装脚本。仓库内 CI 和维护文档统一使用新 CLI，避免双入口长期漂移和重复维护。内部 Python 模块不是稳定 CLI，允许继续按职责演进。

## 迁移后验证

| 验证项 | 结果 |
| --- | --- |
| Python 编译与工具自测 | 82 个 unittest 通过；77 个命名性能契约断言通过 |
| 根工程构建 | `cjpm build` 通过 |
| 根工程测试 | 865/865 通过，失败/跳过/错误均为 0 |
| 包隔离矩阵 | 6/6 包、865/865 测试通过 |
| 示例构建矩阵 | 48/48 通过 |
| Markdown 链接 | 222 个文件通过（包含新增 `.dev` 文档） |
| benchmark scenes 契约 | 3/3 通过 |
| 无窗口性能套件 | 106 个帧场景；60 FPS 超限 0；120 FPS 达标 106 |
| phase3 架构探针 | 执行成功并生成 Markdown/JSON 证据 |
| Desktop 生命周期 | 四场景通过；incremental/full 像素差 0 |
| Windows UIA | provider、属性查询与 Invoke 往返通过 |
| 干净发布目录 | Windows x86_64 四场景通过；像素差 0 |
| 严格 L2 工程规则 | 新增问题 0，消除 3，ERROR/WARN 0 |
| cjlint/cjfmt 外部视图 | 命令成功执行；保留 1,892 条既有 WARN 作为存量治理视图 |
| Git 空白检查 | `git diff --check` 通过 |

迁移前后无窗口基准的关键计数完全一致。全部 10 个 benchmark 与 2 个 fixture Cangjie 工程均配置集中
`target-dir`；最终扫描确认 `.dev` 内没有生成的 `target` 或 `__pycache__`。迁移后的机器报告位于
`target/dev` 和 `target/bench`，不会提交到版本库。
