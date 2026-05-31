/**
 * @file entry-screensaver.js
 * @brief Entry point and controller logic for the macOS Screensaver application (bilingual comments).
 *        屏保端（macOS Screen Saver）专用的零网络/受限沙盒入口点与控制逻辑（中英双语注释）。
 */

import '../style.css'
import { getZenithCandidates, updateCandidateAltitude } from './astronomy.js'
import { generateCopy } from './copywriter.js'
import tzlookup from 'tz-lookup'
import { UI_TRANSLATIONS } from './i18n.js'

/**
 * @brief Helper function to check if debug mode is active inside the injected screensaver config.
 *        调试模式状态检测助手（读取 macOS 屏保容器注入的偏好设置）。
 */
function isDebugActive() {
  if (typeof window !== 'undefined' && window.MY_UNIVERSE_CONFIG && window.MY_UNIVERSE_CONFIG.debug) {
    return true;
  }
  return false;
}

// ==========================================
// Forensics Logging & Handlers for sandboxed debugging
// 沙盒环境下的全局异常捕获与法证日志记录，帮助在受限的 macOS 屏保容器中定位潜在崩溃
// ==========================================
window.onerror = function(msg, src, line, col, err) {
  if (isDebugActive()) {
    console.error(
      "[GLOBAL ERROR DETAIL]",
      msg,
      src,
      line,
      col,
      err ? err.stack : "no stack"
    );
  }
};

window.addEventListener("unhandledrejection", e => {
  if (isDebugActive()) {
    console.error("[PROMISE ERROR]", e.reason);
  }
});

// Global scope variables
// 屏保端全局状态变量
let runtimeConfig;
let currentLang;
let broadcasterScreen;
let mainCopyEl;
let metaInfoEl;
let locationTimeInfoEl;
let activeSatellites = []; // Screensaver operates 100% offline for sandbox safety / 屏保端保持 100% 离线计算以保障沙盒安全性

/**
 * @brief Retrieves the runtime configuration injected by the macOS Swift wrapper.
 *        安全获取 macOS 宿主 Swift 外壳在全局作用域注入的偏好设置。
 */
function getRuntimeConfig() {
  if (typeof window !== 'undefined' && window.MY_UNIVERSE_CONFIG) {
    return window.MY_UNIVERSE_CONFIG;
  }
  return { runtime: 'screensaver' };
}

/**
 * @brief Prohibits reading disk localStorage inside sandbox to bypass WKWebView strict security policies.
 *        沙盒写保护：在 macOS 屏保沙盒中直接返回兜底值，避免读写外部存储器触发系统异常。
 */
function safeLocalStorageGet(key, fallback = null) {
  return fallback;
}

/**
 * @brief Prohibits writing disk localStorage inside sandbox to bypass WKWebView strict security policies.
 *        沙盒写保护：在 macOS 屏保沙盒中直接拒绝写入操作，保障容器执行安全性。
 */
function safeLocalStorageSet(key, value) {
  return false;
}

/**
 * @brief Translates active UI elements and applies language typographic classes.
 *        应用语言排版规则，刷新屏保文本排版并注入针对语种微调的字体类。
 */
function applyLanguage() {
  const t = UI_TRANSLATIONS[currentLang];
  if (!t) return;
  
  if (currentLang === 'en') {
    document.body.classList.add('lang-en');
    document.body.classList.remove('lang-zh', 'lang-ja');
  } else if (currentLang === 'ja') {
    document.body.classList.add('lang-ja');
    document.body.classList.remove('lang-en', 'lang-zh');
  } else {
    document.body.classList.add('lang-zh');
    document.body.classList.remove('lang-en', 'lang-ja');
  }
}

/**
 * @brief Primary setup triggered immediately on DOM completion.
 *        屏保主初始化生命周期，提取 Swift 配置并进行零阻塞的视觉投递准备。
 */
function initializeZenith() {
  runtimeConfig = getRuntimeConfig();
  currentLang = runtimeConfig.language || 'zh';

  broadcasterScreen = document.getElementById('broadcaster');
  mainCopyEl = document.getElementById('main-copy');
  metaInfoEl = document.getElementById('meta-info');
  locationTimeInfoEl = document.getElementById('location-time-info');

  applyLanguage();

  // Screensaver layout setup
  // 注入屏保专用布局类，微调视觉占比
  document.body.classList.add('mode-screensaver');
  
  // Apply host-injected screen brightness percentage filter
  // 应用来自 macOS 选项面板滑动条注入的亮度滤镜
  if (runtimeConfig.brightness) {
    document.body.style.filter = `brightness(${runtimeConfig.brightness})`;
  }

  // Remove onboarding welcoming container completely for zero-blocking visual delivery
  // 彻底移除/隐藏 Web 端拥有的新手引导（Onboarding）容器，确保屏幕保护零阻碍、免交互瞬间呈现
  document.getElementById("intro")?.classList.remove("active");

  startBroadcasterSession(runtimeConfig);
}

