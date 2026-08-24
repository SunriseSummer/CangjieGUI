# fonts：本地字体文件加载

一张字体样本册，集中演示从本地字体文件加载字体：`Fonts.register(name, path)` 登记字体名到文件路径，
再由 `Label.fontFamily(name)` 按名套用。示例加载一款衬线（Georgia）与一款等宽（Consolas），与系统默认
无衬线字体并列对照；可切换大样张所用字体并叠加粗体。找不到文件的字体运行时自动回退系统字体。

## 演示要点

- `Fonts.register(name, path)` 从本地字体文件加载：衬线、等宽各挑第一个存在的候选文件登记
- `Label.fontFamily(name)` 按注册名渲染；同一样张在三种字体下并列，字形差异一目了然
- 字体名与字体样式叠加：`SegmentedControl` 选字体、`Chip` 叠加粗体，加载字体也能加粗（打开该文件的粗体变体）
- 字体选择器按最长标签取得自然宽度；窗口变窄时各段独立省略、裁剪，不与相邻标签叠画
- 宽容回退：未注册的名称或打不开的字体文件自动回退系统 UI 字体，不报错（样本册标注实际路径或回退提示）
- 字体名解析（挑第一个存在的候选）与选中项到字体名的映射都是纯函数，存在性以谓词注入，便于单测

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口；解析并注册字体（`firstExisting` + `FileSystem.exists`） |
| [data.cj](src/data.cj) | `TypeFace` 类型、跨平台字体候选、字体解析与选中映射（纯函数） |
| [model.cj](src/model.cj) | `FontsModel`：选中字体、粗体开关；当前字体名派生 |
| [views.cj](src/views.cj) | 标题、字体样本册、字体选择器 + 粗体开关、大样张 |
| [theme.cj](src/theme.cj) | 浅色主题（石青强调） |

## 关键实现

### 从本地文件注册字体

每种字体给出跨平台候选路径，挑第一个存在的文件登记；`Fonts.register` 只登记映射，运行时首用才真正打开：

```cangjie
if (let Some(path) <- firstExisting(face.candidates, {p => FileSystem.exists(p)})) {
    Fonts.register(family, path)
}
```

### 按名套用与宽容回退

视图以 `Label.fontFamily(name)` 按名渲染；名称未注册或文件打不开时，渲染层回退系统字体，界面不受影响：

```cangjie
Label(SPECIMEN).fontFamily("demo-serif")   // 加载成功则用 Georgia，否则回退系统字体
```

## 关于 CJK

示例加载的 Georgia / Consolas 是拉丁字体，不含 CJK 字形，故样张用拉丁文以专注对比衬线、等宽与无衬线的
字形；中文覆盖仍由系统字体承担（界面标签即是）。要在中文场景换字体，请注册含 CJK 的字体文件。

## 运行

```powershell
cd examples/fonts
cjpm run
```

用分段控件切换样张字体、`粗体` 开关叠加加粗。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot fonts.bmp"
```
