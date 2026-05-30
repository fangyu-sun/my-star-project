# 🌌 宇宙天顶播报器 / Zenith Cosmic Broadcaster

<p align="center">
  <strong>一款唯美、深邃且实时的宇宙呼吸雷达。通过地理定位与物理轨道推算，在一个 60° 穹顶下循环为您播报正陪伴您的那颗星星。即使孤独，至少有一颗星星陪着你。</strong><br>
  <em>A beautiful, deep, and real-time cosmic breathing radar. It cycles through celestial bodies in a 60° dome above you, proving that even in solitude, at least one star keeps you company.</em>
</p>

---

## ✨ 核心亮点 / Key Features

### 1. 🚀 人造卫星实时轨推算 / Real-time Satellite Propagation
* **SGP4 轨道模型**：引入經典的 `satellite.js` 物理轨道库，结合 TLE 两行轨道要素，实时解算出人造卫星在您顶心坐标系（Topocentric）的高度角、方位角与斜距（Range）。
* **动态 TLE 拉取 + 离线容灾**：启动时自动拉取前 50 颗最热门卫星与最新星链（Starlink）数据。若网络不可用，自动降级至内置经典空间站（ISS/CSS）和哈勃太空望远镜（HST）等离线轨道要素。
* **极速飞越评级**：当近地空间站或人造卫星在您头顶 10 度天空范围内飞越时，系统将给予最高优先评级，以秒为单位滚动展示人类空间站的飞跃速度与距离！

### 2. 🌌 60° 穹顶雷达与深空陪伴 / 60° Cosmic Dome & Solitude Companion
* **60° 广袤穹顶与 8秒呼吸轮播**：我们将观测阈值设定为高度角 $\ge 60^\circ$。符合条件的行星、航天器或恒星将被收入穹顶雷达池中。每隔 8 秒，系统会以极具生命力的慢速呼吸动效，在您眼前循环更替这一刻头顶星空的守望者。
* **八大行星与 2800 颗亮星**：集成视星等 5.5 以内的 HYG 亮星星表以及八大行星轨道计算。系统不仅能捕捉微弱的暗星，甚至可能告诉您，此时木星或火星恰好位于您的夜空最高点。
* **诗意宇宙解说**：为不同天体定制的沉浸式双语解说词。它不再是冰冷的数据，而是通过诸如 *“此刻，一颗 517.7 光年外的位于唧筒座的恒星，正高悬于你的天顶。”* 等语句，建立起属于你与宇宙的私人浪漫。

### 3. ⚡ 定位仪式感与无缝状态切换 / Location Ceremony & Seamless Transitions
* **“正在解析空间坐标”**：初次点击“开启连接”时，应用会提供 1.5 秒的悬念与信任反馈，增强了“与深空接轨”的仪式感。
* **绝对静谧的后台轮播重算**：在您静静欣赏 8 秒呼吸文案的同时，后台不仅在为您高精度刷新 GPS (`maximumAge: 0`)，还在静默地以 60 秒为周期重算当前穹顶上空的候选天体，做到真正的无感切换。
* **全局绝对定位防抖**：采用终极 `position: absolute` 防抖架构。无论中英文本如何更替，天顶恒星（Zenith Dot）都被死死锁定在像素级坐标系中，永不偏移，彻底杜绝字体基线差异造成的任何排版跳跃。

### 4. ⏱️ 高精度自转时针 / Sub-second Earth Rotation Chronometer
* **肉眼见证地球自转**：我们将 `ALTITUDE`（高度角）与 `ZENITH OFFSET`（天顶偏离角）的计算与输出精度提升至**小数点后三位 (`.toFixed(3)`)**。
* **宇宙时空律动**：由于地球以约 $15^\circ/\text{小时}$ 的速度自转（每秒钟天空掠过约 $0.00417^\circ$），在每秒钟的更新频率下，您会直观地看到小数点后第三位数字以约 **`0.004`** 的速度进行优美、均匀的数字滚跳，带给您星空在分秒间流逝的绝佳天文质感。

### 5. 🖥️ macOS 原生屏幕保护程序与实时预览 / macOS Native Screen Saver & Live Preview
* **Out-of-Process 独立进程沙盒适配**：完美适配 macOS Big Sur 及更高版本的系统沙盒安全机制，所有持久化读写完全基于 `ScreenSaverDefaults`，资源加载完全基于 `Bundle(for:)` 动态定位。
* **双向 WeakScript 内存安全网桥**：在 Web 渲染容器与 Swift 宿主之间建立 high 精度的 `WeakScriptMessageHandler` 弱引用代理，完美打破强引用循环，彻底杜绝多显示器及频繁切换选项卡时可能引发的 `EXC_BAD_ACCESS` 闪退崩溃，实现零内存泄漏与绝对稳定的运行。
* **同屏高保真实时预览 (Options Live Preview)**：在系统设置配置面板左侧加入 380x260 的 `WKWebView` 实时渲染画布。用户调整“地理位置模式”、“语言（English / 简体中文 / 繁體中文 / 日本語）”、“显示频率”以及“文本辉度”时，左侧画布均能无延迟实时高保真同步预览渲染效果。

