# KeySoil (按键沃土) — 实现规划设计文档 v3

## 背景

KeySoil 是一款跨平台桌面陪伴应用。用户在正常使用键盘工作时，每一次按键都会转化为虚拟农场中的成长行为。应用通过透明悬浮窗口展示按**键盘配列排布的小型像素农场**——每个按键对应一块土壤，该按键被按下的频率直接影响对应土壤中作物的生长状态。

**核心理念**：打字即耕耘。常按的键作物茂盛，少用的键维持荒芜，键盘即农场。

项目需要提前准备完整的美术资源（键盘土壤纹理、四种作物精灵、宠物动画、金币/收获徽章等），以用于后续的开发过程。

**技术栈**：Electron + TypeScript + Canvas 2D + uiohook-napi + pnpm

---

## 1. 美术资源需求

以下为本项目所需的全部美术资源需求内容，原始美术资源素材应当存放在 `raw-assets/` 目录中，经过处理后输出到 `assets/` 目录。

### 1.1 键盘土壤纹理

这些是**键帽形状的土壤纹理**，直接决定了每个键位格的外观。同一阶段有不同宽度的变体以适应不同宽度的按键。

| 键宽 | 文件模式 | 尺寸 | 用途 |
|------|---------|------|------|
| 标准 (1×) | `key_soil_stage_{1-4}.png` | 627×627 | 普通字母/数字键 |
| 1.5× 宽 | `key_soil_stage_{1-4}_wide_1_5.png` | 941×627 | Tab、\| 等 |
| 2.2× 宽 | `key_soil_stage_{1-4}_wide_2_2.png` | 1379×627 | Caps、Shift、Return |
| 4.8× 宽 | `key_soil_stage_{1-4}_wide_4_8.png` | 3010×627 | Space 键 |
| 基准土 | `key_soil.png` | 1254×1254 | 基础/空白土壤 |
| 填充状态 | `key_soil_fill_stage_{1-4}.png` | 512×320 | 土壤肥沃度填充条 |

**土壤阶段含义**：
- Stage 1：干裂荒地（progress 0）
- Stage 2：开始湿润（progress < 34%）
- Stage 3：肥沃土壤（progress < 72%）
- Stage 4：最肥沃黑土（progress ≥ 72% 或成熟）

### 1.2 作物精灵

四种作物，每种 4 个生长阶段：

| 作物 | ID | 阶段文件 | 生长需求 | 售价 | 解锁价 |
|------|-----|---------|---------|------|-------|
| 小麦 🌾 | `wheat` | `wheat_stage_{1-4}.png` (320×320) | 24 键 | 8 金币 | 0（初始） |
| 番茄 🍅 | `tomato` | `tomato_stage_{1-4}.png` | 45 键 | 18 金币 | 50 金币 |
| 玉米 🌽 | `corn` | `corn_stage_{1-4}.png` | 75 键 | 35 金币 | 140 金币 |
| 草莓 🍓 | `strawberry` | `strawberry_stage_{1-4}.png` | 120 键 | 65 金币 | 320 金币 |

每个作物还有合并版本：`{crop}_stages.png`（4 阶段合并在单张图中）。

### 1.3 宠物动画

| 宠物 | 前缀 | 动画状态 |
|------|------|---------|
| 小狗 🐕 | `pet_dog` | idle, run_1~4, collect, rest, sleep, prone |
| 小猫 🐈 | `pet_cat` | idle, run_1~4, collect, rest |

宠物可在农场中巡逻，自动收获成熟作物（间隔约 24 秒）。

### 1.4 UI 与音效

| 资源 | 文件 | 尺寸 | 用途 |
|------|------|------|------|
| 金币 | `coin.png` | 256×256 | 货币图标 |
| 收获徽章 | `harvest_badge.png` | 256×256 | 收获成就 |
| 农场背景 | `farm_background.png` | 1586×992 | 全屏背景 |
| BGM | `bgm.mp3` | ~8.9MB | 背景音乐（可选） |

### 1.5 资源处理管线

