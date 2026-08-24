[cui](../../index.md) › [cui.core](index.md) › RetainedSubtree

# RetainedSubtree

`cui.core` 包中的 public class，实现 [`Widget`](Widget.md)

显式保留模式高级/兼容边界；普通 builder 已自动进入增量组合、选择性持久渲染、显示列表和 damage
策略，应用通常不需要本类型。两种重载都会把 body 执行期间实际读取的 `State.value` / `revision`
登记为 build 依赖，任一依赖写入后自动重建；稳定帧复用上次构建的子树。measure 与 layout 也分别收集 State
读取并只失效必要阶段；`cachePaint: true` 时 draw 读取会使陈旧命令缓冲自动失效。显式 revision 重载用于额外覆盖
普通捕获值、主题等非 State 输入。可用尺寸和布局矩形相同时还会跳过测量与布局；事件、
焦点、局部状态、lifecycle effect 和浮层仍保持活动。

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
- `cachePaint!`：默认 `false`。为真时首次绘制记录不可变、透明的 Renderer 值命令，之后按原 z 序重放；不会
  截取祖先背景，也没有每边界 GPU 纹理。draw 内的 State 读取会自动只失效 paint；revision 仍须覆盖主题、
  普通捕获值、资源 epoch 和其他不可观察视觉输入。
- `body!`：首次挂载、自动 State 依赖写入或 revision 变化时执行的子树声明。

自动追踪只覆盖 body **内部**读取；在调用构造函数前求值的快照不会成为边界依赖。空 key 或重复 key 会抛出
参数/状态异常。边界命中时，嵌套 `rememberState` 仍被视为已挂载；
该命中操作与后代数量无关。边界卸载后状态、effect 与绘制命令一起释放；若根构建在边界重建后失败，新的子树和所有权
变化会被取消，先前已提交的 revision、子树与嵌套状态保持有效。

框架会在绘制期调用请求续帧、读取焦点/悬停/按压/拖拽状态，或登记 tooltip、IME、overlay 时自动绕过当前及
祖先的命令缓存，并把原因写入 retained diagnostics，避免冻结动态协议。检测到动态绘制后先直接绘制 32 帧，
再次探测仍动态则把窗口指数扩大、上限 256 帧；State/revision/几何失效会立即清零退避并重试。因此稳定动态
区域不会每帧承担“先录制再丢弃”的成本，动态条件变静态后又能重新获得缓存。直接绘制期间仍收集 paint State
依赖，不牺牲失效正确性。直接读取自定义可变字段无法被自动侦测；
这类绘制必须以 State/revision 表达依赖，或不要启用 `cachePaint`。

桌面宿主会把局部 State 失效累积为 damage，并只重放与区域相交的干净命令边界。输入、动画/Frame 订阅、浮层、
交互状态、窗口变化、root build/layout/paint State 依赖、超过视口 70% 的 damage 或后端拒绝都会保守回退全帧。
内置控件按布局框外扩 16 逻辑像素覆盖阴影；自定义 Canvas 若绘制越界更远，应扩大实际布局/边界或关闭该 paint
缓存，否则局部更新无法知道额外的旧像素范围。

## 方法

### cacheStats

```cangjie
public func cacheStats(): RetainedSubtreeStats
```

返回当前身份累计的构建、布局与绘制命中数，供诊断和性能测试使用。

## 示例

```cangjie
RetainedSubtree("summary") {
    summaryView(model.snapshot.value) // 自动登记为 build 依赖
}
```

详见[保留昂贵子树并建立帧级测试](../../../guide/how-to/retain-and-test.md)。
