# Windows 交付质量审计（2026-09-06）

> 历史记录：本文保留当时的实现及测量结果。2026-09-07 后续字体迁移已改用官方 SDL_ttf 和仓颉实现，原生扩展及其构建要求已移除；当前使用契约见[字体指南](../../docs/guide/how-to/fonts-and-typography.md)。

**Windows 本机回归已通过；正式商用发布仍需完成文末清单。原生线程迁移已通过自动绑定修复，并完成 20 轮压力复核。**

本轮以 Windows x86_64、仓颉 1.0.5、当前配套 CangjieSDL 为验收对象。目标是常规桌面业务应用的交付候选；Linux／macOS、复杂双向编辑、完整屏幕阅读器支持和正式安装包分别验收。目前不能把框架标为所有平台均可正式商用。

## 已修复的问题

| 范围 | 原因及修复 | 验证 |
|---|---|---|
| 静止表格持续失效 | Table 绘制时重复写 State；滚动校正改在布局中仅按变化写入 | 修复前失败，修复后连续绘制不增加调度代数 |
| 自定义单元格异常 | 裁剪栈缺少异常恢复；所有表格裁剪区域使用 finally 成对退出 | 单元格抛错后外层裁剪保持原样 |
| 首帧／缩放后局部绘制 | 提前准备文本时已经分配超采样纹理，但尚未初始化；单独跟踪目标内容有效性 | 首次与调整尺寸后强制完整清屏，后续才接受局部保留 |
| 原生线程与窗口寿命 | 仓颉线程 ID 无法识别底层 OS 线程迁移；建窗前自动绑定仓颉线程与原生线程，多窗口共享计数，最后关闭时释放；原生入口保留线程检查，wake 与 close 互斥，构造失败统一回滚 | 关闭后／跨线程调用负向测试、真实窗口唤醒、资源清理；对话框父窗口检查也在分配异步请求之前执行 |
| 重复资源清理 | 内部 Renderer 释放接口声明幂等但重复释放会抛错；分离线程身份与资源存活检查，资源释放后窗口仍能销毁 | headless 重复释放、原生窗口先释放渲染资源再关闭 |
| 后台消息洪峰 | 无界队列与一次性排空会积压内存或饿死绘制；默认容量 4096，每次最多执行 256 项，合并唤醒 | 10,000 次后台投递、20,000 次连锁投递，绘制继续且队列不越界 |
| 关闭确认 | 统一系统关窗与应用请求，支持延后、取消、接受；重复请求合并，停止后旧决定失效 | 取消后重试、重复完成、处理器异常、单次清理 |
| 模态焦点与动作隔离 | 初始焦点、关闭恢复、嵌套打开者卸载后备，以及语义动作穿透背景 | 焦点与无障碍动作集成测试，保留禁用动作约束 |
| 数值边界 | Slider 构造与 range 的顺序不一致，NaN／极小步长会异常转换；窗口尺寸缩放可能溢出 | 反向范围、NaN、极小步长、非法窗口尺寸及缩放回归 |
| 交付验收污染 | 开发机 PATH／库路径可能为缺失 DLL 提供兜底；运行时移除这些路径 | 直接启动独立临时目录中的程序；记录运行库与两仓库有效工作树 SHA-256 |

SDK 基线曾出现 175 项中 1 项唤醒测试超时。独立实验复现了 `Future.get()` 等待后原生线程迁移（100 次等待出现 1 次），证明原有线程检查不完整；这不是对原始超时唯一原因的原生堆栈证明。随后更严格的五轮消息压力复核在第 5 轮再次触发原生线程迁移检查，证明仅靠检查和避免 Future.get 不足以保证归属。最终使用仓颉 1.0.5 运行时已导出的 `CJ_BindOSThread`／`CJ_UnbindOSThread`：窗口自动持有可共享的绑定，覆盖锁等待与调度迁移；1,000 次 Future 等待、多窗口、构造失败及 20 轮压力均通过。原始失败保存在 `native-migration-under-post-pressure.log`。

## 接口与行为迁移

- `DesktopApp(..., maxPendingPosts: 4096)`、`postStats()`、`setCloseRequestHandler()`、`requestClose()`，以及 `CloseRequest`／`DesktopPostStats` 为新增接口。
- `post == false` 现在保证未入队；唤醒失败但已接收时返回 true，并累加诊断。接收不等于完成，退出仍会丢弃等待动作。
- Modal 新增 `initialFocus`、`dismissOnEscape`、`dismissOnBackdrop`；默认自动聚焦第一个内部焦点项，因此首次 Tab 会前进到下一个项。
- SDL 窗口和 Renderer 的原生线程／释放状态检查更严格；不要在 UI 线程阻塞等待 Future。非法数值配置明确抛错，替代迟发的绘制或转换异常。
- 编辑器菜单与关闭框使用“内存检查点”文案，示例没有磁盘保存。真实应用只应在持久化成功后接受关闭请求。

