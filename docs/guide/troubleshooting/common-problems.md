[CUI 指南](../index.md) › 常见问题

# 按症状排查 CUI 问题

## 先看现象

从用户能看到的症状进入，不要先猜组件内部：

1. `cjpm build` 失败，先走“构建/依赖”。
2. 构建成功但窗口启动时报 SDL3/SDL3_ttf，走“运行库”。
3. 点击后文字不变、到下一次点击才显示上次结果、短暂变化后复原，或后台任务偶发无结果，走“状态与线程边界”。
4. 插入、排序、过滤或滚出视口后，选择/编辑状态跟错项，走“列表身份与虚拟化”。
5. 小窗口裁切、滚轮无效或大窗口没有主区域伸缩，走“布局溢出”。
6. Modal 打开时背景仍响应、Tab 离开对话框、关闭后按键异常，走“Modal 与焦点”。

一次只保留一个最小场景。先判断失败发生在构建、进程启动、状态流、数据身份、布局还是事件边界，再改对应一层；同时改主题、状态键和容器会破坏诊断证据。

## 可能原因

- **构建/运行边界**：依赖路径指向了 `src` 而不是 `cui` 根，或本机加载器找不到 SDL 动态库。

- **状态所有权**：把事实放在普通局部变量、每次构建重新赋初值、使用重复/变化的 `rememberState` 键，或让后台线程直接写 UI `State`。

- **身份与虚拟化**：用数组索引作业务 id；虚拟行滚出后仍期待其行内 `rememberState` 存活。

- **布局约束**：固定宽高超过视口、伸缩区域选错、把大量行放进普通 `ScrollView`，或估计行高与实际换行内容不符。

- **事件/浮层**：用普通 `Panel` 冒充 Modal、根 `EventHandler` 抢走文本键、把“恢复 opener 焦点”当成当前 API 保证，或创建 `Toaster` 却没有 `ToastLayer`。

## 诊断步骤

### 症状一：项目无法构建，或构建后窗口无法启动

先执行 `cjpm build`。若退出码非 0，只检查错误指向的 `cjpm.toml` 路径、导入和公开签名；不要先复制 DLL。构建通过后再执行 `cjpm run`。Windows 下若启动器报告 SDL3/SDL3_ttf 缺失，把仓库的实际运行库目录临时加到当前终端：

```powershell
$env:PATH = "C:\path\to\workspace\sdl\.sdl3;$env:PATH"
cjpm build
cjpm run
```

第一个命令失败属于编译/依赖；第一个成功、第二个报 DLL 加载失败才属于运行时搜索路径。用[第一个窗口](../getting-started/first-window.md)复测：最小窗口也失败，继续修复环境；最小窗口成功而业务窗口失败，再回到业务代码。

### 症状二：状态不更新，或后台结果偶发丢失

先检查所有会影响 `Label` 文本、条件分支、布局、启用态或命中的模型字段。若事件回调写的是普通 `var`，而同一事务没有任何 `State` 写，`FrameScheduler` 不会失效；当前帧会继续绘制事件前已经构建的树，空闲循环也可能不再绘制。计算器曾因此表现为按钮点击后显示滞后一拍。修复是把可见事实本身改为 `State`，并让构建读取 `.value`：

```cangjie role=fix
class CounterModel {
    let display = State<String>("0")
}

Button("+1", {=> model.display.value = nextValue(model.display.value)})
Label(model.display.value)
```

用两次连续点击只是复现手段，不是通过条件；正确结果是第一次 MouseUp 所在帧在 draw 前发生一次稳定重建，并立即显示新值。可用 `WidgetTestHost.frame(..., events:)` 断言 `stabilizationPasses == 2` 与最终构建读值。

先搜索 `spawn`。下面的最小探针故意展示错误边界：工作线程直接写 UI `State`。它可能偶尔显示结果，却违反 CUI 的线程约束，不能作为修复：

```cangjie role=probe
let status = State<String>("等待中")
let _ = spawn {
    status.value = "后台直接写入" // 症状探针：禁止在真实 UI 中这样做。
}
```

若没有后台任务，再把页面缩成一个 `rememberState`、一个 `Label`、一个 `Button`；连续点击能递增，说明事件循环和状态存储正常，问题在原模型重建、重复键或写读不是同一个对象。

