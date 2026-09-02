[cui](../../index.md) › [cui.core](index.md) › RetainedSubtree

# RetainedSubtree

位于 `cui.core` 包的公开类，实现 [`Widget`](Widget.md)

显式控制增量保留边界。普通 builder 已自动跟踪状态依赖并复用稳定子树，应用通常不需要直接使用本类型。

两种构造方式都会跟踪 `body` 执行期间读取的 `State.value` 和 `revision`。依赖变化后重新构建，稳定帧复用上次子树；
测量、布局和绘制阶段也会分别跟踪依赖，只重新执行必要阶段。显式 `revision` 用于框架无法观察的普通值。

框架只会在可用尺寸、UI 环境、布局区域和可见区域都兼容时复用测量与布局结果。DPI、字体缩放、Renderer、主题或字体
注册表变化会自动使相关缓存失效，不需要应用手工增加 `revision`。事件、焦点、局部状态、生命周期 effect 和浮层始终保持活动。

## 声明

```cangjie
public class RetainedSubtree <: Widget
```

## 构造函数

```cangjie
public init(key: String, cachePaint!: Bool = false, body!: () -> Unit)
public init(key: String, revision: UInt64, cachePaint!: Bool = false, body!: () -> Unit)
```

- `key`：当前声明作用域内的稳定非空身份；同一构建中不得重复。
- `revision`：可选的显式版本；普通捕获值或其他不可观察输入变化时必须推进。
- `cachePaint!`：默认 `false`。为 `true` 时记录首次绘制命令，并在后续稳定帧按原显示顺序重放。它不截取祖先背景，
  也不为每个边界创建 GPU 纹理。`draw` 内读取的 `State` 会自动使绘制缓存失效；其他可变视觉输入必须由
  `revision` 表达。
- `body!`：首次挂载、自动 State 依赖写入或 revision 变化时执行的子树声明。

自动跟踪只覆盖 `body` **内部**的读取；调用构造函数前已经计算好的快照不会成为依赖。空 key 或同一构建中的重复 key
会抛出异常。边界命中时，嵌套的 `rememberState` 仍处于挂载状态；边界卸载后，局部状态、effect 和绘制命令一起释放。
若边界重建后根构建失败，框架放弃本次结果，继续保留上次成功提交的子树和状态。

能用 `State` 表达输入时，优先使用只带 key 的构造方式。普通对象、外部快照或资源版本无法自动观察，才使用显式
`revision`。

绘制中使用续帧、焦点、悬停、按压、拖动、提示、输入法或浮层等动态能力时，框架会自动暂时绕过当前边界及祖先的命令
缓存，并在诊断结果中记录原因。直接读取自定义可变字段无法被发现；这类数据必须改为 `State`、纳入 `revision`，或关闭
`cachePaint`。

桌面宿主会把局部状态失效合并为待更新区域，只重放与该区域相交的稳定绘制命令。输入、动画、帧订阅、浮层、窗口变化、
更新区域过大或渲染后端不支持局部保留时，会安全回退为全帧绘制。自定义 Canvas 若绘制到布局区域之外，应通过
[`PaintOutset`](PaintOutset.md) 声明额外范围，否则局部更新可能遗漏旧像素。

## 方法

### cacheStats

```cangjie
public func cacheStats(): RetainedSubtreeStats
```

返回当前身份累计的构建、布局与绘制命中数，供诊断和性能测试使用。

## 示例

完整且经过编译验证的示例见[验证增量更新与帧行为](../../../guide/how-to/retain-and-test.md)。