准备好的素材为高清 PNG，需经后处理适配 Canvas 渲染：

```
原始素材 (如 627×627 PNG)
  │
  ▼
scripts/optimize-assets.ts  (使用 sharp)
  ├── 按需缩放到目标尺寸 (如键帽 ~120×120px, 作物 ~64×64px)
  ├── 可选：打包为精灵图集 (atlas.png + atlas.json)
  └── 输出到 assets/ 目录
```

此脚本作为构建前置步骤，源资源放置在 `raw-assets/` 中，由 pnpm 脚本调用。

---

## 2. 架构总览

```
┌──────────────────────────────────────────────────────────┐
│                     Main Process                         │
│                                                          │
│  ┌────────────────────┐   ┌──────────────────────────┐  │
│  │ KeyboardHook        │   │ OverlayWindow            │  │
│  │ (uiohook-napi)      │   │ - transparent             │  │
│  │ - keydown events    │   │ - alwaysOnTop             │  │
│  │ - 30ms throttle     │   │ - focusable: false        │  │
│  │ - keyCode→label     │   │ - skipTaskbar             │  │
│  │ - modifier detach   │   │ - ~900×700 or resizable   │  │
│  └─────────┬──────────┘   └─────────────┬────────────┘  │
│            │                             │               │
│            └─────────── IPC ─────────────┘               │
│   main → renderer: 'keystroke' {keyCode, timestamp}     │
│   main → renderer: 'settings-changed'                   │
│   renderer → main: 'get-settings', 'save-settings'      │
│   renderer → main: 'harvest-animation'                  │
│                                                          │
│  ┌───────────────┐                                      │
│  │ SystemTray     │ 右键: 显示/隐藏, 统计, 设置, 退出     │
│  └───────────────┘                                      │
├──────────────────────────────────────────────────────────┤
│                   Renderer Process                       │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │                FarmEngine                           │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────┐ │ │
│  │  │ GameState    │  │KeyPlotState[]│  │PetState[]│ │ │
│  │  │ + coins      │  │ ~60 plots    │  │ dog/cat  │ │ │
│  │  │ + unlocked   │  │ per-keycode  │  │ auto     │ │ │
│  │  └──────────────┘  └──────────────┘  └──────────┘ │ │
│  └───────────────────────┬────────────────────────────┘ │
│                          │                               │
│  ┌───────────────────────┴────────────────────────────┐ │
│  │           KeyboardCanvasRenderer                    │ │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────────┐  │ │
│  │  │Layout      │ │KeyTile     │ │ParticleSystem  │  │ │
│  │  │Renderer    │ │Renderer    │ │(300 粒子对象池) │  │ │
│  │  │(键盘布局)   │ │(土壤+作物) │ │                │  │ │
│  │  └────────────┘ └────────────┘ └────────────────┘  │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

---

## 3. 游戏机制设计

### 3.1 数据模型

```typescript
// —— 作物定义 ——
interface CropDefinition {
  id: string;            // "wheat" | "tomato" | "corn" | "strawberry"
  displayName: string;   // "小麦" | "番茄" | "玉米" | "草莓"
  growRequirement: number; // 成熟所需按键次数
  sellPrice: number;     // 收获获得金币
  unlockPrice: number;   // 解锁所需金币
  stageCount: number;    // 生长阶段数 (固定为 4)
}

// —— 键盘按键定义 ——
interface KeyboardKeyDefinition {
  keyID: string;         // "kc_6" (keycode-based)
  keyCode: number;       // macOS keycode (参考原项目)
  label: string;         // "A", "B", "Space", "Tab" 等
  widthUnits: number;    // 按键宽度倍数 (1=标准, 1.5=Tab, 6.7=Space)
}

// —— 单个键位地块状态 ——
interface KeyPlotState {
  keyID: string;
  keyCode: number;
  keyLabel: string;
  widthUnits: number;
  cropID: string;        // 当前种植的作物 ID
  progress: number;      // 当前生长进度 (按键累计次数)
  lastHitAt: number;     // 上次被按下的时间戳 (用于高亮)
}

