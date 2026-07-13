# 性能基准（bench）

CUI 的性能测试统一在此目录，分三部分：可复用的计时与报告工具、可复现的单场景微基准，以及端到端
整应用基准。

## 目录结构

- `harness/`：可复用的基准工具库（`bench_harness`）。提供纳秒计时、抗死代码消除的计时循环，以及
  整数制的时长与比率格式化。其余基准以路径依赖引入它。
- `micro/`：无头单场景微基准（可执行）。不需显示、随处可跑，直接打印每次迭代耗时。当前含 Table
  每帧排序与字符串操作两组。
- `large_table/`：端到端整应用基准（可执行）。真实 `DesktopApp` 加大数据量 `Table`，内置每秒打印
  帧率的计量器。因涉及真实文本渲染，需要显示环境。

## 运行

- 微基准（无头）：`cd bench/micro && cjpm run`
- 端到端（需显示）：`cd bench/large_table && cjpm run`；点击列头排序后滚动，观察控制台的 `[fps]` 输出。

## 方法学

- 计时用 `sdl.system.PerformanceClock.ticksNanoseconds`（SDL 高精度时钟，无需建窗）。
- 无头限制：`Renderer.headless()` 返回近似的假度量、不经真实字体后端，故一切依赖 SDL_ttf 的端到端
  计时（文本绘制帧率、文本度量缓存的净收益）在无头下测不了，须用 `large_table` 在带显示环境测。纯
  CPU 的每帧成本（排序、布局、字符串操作）在无头可靠测得。
- 运行时特征备忘：`String` 逐字节下标（带越界检查）开销显著，标准库批量字符串操作更优；故字符串与
  文本路径的优化必须实测，勿凭"减少分配"的直觉（见根目录 `done.md` 中两项据实回退的记录）。

## 新增基准

- 单场景微基准：在 `micro/src/` 加一个 `*.cj`，写 `public func runXxxBench()`，用 `bench_harness` 的
  `timeit(name, iterations, body)`（`body` 返回 `Int64` 校验值以防被优化掉）与 `printResult`、
  `printSection` 输出，再在 `main.cj` 中调用。
- 端到端应用：仿 `large_table/` 或 `examples/` 新建一个可执行包，`[dependencies]` 引 `cui` 与
  `bench_harness`，在帧回调里用计量器打印帧率或帧耗时。
