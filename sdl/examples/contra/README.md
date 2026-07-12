# Neon Commando：骨骼动画横版动作射击示例

`Neon Commando` 是一个向经典横版动作射击游戏致意的单关示例，也是一份面向教学的中型
仓颉与 SDL 工程范例。关卡包含高低平台、断桥、水域、步兵、炮台、无人机、扩散枪补给
与多弹幕 Boss；主角有五格生命，每次受击扣除一格，击毁终点的丛林核心即可通关。

## 演示要点

示例集中演示两处在小型样例中不常见的工程内容：

1. 轻量 2D 骨骼动画：主角不使用逐帧整身贴图，而由项目内置的骨骼运行时，以脊柱自由度、
   四肢解析式 IK、线性混合蒙皮与关节交叉淡化，统一驱动奔跑、腾空、落地、下蹲、翻转与
   连续瞄准。
2. 分层的多子包工程结构：约 2500 行代码按职责拆成 7 个仓颉包，依赖单向流动，演示如何
   组织一个避免单文件承载全部逻辑的游戏项目。

定步长帧循环、按键持续状态与集中配置沿用示例集通用的结构约定（见
[示例总览](../README.md#通用模式)），后文重点讲解本示例特有的分层架构与骨骼动画。

## 构建与运行

```powershell
cjpm build
cjpm run
```

运行时需要 `SDL3.dll` 与 `SDL3_ttf.dll`，部署方式见 [示例总览](../README.md#运行时动态库)。

## 操作

| 动作 | 按键 |
|---|---|
| 移动 / 键盘八向瞄准 / 蹲下 | 方向键或 `WASD` |
| 键盘射击 | `K`（按住连射） |
| 跳跃 | 空格；起跳后快速连按可逐级跳得更高 |
| 鼠标瞄准与射击 | 移动鼠标连续瞄准，按住左键连射 |
| 重新挑战 | 结算界面按 `Enter` 或 `R` |
| 退出 | `Esc` |

键盘方向可与 `K` 组合，实现向上、斜向与空中向下射击；蹲下时按住 `W`（可再叠加左右方向）
即为蹲姿斜上或竖直射击。反向移动时，身体、双臂与枪械在同一帧完成翻身。鼠标模式下，
枪械以骨架握点为旋转轴连续转动，双手通过 IK 分别锁定握把与护木；按住 `S` 蹲下不会中断
鼠标瞄准，可保持任意角度蹲姿射击。绿色 `S` 补给会将步枪升级为三向扩散枪。

## 工程结构：分层子包

代码按依赖层次拆成 7 个包。依赖只能自上而下（上层可用下层，下层绝不反向依赖），
因此不存在循环包依赖，每一层都能单独理解与替换。

```
  contra            (根/应用外壳)  main、帧循环、键鼠事件
      │  依赖 ↓
  contra.render     场景渲染         入口 view、环境、实体、主角、蒙皮、HUD、资源
  contra.sim        世界模拟         update、玩家、敌人、特效、碰撞结算
      │
  contra.rig        骨骼动画运行时    pose、脊柱、腿、臂(每帧解出一副 HeroSkeleton)
      │
  contra.model      实体与世界        实体数据、GameState、关卡编队、种类判定
      │
  contra.config     集中调参 + 调色板   ┐  两个无游戏依赖的叶子包
  contra.geom       2D 数学 + 骨骼原语 + IK ┘  (geom 可原样复用到其他项目)
```

| 包 / 文件 | 职责 |
|---|---|
| `contra` · `main.cj` | 窗口创建与资源生命周期 |
| `contra` · `loop.cj` | 定步长帧循环、键鼠事件到输入状态的转换 |
| `contra.config` | 画布/角色/敌人/特效/HUD 的全部调参与像素调色板 |
| `contra.geom` | 插值/角度、向量/AABB、骨骼原语与关节工具、双骨解析 IK |
| `contra.model` | 枚举与种类判定、实体数据袋、世界状态与关卡编队 |
| `contra.rig` | 顶层编排、脊柱姿态、双腿 IK 与步态、双臂 IK 与持枪约束 |
| `contra.sim` | 逐帧模拟入口、玩家物理与战斗、敌人 AI、镜头/子弹/粒子、碰撞结算 |
| `contra.render` | 渲染入口与坐标工具、场景、实体、主角分层、四肢蒙皮、HUD、纹理资源 |
| `assets/commando_parts_v2.png` | 主角躯干、四肢、战靴和装饰透明分层图集 |
| `assets/commando_hands.png` | 扳机手、护木手及后坐力姿态透明图集 |

### 跨子包可见性

顶层声明默认只在本包及其子包内可见（`internal`）。本示例是单模块可执行程序，包之间
是兄弟关系，因此凡是被其他包用到的类型、函数、字段乃至结构体的 `static let` 常量，都要
显式标注 `protected`（模块内可见）。这是将大工程拆包时需要注意的一点。

基础包 `contra.geom`、`contra.config` 对外符号几乎全为 `protected`，供上层广泛取用；越靠近
顶层编排的包，接口面越收窄：`contra.rig` 对外只暴露 `HeroSkeleton`、`evaluateHeroSkeleton`
与 `weaponMuzzlePoint`，`contra.sim` 只暴露逐帧入口 `update`，`contra.render` 也仅暴露绘制
入口 `draw` 与资源句柄 `GameAssets`。接口面越窄的包越易于理解与维护。

## 骨骼动画

主角不使用逐帧整身贴图。`contra.rig` 是一套轻量 2D 骨骼动画运行时，每帧从玩家的连续状态
（位置、速度、朝向、瞄准与各种融合权重）重新解算出一副骨架。骨骼数据模型是 `contra.geom`
中的四个原语：`RigPoint`、`RigBone`、`RigLimb` 与 `RigChain`。

### 每帧解出一副骨架

运行时不保留任何跨帧动画状态，也不依赖固定帧率，因此天然可插值、可镜像。顶层编排
`evaluateHeroSkeleton` 先解脊柱，挂上骨盆、腹、胸、头，再解双腿与双臂，最后组装成一副
`HeroSkeleton`：

```cangjie
protected func evaluateHeroSkeleton(player: Player): HeroSkeleton {
    let body = evaluateHeroBody(player)
    let pelvis = RigBone(body.hip, mirroredAngle(body.pelvisAngle, body.facing))
    let abdomen = RigBone(body.abdomenBase, mirroredAngle(body.abdomenAngle, body.facing))
    let chest = RigBone(body.chestBase, mirroredAngle(body.chestAngle, body.facing))
    let head = RigBone(body.neck, mirroredAngle(body.headAngle, body.facing))
    let rearLeg = evaluateHeroLeg(player, body, false)
    let frontLeg = evaluateHeroLeg(player, body, true)
    let arms = evaluateHeroArms(player, body)

    HeroSkeleton(
        body.facing,
        body.hip,
        pelvis,
        abdomen,
        chest,
        head,
        rearLeg,
        frontLeg,
        arms.rearArm,
        arms.frontArm,
        arms.weaponGrip
    )
}
```

一副 `HeroSkeleton` 由脊柱四段（骨盆、腹、胸、头）、双腿双臂四条骨链与一个握枪点组成，
渲染层只读不改。奔跑、腾空、下蹲、落地、翻身与连续瞄准都由这一套求值统一驱动。以下各节
依次说明双腿与双臂的 IK、四肢蒙皮的接缝融合，以及由脊柱统一完成的姿态、瞄准与手感。

### 双腿：IK 与步态

双腿使用髋—膝—踝双段 IK，并带独立的战靴末端。步态拆成 62% 支撑相与 38% 摆动相，并加入
脚跟到脚尖的滚动。奔跑相位由实际位移累积得到，不依赖世界坐标或固定帧率；步幅与抬脚高度
使用连续曲线，停步、转向与速度变化都不会跳帧。腾空时上升段双腿向臀下收拢，下落段前腿
前伸准备落地。

### 双臂：IK 与持枪约束

双臂使用肩—肘—腕双段 IK：前景手臂握住手枪式握把并扣扳机，后侧手臂跨过胸前、从枪管下方
托住前护木（上臂在躯干后、前臂在躯干前，构成真实的遮挡层级），翻身时保持相同的人体层级。
肩关节锚点对齐躯干贴图自带的三角肌，使前臂自然从肩窝长出而非贴在胸前；肘部极点跟随枪管
下侧，平射时双肘下垂、仰射时肘部前抬、俯射时收向身后。

枪托平射时贴住肩窝，仰俯角越陡越向体前滑出，以保证竖直向上或向下射击时枪身避开头部与
大腿。枪口火焰、视觉枪管末端与子弹出生点共享同一个经朝向修正的枪口约束，左右镜像完全
对称。

### 蒙皮与接缝融合

大腿/小腿与大臂/小臂采用 2D 线性混合蒙皮渲染（`sdl` 的 `texturedStrip`）：两段贴图沿共享
骨链铺设为三角条带，关节混合区内的顶点按 smoothstep 权重混合两根骨骼的刚体变换，并共享
同一宽度剖面。上下两段在膝/肘处各向对方延伸一段重叠带（纹理随之轻微拉伸），上段作不透明
底、下段在重叠带内以 smoothstep 渐入盖住。即便两段美术图接缝处明暗不连续，也被这条渐变带
混合抹平，肘膝呈连续圆角弯曲，没有刚体拼接的割裂、色调硬缝或穿模。

髋部同理处理刚性腰带与摆动大腿之间的接缝：腰带绘制后，把大腿顶部沿骨轴、以与主条带一致
的纹理映射重绘在腰带下沿，透明度自腰带下缘向上渐隐为 0，使大腿以柔边自然探入腰带下方；
腰带扣与弹袋位于渐隐区之上，不受影响。

### 姿态、瞄准与手感

头部、胸腔与腹部按不同权重跟随瞄准俯仰，蹲姿降低重心并加大前倾，瞄准动作由整条脊柱协同
完成。地面姿态采用前后脚错位、膝部微屈、骨盆稳定与胸腔前倾的战术警戒站姿；移动时加入
骨盆反向扭转与更低的重心。待机呼吸、步态重心、落地压缩、后坐力与头巾摆动均为连续参数
动画。

鼠标瞄准使用平滑响应与翻身滞回，避免指针掠过角色中心时左右抖动；键盘切向则采用同步响应，
消除躯干与武器翻转不同步。跳跃提供 110 ms 离地宽容与 120 ms 输入缓冲，同时保留快速连按
增高的机制。

## 关键实现

- 所有运动以秒为单位并截断异常长帧，速度不依赖显示器刷新率。
- 世界坐标与屏幕坐标分离（见 `render/view.cj` 的 `worldX`/`screenRect`），镜头平滑跟随并在
  Boss 区自动锁定。
- 角色判定框小于视觉轮廓，受击后有短暂无敌；跌落水域只扣一格生命，并从最近的检查点返回。
- 全部可调数值集中在 `contra.config`，不散写魔法数：更换配色只改 `palette.cj`，调整平衡只改
  `specs.cj`。
- 背景、主角、敌兵与枪械采用统一的半写实像素风格，轻量特效与 HUD 由代码实时绘制。

## 扩展方向

可按由小到大的顺序扩展：

1. 调参（只改 `contra.config`）：修改跳跃高度、扩散枪弹道角、敌人刷新密度，体会集中配置的
   作用。
2. 新增一种敌人：在 `contra.model` 的 `EnemyKind`/`enemySpec`/`enemyPoints` 加一档，在
   `contra.sim/foes.cj` 编写它的 AI，在 `contra.render/actors.cj` 绘制它，正好走一遍数据、
   逻辑、渲染三层。
3. 新增一个姿态：例如冲刺或翻滚，在 `contra.rig` 中为脊柱、腿、臂加一组目标姿态并用连续
   权重融合。
4. 复用 `contra.geom`：它不依赖任何游戏类型，可整包移植到其他项目作为 2D 骨骼与 IK 工具箱。