// —— 全局游戏状态 ——
interface GameState {
  version: number;           // 存档版本号
  coins: number;             // 金币
  unlockedCropIDs: string[]; // 已解锁的作物 ID
  keyPlots: KeyPlotState[];  // 所有键位地块 (由 KeyboardLayout 初始化)
  selectedCropID: string;    // 当前选中的种植作物
  adoptedPets: PetState[];   // 已领养的宠物
  dailyStats: Record<string, DailyStats>; // 每日统计
}

// —— 收获结果 ——
interface HarvestResult {
  keyID: string;
  keyCode: number;
  cropID: string;
  coins: number;
  source: 'player' | 'pet';
}
```

### 3.2 键盘布局定义

`KeyboardLayout` 定义了完整 ANSI QWERTY 布局，包含 ~60 个按键，每个按键使用物理 keycode 标识。主进程通过 `uiohook-napi` 获取的 keycode 根据 `process.platform` 进行平台映射。布局中每个按键的宽度倍数（`widthUnits`）用于渲染时计算实际像素尺寸。

### 3.3 按键 → 生长流程

```
OS 键盘事件 (uiohook-napi)
  → main process 30ms throttle + 去重
    → IPC: { keycode: number, timestamp: number }
      → renderer: FarmEngine.apply(keycode)
        → 查找 keyPlotMap.get(keycode)
          → 该 keyPlot.progress += 1
          → 检查是否 progress >= crop.growRequirement
            → 是: 地块进入成熟状态
            → 否: 更新土壤阶段 visual
        → 触发对应键位格的水滴粒子
```

### 3.4 收获机制

- **玩家主动收获**：双击或单击成熟键位格（由 UI 事件触发）
- **宠物自动收获**：已领养宠物每隔 ~24 秒自动寻找成熟地块并收获
- 收获后：地块 progress 归零，重新种植当前选中的作物
- 收获获得金币 = 作物 `sellPrice`

### 3.5 作物升级系统

- 初始解锁：小麦（免费）
- 赚取金币后可解锁更高级作物
- 解锁后可在种子袋中选择，所有后续种植默认使用该作物
- 可手动点击任意地块单独种植特定作物

### 3.6 土壤视觉阶段

| 阶段 | 土壤阶段 | 对应资源 |
|------|---------|---------|
| 初始 | 干裂荒地（进度 0） | `key_soil_stage_1[_wide_X].png` |
| < 34% | 开始湿润 | `key_soil_stage_2[_wide_X].png` |
| < 72% | 肥沃壤土 | `key_soil_stage_3[_wide_X].png` |
| ≥ 72% | 最肥沃黑土 | `key_soil_stage_4[_wide_X].png` |

---

## 4. 渲染管线

### 4.1 渲染层级

每个键位格的绘制顺序（从底层到顶层）：

```
1. 键帽阴影    (椭圆暗色投影)
2. 土壤纹理    (key_soil_stage_X_wide_Y.png，根据进度和键宽选取)
3. 作物精灵    ({crop}_stage_{1-4}.png，根据进度插值选取阶段)
4. 进度条      (底部迷你进度条，绿色→金色渐变)
5. 成熟光环    (金色辉光，成熟时 pulsating)
6. 最近按键高亮 (绿色辉光，最近 0.65s 内按过)
7. 按键标签    (左上角小标签，显示键名如 "A", "Esc")
8. 收获金币图标 (右下角，成熟时显示)
```

### 4.2 Canvas 架构

**双层 Canvas**：

```
底层 Canvas — 静态元素，低频更新
  ├── 农场背景 (farm_background.png)
  ├── 昼夜色彩覆盖 (day: warm tint, night: blue tint)
  └── 更新频率: 仅在昼夜切换或窗口 resize 时

顶层 Canvas — 动态元素，每帧更新
  ├── 遍历所有 KeyPlotState，绘制键位格
  ├── 宠物精灵动画 (SpriteKit → Canvas sprite sheet animation)
  ├── 粒子系统 (300 粒子对象池)
  └── 更新频率: requestAnimationFrame
