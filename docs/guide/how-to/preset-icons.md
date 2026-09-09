# 按需使用预置图标

CUI 提供 40 枚原创线框图标，覆盖导航、文件操作、日期时间、状态提示等日常场景。
SVG 数据直接写在 `.cj` 源码中；运行时没有图标文件、字体文件或资源目录依赖。
完整目录见 [cui.symbols](../../api/cui/symbols/index.md)，真实截图与交互演示见[预置图标图鉴](../../../examples/symbols/README.md)。

## 导入与使用

每个图标通过自己的子包导入。每个 `public let ICON_*` 都是普通 `IconSource` 值，适用于 Icon、IconButton、RichSpan、TreeNode 和自绘的 paintIcon。

```cangjie verify
package docexample
import cui.core.{HStack, LengthUnits}
import cui.desktop.DesktopApp
import cui.media.{Icon, IconButton}
import cui.symbols.calendar.ICON_CALENDAR
import cui.symbols.clock.ICON_CLOCK
import cui.{Color, WindowSpec}

main(): Unit {
    let app = DesktopApp(WindowSpec("Embedded icons", 480, 220))
    app.run {
        HStack(spacing: 16.vp) {
            Icon(ICON_CALENDAR).iconSize(24.vp).foregroundColor(Color.rgb(30, 120, 110))
            IconButton(ICON_CLOCK, label: "时间", onClick: {=> println("time")})
        }.padding(24.vp)
    }
}
```

可以直接在构建函数中读取常量：每次访问保持同一份不可变资源身份，不重新复制 SVG 字节。
`public let` 禁止重新赋值，`IconSource` 也不暴露可变资源数据。它在包初始化时创建，不属于仓颉编译期 `const`。
组件样式和 `withRenderingMode` 派生出的描述不会改写全局常量。
这与反复调用 `IconSource.memory` 不同。每个已导入图标的资源描述只初始化一次，首次绘制／预加载才解码并创建纹理。
初始化不要求 SDL 窗口已经存在。常量不持有 GPU 对象，继续遵循图像缓存的 UI 线程规则。

## 静态链接边界

**按需的单位是独立子包。** 图标不在 `cui.*` 或 `cui.symbols.*` 中汇总再导出，也没有运行时图标名称枚举、全量表或启动注册。
精确导入 `cui.symbols.search.ICON_SEARCH`，只需要 search 的图形数据。不要为了方便再创建导入全部图标的业务总包。

Windows Cangjie 1.0.5 的实测表明：同一包的不同文件、不同函数，甚至只经总包再导出，均可能把未调用图标的数据带入程序。
因此不能把源码拆文件、惰性创建或 `-O2` 当作链接裁剪保证。本实现采用单图标单包，使用默认静态链接，不要求 LTO 或特殊链接参数。

`DatePicker` 和 `TimePicker` 已恢复日历、时钟图标，因此 `cui.controls`、依赖它的包以及保留兼容性的 `cui.*` 会间接引用这两枚资源。
它们不会带入其余 38 枚。需要没有任何预置图标的最小程序时，直接导入 `cui.core`、`cui.media` 等实际需要的包，并避免引入 controls 的依赖链。
显式或间接导入均算作链接依赖；此机制不是对聚合包内部所有未调用控件进行跨包消除。

维护者可用 `python .dev/cli.py check symbol-linking` 验证独立导入和聚合导入实际包含的资源集合，以及公开值不可重新赋值的约束。
字节数受节对齐及公共依赖影响，不能仅用大小差判断资源是否排除。
此处的静态裁剪不涵盖主动链接完整动态 GUI 库或 `whole-archive`；更换平台／编译器后应重跑门禁。

## 外观与尺寸

所有图标使用透明背景、24 × 24 网格、1.75 单位描边、圆头与圆角连接。建议常规按钮使用 20／24 vp，密集工具栏使用 16／20 vp，
独立展示使用 32／48 vp。16 vp 当前使用统一稿按尺寸栅格化，并非独立光学校正版；非常密集的界面应检查细节清晰度。

默认 Template 模式把 Alpha 当作形状，颜色由前景色或按钮角色决定，深色背景同样可用。
预置 SVG 的黑色仅表示形状，不限制最终颜色。`iconOpacity`、`IconStyle` 的采样与镜像同样生效。
不要给每种主题重新拼接 SVG；颜色不参与模板纹理缓存键。默认线性采样适合这套矢量资源。

图标按实际渲染尺寸和 DPI 生成纹理，缓存失效后重新生成；它们不是每帧重新解析的 SVG，也不是 GPU 上直接绘制路径。
`preloadIcon`、`invalidateIcon`、资源失败与关闭行为均沿用[图标组件指南](icons.md)。

```cangjie verify
package docexample
import cui.core.{HStack, LengthUnits}
import cui.desktop.DesktopApp
import cui.media.{Icon, IconStyle}
import cui.symbols.arrow_right.ICON_ARROW_RIGHT
import cui.{Color, TextureFlip, WindowSpec}

main(): Unit {
    let app = DesktopApp(WindowSpec("Symbol styling", 480, 220))
    app.run {
        HStack(spacing: 16.vp) {
            Icon(ICON_ARROW_RIGHT).iconSize(32.vp).foregroundColor(Color.rgb(30, 120, 110))
            Icon(ICON_ARROW_RIGHT, style: IconStyle(size: 32.vp, flip: TextureFlip.Horizontal))
                .iconOpacity(0.4)
        }.padding(24.vp)
    }
}
```

## 维护与许可

图案为本项目原创，遵循仓库 MIT 许可证，无第三方图标字体或素材依赖。
新增图标时添加独立子包，并同步 API 目录、symbols 包的测试资源清单和图鉴示例；不得加入会导入全量资源的公共集合。
单资源包内保留一段自包含的静态 SVG 图形文本，限制在当前 SDL3_image 已验证的基本 SVG 子集。
当前没有动画、CSS、外部链接或字体依赖。


## 从函数接口迁移

导入路径中的子包保持不变，导出名称统一为 `ICON_` 加大写下划线名称；使用处删除调用括号。
例如原来的 `clockIcon()` 改为 `ICON_CLOCK`，`chevronLeftIcon()` 改为 `ICON_CHEVRON_LEFT`。
旧工厂函数已移除，不保留双套入口。完整名称见上方 API 目录。