/**
 * @brief Starts the astronomical calculation core session for the screensaver.
 *        启动核心天体计算会话，解析 Swift 注入的经纬度与地名数据，开启时序换算。
 */
function startBroadcasterSession(config = {}) {
  const t = UI_TRANSLATIONS[currentLang];
  let currentLat = typeof config.latitude === 'number' ? config.latitude : 51.4779;
  let currentLon = typeof config.longitude === 'number' ? config.longitude : -0.0015;
  let cityString, resolvedTimezone;

  // Use timezone from configuration, or lookup via coordinates
  // 优先采用 Swift 传入的城市时区；未指定时则通过经纬度库反查本地时区
  resolvedTimezone = config.timezone && config.timezone !== "" ? config.timezone : tzlookup(currentLat, currentLon);
  
  // Format the visual location name based on active location modes
  // 根据不同的定位模式，拼装最终呈现在屏保屏幕左上角的地理地名
  if (config.locationMode === 'city' || config.locationMode === 'default') {
    let parts = [config.cityName, config.regionName, config.countryName].filter(Boolean);
    cityString = parts.join(", ");
  } else if (config.locationMode === 'runtimeCurrentLocation') {
    if (config.language === 'zh-TW') {
      cityString = "當前位置 (設備即時)";
    } else if (config.language === 'zh') {
      cityString = "当前位置 (设备实时)";
    } else {
      cityString = "Current Location (Device)";
    }
  } else if (config.locationMode === 'currentLocation' || config.locationMode === 'savedCurrentLocation' || config.locationMode === 'currentPosition') {
    if (config.language === 'zh-TW') {
      cityString = "當前位置 (已保存)";
    } else if (config.language === 'zh') {
      cityString = "当前位置 (已保存)";
    } else {
      cityString = "Current Location (Saved)";
    }
  } else {
    cityString = `${Math.abs(currentLon).toFixed(2)}°${currentLon >= 0 ? 'E' : 'W'}, ${Math.abs(currentLat).toFixed(2)}°${currentLat >= 0 ? 'N' : 'S'}`;
  }
  
  // Build and overlay high-fidelity debugging info if debug mode is active
  // 如果调试模式被开启，动态向屏保边缘绘制半透明诊断图层，透视 Swift 通信元数据
  if (config.debug) {
    const debugDiv = document.createElement('div');
    debugDiv.style.position = 'absolute';
    debugDiv.style.bottom = '10px';
    debugDiv.style.left = '10px';
    debugDiv.style.color = 'rgba(0, 255, 0, 0.8)';
    debugDiv.style.fontFamily = 'monospace';
    debugDiv.style.fontSize = '12px';
    debugDiv.style.zIndex = '9999';
    debugDiv.style.backgroundColor = 'rgba(0,0,0,0.5)';
    debugDiv.style.padding = '8px';
    debugDiv.style.pointerEvents = 'none';
    debugDiv.innerHTML = `
      <strong>MyUniverseSaver DEBUG</strong><br>
      activeMode: ${config.locationMode}<br>
      dataSource: injected config (zero-blocking)<br>
      latitude: ${currentLat}<br>
      longitude: ${currentLon}<br>
      timezone: ${resolvedTimezone}<br>
      displayName: ${cityString}<br>
      buildTimestamp: ${config.buildTimestamp || 'unknown'}<br>
      updatedAt: ${config.updatedAt || '0'}
    `;
    document.body.appendChild(debugDiv);
  }

  let domeCandidates = [];
  let currentDomeIndex = 0;

  /**
   * @brief High-precision clock tick update, recalculating astronomical look-angles.
   *        时钟秒级震荡更新：以极高精度（3位小数）刷新天顶天体俯仰角与偏角数值。
   */
  function updateTime() {
    const date = new Date();
    const localeStr = currentLang === 'zh-TW' ? 'zh-TW' : currentLang === 'zh' ? 'zh-CN' : currentLang === 'ja' ? 'ja-JP' : 'en-US';
    
    let timeOptions = { hour: '2-digit', minute: '2-digit', hour12: false };
    if (resolvedTimezone) {
      try {
        timeOptions.timeZone = resolvedTimezone;
      } catch (e) {
        if (isDebugActive()) {
          console.warn("Invalid timezone from config/tz-lookup:", resolvedTimezone);
        }
      }
    }
    
    const timeString = date.toLocaleTimeString(localeStr, timeOptions);
    
    let displayCity = cityString;
    if (locationTimeInfoEl) {
      locationTimeInfoEl.textContent = `${displayCity} · ${timeString}`;
    }

    // Refresh candidate altitude real-time on clock ticking
    // 时钟的每一秒，驱动天顶星空候选列表中的活跃星体仰角和偏移偏角进行高频高精度重算
    if (domeCandidates && domeCandidates.length > 0) {
      const currentObj = domeCandidates[currentDomeIndex % domeCandidates.length];
      if (currentObj) {
        updateCandidateAltitude(currentObj, currentLat, currentLon, date);
        const currentT = UI_TRANSLATIONS[currentLang];
        const offZenith = (90 - currentObj.altitude).toFixed(3);
        const displayId = currentObj.id ? currentObj.id.toUpperCase() : 'STAR';
        if (currentObj.isSatellite) {
          metaInfoEl.innerHTML = `${currentObj.name.toUpperCase()} &nbsp;&middot;&nbsp; ${currentT.alt} ${currentObj.altitude.toFixed(3)}&deg; &nbsp;&middot;&nbsp; ${currentT.range} ${currentObj.distanceStr}`;
        } else {
          metaInfoEl.innerHTML = `${displayId} &nbsp;&middot;&nbsp; ${currentT.alt} ${currentObj.altitude.toFixed(3)}&deg; &nbsp;&middot;&nbsp; ${currentT.zenithOffset} ${offZenith}&deg;`;
        }
      }
    }
  }

  /**
   * @brief Filters active candidates inside 60-degree dome.
   *        穹顶锥形过滤器：计算此时此刻进入 60° 穹顶的可用天表候选队列。
   */
  function fetchDomeCandidates() {
    const date = new Date();
    try {
      domeCandidates = getZenithCandidates(currentLat, currentLon, date, activeSatellites) || [];
    } catch (e) {
      if (isDebugActive()) {
        console.error(e);
      }
      domeCandidates = [];
    }
  }

  /**
   * @brief Decodes current astronomical entity into localized poetic copy.
   *        解算当前处于轮播顶部的天体，组装相应的意境语段并输出渲染到正中央 DOM。
   */
  function renderCurrentCandidate() {
    if (!domeCandidates || domeCandidates.length === 0) {
      const currentT = UI_TRANSLATIONS[currentLang];
      metaInfoEl.innerHTML = `${currentT.lat} ${currentLat.toFixed(2)} &nbsp;&middot;&nbsp; ${currentT.lon} ${currentLon.toFixed(2)}`;
      mainCopyEl.textContent = "";
      return;
    }
    
    if (currentDomeIndex >= domeCandidates.length) {
      currentDomeIndex = 0;
    }

    const currentObj = domeCandidates[currentDomeIndex];
    const copy = generateCopy(currentObj, currentLang);
    mainCopyEl.textContent = copy;
    
    const currentT = UI_TRANSLATIONS[currentLang];
    const offZenith = (90 - currentObj.altitude).toFixed(3);
    
    const displayId = currentObj.id ? currentObj.id.toUpperCase() : 'STAR';
    
    if (currentObj.isSatellite) {
      metaInfoEl.innerHTML = `${currentObj.name.toUpperCase()} &nbsp;&middot;&nbsp; ${currentT.alt} ${currentObj.altitude.toFixed(3)}&deg; &nbsp;&middot;&nbsp; ${currentT.range} ${currentObj.distanceStr}`;
    } else {
      metaInfoEl.innerHTML = `${displayId} &nbsp;&middot;&nbsp; ${currentT.alt} ${currentObj.altitude.toFixed(3)}&deg; &nbsp;&middot;&nbsp; ${currentT.zenithOffset} ${offZenith}&deg;`;
    }
  }

  let isTransitioning = false;

  /**
   * @brief Coordinates the 3s HSL breathing curve to transition between stars.
   *        控制天体交替过渡：触发 3000ms 的慢速呼吸淡出淡入（对应 CSS 呼吸动画）。
   */
  function carouselTick() {
    if (domeCandidates.length <= 1 || isTransitioning) return;
    
    isTransitioning = true;
    const transitionDuration = 3000;
    
    mainCopyEl.classList.add('text-breath-out');
    metaInfoEl.classList.add('text-breath-out');
    
    setTimeout(() => {
      currentDomeIndex++;
      if (currentDomeIndex >= domeCandidates.length) {
        currentDomeIndex = 0;
      }
      renderCurrentCandidate();
      
      mainCopyEl.classList.remove('text-breath-out');
      metaInfoEl.classList.remove('text-breath-out');
      
      setTimeout(() => {
        isTransitioning = false;
      }, transitionDuration);
    }, transitionDuration);
  }

  // =========================================================================
  // Active Native Events Hooks (Driven by Swift native timers to prevent sandbox suspending)
  // 主动式 Swift 宿主脉冲钩子（由 Native Swift 定时器主动唤醒，规避沙盒机制对 JS 定时器的强制挂起）
  // =========================================================================
  window.triggerZenithUpdate = () => {
    updateTime();
    renderCurrentCandidate();
  };

  window.triggerCarouselTick = () => {
    carouselTick();
  };

  // Perform initial rendering and session display
  // 运行首发解算，装载数据并激活主屏
  fetchDomeCandidates();
  updateTime();
  renderCurrentCandidate();
  
  // Show broadcaster screen
  // 移除所有屏幕活跃状态，单独呈现播报主体屏幕
  document.querySelectorAll('.screen').forEach(el => el.classList.remove('active'));
  broadcasterScreen.classList.add('active');
}

// Start execution once DOM is ready
// 监听 DOM Ready 并按需调起核心入口点
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeZenith);
} else {
  initializeZenith();
}