```

### 4.3 宠物动画系统

宠物动画采用精灵图帧动画实现，每个宠物有多组帧序列：

```typescript
interface PetSprite {
  idle: HTMLImageElement;
  run: HTMLImageElement[];    // 4 帧
  collect: HTMLImageElement;
  rest: HTMLImageElement[];
}

// 动画循环: 巡逻(idle) → 跑向成熟地块(run) → 收集(collect) → 返回巡逻
```

### 4.4 性能优化

| 策略 | 说明 |
|------|------|
| 脏键集合 | 只重绘 `progress` 变化的键位格，而不是整个键盘 |
| 双层 Canvas | 底层不变不重绘；顶层仅绘制变化区域 |
| 粒子对象池 | 预分配 300 粒子，复用避免 GC |
| 空闲降频 | 30s 无按键后降至 10fps，有按键立即恢复 60fps |
| 图像预加载 | 所有精灵在启动时预加载到 Image 对象缓存 |
| `imageSmoothingEnabled = false` | 保持像素锐利 |

---

## 5. 窗口与托盘

### 5.1 悬浮窗口

```typescript
const overlayWindow = new BrowserWindow({
  width: 960,
  height: 680,
  transparent: true,
  frame: false,
  alwaysOnTop: true,
  focusable: false,
  skipTaskbar: true,
  hasShadow: false,
  resizable: true,             // 允许用户调整大小
  type: 'toolbar',
  webPreferences: {
    contextIsolation: true,
    nodeIntegration: false,
    sandbox: true,
    preload: path.join(__dirname, 'preload.js'),
  },
});

