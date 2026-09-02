# CUI 性能测试

性能测试属于 `.dev` 开发工具体系，但保持独立的测量协议、工作负载、基线和报告。日常使用只调用统一 CLI：

```text
python .dev/cli.py bench run --samples 1
python .dev/cli.py bench run --display --samples 3
python .dev/cli.py bench run --display --samples 5 --check
python .dev/cli.py bench probe --samples 3
python .dev/cli.py bench suite --display --samples 5
python .dev/cli.py bench compare --a old-1.txt old-2.txt --b new-1.txt new-2.txt
```

## 组成

- `workloads/shared`：计时 harness 与可复用场景构造。
- `workloads/headless`：无窗口、CPU 侧 build/layout/draw 微基准。
- `workloads/display`：真实 SDL 文本光栅、GPU present 与尾延迟场景。
- `workloads/diagnostics`：增量更新架构压力与决策实验。
- `tooling`：执行隔离、记录解析、采样聚合、环境取证、基线、报告和回归判定。
- `baselines`：平台隔离的活动基线；只能通过候选采集和显式晋升更新。
- `probes`：不依赖 CUI 场景语义的原生验证探针。

所有动态结果写入 `target/bench/results`，所有 Cangjie 构建写入 `target/bench/build`。

## 三类命令

- `bench run`：日常 headless/显示基准、HTML/JSON 报告与可选回归门禁。
- `bench probe`：局部更新、遍历扇出和 retained 状态成本的架构证据。
- `bench suite`：工具自测、场景契约、日常基准和架构探针的完整编排。
- `bench compare`：比较两组已有原始捕获，默认各侧取中位数。

## 测量纪律

- 预热与正式样本分离；正式结果按用例取中位数并记录 MAD、全距。
- 对顺序敏感的 A/B 在同一进程成对执行，并跨样本交替 AB/BA。
- headless 与不同渲染后端、超采样、vsync 的 display 域分别归一化。
- 回归门禁先估计同域机器因子，再判断偏离群体变化的单点退化。
- 样本不稳定、环境不一致、基线缺失或覆盖不足时拒绝给出伪 PASS。
- 电池供电样本只作为观测证据，不能晋升为硬门禁基线。
- 微小到不足以影响帧预算的用例不参与硬裁决，但显著变化仍列为诊断信息。

更完整的场景、机器记录和基线协议见 `docs/methodology.md`。

## 新增工作负载

1. 放入合适的 `workloads/<domain>/<name>`，不要把性能逻辑放回正确性脚本。
2. 复用 `workloads/shared/harness` 的计时与机器记录格式。
3. 在 `cjpm.toml` 将 `target-dir` 指向 `target/bench/build/<domain>/<name>`。
4. 为执行、解析和判定补充工具契约测试。
5. 新用例先采集候选并审查稳定性，不直接改活动基线。
