# 窗口启动画面修复 · 2026-09-06

## 原因

原先 `DesktopApp → SdlWindow` 使用默认可见窗口。当前 SDL 3.4.12 的 `SDL_CreateWindowAndRenderer` 在内部完成渲染器创建后显示窗口；此后仓颉层才初始化文字引擎、解析字体，并进入首次构建、布局和绘制。窗口可见与有效 UI 首帧之间存在空档，字体初始化或首次布局较慢时尤其明显。

此时客户区尚无应用提交的完整画面，可能显示黑色、背景残影或异常边线。启动可见性回归在原实现上明确失败：构造返回和首帧绘制期间窗口已经可见。代码中未发现主动绘制黑白启动测试图案的路径。

此外，初始窗口按传入的应用缩放创建，随后才查询系统 DPI 并调用 `SDL_SetWindowSize`。旧流程在可见状态下做这次修正；本机字体示例采样记录到客户区由 840×880 变为 1890×1980，最早画面还没有正常 UI。修复将该尺寸调整也移到首次显示之前。

核对来源：[SDL 3.4.12 创建窗口与渲染器的实现](https://github.com/libsdl-org/SDL/blob/release-3.4.12/src/render/SDL_render.c)、[SDL_RenderPresent 的缓冲契约](https://wiki.libsdl.org/SDL3/SDL_RenderPresent)。

## 修改

- CangjieSDL 的 `SdlWindow` 增加兼容的可选参数 `hidden!: Bool = false`，直接控制原生创建标志；默认调用行为保持可见。隐藏窗口的 `present()` 不会擅自显示它，显示由 `show()` 明确控制。
- `DesktopApp` 使用隐藏创建，完整首帧成功 `present()` 后再显示。构造后尚未调用 `run` 的窗口不可见；首帧绘制抛错或已请求关闭时不会显示空窗口。
- 显示后请求一次重绘，使显示／曝光／DPI 变化能及时反映在 UI 中；随后的正常空闲等待与增量重绘继续工作。
- 补充 `SdlWindow` 的字体／Renderer 构造失败清理，释放尚未交付给调用方的原生窗口和渲染器。

这是通用宿主修复，使用 `DesktopApp` 的示例无需增加延时、重复清屏或手工隐藏窗口。启动所需的字体加载和布局耗时仍然存在，只在画面准备好后展示窗口。

## 验证

- 修改前：CUI 903 项、CangjieSDL 173 项测试通过，并保存严格 L2 基线；新增真实窗口测试复现提前显示。
- 修改后：两库 `--full --strict` 的构建与全量测试通过，CUI 903 项、CangjieSDL 175 项；严格 L2 均新增 0，未扩大检查豁免或关闭范围。
- 完整风格工具仍报告 CUI 1958、SDL 1288 条 WARN；两库 L2 逻辑检查均无 ERROR／WARN。风格结果与逻辑基线分别记录。
- 七个真实窗口场景连续两轮通过；直接渲染和 2× 超采样均验证构造／首帧隐藏、提交后可见、首帧绘制失败不显示。增量与完整重绘像素差为 0。
- 原增量重绘测试改为在首个可见帧后排队发布更新，避免将窗口显示产生的完整重绘误判为局部重绘退化；仍严格断言局部重绘与直接渲染回退路径。
- SDK 回归覆盖隐藏呈现、显式显示、再次隐藏后呈现，以及默认可见调用的兼容性。

- fonts、editor、typography 的构建／测试与真实窗口截图六项门禁全部通过；字体示例修复前后的稳定 BMP 像素差为 0。
- 修复后的字体示例首次可见采样已包含正常 UI，客户区从首次采样起即为最终 DPI 尺寸；可见区采样未发现黑屏。屏幕采样包含系统淡入动画，仅作为辅助观察，不替代原生可见性断言。
- 文档结构检查通过（CUI 237 篇、SDL 151 篇），全部 224 段文档程序编译通过（137 + 87）；桌面回归工具的 6 项 Python 单元测试通过。
- 两库 `git diff --check` 通过。

本机日志位于 `target/dev/startup-quality/`：`reproduce-run.log` 保存原实现的失败标记，`*-after-full.log`、`*-after-l2.log`、`*-snippets.log` 保存质量与编译结果，`desktop-after-report.json`、`examples-after-report.json` 保存真实窗口验收。`fonts-before/`、`fonts-after/` 保存启动观察与稳定帧。

本轮实机验证平台为 Windows。Linux/macOS 使用同一 SDL 隐藏创建与显式显示接口，仍需各自窗口系统的首帧实机验收。

接口说明：[SdlWindow](../../../CangjieSDL/docs/api/sdl/SdlWindow.md)、[DesktopApp](../../docs/api/cui/desktop/DesktopApp.md)。
