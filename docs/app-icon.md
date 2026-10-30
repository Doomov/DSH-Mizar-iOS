# 应用图标与星标动画

手机和电脑是一个产品，所以是一个图标：`AGI Mizar` 桌面端 `crates/agi-app/icons/` 里的那颗星。
这个仓库不重画它，只把它变成 iOS 需要的样子，并把它变成能做动画的两层。

```
python3 scripts/make-app-icon.py             # AppIcon-1024.png / -dark.png ← 桌面端两个外观
python3 scripts/make-star-geometry.py        # 星形路径 + 灵动岛图标 + 动作胶片
python3 scripts/make-app-icon.py --check     # 只检查 PNG 是否与源一致
python3 scripts/make-star-geometry.py --check  # 只检查生成的 Swift 是否过期
```

`make-app-icon.py` 默认去工作区里找 `../AGI Mizar/crates/agi-app/icons/{icon,icon-dark}.png`；
`make-star-geometry.py` 的形状数据在脚本里（`LAYER_PROFILE`），`--trace 参考图.png` 可以从
一张单层参考图重新量出那张表。生成物都提交进仓库；脚本只在图标本身要改时跑。

## 1. 图标本体

| 平台 | 形状 | 为什么 |
|---|---|---|
| macOS（桌面端） | 1024 画布 + 824 圆角方块 + 透明外边距 | Dock / Finder / 启动台要这个网格 |
| iOS（本仓库） | 1024 **满幅、不透明、无圆角**，两个外观 | 系统自己裁圆角；App Store Connect 直接拒收带 alpha 的图标 |

`make-app-icon.py` 只做这件事：裁出 824 的方块、把 macOS 留下的四个透明角压成该外观的底色
（浅色白、深色黑）、按 Lanczos 放大到 1024、丢掉 alpha 通道。星本身的像素是桌面端的，没有被重画。

`AppIcon.appiconset/Contents.json` 里是**两个 1024**：一个默认（浅色），一个
`appearances: [{appearance: luminosity, value: dark}]`。iOS 18 起系统在深色模式下自己取后者；
桌面端本来就有 `icon-dark.png`（白星、黑底），所以这是同一套素材，不是另做一套。
着色（tinted）变体没有做：桌面端没有对应素材。

## 2. 星形：一层一条路径

图标是**两颗三臂星**相差 60° 叠出来的六臂星，所以动画不需要第二个素材：
`StarGeometry+Generated.swift` 里只有一条三臂路径，另一层就是这条路径转 60°。

形状的来源是**所有者给的那张单层参考图**，量成一张极坐标表 `LAYER_PROFILE`（离尖端每 5° 一个半径，
相对尖端半径 0…1），脚本按这张表采样（2.5°）、用 Catmull-Rom 转成三次曲线。三个要点：

- **凹口不是圆。** 半径一路掉到 60° 处的 0.247（尖端为 1.0）。早先这一版用 `icon-design/` 的 SVG，
  它是从**合成图**描的，用一段圆弧把每个缺口闭合成半径 0.328 的圆核 —— 两层叠起来那个圆核就是
  「中间一个球」，臂反而像长在球上。参考图里没有这个球，所以现在按参考图量。
- **单层路径在它的盒子里不居中**：三条臂朝上、左下、右下，盒子上边是顶点、下边是两条下臂。
  两层叠起来才居中，所以旋转中心是盒子中心，路径自己不去补偏移。
- 归一化成 `0...1` 的坐标：SwiftUI 的 `Path` 没有圆弧指令，也不需要 —— 全部是三次曲线。

`StarMotionTests` 钉住的是几何不变量（顶点半径 = `tipFraction`、左右对称、宽高比 2/√3、
两层合成后居中且竖长），不是像素；像素在快照里。

## 3. 两种动画

两种都只依赖四个数字，都在 `StarMetrics` 里，`DSH-MizarTests/StarMotionTests.swift` 钉住它们。

动作胶片（上排一次呼吸、下排一次 flick，逐帧）由 `make-star-geometry.py` 生成在工作区的
`../../docs/evidence/ios-star-motion-2026-10-30.png`：它是工作区级的证据文件，不在本仓库内，
但每次跑那个脚本都会重画一遍，所以和参数不会有出入。

### running —— 长时间等待

- 两层各自 360° / **9 秒**，方向相反、速度相同。
- 一层转 60°，两层就重新对齐一次，所以轮廓的呼吸周期是 **9 / 6 = 1.5 秒**：六芒 → 三芒 → 六芒。
- 线性循环，不用缓动：缓动循环每圈会「顿」一次，9 秒一次也很显眼。
- 360° 与 0° 在 120° 对称的层上是同一个姿势，所以循环接缝不可见。
- 用在：`Connecting…`（`LaunchingView`）、配对搜索、未配对首屏、未指定进度的同步窗，
  以及**所有「会话正在运行」的指示**（侧栏工作区、会话行、轮次摘要、轮次索引、子代理面板、
  连接面板的圆环里、`Running now` 胶囊里）。这些位置原来是 `TwinStar`（两个点互绕），
  现在统一成同一颗转动的星，尺寸按「墨宽」给（`MizarStar(ink:)`，14–17pt；两轮反馈后从 9–13 放大）。