有后台任务时使用互斥量保护的信箱。工作线程只发布普通数据；按钮同时把 UI 状态改为“正在加载”，触发下一次构建并挂载帧处理器。帧回调在 UI 线程收取结果后才写状态。

下面是可直接放进空项目 `src/main.cj` 的完整修复程序。工作线程只发布普通字符串，`FrameHandler` 在 UI 帧收取后才写 `State`：

```cangjie role=fix
package docexample

import cui.*
import std.sync.Mutex

class UiMailbox {
    private let mutex = Mutex()
    private var pending: ?String = None
    private var busy = false

    func start(): Bool {
        var shouldStart = false
        synchronized(mutex) {
            if (!busy) {
                busy = true
                shouldStart = true
            }
        }
        if (!shouldStart) {
            return false
        }
        let _ = spawn {
            publish("后台结果已就绪")
        }
        true
    }

    private func publish(result: String): Unit {
        synchronized(mutex) {
            pending = Some(result)
            busy = false
        }
    }

    func collect(): ?String {
        synchronized(mutex) {
            let result = pending
            pending = None
            return result
        }
    }

    func needsPolling(): Bool {
        synchronized(mutex) {
            return busy || pending.isSome()
        }
    }
}

func renderLoading(mailbox: UiMailbox, status: State<String>): Unit {
    VStack {
        Label(status.value)
        Button("开始加载", {=>
            if (mailbox.start()) {
                status.value = "正在加载"
            }
        })
    }
}

func renderMailbox(mailbox: UiMailbox, status: State<String>): Unit {
    if (mailbox.needsPolling()) {
        FrameHandler(onFrame: {_ =>
            match (mailbox.collect()) {
                case Some(result) => status.value = result
                case None => ()
            }
        }) {
            renderLoading(mailbox, status)
        }
        return
    }
    renderLoading(mailbox, status)
}

main(): Unit {
    let mailbox = UiMailbox()
    let status = State<String>("尚未开始")
    let app = DesktopApp(WindowSpec("后台任务信箱", 420, 240))

    app.run {
        renderMailbox(mailbox, status)
    }
}
```

这里 `needsPolling()` 同时检查 busy 和 pending，避免工作线程刚发布结果、UI 就提前卸载帧处理器。耗时工作绝不放在锁内；生产代码还应在工作线程捕获异常并把错误文本也发布进信箱。

### 症状三：列表重排后状态串到别项或跟错行，或滚回后编辑内容消失

先选中业务 id `B`，在它前面插入一项，再排序。若高亮或编辑状态落到别的对象，检查 `ForEach(..., key:)`/`LazyColumn.of(..., key:)` 是否返回业务 id，而不是索引。过滤掉选中项后，应明确清空 id 或选择邻近项。

确认修复：再次插入、排序、过滤并滚离后返回，高亮和上提到模型的草稿仍显示业务 id `B`；只保存在虚拟行内的临时展开状态允许按页面约定复位。

若只在滚出视口再滚回后丢失，问题不是 key 不稳定：虚拟行离开构建树时，其行内 `rememberState` 会被清理。把需要跨滚动保留的编辑、展开和校验状态提升到以业务 id 为键的应用模型；稳定 key 负责重排身份，不负责让已卸载控件继续存活。

### 症状四：内容溢出、滚轮无效或窗口放大后仍挤在一角

测试最小、常用和较大三种窗口尺寸。先问哪个区域应伸缩：主内容使用 `.flex()`，工具栏和主要按钮留在滚动区外。普通长内容用 `ScrollView`；大量固定行用 `LazyColumn`。如果内容高度没有超过视口，滚轮不产生位移是正常结果。

若虚拟列表跳动，逐项核对 `itemHeight`/估计高度是否包含换行、可选标题和分隔条。不要用缩小字体或给所有控件固定宽度掩盖约束问题。

先检查父容器给出的尺寸、弹性控件和真正负责滚动的那一层；比较最小、常用和最大窗口，记录哪个区域先裁切。内容很多但节点数量不大时用滚动，项目数量很大时检查是否需要虚拟化。