// 鼠标穿透透明区域
overlayWindow.setIgnoreMouseEvents(true, { forward: true });
```

### 5.2 系统托盘

- 托盘图标：使用 `key_soil.png` 缩制为 16×16 / 32×32 模板图标
- 右键菜单：显示/隐藏、统计、设置、退出
- 左键：切换窗口可见性

---

## 6. 项目结构

```
keysoil/
├── package.json                    # pnpm 工作区配置
├── pnpm-lock.yaml
├── tsconfig.json
├── tsconfig.node.json              # main/preload 专用 TS 配置
├── tsconfig.web.json               # renderer 专用 TS 配置
├── electron-builder.yml            # 打包分发配置
├── electron-vite.config.ts         # electron-vite 配置
├── .eslintrc.cjs
├── .prettierrc
├── .gitignore
│
├── electron/                       # —— Main Process ——
│   ├── main.ts                     # 入口：初始化窗口、hook、托盘
│   ├── preload.ts                  # contextBridge 安全 API
│   ├── keyboard/
│   │   ├── hook.ts                 # uiohook-napi 封装
│   │   └── keycodeMap.ts           # OS keycode → label 映射 (按平台)
│   ├── window/
│   │   └── overlay.ts              # 透明悬浮窗口工厂
│   ├── tray.ts                     # 系统托盘
│   └── ipc.ts                      # IPC 通道注册
│
├── src/                            # —— Renderer Process ——
│   ├── index.html
│   ├── index.ts                    # 入口，启动引擎
│   ├── farm/
│   │   ├── FarmEngine.ts           # 核心引擎
│   │   ├── GameState.ts            # 游戏状态模型 + 序列化
│   │   ├── KeyboardLayout.ts       # 键盘布局定义
│   │   ├── CropDefs.ts             # 4 种作物定义
│   │   ├── PetDefs.ts              # 宠物定义
│   │   └── constants.ts            # 时序常量
│   ├── renderer/
│   │   ├── KeyboardRenderer.ts     # 键盘配列渲染主循环
│   │   ├── KeyTileRenderer.ts      # 单键位格绘制
│   │   ├── SpriteManager.ts        # 精灵资源加载、缓存、查询
│   │   ├── ParticleSystem.ts       # 粒子对象池
│   │   ├── PetRenderer.ts          # 宠物精灵帧动画
│   │   └── Background.ts           # 农场背景 + 昼夜效果
│   ├── ui/
│   │   ├── HUD.ts                  # 顶部信息栏 (金币、统计)
│   │   ├── CropDock.ts             # 底部种子袋选择栏
│   │   ├── SettingsPanel.ts        # 设置面板 (DOM overlay)
│   │   └── styles.css
│   └── styles/
│       └── main.css                # body transparent, overflow hidden
│
├── assets/                         # —— 处理后的美术资源 ——
│   ├── keycaps/                    # 键帽土壤纹理 (缩放后)
│   │   ├── stage_1.png ... stage_4.png
│   │   ├── stage_1_wide_1_5.png ... stage_4_wide_1_5.png
│   │   ├── stage_1_wide_2_2.png ... stage_4_wide_2_2.png
│   │   └── stage_1_wide_4_8.png ... stage_4_wide_4_8.png
│   ├── crops/                      # 作物精灵 (缩放后)
│   │   ├── wheat/
│   │   ├── tomato/
│   │   ├── corn/
│   │   └── strawberry/
│   ├── pets/                       # 宠物精灵
│   │   ├── dog/
│   │   └── cat/
│   ├── ui/                         # UI 素材
│   │   ├── coin.png
│   │   ├── harvest_badge.png
│   │   └── farm_background.png
│   ├── icons/
│   │   └── tray-icon.png
│   └── audio/
│       └── bgm.mp3
│
├── raw-assets/                     # —— 原始美术素材 ——
│   └── (需要准备的素材文件)
│
├── scripts/                        # —— 构建辅助脚本 ——
│   ├── optimize-assets.ts          # 资源缩放 + 打包 (sharp)
│   ├── copy-assets.ts              # 从 raw-assets 复制并处理
│   └── generate-icons.ts           # 图标尺寸生成
│
├── tests/                          # —— 测试 ——
│   ├── unit/
│   │   ├── FarmEngine.test.ts      # FarmEngine 核心逻辑
│   │   ├── GameState.test.ts       # GameState 序列化/反序列化
│   │   ├── KeyboardLayout.test.ts  # 布局计算正确性
│   │   ├── CropDefs.test.ts        # 作物定义验证
│   │   └── SpriteManager.test.ts   # 资源加载
│   ├── integration/
│   │   ├── keyboard-hook.test.ts   # uiohook-napi 集成
│   │   ├── ipc-bridge.test.ts     # IPC 通道收发
│   │   ├── farm-render.test.ts    # 引擎→渲染 数据流
│   │   └── persistence.test.ts   # 存档读写
│   └── e2e/
│       ├── app-launch.spec.ts      # 应用启动 + 窗口创建
│       ├── farm-growth.spec.ts     # 完整生长→收获流程
│       ├── keyboard-input.spec.ts  # 键盘输入→渲染反馈
│       ├── tray-interaction.spec.ts# 托盘菜单交互
│       └── settings-persistence.spec.ts # 设置持久化
│
├── .github/
│   └── workflows/
│       ├── ci.yml                  # PR/推送时: lint + typecheck + unit + integration
│       └── release.yml             # Tag 推送时: 全平台构建 + 发布 Release
│
└── README.md
```

---

## 7. 包管理与脚本

### 7.1 pnpm 配置

```json
// package.json
{
  "name": "keysoil",
  "version": "0.1.0",
  "private": true,
  "packageManager": "pnpm@9.x",
  "scripts": {
    "dev": "electron-vite dev",
    "build": "electron-vite build",
    "preview": "electron-vite preview",
    "assets:copy": "tsx scripts/copy-assets.ts",
    "assets:optimize": "tsx scripts/optimize-assets.ts",
    "assets:build": "pnpm assets:copy && pnpm assets:optimize",
    "test:unit": "vitest run --config vitest.unit.config.ts",
    "test:integration": "vitest run --config vitest.integration.config.ts",
    "test:e2e": "playwright test",
    "test": "pnpm test:unit && pnpm test:integration",
    "test:all": "pnpm test:unit && pnpm test:integration && pnpm test:e2e",
    "lint": "eslint . --ext .ts,.tsx",
    "typecheck": "tsc --noEmit",
    "package:mac": "electron-builder build --mac",
    "package:win": "electron-builder build --win",
    "package:linux": "electron-builder build --linux",
    "package:all": "electron-builder build --mac --win --linux",
    "postinstall": "electron-builder install-app-deps"
  },
  "dependencies": {
    "uiohook-napi": "^1.x"
  },
  "devDependencies": {
    "electron": "^33.x",
    "electron-vite": "^2.x",
    "electron-builder": "^25.x",
    "typescript": "^5.x",
    "vitest": "^2.x",
    "@playwright/test": "^1.x",
    "sharp": "^0.33.x",
    "tsx": "^4.x",
    "eslint": "^9.x",
    "prettier": "^3.x"
  }
}
```

---

## 8. 测试策略

### 8.1 单元测试 (Vitest)

测试所有纯逻辑模块，不依赖 Electron/DOM：

| 测试文件 | 测试内容 |
|---------|---------|
| `FarmEngine.test.ts` | `apply()` 按键推进 progress；`harvest()` 成熟后重置 + 加金币；`plant()` 切换作物；进度不溢出 growRequirement；未解锁作物不可收获 |
| `GameState.test.ts` | `defaultState()` 输出合法；序列化/反序列化往返一致性；版本迁移兼容；存档文件损坏时不崩溃 |
| `KeyboardLayout.test.ts` | 5 行布局总宽度一致；所有 keyID 唯一；每个 keyCode 只出现一次；widthUnits 计算正确；`keysByCode` 查找正确 |
| `CropDefs.test.ts` | 所有作物 stageCount = 4；growRequirement > 0；初始解锁作物为 wheat |

### 8.2 集成测试 (Vitest + Electron Test)

测试主进程 + 渲染进程之间的协作：

| 测试文件 | 测试内容 |
|---------|---------|
| `keyboard-hook.test.ts` | uiohook-napi 启动/停止；keydown 事件包含正确的 keycode；throttle 30ms 生效；修饰键单独按下被过滤 |
| `ipc-bridge.test.ts` | `keystroke` 通道正确收发；`get-settings` / `save-settings` 往返正确；preload API 白名单完整 |
| `farm-render.test.ts` | FarmEngine 状态变更后渲染器收到更新；键盘布局坐标计算正确；快照对比测试 (visual snapshot) |
| `persistence.test.ts` | GameState 读写 electron-store；默认状态回退；损坏文件恢复 |

### 8.3 端到端测试 (Playwright)

模拟真实用户操作：

| 测试文件 | 测试内容 |
|---------|---------|
| `app-launch.spec.ts` | 应用正常启动；透明窗口出现；托盘图标可见；无致命错误 |
| `farm-growth.spec.ts` | 模拟 200 次按键 → 小麦地块从荒地成熟；收获动画触发；金币计数器增加 |
| `keyboard-input.spec.ts` | 全局按键 → 对应键位格高亮；快速连打不丢帧；30s 静止后粒子停止 |
| `tray-interaction.spec.ts` | 托盘菜单显示/隐藏切换；退出菜单生效 |
| `settings-persistence.spec.ts` | 修改设置 → 重启后持久化；窗口位置记忆 |

---

## 9. CI/CD 与构建系统

### 9.1 本地构建

```bash
# 开发模式
pnpm dev                    # 启动 Electron 开发服务器 (HMR)

