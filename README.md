# KeySoil（按键沃土）

> 键盘播种，成熟收获 —— 一款打字即耕耘的 macOS 桌面陪伴应用。

KeySoil 是一款 macOS 原生桌面陪伴应用。你在键盘上正常打字时，每一次按键都会驱动虚拟像素农场的生长。农场以**键盘配列**呈现在透明悬浮窗口中。

## 特色

- ⌨️ **键盘即农场**：每个按键就是一块土壤。按下哪个键 → 哪块地就获得浇灌。
- 🌾 **四种作物**：小麦、番茄、玉米、草莓——每种 4 个视觉生长阶段。
- 🐕 **宠物伙伴**：领养小猫小狗，它们会在农场巡逻并自动帮你收获成熟作物。
- 🍅 **番茄钟**：内置专注计时器，在打字耕耘的同时管理专注时间。
- 📋 **待办清单**：轻量级任务管理，伴随农场一起使用。
- 🪟 **透明悬浮窗**：始终置顶、菜单栏驻留，不影响正常工作。
- 🔒 **隐私优先**：仅处理物理按键码，绝不记录你输入的内容。完全离线。

## 技术栈

Swift 6 · SwiftUI · SpriteKit · CoreGraphics · Swift Package Manager

## 环境要求

- macOS 14.0+
- Xcode 16+ / Swift 6
- 辅助功能权限（用于全局键盘监听）

## 快速开始

### 开发

```bash
make build          # 编译项目
make run            # 启动应用
```

### 测试

```bash
make test           # 运行单元测试 (swift test)
make selftest       # 运行独立自测可执行文件
```

### 发布构建

```bash
make release        # swift build -c release
```

### 快照验证

```bash
swift run TypingFarmerMac -- --snapshot /tmp/snapshot.png
open /tmp/snapshot.png
```

## 项目结构

```
Sources/
├── TypingFarmerCore/           # 平台无关核心逻辑 (数据模型、游戏引擎、番茄钟)
├── TypingFarmerMacSupport/     # macOS 平台支持 (持久化、键盘布局桥接)
└── TypingFarmerMac/            # macOS 应用主体 (AppKit + SwiftUI + SpriteKit)
    └── Resources/              # 美术资源 (63 PNG + BGM)
Tests/
├── TypingFarmerCoreTests/      # 核心逻辑测试
└── TypingFarmerMacSupportTests/ # 持久化测试
```

详见 [CLAUDE.md](CLAUDE.md) 获取详细项目文档，[docs/design.md](docs/design.md) 查看完整实现计划与分工。

## 运行须知

首次运行需授予「辅助功能」权限（系统设置 → 隐私与安全性 → 辅助功能），否则无法监听全局键盘事件。

## 许可证

[MIT](LICENSE)
