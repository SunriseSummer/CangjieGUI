<!-- kind: troubleshooting; audience: component-author -->

# 排查图片空白、动画不停与帧卡顿

## 先看现象

先把问题归到一个可观察分支，不要同时改缓存、布局和动画：

| 现象 | 先确认 | 再进入 |
|---|---|---|
| 图片区域空白 | 路径是否存在、BMP 能否单独打开 | 症状一 |
| 首次出现慢，之后正常 | 是否只发生在首次解码 | 症状二 |
| 静止页面仍高占用 | 是否永久挂载 `FrameHandler` 或 `Pulse` | 症状三 |
| 滚动或动画偶发长帧 | 长帧属于构建、布局、绘制还是后台等待 | 症状四 |
| 快照在不同机器变化 | 输入、字体、窗口尺寸是否确定 | 症状五 |

排查前记录操作系统、构建类型、窗口尺寸、数据量、图片路径与复现动作。没有这些上下文的“很卡”无法复核。

## 可能原因

图片空白通常来自错误工作目录、文件缺失、解码失败或盒子尺寸为零；首次慢多来自磁盘读取和纹理解码；持续占用来自无条件续帧；长帧还可能来自在行构建或绘制回调中做排序、文件读取和重复资源创建。

## 诊断步骤

### 症状一：ImageView 只显示空白

先检查进程实际工作目录，再检查文件存在与长度，最后用独立图片查看器打开。CUI 对缺失或解码失败的图片画空白并缓存失败结果，不会每帧抛错，因此“窗口没崩”不能证明资源有效。

下面探针故意使用不存在路径，只用于确认当前症状与失败占位一致：

```cangjie verify role=complete profile=gui-visual
package docexample

import cui.*

main(): Unit {
    println("exists=${FileSystem.exists("missing-preview.bmp")}")
    let app = DesktopApp(WindowSpec("图片探针", 320, 220))
    app.run {
        ImageView("missing-preview.bmp", preferredWidth: Some(160.vp), preferredHeight: 90.vp)
    }
}
```

若输出 `false` 且区域空白，先修路径与交付资源；不要修改布局或缓存。下面修复在启动窗口前生成确定 BMP，并在退出后清理，能同时排除路径、权限和解码格式不确定性：

```cangjie verify role=complete profile=gui-visual
package docexample

import cui.*

let PATH = "known-good.bmp"

main(): Unit {
    try {
        try (surface = Surface.create(80, 60)) {
            surface.clear(Color.rgb(52, 120, 246))
            surface.saveBmp(PATH)
        }
        println("exists=${FileSystem.exists(PATH)}")
        let app = DesktopApp(WindowSpec("图片修复", 320, 220))
        app.run {
            ImageView(PATH, fit: ImageFit.Contain,
                preferredWidth: Some(160.vp), preferredHeight: 120.vp)
        }
    } finally {
        if (FileSystem.exists(PATH)) { FileSystem.remove(PATH) }
    }
}
```

修复程序能显示蓝色矩形，说明渲染链路正常，原问题在输入文件或路径；它仍空白时，再检查 SDL 图像能力、盒子尺寸和运行库版本。

### 症状二：图片第一次出现明显停顿

1. 用同一路径连续打开两次；只有第一次慢，优先判为磁盘读取或首次解码。
2. 查看是否每帧生成新文件名或查询参数；路径变化会绕过复用。
3. 确认列表行构建中没有 `Surface.create`、`saveBmp` 或文件读取。
4. 分别记录冷启动和缓存命中数据，不把两者平均成一个数字。

修复顺序是：在进入页面前准备资源；复用稳定路径；为列表缩略图预先生成合适尺寸；只有源文件确实变化时才使对应缓存失效。不要把 `ImageView.close()` 当成全局清缓存，它只退役当前视图。

### 症状三：界面静止后仍持续重绘

1. 搜索所有 `FrameHandler`、`Pulse` 和动画模型。
2. 暂时卸下其中一个，观察静止帧是否停止。
3. 对 `Animator` 打印 `goal`、`value`、`settled()`；若目标每帧变化，检查构建函数是否重复重设。
4. 检查 `FrameHandler` 是否只出现在 busy、animating 或 visible 分支。

确定动画已经稳定后，卸下 `FrameHandler`；后台结果收取后关闭 polling 分支；页面不可见时暂停 `Pulse`。如果产品需要常驻动画，明确记录这是设计成本，并提供“减少动态效果”或暂停条件。

### 症状四：滚动或动画有长帧

1. 固定窗口尺寸与数据，分别录制静止、滚动、动画三个阶段。
2. 构建阶段长：检查行构建器中的筛选、排序、字符串格式化和资源创建。
3. 布局阶段长：检查深层嵌套、重复测量、可变高大列表和不受限尺寸。
4. 绘制阶段长：检查是否发出了大量自绘命令、加载了超大图片或每帧都在新建纹理。
5. 全阶段一起长：查看 UI 线程是否同步读文件或等待锁。

每次只改一个原因并重放相同动作。大列表优先迁移到[虚拟化容器](../how-to/virtualize-large-data.md)；后台工作按[信箱模式](../how-to/desktop-files-and-background.md)返回；画布只绘制可见内容。

### 症状五：快照不稳定

先排除时间、随机数、网络、系统路径和异步未完成状态，再固定窗口和主题。字体栅格在不同平台可能略有差异，跨平台比较应使用结构性容差或分别维护基准；同一机器的稳定区域仍应逐像素一致。快照不覆盖菜单打开、Modal 阻断和拖动手势，这些另写事件测试。

确认方法：在同一构建、同一机器连续生成两次快照，文件尺寸和稳定区域应一致；再人工打开图像，标题、盒子和资源不能裁切。若只剩跨平台字体边缘差异，将它记录为人工边界，不要用无限容差掩盖真实布局变化。

## 修复方法

按证据选择最小修复：输入坏就修路径或生成流程；首次解码慢就预热并复用稳定 key；无条件续帧就增加挂载条件；UI 线程长任务就移到后台信箱；布局过量就虚拟化或减少测量层级。完成后同时保留修复前探针、修复后结果与未自动化边界。

## 确认已经修复

- 已知有效 BMP 能显示，缺失文件能被探针明确识别。
- 冷启动与缓存命中分别记录，不再混报。
- 静止 5 秒无持续帧，动画和轮询完成后停止。
- 相同数据和动作下，目标阶段耗时回落且没有把成本移到另一阶段。
- 快照、事件测试和人工平台检查分别有状态。

## 避免再次发生

把确定输入的媒体快照、动画显式时间测试、大列表固定数据回放和干净交付目录冒烟加入发布清单。代码评审时禁止在绘制回调和虚拟行构建器中进行文件 I/O，要求所有持续帧组件写明停止条件。

## 相关 API

[ImageView](../../api/cui/media/ImageView.md)、[媒体函数](../../api/cui/media/functions.md)、[Animator](../../api/cui/core/Animator.md)、[FrameHandler](../../api/cui/core/FrameHandler.md)、[DesktopApp](../../api/cui/desktop/DesktopApp.md)。

## 下一步

回到[快照与性能记录](../how-to/snapshot-and-profile.md)建立稳定基线；如果问题属于运行库或线程状态，使用[通用排障](common-problems.md)。