确认修复：三个窗口尺寸下主要操作都可见或可滚动到达；内容不足一屏时滚轮交给外层，放大后主内容区能吸收剩余空间而不是仍挤在角落。

### 症状五：Modal 背景仍响应、Tab 越界或关闭后按键异常

只保留一个背景按钮、一个打开按钮和一个 `Modal`。真正的 `Modal` 会吞掉背景事件并把 Tab 限制在对话框的可聚焦控件；普通居中 `Panel` 不会。分别通过 Esc、遮罩、取消和确认关闭，记录关闭后的当前焦点与下一次 Tab；当前公开 API 没有 opener/restore-target 参数，不要把恢复到打开按钮写成通过条件。

若 Toast 不出现，确认同一棵根 `ZStack` 同时包含长期存在的 `Toaster` 与 `ToastLayer(toaster)`。若出现后不消失，确认帧仍在推进；不要用阻塞 `sleep` 等待 Toast。

## 修复方法

- 先修正 `cui` 项目根依赖，再单独修复 SDL 运行库搜索路径。
- 把所有可见/可交互事实移到 `State`，把可计算值改为派生值；普通模型 `var` 不充当隐式失效信号；状态键固定、唯一且类型稳定。
- 后台线程只向 `Mutex` 保护的信箱发布普通数据；`FrameHandler` 在 UI 帧收取后才写 `State`。
- 动态项目用业务 id；虚拟化后仍要保留的行状态提升到模型。
- 按内容关系选择容器，让主区域伸缩；普通滚动与虚拟化按节点规模选择。
- 使用真实 `Modal` 和 `ToastLayer`，让快捷键复用业务动作，并按当前公开焦点契约验收。

## 确认已经修复

构建问题以 `cjpm build` 退出码 0 为准，运行库问题以最小窗口打开并关闭为准。状态问题必须在第一次点击所在帧就反映，连续点击、窗口缩放和重建后仍保持；后台任务期间窗口仍响应，完成/错误都从信箱上屏。列表问题应在插入、排序、过滤后仍跟随同一 id，跨滚动状态由模型保留。布局应在三种窗口尺寸下可达。Modal 期间背景操作无效，Tab 不离开对话框；关闭后只检查实测的下一次 Tab 行为，不要求自动恢复 opener。Toast 可见后按预期消失。

## 避免再次发生

保留第一个窗口作为环境冒烟应用；为 id→索引映射、表单校验和过滤写纯逻辑测试；真实桌面回归同时覆盖鼠标和完整键盘路径。后台工作统一采用 mailbox + UI 帧收取，不在 `spawn` 中持有 UI `State`。验证报告应区分“编译通过”和“真实窗口交互已走查”，并让示例 manifest 的源码哈希与当前正文一致。

## 相关 API

- [`ImageView`](../../api/cui/media/ImageView.md) — 图片空白和缓存问题的入口。

- [`DesktopApp`](../../api/cui/desktop/DesktopApp.md) — 启动与帧循环。
- [`State`](../../api/cui/core/State.md)、[`Keyed`](../../api/cui/core/Keyed.md) — 状态与身份。
- [`FrameHandler`](../../api/cui/core/FrameHandler.md) — 在 UI 帧收取后台信箱。
- [`ScrollView`](../../api/cui/core/ScrollView.md)、[`LazyColumn`](../../api/cui/core/LazyColumn.md) — 滚动与虚拟化。
- [`Modal`](../../api/cui/controls/Modal.md)、[`Toaster`](../../api/cui/controls/Toaster.md)、[`ToastLayer`](../../api/cui/controls/ToastLayer.md) — 浮层和通知。

## 下一步

媒体、动画或帧耗时问题继续[媒体性能排障](media-performance.md)；准备交付时按[打包桌面应用](../how-to/package-desktop-app.md)做干净目录冒烟。

问题解决后返回[指南首页](../index.md)选择学习路径。状态/身份问题回到[状态与绑定](../concepts/state-and-binding.md)和[数据列表](../how-to/data-list.md)；布局问题回到[布局与滚动](../concepts/layout-and-scrolling.md)；焦点问题回到[焦点、事件与浮层](../concepts/focus-events-and-overlays.md)。
