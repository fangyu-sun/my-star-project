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

---

## 📂 项目结构映射 / Project Directory Map

* [`index.html`](file:///Users/sunfangyu/star-tracker/index.html) - 简约高级感的暗色系单页应用容器。
* [`style.css`](file:///Users/sunfangyu/star-tracker/style.css) - 精美极简主义设计，包含夜空粒子与呼吸动画。
* [`src/main.js`](file:///Users/sunfangyu/star-tracker/src/main.js) - 地理定位控制器与每秒刷新数据流核心逻辑。
* [`src/astronomy.js`](file:///Users/sunfangyu/star-tracker/src/astronomy.js) - 融合行星（含太阳/月亮）、恒星（HYG库）与人造卫星的权重计算引擎。
* [`src/satellite_engine.js`](file:///Users/sunfangyu/star-tracker/src/satellite_engine.js) - 基于 SGP4 模型解算顶心高度角、方位角与斜距的独立算法库。
* [`src/copywriter.js`](file:///Users/sunfangyu/star-tracker/src/copywriter.js) - 为不同天体定制的沉浸式唯美中文文案生成器。
* [`src/data/`](file:///Users/sunfangyu/star-tracker/src/data/) - 存放离线 TLE 保底数据、恒星目录与标准星座映射。
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

## 🌟 工作规范规范说明 / Version Control Guidelines
本仓库严格遵守 [工作规范.md](file:///Users/sunfangyu/star-tracker/工作规范.md) 所定义的原子化开发原则：
> 每当完成一个具体功能模块并测试通过后，系统将自动触发 `git add` 和 `git commit`，保持每一次代码历史提交都有着原子级别的可追溯性与清晰的双语提交信息。