# 编译产物
pnpm build                  # electron-vite 构建 main + preload + renderer
pnpm package:mac            # 打包 macOS .dmg
pnpm package:win            # 打包 Windows .exe (NSIS)
pnpm package:linux          # 打包 Linux .AppImage / .deb
```

### 9.2 GitHub Actions — CI (`ci.yml`)

触发条件：`push` 到任意分支、`pull_request` 到 `main`

```yaml
name: CI
on:
  push:
    branches: ['**']
  pull_request:
    branches: [main]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'pnpm' }
      - run: pnpm install --frozen-lockfile
      - run: pnpm typecheck
      - run: pnpm lint
      - run: pnpm test:unit

  integration:
    needs: quality
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'pnpm' }
      - run: pnpm install --frozen-lockfile
      - run: pnpm test:integration
      - run: pnpm test:e2e
        if: matrix.os == 'ubuntu-latest'  # e2e 仅在 Linux 上运行（headless）

  assets:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - run: pnpm install --frozen-lockfile
      - run: pnpm assets:build
      - uses: actions/upload-artifact@v4
        with:
          name: optimized-assets
          path: assets/
```

### 9.3 GitHub Actions — Release (`release.yml`)

触发条件：推送 `v*` 格式的 Git Tag（如 `v0.1.0`）

```yaml
name: Release
on:
  push:
    tags: ['v*']

