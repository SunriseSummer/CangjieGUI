# 下一代 GUI 框架完成度审计

## 审计结论

按 2026-08-31 当前工作树和本轮约定的验收范围，下一代 GUI 框架重构目标已经完成。验收平台为 Windows x86_64；
用户明确要求本轮先不考虑其它平台测试，因此 Linux/macOS 实机结果不属于本轮退出条件，也不能从本文结论中
推导为已通过。

“完成”表示核心架构、编程接口、性能、正确性、示例、桌面生命周期和 Windows 干净交付均有直接证据；不表示
框架从此不再演进，也不表示外部 lint 存量已经全部清零。

## 要求—证据矩阵

| 目标要求 | 判定 | 当前直接证据 |
| --- | --- | --- |
| 单一、自动、增量 UI 内核 | 完成 | `AutomaticRenderNode`、generational Element arena、phase facet、ScenePatch、display list 与 damage；失败构建/布局原子性反例 |
| 状态管理易用且可推理 | 完成 | `State`/`DerivedState`/`Binding`/Lens/Prism、事务与等价策略；Reducer/Store/EffectStore 渐进接口；可执行 optics/策略定律 |
| 身份、生命周期和失败一致 | 完成 | 位置槽/显式 key、transaction arena、pending/committed 几何与 fragment、effect 清理、资源 epoch 和异常传播测试 |
| 事件、焦点、浮层、语义一致提交 | 完成 | Capture/Target/Bubble、有序 AABB、焦点/overlay/semantics fragment、商树结构 revision、独立熔断 Windows UIA bridge |
| 惰性与大模型具有明确复杂度 | 完成 | viewport-local 物化、自测量 extent、index/key 路由；IdentifiedArray/EntityTable 持久更新与批量 reducer；规模基准和访问计数 |
| 默认性能不低于重构前，综合收益最大 | 完成 | 125 项稳定 AC 五样本基线；独立五样本 `--check` 0 回归；结构 A/B；未达门槛的 SDL_GPU 后端被明确拒绝 |
| 增量与全量结果等价 | 完成 | Desktop lifecycle damage/full 像素差 0；8 个真实应用 retained/full 差分全部通过 |
| API、文档和示例可用 | 完成 | 48/48 独立示例；24/24 真实窗口 smoke；入门、概念、how-to、API、架构和总结文档 |
| Windows 可干净发布 | 完成 | 6 个制品带 SHA-256；4 个无开发环境依赖的隔离场景；窗口、文本、后台唤醒、资源清理、damage、UIA 全部通过 |
| 测试与质量门禁可信 | 完成 | GUI 853/853、生产行覆盖 79.58%；严格 L2 新增 0；性能候选两阶段晋升、源码/环境摘要和工具负例 |

## 本轮收尾重新发现并关闭的问题

1. 五样本复现最初把 `ModelStore selector` 错判为约 2.2x 退化。干净重建仍复现，但将同一二进制分别固定在
   CPU 0–3 与 4–7 后，耗时分别约为 1.18/0.79 ms 与 1.95/1.14 ms。Windows CPU-set 信息证明两组属于不同
   EfficiencyClass，根因是移动混合核心调度，不是框架算法。runner 现在固定最高 EfficiencyClass，并记录亲和性。
2. 旧 runner 没有先 clean benchmark 包，coverage/profile 或陈旧二进制可能给出假通过。现在每包首次运行前
   强制 `cjpm clean`，并有“每包只清一次”的工具自测。
3. 真实窗口采集出现约 1.37ms 到 2.04ms 的驱动热状态换档。粗粒度按 `driver/ssN/vsync` 归一化会错误地把
   planner 与 controls 当成同一热行为域，因此该方案被实验否决。最终采用两轮未记录显示稳态预热、轮次轮转、
   AB/BA 对消和敏感场景进程中位数，原始 10% MAD 门槛不变。
4. `incremental_dashboard` 原来按固定顺序共享同一 host，command/damage 继承前一变体热状态。三个变体现在拥有
   独立 host/state/driver，完整套件在每个样本内聚合正序和逆序。
5. 最终视觉 smoke 发现 `process_manager` 的确定性表格仍在“正在刷新”与“0 秒前刷新”间竞态。fixture 现在预置
   同一邮箱，快照模式不启动重复线程；刷新间隔按结果完成上屏的时刻重置。目标复验 3/3、完整 smoke 24/24。

## 当前机器权威记录

- `target/dev/test-package-results/report.json`：controls 195/195、core 524/524、desktop 12/12、media 12/12、
  testing 73/73、text 49/49，共 865/865；生产 166 文件，14610/18359 行，79.58%。
- `.dev/bench/baselines/default/baseline.json` / `.dev/bench/baselines/default/baseline.meta.json`：125 项 Windows x86_64、AC、五样本活动基线；CPU affinity
  `0xF`；候选由 `explicit-reviewed-candidate-v1` 显式晋升。
- `target/bench/results/baseline-capture.json`：106 frame、213 micro、19 display；36 个物质级案例全部稳定、0 不稳定；
  106/106 headless 达到 120fps，display P95 19/19 达到 60fps、18/19 达到 120fps。
- `target/bench/results/check.json`：独立全新构建五样本 PASS；18 个稳定物质级 headless 案例 factor 1.044、残差
  ±2%、0 回归；lazy-index、lazy-scroll、observable-state 配对变化 0.96x/1.03x/0.95x。
- `target/dev/test-package-results/desktop-lifecycle.json`：20/20 真实窗口启动/退出，retained-damage/full 像素差 0。
- `target/dev/examples/report.json`：48/48 示例包门禁。
- `target/dev/examples/smoke-report.json`：8 个代表应用的 test/snapshot/retained-diff 共 24/24。
- `target/dev/release/windows-x86_64-delivery.json`：主程序、仓颉 runtime、bounds、SDL3、SDL3_ttf、UIA
  六个制品；retained-damage、automatic-partial、automatic-fallback、lifecycle 四场景通过，像素差 0。

## 允许保留但不能误述的边界

- Linux/macOS 的 workflow、runtime staging、固定摘要 bootstrap 和 profile 隔离基线基础设施已经存在，但本轮未在
  那两类真实机器上验收。后续若要发布到这些平台，仍必须采集各自构建、窗口、字体、输入、无障碍、截图、干净
  交付和性能基线；Windows 数据不能替代它们。
- 完整外部检查仍有 1875 条存量（cjlint 1767、cjfmt 108）。严格 L2 对本次变更保持 error 0、warning 0、new 0；
  外部存量继续按真实缺陷、领域命名、运行时多态和工具误判分类，不通过删除规则或扩大豁免伪装清零。
- 自动可观察惰性数据相对手工 snapshot+revision 的配对微基准约有 4% 成本；这是用很小热路径成本换取消除手工
  版本协议的明确综合收益。真实 dashboard 的 damage 在本机只比 command replay 快约 3%，不宣称普遍数量级收益。
- SDL_GPU/D3D12 代表场景未达到收益/P95 晋升门槛，保持实验探针而不是生产第二后端。这是完成后的设计结论，不是
  缺失实现。

全过程、架构收益和数学依据见[重构总结](next-generation-refactor-summary.md)。