见[生命周期指南](../../docs/guide/how-to/desktop-lifecycle.md)、[DesktopApp](../../docs/api/cui/desktop/DesktopApp.md)、[Modal](../../docs/api/cui/controls/Modal.md) 和 [editor](../../examples/editor/README.md)。已有字体、文本编辑和首帧修复全部保留。

## 本机验收结果

- CUI 917/917、SDK 187/187 测试通过，构建通过。
- 两库 L2 内置检查均无 ERROR／WARN，对修改前基线新增 0（保留 25／14 项 INFO）。
- 138 个文档程序编译通过，93 项开发工具测试通过；API 文档覆盖及链接检查通过。
- 48/48 个独立示例测试通过，完整记录见 `target/dev/examples/report.json`。
- 自动绑定修复后，20 轮 × 8 个真实窗口场景全部通过；包含 200,000 次后台投递尝试、400,000 次连锁动作，保留／全量绘制像素差为 0。
- 独立 Windows UIA 客户端通过：属性查询 P50 0.161 ms，Invoke 往返 31.028 ms；这些是本次测量值，不是通用性能保证。

代表性示例的 8 对截图已按零容差独立复核；结果见 `target/dev/commercial-quality/smoke-pixels-final.json`。首次 smoke 编排触及本机设置的 20 分钟总限时，已完成 5 对截图；剩余 3 个示例单独完成构建、截图和全量对照，原始超时日志保留。并行编译期间，一次 SDK 像素测试超过临时 15 秒逐例上限；恢复正式验收的 60 秒逐例上限后 180 项通过，测试断言未改动。

## 可复核的验收入口

```text
cjpm build
cjpm test --no-progress --timeout-each 60s
python -X utf8 .dev/cli.py test tools
python -X utf8 .dev/cli.py check docs
python -X utf8 .dev/cli.py check snippets --timeout 900
python -X utf8 .dev/cli.py test examples --action test --jobs 4 --timeout 600
python -X utf8 .dev/cli.py test examples --action build --jobs 4 --timeout 600
python -X utf8 .dev/cli.py test examples --action test --jobs 2 --timeout 600 --smoke-snapshots --retained-diff
python -X utf8 .dev/cli.py test desktop --repeat 20 --build-timeout 600 --timeout 45
powershell -NoProfile -File .dev/platform/windows/check_uia.ps1
python -X utf8 .dev/cli.py release verify --build-timeout 600 --timeout 120
```

本机过程证据保存在 `target/dev/commercial-quality/`，包含修复前的失败样例与完整输出。最终隔离交付报告位于 `target/dev/release/windows-x86_64-delivery.json`：检查 `ok`、逐场景结果、像素差、二进制摘要及 `sources` 工作树清单；验收中源码改变会直接失败。严格质量门禁执行完整检查及 L2 与修改前基线比较，不扩大豁免。完整检查中的外部 cjlint／cjfmt 仍报告 GUI 1964 条、SDL 一千余条告警，以命名、声明及格式规则为主；并非零告警验收，也未对这些外部告警建立本轮修改前的完整基线。L2 内置检查与修改前基线独立比较。3 处测试变量初始化中出现的运行时 ABI 名称被 cj-prefix 误判为声明名，使用附理由的行级豁免；没有调整共享规则或基线。

隔离运行库验收仍运行在已安装系统字体及图形驱动的开发主机上，不等于干净虚拟机或全新机器验收。独立 UIA 客户端验证的是现有属性与 Invoke 通路，不代表完整 Text／RangeValue／Grid 模式或屏幕阅读器验收。

运行时绑定依赖已核对的仓颉 1.0.5 导出 ABI；升级工具链前必须重新验证。参见[对应运行时源码](https://gitcode.com/Cangjie/cangjie_runtime/tree/c6aa169ce8c6aaeb65cb1262bddb3700aebe8cb9)。由其它宿主预先绑定的线程会明确拒绝，SDK 不擅自释放宿主持有的绑定。

## 正式商用发布仍需完成

1. 将本次工作树固定为可取得的 GUI／SDL 配套提交或版本；CI 目前仍默认选择上游 main。现有便携构建计划会构建未加扩展的 SDL_ttf，必须接入配套字体补丁和 ABI 检查后才能宣称 Linux／macOS 可交付。
2. 建立目标业务的控件与无障碍验收矩阵。Switch／Slider／Table／TreeView 默认语义及 UIA 文本范围、范围值、表格模式尚不完整；Linux AT-SPI 与 macOS 原生桥未完成。
3. 在目标显卡、混合 DPI、输入法及干净机器上验收；补充数小时滚动／编辑／开关窗口的 RSS、句柄和显存趋势。短压力回归不能替代长期稳定性记录。
4. 形成安装、签名、升级回退及第三方运行库／字体许可材料清单。仓库已有两项目的 MIT LICENSE，但当前临时运行库验收目录并非包含完整许可材料的最终安装包。
5. 明确支持的语言与数据规模。复杂脚本／段落 bidi、跨样式 shaping、超大文档差量编辑、Table 稳定行身份与高级编辑仍是独立演进项目。

剩余项已按发布风险写入本地 `.todo/todo.md`。这些边界应随正式版本一起公开，不能由“单元测试全部通过”替代。
