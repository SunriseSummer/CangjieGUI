# CUI 开发工具

`.dev` 是仓库内所有开发态工具的唯一根目录，统一承载正确性检查、端到端测试、快照、跨平台发布验证与性能测试。源码与可审查基线放在这里，动态报告、缓存和构建产物统一写入根目录 `target/`。

## 统一入口

所有稳定命令都从仓库根目录调用 `.dev/cli.py`。CI、文档和日常使用不直接依赖内部模块路径。

```text
python .dev/cli.py --help
python .dev/cli.py test tools
python .dev/cli.py check docs
python .dev/cli.py test packages
python .dev/cli.py test examples --action build --jobs 2 --timeout 300
python .dev/cli.py test desktop
python .dev/cli.py bench run --samples 1
```

常用命令：

| 领域 | 命令 | 作用 |
| --- | --- | --- |
| 工具自测 | `test tools` | 验证 Python 工具、工作流契约和性能门禁逻辑 |
| 文档 | `check docs` | 检查仓库 Markdown 本地链接 |
| 包测试 | `test packages` | 隔离运行各 CUI 包测试并生成统一报告 |
| 示例 | `test examples` | 构建或测试全部示例，可选真实窗口快照 |
| 桌面生命周期 | `test desktop` | 验证窗口线程、增量绘制、唤醒、退出和清理 |
| 快照 | `snapshot` | BMP/PNG 转换、像素 diff 与基线看护 |
| 示例画廊 | `gallery` | 生成示例真实渲染截图 |
| 发布 | `release ...` | 工具链引导、SDL 构建/暂存和干净交付验证 |
| 性能 | `bench ...` | 基准采集、比较、回归门禁和架构压力实验 |

各子命令支持 `--help`，例如：

```text
python .dev/cli.py test examples --help
python .dev/cli.py release verify --help
python .dev/cli.py bench run --help
```

## 工程结构

```text
.dev/
├── cli.py                         # 唯一稳定 CLI
├── config/                        # 固定版本、哈希等声明式配置
├── cui_dev/
│   ├── common/                    # 路径、进程执行等共享基础设施
│   ├── checks/                    # 文档与包级正确性检查
│   ├── e2e/                       # 示例和桌面生命周期测试
│   ├── snapshots/                 # 纯标准库图像与画廊工具
│   └── release/                   # 跨平台引导、构建、暂存、交付验证
├── fixtures/                      # 最小独立 Cangjie 测试工程
├── platform/windows/              # Windows 专属 UIA 工具
├── tests/                         # 通用工具自测
├── bench/
│   ├── tooling/                   # 采集、解析、基线、报告和门禁模块
│   ├── tests/                     # 性能工具自测
│   ├── workloads/                 # shared/headless/display/diagnostics
│   ├── probes/                    # 独立原生探针
│   ├── baselines/                 # 可审查、平台隔离的活动基线
│   ├── templates/                 # 自包含报告模板
│   └── docs/                      # 性能方法学
└── docs/                          # 工具维护与迁移记录
```

分层原则：

- `cui_dev/common` 不包含具体测试语义，只提供跨领域基础设施。
- correctness 与 performance 可以复用进程和路径能力，但不能互相替代结论。
- `fixtures` 是测试输入；运行时截图、报告和二进制不是测试输入。
- 平台专属实现放入 `platform/<os>`，跨平台 Python 模块不散落条件脚本。
- 只有 `cli.py` 是稳定入口；内部模块可在不修改 CI 的前提下继续演进。

## 产物位置

| 产物 | 目录 |
| --- | --- |
| 工具与 E2E 报告 | `target/dev/` |
| Python 字节码缓存（显式配置时） | `target/dev/pycache/` |
| 夹具构建 | `target/dev/build/fixtures/` |
| 性能包构建 | `target/bench/build/` |
| 性能采集与报告 | `target/bench/results/` |
| 原生性能探针 | `target/bench/probes/` |

`target/` 已整体忽略。活动性能基线是例外：它们属于审查对象，存放在 `.dev/bench/baselines/`。

CLI 默认把自身及 Python 子进程的字节码缓存导向 `target/dev/pycache`。如需覆盖位置，可设置绝对路径；
相对路径会统一按仓库根解析：

```powershell
$env:PYTHONPYCACHEPREFIX = 'target/dev/pycache'
python .dev/cli.py test tools
```

## 正确性与性能的边界

正确性工具回答“结果是否符合契约”，包括测试断言、像素一致性、生命周期、文档链接和干净交付。性能工具回答“成本是多少、是否发生可信退化”，需要独立样本、中位数/MAD、同进程 A/B、环境证据和平台隔离基线。

构建耗时不能替代性能基准，性能 PASS 也不能替代正确性门禁。两类工具只共享无语义的基础设施。

## 扩展规范

新增工具时：

1. 先选择 `checks`、`e2e`、`snapshots`、`release`、`platform` 或 `bench` 的明确归属。
2. 将领域逻辑实现为可导入模块，参数解析入口使用 `main(argv=None)`。
3. 在 `cli.py` 注册稳定命令，CI 和文档只引用该命令。
4. 在对应 `tests` 目录补充失败路径、超时、非法输入和输出契约测试。
5. 动态文件写入 `target/dev` 或 `target/bench`，不写入源码/夹具目录。
6. 脚本保持聚焦；接近 500 行时按配置、执行、解析、报告或策略继续拆分。
7. 外部进程统一使用共享执行器，保留超时、输出解码和进程树清理语义。

## Windows UI Automation

```powershell
powershell -ExecutionPolicy Bypass -File .dev/platform/windows/build_uia.ps1
powershell -ExecutionPolicy Bypass -File .dev/platform/windows/check_uia.ps1
```

构建脚本自动识别 x86_64/arm64，输出到 `target/native/windows/<arch>`；检查脚本运行独立 UIA 客户端并验证真实窗口 provider。
