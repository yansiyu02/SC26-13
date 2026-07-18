# CLAUDE.md

## 项目概述

KeySoil（按键沃土）是一款跨平台桌面陪伴应用，使用 Electron + TypeScript 构建。用户在正常使用键盘打字时，每次按键都会驱动虚拟像素农场中的作物生长。农场以**键盘配列**的形式呈现在透明悬浮窗口中——每个物理按键对应一块土壤，常用键作物茂盛，冷门键维持荒芜，形成自然的打字热力图。

## 技术栈

- **运行时**: Electron 33+
- **语言**: TypeScript 5.x（strict 模式）
- **包管理器**: pnpm 9+
- **构建工具**: electron-vite
- **打包工具**: electron-builder
- **渲染**: Canvas 2D（双层画布）
- **全局键盘钩子**: uiohook-napi
- **图像处理**: sharp
- **测试**: Vitest（单元/集成）、Playwright（端到端）
- **CI/CD**: GitHub Actions

## 项目结构

```
keysoil/
├── electron/           # 主进程
│   ├── main.ts         # 入口：窗口、键盘钩子、托盘初始化
│   ├── preload.ts      # contextBridge 安全 API
│   ├── keyboard/       # uiohook-napi 封装 + keycode 映射
│   ├── window/         # 透明悬浮窗口工厂
│   ├── tray.ts         # 系统托盘
│   └── ipc.ts          # IPC 通道注册
├── src/                # 渲染进程
│   ├── index.html
│   ├── index.ts        # 入口，启动引擎与渲染器
│   ├── farm/           # 游戏逻辑（FarmEngine、GameState 等）
│   ├── renderer/       # Canvas 渲染（键盘布局、键位格、粒子、宠物）
│   └── ui/             # HUD、种子栏、设置面板（DOM 覆盖层）
├── assets/             # 处理后的美术资源
├── raw-assets/         # 原始美术素材
├── scripts/            # 资源处理脚本
├── tests/              # unit/、integration/、e2e/
└── .github/workflows/  # CI + Release
```

## 核心设计决策

- **键盘即农场**：每个物理按键就是一块土壤。按下哪个键就浇灌哪块地。常用键（如 E、T、A、O）自然茂盛，冷门键（如 Z、Q）自然荒芜。
- **美术资源需求**：需要进行准备的像素美术素材（键帽土壤纹理 4 阶段 × 4 宽度变体、4 种作物 × 4 生长阶段、宠物动画、UI 元素）。
- **双层 Canvas**：底层绘制静态元素（土壤 + 键盘布局），顶层绘制动态元素（作物、粒子、宠物动画）——最小化重绘开销。
- **安全隐私**：主进程仅传递物理 keycode，不传递实际字符。应用完全离线，不记录、不存储、不传输任何输入内容。

## 常用命令

```bash
pnpm dev              # 启动开发服务器（HMR）
pnpm build            # 生产构建
pnpm test:unit        # 运行单元测试
pnpm test:integration # 运行集成测试
pnpm test:e2e         # 运行端到端测试
pnpm lint             # ESLint 代码检查
pnpm typecheck        # TypeScript 类型检查
pnpm assets:build     # 处理原始素材 → 优化后资源
pnpm package:mac      # 打包 macOS 应用
pnpm package:win      # 打包 Windows 应用
pnpm package:linux    # 打包 Linux 应用
```

## 实现计划

完整实现计划与架构设计参见 `docs/design.md`。
