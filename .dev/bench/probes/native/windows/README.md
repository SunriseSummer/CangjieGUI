# SDL_GPU 原生 MSAA 可行性探针

这个 Windows-only 探针回答一个窄问题：在当前高 DPI 瓶颈尺寸上，SDL_GPU/D3D12 的原生 4× MSAA
加硬件 resolve，是否有资格继续做真实 CUI 场景原型。它不替换生产 Renderer，也不把 clear-only 结果外推为
完整 UI 收益。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .dev/bench/probes/native/windows/build_sdl_gpu_msaa_probe.ps1 -Run
```

脚本以固定 SHA-256 下载并验证 SDL 3.4.12 官方源码头文件，用同版本
`../CangjieSDL/.sdl3/SDL3.dll` 动态解析 ABI，严格 C++20/Werror 构建后运行。默认工作集来自 planner 的
3780×2430 物理输出：D3D11 侧创建 7560×4860 单采样目标并线性缩小，SDL_GPU 侧创建
3780×2430×4-sample 目标并以 `SDL_GPU_STOREOP_RESOLVE` 直接解析到交换链；两侧名义覆盖均为
36,741,600 个样本。交换链显式使用 `IMMEDIATE`，否则默认 present 节拍会把 GPU 侧锁到显示器刷新周期，
形成无效 A/B。

每个 repeat 运行 ABBA，下一 repeat 反转为 BAAB；默认三轮、每批 30 帧预热和 180 帧测量。每批保存提交
mean/P50/P95/max、最终 GPU 排空和把排空摊入后的完整帧均值。必须同时满足：完整帧中位至少快 1.25×，且
GPU 提交 P95 不差于 SSAA，才晋级真实场景原型。机器记录写入
`target/bench/results/sdl-gpu-msaa-probe.json`。

探针每批都新建并按 `texture → window claim → device → window` 的逆所有权顺序释放资源；交替批次也因此兼作
设备/交换链重建压力。仍须注意：clear 可能使用驱动 fast-clear，探针没有着色器、几何、clip、纹理上传、
文本 atlas 或 blend。通过只证明 resolve/present 下界值得投资下一阶段，不证明生产迁移。

## 代表性值命令流

第二阶段用同一份只含值的场景 IR 驱动两侧：73 个保持顺序的 material/clip packet、7728 个顶点，覆盖纯色
三角形、圆形边缘、scissor、straight-alpha blend，以及模拟 glyph atlas 的线性采样纹理。SDL_GPU 侧直接复用
固定 SDL 3.4.12 源码包内官方 DXIL 和公开 pipeline ABI；shader 字节不复制进仓库，也不引入 DXC。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .dev/bench/probes/native/windows/build_sdl_gpu_scene_probe.ps1 -Run
```

探针在计时外分别读回两侧像素，转换为 RGBA 后检查内容覆盖、通道 MAE 和大差异像素比例，防止空帧或错误
blend 伪造性能。需要人工审图时可直接运行目标程序并传
`--dump-prefix target/bench/results/scene`，它会生成两张 PPM。机器记录写入
`target/bench/results/sdl-gpu-scene-probe.json`。

3780×2430 下两个独立进程、每侧各六批的完整帧中位为 3.570/3.608 ms 与 3.578/3.544 ms
（D3D11 ss2 / SDL_GPU msaa4）；一轮 GPU 慢 1.1%，另一轮快 0.9%，没有可辨认收益。GPU 提交 P95 则从
4.041/4.168 ms 变为 4.407/4.318 ms，两轮分别退化约 9.0%/3.6%。像素验证为 MAE 0.0416、超过 16 灰阶
的像素 0.0528%，两侧非背景覆盖都为 63.8707%，所以结果不是漏画。低分辨率 640×400 下 GPU 固定开销也
明确更高。

因此 clear-only 下界的约 1.34× 没有推广到有代表性的命令解释；真实 draw/pipeline/scissor/采样开销抵消了
硬件 resolve 收益。代表性门槛要求“至少 1.15× 或绝对 1 ms、P95 不退化、像素验证通过”，当前明确失败。
决策是不建设生产 SDL_GPU 后端、不扩张 Cangjie FFI/纹理/文本所有权；保留探针作为以后硬件、SDL 或驱动
发生实质变化时的可重复反证入口。
