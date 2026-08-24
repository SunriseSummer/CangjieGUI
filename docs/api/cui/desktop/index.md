[cui](../../index.md) › cui.desktop

# cui.desktop

```cangjie
import cui.desktop.*
```

桌面应用对象包：[`DesktopApp`](DesktopApp.md) 拥有 SDL 窗口与渲染循环，驱动事务式失效、分相 retained
执行、透明命令重放、保守局部 damage、事件后同帧一致性重建与绘制，并提供跨线程动作投递、资源管理、系统
文件对话框、基础光标与最小窗口尺寸等设施。空闲时阻塞等待事件或截止时间；`--snapshot`/`--profile` 与
retained 对照开关内置。

## 类型

**类**

| 类型 | 说明 |
|---|---|
| [`DesktopApp`](DesktopApp.md) | 桌面应用对象：拥有 SDL 窗口并运行帧循环——每帧从 [`run`](DesktopApp.md#run) 的界面构建函数重建组件树、布局、分发输入、绘制。 |
