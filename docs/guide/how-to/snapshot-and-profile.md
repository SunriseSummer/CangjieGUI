<!-- kind: how-to; audience: component-author -->

# 生成快照并定位帧耗时

## 目标

生成可检查的 BMP 快照，并把视觉回归与交互测试、帧性能记录分开。完成约需 15 分钟。

## 适用场景

组件文档示例、布局回归、主题变更和发布前烟雾检查。快照只能证明一个静态画面，不足以证明焦点、Modal、拖动或后台任务正确。

## 准备工作

准备固定窗口大小、稳定输入和可写的产物目录，记录构建类型、操作系统和字体环境。先决定哪些结果由快照自动检查，哪些由事件测试检查，哪些必须人工操作；三类状态在报告中分开，不能用一个“通过”概括。

## 操作步骤

### 1. 让初始画面确定

固定窗口尺寸、内置文本和本地资源；不要把当前时间、随机数或网络结果放进基准图。下面程序可普通交互运行，也可用 `--snapshot` 自动退出。

```cangjie verify role=complete profile=gui-visual
package docexample

import cui.*

main(): Unit {
    FileSystem.createDirectory("target/snapshots")
    let app = DesktopApp(WindowSpec("快照基准", 520, 320))
    app.run {
        let progress = rememberState<Float32>("release-progress") {0.72}
        VStack(spacing: 12.vp) {
            Label("发布检查").bold()
            ProgressBar(progress)
            HStack(spacing: 8.vp) {
                Badge("构建通过", kind: BadgeKind.Success)
                Label("72%").muted()
            }.height(36.vp)
            Button("主要动作", {=> ()}, role: ButtonRole.Primary)
        }.padding(24.vp)
    }
}
```

### 2. 运行快照模式

构建完成后执行：

```text
cjpm run --run-args="--snapshot target/snapshots/release-check.bmp"
```

程序先创建输出目录，再由快照模式绘制并自动退出。检查文件存在、长度非零、BMP 头有效，并查看标题、进度条、徽章和按钮没有裁切；高 DPI 下图片尺寸使用后备像素，可能大于 `WindowSpec` 的逻辑尺寸。

### 3. 为交互另写测试

使用 `WidgetTestHost.frame` 注入键盘或指针事件，并断言事件后的状态和帧结果。Modal 背景屏蔽、Tab 顺序、菜单
Escape、画布拖动都应通过事件测试或人工步骤验证。快照可作为补充，不能替代这些断言。

### 4. 读取阶段帧报告

先分别测“静止 5 秒”“滚动大列表”“动画期间”“图片首次出现”和“图片缓存命中”。记录窗口大小、数据规模、构建类型与机器环境，再比较构建、布局、绘制各阶段；没有这些上下文的单个毫秒数不可复现。

`--profile` 每 60 帧同时输出阶段均值、总帧 P50/P90/P95/P99/最大值、同帧稳定化次数、触发来源（输入/状态/
计时/尺寸/强制）、后端实际采用的 retained 局部 damage 帧数，以及文本度量、实算、塑形、绘制次数。阶段均值定位持续成本，P95/最大值定位偶发
长帧；稳定化次数大于 1 表示事件或布局写状态后发生了绘制前重建，长期触顶则应移除构建副作用。

每个窗口还输出一条 `@@FRAME_PROFILE` 键值记录，字段均使用纳秒或计数，可直接被日志采集器解析；该行与上方
中文说明来自同一批样本。记录比较时同时保存窗口尺寸、数据规模、构建优化级别、渲染后端和机器环境。

局部 damage 计数为 0 不一定是故障：输入、动画/Frame 订阅、浮层、窗口变化、大范围更新、1× 无持久目标或
`--cui-disable-retained-damage` 都会有意全帧。先从 `retainedDiagnostics().describe()` 查看 pending damage、
dirty 原因和命令规模，再用全量开关做像素差分；不要仅凭帧率猜测是否走了优化路径。

长文本问题还应记录 `ctx.paragraphCacheStats()`：预热后的同文同宽应以 hits 增长，持续 misses 表示文本、宽度、
字号/字体或行数上限正在抖动，evictions 快速增长表示工作集超过 4 MiB。display list 的
`RenderCommandBufferStats.batchSubmissionCount` / `batchedCommandCount` 可确认相邻基础原语是否真正形成批次；
批次为 0 不代表错误，圆角 mesh、文本、纹理或被 clip/颜色隔开的命令本来就不应强行合并。

仓库开发者还可运行 `python .dev/cli.py bench run` 生成 headless/显示基准报告，用
`python .dev/cli.py test examples --smoke-snapshots` 运行跨特性端到端窗口看护。

## 确认结果

快照命令退出码为 0，BMP 可打开且尺寸与窗口一致。重复运行两次，稳定区域应一致。静止页面没有持续帧；动画或轮询结束后帧循环停下。交互清单独立记录为通过、失败或人工边界，不与快照结果混成一个“运行通过”。

## 常见错误

- 使用变化数据做黄金图：每次构建都产生噪声差异。
- 只检查文件存在：零字节或错误尺寸也会被误判通过。
- 把快照通过当成键盘可用：静态图看不出事件消费。
- 没有预热就比较纹理首次解码与缓存命中：数据不可比。

## 相关 API

[DesktopApp](../../api/cui/desktop/DesktopApp.md)、[ProgressBar](../../api/cui/controls/ProgressBar.md)、[Badge](../../api/cui/controls/Badge.md)。

## 下一步

一般启动、状态或浮层问题先看[通用排障](../troubleshooting/common-problems.md)；发现卡顿时到[媒体与性能排障](../troubleshooting/media-performance.md)，准备交付时继续[打包桌面应用](package-desktop-app.md)。
