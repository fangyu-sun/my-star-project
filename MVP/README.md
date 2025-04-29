# Star Tracker

一个简单的星体追踪器应用，可以显示当前可见的最亮天体的位置。

## 功能

- 输入经纬度坐标
- 显示当前可见的最亮天体（太阳、月亮、火星、木星）
- 显示天体的高度角和方位角

## 安装

1. 克隆仓库
2. 安装依赖：
```bash
pip install -r requirements.txt
```

## 运行

1. 启动后端服务：
```bash
python app.py
```

2. 在浏览器中打开 `index.html`

## 技术栈

- 前端：HTML, CSS, JavaScript
- 后端：Python, Flask
- 天文计算：PyEphem 