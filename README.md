# 🌌 宇宙天顶播报器 / Zenith Cosmic Broadcaster

<p align="center">
  <strong>一款唯美、深邃且实时的天顶天体与卫星播报器。通过地理定位与物理轨道推算，为您寻找正悬于您头顶那片星空的微观浪漫。</strong><br>
  <em>A beautiful, deep, and real-time cosmic broadcaster for overhead stars and satellites, tracing the romance of the universe right above you.</em>
</p>

---

## ✨ 核心亮点 / Key Features

### 1. 🚀 人造卫星实时轨推算 / Real-time Satellite Propagation
* **SGP4 轨道模型**：引入經典的 `satellite.js` 物理轨道库，结合 TLE 两行轨道要素，实时解算出人造卫星在您顶心坐标系（Topocentric）的高度角、方位角与斜距（Range）。
* **动态 TLE 拉取 + 离线容灾**：启动时自动拉取前 50 颗最热门卫星与最新星链（Starlink）数据。若网络不可用，自动降级至内置经典空间站（ISS/CSS）和哈勃太空望远镜（HST）等离线轨道要素。
* **极速飞越评级**：当近地空间站或人造卫星在您头顶 10 度天空范围内飞越时，系统将给予最高优先评级，以秒为单位滚动展示人类空间站的飞跃速度与距离！

### 2. ⭐ 严格天顶限制与 2800+ 恒星库 / Strict Zenith View & 2800+ Star DB
* **天顶 10° 锥形范围**：高度角严格限定在 $\ge 80^\circ$（天顶 $90^\circ \pm 10^\circ$ 锥型视角内），只有真正处于您头顶正上方的亮星才能入选。
* **2800 颗亮星与 88 星座映射**：集成视星等 5.5 以内的 HYG 亮星星表。对于无通用命名的恒星，系统通过全天 88 星座边界数据自动归入对应星座，并生成富含诗意的双语文学段落（如：*“此刻，一颗 517.7 光年外的位于唧筒座的恒星，正高悬于你的天顶。”*）。
* **无垠暗空保底**：当天顶 10 度无任何肉眼可见天体或卫星时，呈现空灵静谧的“无垠暗空”文案，维持天文观测的真实性。

### 3. ⚡ 零延迟瞬间载入与后台静默刷新 / Zero-Delay Loading & Silent GPS Refresh
* **极速首屏秒开**：通过 `localStorage` 本地缓存上一次成功的定位城市与经纬度。点击“开启连接”时跳过任何可能导致卡顿的加载等待，瞬间以您的常用位置切入星空！
* **后台高精度位置重锁 (`maximumAge: 0`)**：在星空平稳运行的同时，系统在后台发起全新的高精准实时 GPS 搜寻，并完全剔除硬超时限制，给予用户充足的系统权限批准时间。
* **无感平滑切换**：一旦后台成功捕捉到最新经纬度，顶部的城市名、时间以及天顶星空会在背景完成无缝、平滑的瞬间重定位，既无卡顿也无突兀弹窗。
* **无缝降级**：若用户首次使用且拒绝或无法提供位置权限，系统将自动以“北京 (默认位置)”进行保底运算，确保全平台 100% 完美可用。

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
