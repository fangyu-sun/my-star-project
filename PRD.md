# 产品需求文档 (PRD)：MyUniverse macOS 屏放系统

## 1. 产品定位

MyUniverse 是一个基于真实天文计算的 macOS 原生屏幕保护程序。

产品目标不是星图软件，不是天文工具，也不是桌面 Widget。

它是一台持续运行的「宇宙状态播报器」。

用户离开电脑时，屏保自动展示此刻对应地点上空最具代表性的天体，并通过极简文字叙事传递时间、距离与宇宙尺度感。

---

## 2. 运行架构

### 双运行模式

#### Web Mode

浏览器运行模式。

用于开发、调试与交互体验。

允许：

* Geolocation
* DOM UI
* 用户交互
* 调试工具

#### Screensaver Mode

macOS ScreenSaver.framework 托管模式。

用于正式屏保运行。

原则：

* 禁止引导页
* 禁止 Onboarding
* 禁止欢迎页
* 禁止运行时弹窗
* 禁止运行时设置界面
* 禁止依赖网络
* 禁止阻塞渲染

WKWebView 仅作为渲染容器。

Swift 宿主负责配置注入。

---

## 3. Zero-Blocking Rendering Principle

屏保启动后必须立即渲染。

禁止：

* 等待定位
* 等待网络
* 等待城市解析
* 等待时区计算
* 等待权限授权

任何情况下都不得出现黑屏等待状态。

---

## 4. Location System

### Location Mode

系统提供三种互斥模式：

#### Current Position

优先使用当前设备位置。

#### City

固定使用用户选择城市。

#### Manual Coordinates

固定使用用户输入经纬度。

---

### Current Position Principle

Current Position 是用户意图。

不是定位结果。

Current Position 不保证一定获得当前位置。

运行流程：

Current Position

↓

读取 Last Successful Snapshot

↓

立即渲染

↓

后台尝试刷新当前位置

↓

成功

↓

覆盖 Current Position Snapshot

↓

本次 Session 不刷新

↓

下次 Session 生效

---

### Current Position Session Rule

每次屏保启动最多获取一次位置。

禁止：

* 持续定位
* Significant Location Change
* Background Location Updates
* Session 内位置刷新

屏保运行期间位置固定。

---

### Permission Request Rule

唯一允许申请定位权限的入口：

Find Current Location

按钮。

禁止：

* 屏保启动时申请权限
* Preview 时申请权限
* 自动申请权限

---

### Current Position State

保存：

* cityId
* latitude
* longitude
* timezone
* displayName
* countryName
* updatedAt

每次成功获取位置后立即覆盖。

无距离阈值。

---

## 5. Location State Persistence

三套状态永久保留：

### Current Position State

最后一次成功定位结果。

### City State

最后一次选择城市。

### Manual Coordinate State

最后一次输入坐标。

切换模式时：

仅切换 activeMode。

不得删除其他模式数据。

---

## 6. City Search System

### 城市库

内置约 12000 个城市。

数据离线打包。

禁止联网查询。

---

### 搜索方式

即时搜索。

每输入一个字符立即过滤。

---

### 搜索结果

显示格式：

City, Country

例如：

Tokyo, Japan

Perth, Australia

London, United Kingdom

---

### 排序规则

Population DESC

人口越高优先级越高。

---

### 搜索语言

固定英文。

例如：

tok

per

lon

---

### 显示语言

根据当前 UI Language 动态显示：

Perth

珀斯

パース

伯斯

---

### 城市数据结构

每个城市至少包含：

* cityId
* timezone
* latitude
* longitude
* population
* countryCode
* names
* aliases

cityId 为唯一主键。

---

## 7. Manual Coordinates

### 输入格式

仅支持 Decimal Degrees。

例如：

-31.95

115.86

---

### 不支持

31°57′08″S

115°51′38″E

---

### 校验规则

Latitude:

-90 ~ 90

Longitude:

-180 ~ 180

非法坐标禁止保存。

---

### 时区处理

允许输入世界任意经纬度。

必须自动推断对应 IANA Timezone。

不得依赖最近城市。

---

### 显示规则

优先显示最近城市。

如果不存在合理城市：

显示：

经纬度 · 时间

例如：

115.86°E, 31.95°S · 22:41

---

## 8. Timezone Engine

系统内置离线时区映射能力。

支持：

Lat/Lon

↓

Timezone Lookup

↓

IANA Timezone

↓

Local Time

例如：

Australia/Perth

Asia/Tokyo

Europe/London

---

## 9. Preview Mode

Preview 仅加载已保存配置。

禁止：

* Runtime Location
* Permission Request
* 网络请求

Preview = Saved Configuration Preview

---

## 10. Options System

### Transaction Model

Options 不采用即时保存。

采用事务模式。

打开：

UserDefaults

↓

Form State

用户修改：

仅修改 Form State。

---

### Save

Validate

↓

Write UserDefaults

↓

Close

---

### Cancel

Discard Form State

↓

Close

---

### Window Close

等价于 Cancel。

关闭窗口即丢弃未保存修改。

---

### Find Current Location

仅更新 Form State。

不得立即写盘。

如果用户未点击 Save：

定位结果必须丢弃。

---

## 11. Display Settings

### Language

默认：

English

支持：

* English
* 简体中文
* 繁體中文
* 日本語

配置损坏时回退：

English

---

### Display Frequency

Slider：

Slow

Normal

Fast

映射：

Slow = 30s

Normal = 10s

Fast = 5s

默认：

Normal

---

### Text Glow Intensity

控制文字发光强度。

不控制屏幕亮度。

不控制背景亮度。

背景始终纯黑。

---

## 12. Runtime Display

底部统一显示：

City · Local Time

例如：

Perth · 22:41

珀斯 · 22:41

東京 · 22:41

时间来自目标地点时区。

不是设备时区。

---

## 13. Fallback Strategy

Fail Open。

任何异常情况下都必须继续运行。

禁止：

* 空白屏幕
* 崩溃
* 错误弹窗

---

### Ultimate Fallback

Royal Observatory Greenwich

作为最终兜底位置。

---

## 14. Debug Overlay

Debug Overlay 属于开发工具。

不是产品功能。

---

显示内容：

* Version
* Build Timestamp
* Runtime
* Active Mode
* Data Source
* Latitude
* Longitude
* Timezone
* Display Name
* Language
* Frequency
* Text Glow
* Last Successful Location UpdatedAt

用于快速定位：

* 缓存问题
* Bundle 问题
* 定位问题
* 配置问题

---

## 15. First Run Experience

不存在 First Run Experience。

不存在：

* Welcome
* Onboarding
* Tutorial
* First Launch Flow

第一次运行与第一百次运行行为完全一致。

进入屏保后立即展示宇宙内容。
