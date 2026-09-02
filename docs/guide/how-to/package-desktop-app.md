<!-- kind: how-to; audience: desktop-app-developer; builds-on: first-window -->

# 打包能在目标机器启动的桌面应用

## 目标

在[第一个窗口](../getting-started/first-window.md)工程基础上，把可执行文件、SDL 运行库和应用资源放进干净交付目录，并做一次脱离源码树的启动检查。约需 20 分钟。

## 适用场景

把开发机上已经通过构建、交互和快照检查的 CUI 程序交给测试人员或最终用户。这里讲最小可移植目录，不代替操作系统安装包、签名或自动更新方案。

## 准备工作

确认目标机器的操作系统和处理器架构与构建产物一致。先在项目内运行首窗口，再找到 `cjpm build` 生成的可执行文件；SDL 动态库名称因平台不同，Windows 常见为 `SDL3.dll`，Linux 为对应的 `.so`。从源码构建 Windows 包时先运行 `.dev/platform/windows/build_uia.ps1` 生成同架构 UI Automation 桥。

## 操作步骤

### 1. 确定发布身份

在 `WindowSpec` 中设置稳定的窗口标题、尺寸和是否允许缩放。例如首窗口可使用标题 `CUI 计数器`、尺寸
`640 × 420`，并将 `resizable` 设为 `true`。版本号、构建号和许可证等信息放进交付清单，不要临时拼进界面文本。

### 2. 建立干净目录

交付目录至少包含可执行文件和匹配架构的 SDL 运行库。Windows 还要复制
`target/native/windows/<arch>/cui_uia.dll`；其源码位于 `platform/windows/accessibility/uia/`，由
`.dev/platform/windows/build_uia.ps1` 独立构建。框架在运行时动态加载 DLL，缺少时应用仍能启动，但原生
UI Automation provider 不可用。应用运行时读取的字体、图像或配置也按程序约定的相对路径复制。资源路径应集中定义，
例如把图标路径保存为 `assets/app-icon.bmp`，并以可执行文件所在目录为基准解析。不要把整个源码仓库、编译缓存和测试快照一起打包。

### 3. 脱离源码树冒烟

打开全新的终端，把当前目录切到交付目录，直接启动可执行文件。不要依赖项目根目录的 PATH 或相对文件。再运行一次 `--snapshot smoke.bmp`，确认动态库和资源在干净目录也能找到。

### 4. 记录平台边界

Windows 检查 SDL 与 `cui_uia.dll` 的架构、安全软件拦截，并用 Narrator/Inspect 或自动化客户端实际读取控件和执行一次动作；Linux 同时检查 SDL 及系统 PCRE2 等动态依赖，并在与目标发行版相近的环境验证。签名、安装位置权限、沙箱和文件对话框行为都属于平台测试，不能由开发机一次启动代替。

## 确认结果

源码目录不在 PATH 时，交付目录里的程序仍能打开、关闭并生成快照；缺少 SDL 时的失败可被明确复现，补回正确运行库后恢复。资源路径不依赖开发机绝对路径。交付清单记录操作系统、架构、构建类型、CUI 版本、运行库文件和人工交互结果。

## 常见错误

- 只复制可执行文件：目标机提示找不到 SDL 或 Windows UIA 动态库。
- 从项目根启动冒烟：程序悄悄读到源码树中的资源。
- 混用不同架构的 DLL：文件存在但加载失败。
- 把 `cjpm run` 成功当成交付验证：它仍处在开发环境中。

## 相关 API

[DesktopApp](../../api/cui/desktop/DesktopApp.md)、[CUI 包入口](../../api/cui/index.md)。

## 下一步

启动失败按[常见问题](../troubleshooting/common-problems.md)的环境分支排查，并把干净目录冒烟加入每次发布清单。
