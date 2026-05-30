---
name: MyUniverse macOS Screensaver Development Skill
description: Guides the agent on compile, install, cache cleaning, and adhering to strict git commit policies for the MyUniverse project.
tags: [macos, screensaver, vite, swift, workflow]
triggers: ["build screensaver", "install screensaver", "clean cache", "commit code", "modify code", "工作规范", "编译屏保"]
---

# MyUniverse Screensaver Developer Skill

本技能文件定义了在 `star-tracker` 项目中进行开发、构建以及版本控制的标准作业程序（SOP）。AI 助手在执行相关任务时必须严格遵守。

---

## 1. 修改代码前的确认机制 (Before-Edit Confirmation)

在对项目中的任何代码（Web JS/CSS、Swift、编译脚本等）进行实际修改或保存前，**必须执行以下步骤**：
1. **分析与设计**：分析用户的需求，明确受影响的文件和逻辑。
2. **汇报设计思路**：向用户详细汇报我们的分析理解和具体的修改方案。
3. **获取授权**：必须等待用户回复确认（例如“同意”、“OK”或“开始修改”），方可进行实际的代码更新与构建测试。

---

## 2. 编译与调试工作流 (Build & Debug Workflow)

本项目包含 Vite Web 前端和原生 macOS Screensaver。所有编译与缓存管理通过 `./build_saver.sh` 执行。

### 核心命令指南：
* **本地 Web 预览开发**：
  ```bash
  npm run dev
  ```
  在本地浏览器中进行快速热更新调试。
* **编译并安装屏保到本地系统**（每次修改 Swift 或 Web 产物后执行）：
  ```bash
  ./build_saver.sh --install-dev
  ```
* **解决屏保画面不更新/系统缓存问题**（如果修改后系统偏好设置中依然显示旧画面）：
  ```bash
  ./build_saver.sh --clean-saver-cache
  ```
* **重置屏保配置默认值**（擦除本地 UserDefaults 中已保存的位置和配置）：
  ```bash
  ./build_saver.sh --reset-saver-defaults
  ```

---

## 3. 原子化模块提交规范 (Git Commit Specifications)

为了保持代码历史的绝对清晰与可追溯性，必须遵循以下 Git 流程：

1. **单模块提交**：每当**完成一个功能模块**且**测试通过（编译成功且功能运行正常）**后，自动执行 `git add` 和 `git commit`。严禁将多个不同功能模块的大量变更堆积到单次提交中。
2. **中英双语 Commit 格式**：提交信息（Commit Message）必须使用中英双语描述具体修改范围。
   
   **格式规范**：`<type>(<scope>): <中文描述> / <type>(<scope>): <English description>`
   
   **示例**：
   * `feat(satellite): 引入 satellite.js 精确推算人造卫星天顶飞越轨迹 / feat(satellite): Introduce satellite.js for precise Zenith satellite pass propagation`
   * `fix(astronomy): 修复天体筛选圆锥角度至严格的 80 度天顶范围 / fix(astronomy): Fix candidate selection cone angle to strict 80-degree zenith range`
   * `docs(workflow): 新增项目 Git 提交与自动模块化开发工作规范 / docs(workflow): Add bilingual project Git commit and modular development guidelines`
