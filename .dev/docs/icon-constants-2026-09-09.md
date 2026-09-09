# 预置图标常量接口迁移

2026-09-09：将全部 40 枚预置图标统一为 `public let ICON_*: IconSource`，移除旧工厂函数。
单图标子包、SVG 数据、资源身份复用、渲染模式和按需链接边界保持不变。

## 使用与迁移

导入 `cui.symbols.clock.ICON_CLOCK`，直接使用 `Icon(ICON_CLOCK)`。
原来的 `clockIcon()` 对应 `ICON_CLOCK`，`chevronLeftIcon()` 对应 `ICON_CHEVRON_LEFT`；其他资源遵循同一命名规则。
这次不保留函数别名。完整声明见 [API 目录](../../docs/api/cui/symbols/index.md)，场景示例见[指南](../../docs/guide/how-to/preset-icons.md)。

公开值在包初始化时创建一次，不读取图像文件、解码或创建纹理。读取常量不会重新复制 SVG。
`let` 不可重新赋值，`IconSource` 本身也不暴露可变资源数据；它不是仓颉的编译期 `const`。
组件上的样式设置及 `withRenderingMode` 不会修改这份全局资源。

## 代码与文档

- DatePicker、TimePicker 和使用预置资源的案例均直接引用常量。
- `examples/symbols`、`examples/icons`、`examples/calendar` 已迁移；booking、scheduler 继续通过日期时间组件间接使用资源。
- 40 个 API 页面改为 `values.md`，明确公开名称、类型、只读性和初始化时机。
- 文档门禁新增公开包级值的声明、索引、再导出与过期条目检查。
- 静态链接门禁直接读取常量，并加入编译器拒绝重新赋值的负向案例；错误类型和超时不能冒充该案例通过。

## 链接边界

仍按独立子包裁剪，`cui.*` 不全量再导出图标。精确导入一枚资源不会带入其他图形数据。
兼容的 `cui.*`／controls 依赖链仍会因为 DatePicker、TimePicker 引入 calendar 与 clock 两枚资源，具体边界见使用指南。

## 验证记录

本次报告和日志位于 `target/dev/icon-constants/`；静态链接程序、命令、日志与哈希位于 `target/dev/symbol-linking/`。
修改前构建及 994 项库测试通过。40 份 SVG 数据在迁移前后的 SHA-256 一致。
迁移后的 media、controls、symbols 相关测试 247/247 通过；开发工具自测 105/105 通过。

最终完整构建与 994/994 库测试通过，同一测试产物的独立重跑也通过。144 个完整文档程序编译通过，350 个 Markdown 文件的链接与 API 覆盖检查通过。
L2 内置质量检查为 0 ERROR／0 WARN，与修改前基线比较无新增结果。

43 个静态程序分别覆盖无图标、40 个单图标、全量和兼容总包，均启动成功且图形包含集合正确。
负向编译得到 `cannot assign to immutable value`，确认公开值不能重新赋值；验证器同时要求编译非零退出、特定错误信息和目标名称，排除缺包或超时等无关失败。

| 程序 | 常量接口 EXE 字节数 | 实际包含的图形 |
|---|---:|---|
| 无预置图标的精确导入 | 8,701,952 | 无 |
| 只导入 ICON_CLOCK | 8,708,096 | clock |
| 全部 40 枚 | 8,870,400 | 全部 40 枚 |
| 兼容 cui.* | 10,807,296 | calendar、clock |

这是 Windows x64／Cangjie 1.0.5 的实际静态构建结果，数字包含公共依赖，受节对齐影响，不包含外部 SDL DLL。
公共 `let` 没有改变单图标子包的排除效果；其他平台和链接策略仍应重新运行门禁。

symbols、icons、calendar、booking、scheduler 五个示例均重新编译并实际截图。
symbols、icons、booking、scheduler 的已有示例测试共 15/15 通过；calendar 原项目没有单元测试，通过应用构建和两类像素对照验证，其图标按钮交互另由库测试覆盖。
每个示例同时比较增量／完整绘制以及迁移前／迁移后图像，十组对照均在零容差下逐像素一致；现有截图无需替换。
示例复验复用同一发布静态库，通过 `cjc --test` 运行各自测试，然后直接编译和启动应用，命令与日志保存在 `examples/` 报告目录中。

全仓外部 cjfmt／cjlint 仍报告 2100 条建议，与内置检查分开统计。图标相关提示涉及 ICON_* 命名、包级资源作用域和 SVG 命名空间：
大写命名是本次明确要求，公开包级只读值是这次接口契约，SVG 命名空间不是网络端点。未增加规则关闭或扩大豁免；既有的精确命名空间说明保持不变。

复验过程曾把 PNG 传给只读取 BMP 的像素比较器；已改用保存的原始 BMP 参考图，重新完成全部五个示例对照，没有放宽容差。

初始预置图标功能的历史记录见[原交付报告](preset-icons-2026-09-09.md)。