---

## 📂 项目结构映射 / Project Directory Map

* [`index.html`](file:///Users/sunfangyu/star-tracker/index.html) - 简约高级感的暗色系单页应用容器。
* [`style.css`](file:///Users/sunfangyu/star-tracker/style.css) - 精美极简主义设计，包含夜空粒子与呼吸动画。
* [`src/main.js`](file:///Users/sunfangyu/star-tracker/src/main.js) - 地理定位控制器与每秒刷新数据流核心逻辑。
* [`src/astronomy.js`](file:///Users/sunfangyu/star-tracker/src/astronomy.js) - 融合行星（含太阳/月亮）、恒星（HYG库）与人造卫星的权重计算引擎。
* [`src/satellite_engine.js`](file:///Users/sunfangyu/star-tracker/src/satellite_engine.js) - 基于 SGP4 模型解算顶心高度角、方位角与斜距的独立算法库。
* [`src/copywriter.js`](file:///Users/sunfangyu/star-tracker/src/copywriter.js) - 为不同天体定制的沉浸式唯美中文文案生成器。
* [`src/data/`](file:///Users/sunfangyu/star-tracker/src/data/) - 存放离线 TLE 保底数据、恒星目录与标准星座映射。
* [`macos-saver/MyUniverseSaver/MyUniverseSaverView.swift`](file:///Users/sunfangyu/star-tracker/macos-saver/MyUniverseSaver/MyUniverseSaverView.swift) - 屏保主视图，管理 WKWebView 周期、多监视器实例及零阻塞配置注入。
* [`macos-saver/MyUniverseSaver/OptionsSheet.swift`](file:///Users/sunfangyu/star-tracker/macos-saver/MyUniverseSaver/OptionsSheet.swift) - 原生 macOS 偏好设置面板，包含城市数据库、定位管理及同屏 Live Preview 回收链。
* [`build_saver.sh`](file:///Users/sunfangyu/star-tracker/build_saver.sh) - 一键式 Universal (x86_64 / arm64) 编译、Vite 静态化转换、缓存清空及本地安装自动化脚本。
* [`工作规范.md`](file:///Users/sunfangyu/star-tracker/工作规范.md) - 中英双语的版本提交与模块自动 Commit 规范。

---

## 🛠️ 安装与运行 / Installation & Running

如果您需要在本地运行、测试或进行二次开发，请确保您的设备上安装了 [Node.js](https://nodejs.org/)。

### 1. 安装项目依赖 / Install Dependencies
```bash
npm install
```

### 2. 启动开发服务器 / Run Vite Development Server
```bash
npm run dev
```
启动后，在浏览器中打开控制台输出的地址即可体验热更新开发环境（通常为 `http://localhost:60000/`）。

### 3. 构建生产包 / Build for Production
```bash
npm run build
```
打包输出的文件将存放于根目录的 `dist/` 文件夹下，您可以直接将其部署至任意静态托管平台（如 GitHub Pages, Vercel 等）。

---

## 🖥️ macOS 屏幕保护程序构建与部署 / macOS Screen Saver Build & Deploy

我们在根目录下配备了全自动编译与部署脚本 `build_saver.sh`。

### 1. 编译并安装到本地系统 / Build and Install
```bash
./build_saver.sh --install-dev
```
此命令将自动执行以下操作：
1. 调用 Vite 以 classic 静态化配置编译 Web 产物，自动剥离 ES Modules，确保 `file://` 下的沙盒兼容性。
2. 自动生成符合 Apple 规范的 `Info.plist`，并将构建时间戳写入以绕过系统缓存。
3. 编译并 lipo 融合成 **Universal Binary**（同时兼容 Apple Silicon M1/M2/M3 和 Intel 处理器）。
4. 强制清空系统的 `legacyScreenSaver` 和 `cfprefsd` 屏保缓存，并将新版 `.saver` 安装至您的 `~/Library/Screen Savers/` 目录下。

### 2. 清理系统屏保缓存 / Clean Screen Saver Caches
如果您在调试时发现系统设置中的画面没有更新，可以通过以下命令强行清空 macOS 系统设置的后台缓存：
```bash
./build_saver.sh --clean-saver-cache
```

### 3. 重置屏保配置默认值 / Reset Saved Configuration
如果您想完全擦除本地已保存的位置和参数配置，将其恢复至默认状态：
```bash
./build_saver.sh --reset-saver-defaults
```

---

## 🌟 工作规范规范说明 / Version Control Guidelines
本仓库严格遵守 [工作规范.md](file:///Users/sunfangyu/star-tracker/工作规范.md) 所定义的原子化开发原则：
> 每当完成一个具体功能模块并测试通过后，系统将自动触发 `git add` 和 `git commit`，保持每一次代码历史提交都有着原子级别的可追溯性与清晰的双语提交信息。