jobs:
  build:
    strategy:
      matrix:
        os: [macos-latest, ubuntu-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'pnpm' }
      - run: pnpm install --frozen-lockfile
      - run: pnpm assets:build
      - run: pnpm build

      - name: Package (macOS)
        if: matrix.os == 'macos-latest'
        run: pnpm package:mac
        env:
          CSC_LINK: ${{ secrets.MAC_CERTS }}
          CSC_KEY_PASSWORD: ${{ secrets.MAC_CERTS_PASSWORD }}

      - name: Package (Windows)
        if: matrix.os == 'windows-latest'
        run: pnpm package:win

      - name: Package (Linux)
        if: matrix.os == 'ubuntu-latest'
        run: pnpm package:linux

      - uses: actions/upload-artifact@v4
        with:
          name: release-${{ matrix.os }}
          path: dist/*.{dmg,exe,AppImage,deb}

  release:
    needs: build
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/download-artifact@v4
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: release-*/*
          generate_release_notes: true
          draft: true
```

### 9.4 electron-builder 配置

```yaml
# electron-builder.yml
appId: com.keysoil.farm
productName: KeySoil
copyright: Copyright © 2026 KeySoil
directories:
  output: dist
  buildResources: build

mac:
  category: public.app-category.productivity
  icon: assets/icons/icon.icns
  target:
    - dmg
    - zip
  hardenedRuntime: true

win:
  icon: assets/icons/icon.ico
  target:
    - nsis
  nsis:
    oneClick: false
    allowToChangeInstallationDirectory: true

linux:
  icon: assets/icons/icon.png
  target:
    - AppImage
    - deb
  category: Utility

files:
  - out/**/*
  - assets/**/*
  - "!raw-assets/**"
  - "!tests/**"