### flick —— 短促的「被拨弄了一下」

- 前层 **+480°** / **1.00 秒**；后层 **−600°** / **1.55 秒**，晚 35 ms 出发。
- 两侧都从静止开始、加速、再减速到静止：缓动是 smootherstep（两端一阶二阶导都为 0），
  所以起步不抖、停住不噎。
- 角度都是 120° 的整数倍（4 圈、5 圈），因此**最后一帧正好是图标的姿势**，不是差两度。
- 后层转得更多、更久，两层不会同时停 —— 同时停就像一个刚体在整体旋转。
- 用在：设置页图标、首页问候、登录墙（92pt）。
- 用手指拨动两层的那一下是意图；参数上它和 running 共用同一套层与颜色，只是时间轴不同。

### opening —— 进度读数

- 后层相对前层从 −60°（两层重合，三臂星）开到 0°（图标，六臂星），`fraction` 就是进度。
- 下载完成时星正好拼成图标；这比一根进度条更像「历史正在到达」。
- 用在：配对后的首次全量下载（96pt）、刷新进度窗（56pt）。
- 它不是装饰，所以 Reduce Motion 下**仍然随进度变化**，只是不做额外转动。

### 颜色：三个平色，不渐变

| 外观 | 前层 | 后层 | 底 |
|---|---|---|---|
| 浅色 | `#0A78AE` | `#08608B` | 白（图标砖） |
| 深色 | 白 | 白 55% | 黑（图标砖） |

- 深浅只由后层一个色阶表示，前层是平的。**不能用径向渐变**：亮起来的中心会被后层衬成一个
  硬边圆盘，又变回那个球。这条写进了 `MizarStarPalette` 的文档注释。
- 深色模式下**所有**裸星（running / flick / opening）都是白色，不是强调色：深蓝在深色底上会沉下去。
  这是 `MizarStarPalette.automatic(for:)`，图标砖也走它（黑底白星 = 深色图标）。
- 图标砖（设置页头部）自己决定底：浅色白砖 + 蓝星，深色黑砖 + 白星；圆角 22.37%、星宽 64%
  都是图标的数。

### Reduce Motion 与性能

- `running` 停在图标姿势；`flick` 直接显示最后一帧；`opening` 跟随进度但用淡入淡出级的动画。
- 抽屉在动（`drawersStill == false`）时，`running` 也停在图标姿势：连续重绘的帧属于正在被拖的卡片。
- 每层是一条 ~145 段的三次路径（按 2.5° 采样），没有 blur、没有 shadow、没有 `drawingGroup`：
  旋转是图层的变换，不需要每帧重新三角化。

## 4. 图标出现在哪里

| 位置 | 代码 | 形态 |
|---|---|---|
| OS 图标 | `Assets.xcassets/AppIcon.appiconset` | 两个 PNG（浅色 / 深色） |
| 设置页头部 | `MizarIconTile(size: 64, motion: .flick)` | 图标砖 + 星，随外观换底 |
| 首页问候 | `MizarStar(motion: .flick, size: 64)` | 浅色蓝 / 深色白 |
| 登录墙 | `MizarStar(motion: .flick, size: 92, palette: .ink(.white))` | 白墨 |
| 连接中 / 配对 / 未配对 | `MizarStar(motion: .running, …)` | 圆环内或页面中央 |
| 同步（首次 / 刷新窗） | `MizarStar(motion: .opening(fraction))` | 图标色 |
| 会话运行指示 | `MizarStar(ink: 10…13, motion: .running)` | 随外观（深色白） |
| 灵动岛与实时活动 | `DSH-Mizar-LiveActivity/…/MizarIcon.imageset` | 白色模板，裁到星 |

**刷新控件不在这个表里**：侧栏和会话页的刷新键保持系统箭头（`arrow.clockwise`）+ 进度环 + 落定勾，
即 `RefreshGlyph` 原样，星标没有进去。

**灵动岛为什么是静态的一张图**：Live Activity 是系统在应用之外渲染的快照，不接受连续
自定义动画，也不链接应用里的 SwiftUI 形状；它的素材尺寸还有上限（素材分辨率不能超过
它被绘制的尺寸，否则系统可能拒绝启动这次活动）。所以那边只有图标本身，没有动画参数。
`MizarIcon` 是 32/64/96（32pt 框的三个倍率），已裁到星的外接框，不留设计盒的 14% 边距。

## 5. 测试

- `DSH-MizarTests/StarMotionTests.swift`：几何不变量（顶点半径、左右对称、宽高比 2/√3）、
  两层合成后居中且竖长、缓动端点静止且单调、呼吸 = 周期/6、flick 落在图标姿势、两层平均速度不同。
- `DSH-MizarTests/SnapshotTests/MizarStarSnapshotTests.swift`：静止 / 半开 / 白墨 / 深色四种姿势，
  加图标砖的浅色与深色两张，参考图在 `DSH-MizarTests/Snapshots/__Snapshots__/`。
- 动画本身无法断言（重复关键帧动画没有可步进的时钟），所以测的是「决定」而不是「效果」。