```

---

## 10. 实现阶段

### Phase 1: 项目骨架 + 窗口

**目标**：Electron 跑起来，透明窗口可见

- [ ] `pnpm create electron-vite keysail` 初始化项目
- [ ] 配置 TypeScript strict mode、ESLint、Prettier
- [ ] 实现 `electron/window/overlay.ts`：透明悬浮窗口 (~900×680)
- [ ] 实现 `electron/preload.ts`：安全 IPC bridge
- [ ] 实现 `src/index.html` + Canvas 初始化 + 背景渲染
- [ ] 实现 `electron/tray.ts`：基础托盘
- [ ] **验证**：`pnpm dev` → 透明窗口可见，托盘图标正常

### Phase 2: 资产处理 + 键盘布局渲染

**目标**：键盘配列可视化，资源加载就绪

- [ ] 编写 `scripts/copy-assets.ts`：从 raw-assets 复制
- [ ] 编写 `scripts/optimize-assets.ts`：sharp 缩放 + 可选打包图集
- [ ] 实现 `src/farm/KeyboardLayout.ts`：键盘布局 + 跨平台 keycode 映射
- [ ] 实现 `src/renderer/SpriteManager.ts`：资源预加载与缓存
- [ ] 实现 `src/renderer/KeyboardRenderer.ts`：渲染静态键盘配列
- [ ] 实现 `src/renderer/KeyTileRenderer.ts`：单键位格 → 土壤纹理绑定
- [ ] **验证**：`pnpm assets:build && pnpm dev` → 窗口显示完整键盘配列，每格有土壤纹理

### Phase 3: 键盘 Hook 集成

**目标**：全局按键可靠驱动渲染

- [ ] 安装 `uiohook-napi`，实现 `electron/keyboard/hook.ts`
- [ ] 实现 `electron/keyboard/keycodeMap.ts`：平台 keycode → 布局映射
- [ ] 实现 `electron/ipc.ts`：keystroke IPC 通道
- [ ] 渲染端接收 keystroke，高亮对应键位格
- [ ] **验证**：在 TextEdit/记事本中打字，对应键位格实时高亮闪烁

### Phase 4: 农场核心逻辑

**目标**：完整生长→收获循环

- [ ] 实现 `src/farm/GameState.ts`：状态模型 + 序列化 (electron-store)
- [ ] 实现 `src/farm/CropDefs.ts`：4 种作物定义
- [ ] 实现 `src/farm/FarmEngine.ts`：`apply()`, `harvest()`, `plant()`, `unlockCrop()`
- [ ] 实现土壤阶段计算与作物精灵阶段选取
- [ ] 实现收获动画（金色粒子爆发）
- [ ] **验证**：连续按同一字母 24 次 → 该键从荒地到成熟 → 收获 → 金币 +8

### Phase 5: 动画与特效

**目标**：流畅的视觉反馈

- [ ] 实现 `src/renderer/ParticleSystem.ts`：对象池 (300 粒子)
- [ ] 按键水滴粒子飞溅
- [ ] 成熟地块 pulsating 辉光
- [ ] 最近按键高亮 (0.65s 渐隐)
- [ ] 作物阶段切换过渡动画
- [ ] 昼夜背景感知 (模拟，非严格时间)
- [ ] 实现 `src/renderer/PetRenderer.ts`：宠物巡逻帧动画

### Phase 6: UI 与设置

**目标**：完整的用户界面

- [ ] 实现 HUD：金币计数器、今日统计
- [ ] 实现 CropDock：种子袋选择栏
- [ ] 实现 SettingsPanel：窗口大小、透明度、置顶、开机自启
- [ ] 统计持久化 (electron-store)
- [ ] 设置面板通过托盘或双击标题栏打开

### Phase 7: 测试完善

**目标**：高覆盖率、CI 全绿

- [ ] 编写所有单元测试（FarmEngine, GameState, KeyboardLayout, CropDefs）
- [ ] 编写集成测试（IPC bridge, keyboard hook, persistence）
- [ ] 编写 E2E 测试（Playwright: 启动→打字→生长→收获）
- [ ] 配置 GitHub Actions CI 在 push 时自动运行

### Phase 8: 打包分发

**目标**：三平台可安装应用

- [ ] 配置 `electron-builder.yml`
- [ ] 编写 GitHub Actions Release workflow
- [ ] macOS 签名配置 (如需分发)
- [ ] 各平台安装测试
- [ ] 编写 README (项目介绍 + 截图 + 安装说明)

---

## 11. 安全与隐私

- **不记录、不存储、不传输**任何按键内容
- Main process 仅传递物理 **keycode**，不传递字符
- Renderer 仅用 keycode 查表定位键位格
- `contextIsolation: true` + `sandbox: true`
- `focusable: false` 确保不参与焦点竞争
- 应用**无网络请求**（完全离线，除非启用自动更新）
- 首次启动展示隐私说明

---

## 12. 验证方案

**端到端验证流程**：

> 1. `pnpm dev` 启动 KeySoil
> 2. 打开 TextEdit/记事本
> 3. 输入 "the quick brown fox jumps over the lazy dog"
> 4. 观察：E/T/A/O 等高频字母键位格作物生长最快；Z/Q/X 等冷门键维持荒地
> 5. 连续输入 24 次 "e" → 该键从荒地→湿润→肥沃→成熟，出现收割金币提示
> 6. 收获 → 金币计数器 +8 → 土壤重置 → 自动重新播种
> 7. 确认打字流畅无卡顿、内存不增长
> 8. `pnpm test:all` → 所有单元/集成/E2E 测试通过
