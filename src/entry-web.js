/**
 * @file entry-web.js
 * @brief Entry point and controller logic for the Web Client application (bilingual comments).
 *        网页端（Web Client）专用的高交互入口点与主控制逻辑（中英双语注释）。
 */

import '../style.css'
import { getZenithCandidates, updateCandidateAltitude } from './astronomy.js'
import { generateCopy } from './copywriter.js'
import tzlookup from 'tz-lookup'
import { UI_TRANSLATIONS } from './i18n.js'

// Helper function to check if debug mode is active (always false on web unless configured)
// 调试模式状态检测助手（在网页端默认保持关闭）
function isDebugActive() {
  return false;
}

// Global scope module-level variables
// 网页端全局状态变量
let currentLang;
let introScreen;
let loadingScreen;
let broadcasterScreen;
let mainCopyEl;
let metaInfoEl;
let locationTimeInfoEl;
let startBtn;
let activeSatellites = []; // Dynamic satellite TLE database / 动态人造空间轨道根数库

/**
 * @brief Safely reads key values from localStorage without throwing exceptions.
 *        安全地从本地 localStorage 中提取缓存值，阻断并包容一切浏览器权限报错。
 */
function safeLocalStorageGet(key, fallback = null) {
  try {
    if (typeof window === 'undefined' || !window.localStorage) return fallback;
    const value = window.localStorage.getItem(key);
    return value === null ? fallback : value;
  } catch (e) {
    return fallback;
  }
}

/**
 * @brief Safely writes key values to localStorage.
 *        安全地向本地 localStorage 写入配置键值，保障沙盒隔离安全。
 */
function safeLocalStorageSet(key, value) {
  try {
    if (typeof window === 'undefined' || !window.localStorage) return false;
    window.localStorage.setItem(key, value);
    return true;
  } catch (e) {
    return false;
  }
}

/**
 * @brief Asynchronously fetches real-time dynamic TLE elements from international API.
 *        异步拉取国际空间物数据库的动态 TLE 轨道根数，以保障人造卫星（如 ISS、星链）计算的时效性。
 */
async function loadActiveSatellites() {
  // 1. Fetch top popular dynamic satellites (including ISS)
  // 1. 拉取国际最热门人造太空物（包含国际空间站 ISS 等）
  try {
    const response = await fetch('https://tle.ivanstanojevic.me/api/tle/?page-size=50&sort=popularity');
    const data = await response.json();
    if (data && data.member && data.member.length > 0) {
      activeSatellites = data.member.map(sat => ({
        satelliteId: sat.satelliteId,
        name: sat.name,
        line1: sat.line1,
        line2: sat.line2
      }));
    }
  } catch (e) {
    if (isDebugActive()) {
      console.warn("Failed to fetch dynamic TLEs, falling back to local database.", e);
    }
  }
  
  // 2. Fetch active Starlink dynamic coordinates
  // 2. 额外拉取 SpaceX 活跃星链的实时轨道数据
  try {
    const responseStarlink = await fetch('https://tle.ivanstanojevic.me/api/tle/?search=STARLINK&page-size=40');
    const dataStarlink = await responseStarlink.json();
    if (dataStarlink && dataStarlink.member && dataStarlink.member.length > 0) {
      const starlinks = dataStarlink.member.map(sat => ({
        satelliteId: sat.satelliteId,
        name: sat.name,
        line1: sat.line1,
        line2: sat.line2
      }));
      activeSatellites = [...activeSatellites, ...starlinks];
    }
  } catch (err) {
    if (isDebugActive()) {
      console.warn("Failed to fetch Starlink TLEs.", err);
    }
  }
}

/**
 * @brief Translates active UI elements and applies language styles.
 *        应用当前语言包，刷新 onboarding 文字并动态切换正文排版字体类。
 */
function applyLanguage() {
  const t = UI_TRANSLATIONS[currentLang];
  
  // Set typographic font-family overrides based on language
  // 针对不同语种，动态注入定制的无衬线/衬线高保真排版类
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
  
  const introTextEl = document.getElementById('intro-text');
  const startBtnEl = document.getElementById('start-btn');
  
  if (introTextEl) introTextEl.innerHTML = t.introText;
  if (startBtnEl) startBtnEl.textContent = t.startBtn;
  
  // Render active states on language inline selector option toggles
  // 刷新语言栏高亮态，与天顶恒星进行冥想呼吸频率咬合
  document.querySelectorAll('.lang-inline-opt').forEach(btn => {
    if (btn.getAttribute('data-lang') === currentLang) {
      btn.classList.add('active');
    } else {
      btn.classList.remove('active');
    }
  });
}

/**
 * @brief Smoothly transitions between layout screens.
 *        平滑切换界面屏幕视图（利用 CSS 渐变阻断指针穿透）。
 */
function switchScreen(screenEl) {
  document.querySelectorAll('.screen').forEach(el => el.classList.remove('active'));
  if (screenEl) screenEl.classList.add('active');
}

/**
 * @brief Main DOM entry setup and listener initialization.
 *        网页端 DOM 加载完毕后的主初始化逻辑与事件监听注册。
 */
function initializeZenith() {
  loadActiveSatellites();

  // Load language settings from localStorage fallback to simplified Chinese
  // 读取用户语言偏好设置，默认兜底为“简体中文”
  currentLang = safeLocalStorageGet('zenith_lang', 'zh');

  introScreen = document.getElementById('intro');
  loadingScreen = document.getElementById('loading');
  broadcasterScreen = document.getElementById('broadcaster');

  mainCopyEl = document.getElementById('main-copy');
  metaInfoEl = document.getElementById('meta-info');
  locationTimeInfoEl = document.getElementById('location-time-info');
  startBtn = document.getElementById('start-btn');

  applyLanguage();

  // 1. Setup inline language switcher clicks
  // 1. 绑定欢迎页/播报页右上角语言栏切换行为（含 2.5s Meditative 渐隐渐显过滤）
  document.querySelectorAll('.lang-inline-opt').forEach(btn => {
    btn.addEventListener('click', (e) => {
      const selectedLang = e.currentTarget.getAttribute('data-lang');
      if (selectedLang === currentLang) return;
      
      document.querySelectorAll('.lang-inline-opt').forEach(b => b.classList.remove('active'));
      document.querySelectorAll(`.lang-inline-opt[data-lang="${selectedLang}"]`).forEach(el => el.classList.add('active'));
      
      currentLang = selectedLang;
      safeLocalStorageSet('zenith_lang', selectedLang);
      
      const introTextEl = document.getElementById('intro-text');
      const startBtnEl = document.getElementById('start-btn');
      const mainCopy = document.getElementById('main-copy');
      const locationTimeInfo = document.getElementById('location-time-info');
      const metaInfo = document.getElementById('meta-info');
      
      const elementsToFade = [introTextEl, startBtnEl, mainCopy, locationTimeInfo, metaInfo];
      
      elementsToFade.forEach(el => {
        if (el) el.classList.add('text-breath-out');
      });
      
      setTimeout(() => {
        applyLanguage();
        
        if (typeof window.triggerZenithUpdate === 'function') {
          window.triggerZenithUpdate();
        }
        if (typeof window.triggerGeocodeRefine === 'function') {
          window.triggerGeocodeRefine();
        }
        
        elementsToFade.forEach(el => {
          if (el) el.classList.remove('text-breath-out');
        });
      }, 2500);
    });
  });

  // 2. Setup onboarding start button click
  // 2. 绑定首屏开启按钮，呼出浏览器位置授权请求
  if (startBtn) {
    startBtn.addEventListener('click', () => {
      const t = UI_TRANSLATIONS[currentLang];
      if (!navigator.geolocation) {
        alert(t.geoError);
        return;
      }

      startBtn.textContent = t.geoAcquiring;
      startBtn.style.pointerEvents = "none";

      setTimeout(() => {
        startBroadcasterSession();
      }, 1500);
    });
  }
}

/**
 * @brief Starts the actual broadcaster core loop.
 *        正式开启宇宙天体数据播报会话主循环。
 */
function startBroadcasterSession() {
  const t = UI_TRANSLATIONS[currentLang];
  let currentLat, currentLon, cityString, isCityDynamic, resolvedTimezone;
  let cachedLatStr = safeLocalStorageGet('zenith_last_lat');
  let cachedLonStr = safeLocalStorageGet('zenith_last_lon');
  
  // Restore cached coordinates, or fallback to Royal Greenwich Observatory
  // 提取用户本地的 GPS 缓存，若无缓存，默认定位到英国皇家格林威治天文台 (Greenwich)
  if (cachedLatStr && cachedLonStr) {
    currentLat = parseFloat(cachedLatStr);
    currentLon = parseFloat(cachedLonStr);
    cityString = safeLocalStorageGet('zenith_last_city') || t.cachedCity;
    isCityDynamic = !safeLocalStorageGet('zenith_last_city');
  } else {
    currentLat = 51.4779;
    currentLon = -0.0015;
    cityString = t.fallbackCity;
    isCityDynamic = true;
  }
  
  resolvedTimezone = tzlookup(currentLat, currentLon);

  let domeCandidates = [];
  let currentDomeIndex = 0;

  /**
   * @brief Updates clock ticking and refreshes Zenith star metadata in real-time.
   *        驱动时钟的秒级运转，并在时钟脉冲下重新换算天顶星体的实时物理元数据。
   */
  function updateTime() {
    const date = new Date();
    const localeStr = currentLang === 'zh-TW' ? 'zh-TW' : currentLang === 'zh' ? 'zh-CN' : currentLang === 'ja' ? 'ja-JP' : 'en-US';
    
    let timeOptions = { hour: '2-digit', minute: '2-digit', hour12: false };
    const timeString = date.toLocaleTimeString(localeStr, timeOptions);
    
    let displayCity = cityString;
    if (isCityDynamic) {
      displayCity = (currentLang === 'zh' || currentLang === 'zh-TW') ? '格林威治' : currentLang === 'ja' ? 'グリニッジ' : 'Greenwich';
      if (cachedLatStr && cachedLonStr && !safeLocalStorageGet('zenith_last_city')) {
        displayCity = UI_TRANSLATIONS[currentLang].cachedCity;
      }
    }

    if (locationTimeInfoEl) {
      locationTimeInfoEl.textContent = `${displayCity} · ${timeString}`;
    }

    // Refresh candidate altitude and ranges on every clock tick
    // 在时钟每一秒钟的振荡下，高精度滚跳更新当前星体仰角小数点后三位
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
   *        计算过滤此时此刻进入 60° 穹顶的可用天体星表候选队列。
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
   * @brief Resolves custom text templates and outputs them to the DOM.
   *        解算当前天体的本地化诗意文案，并渲染输出到网页中央的 #main-copy 容器中。
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

  let carouselIntervalId = null;
  let isTransitioning = false;

  /**
   * @brief Handles carousel transitions with standard HSL breathing curve.
   *        控制天体轮播的 3s 呼吸渐隐渐显（3s暗、3s亮、4s恒亮展示）。
   * @param isManual True if manually triggered by clicking / 是否由用户点击屏幕手动触发
   */
  function carouselTick(isManual = false) {
    if (domeCandidates.length <= 1 || isTransitioning) return;
    
    isTransitioning = true;
    
    // Manual click uses 600ms fast transition, auto carousel uses 3000ms slow breath transition
    // 用户手动点击使用 600ms 快速切歌；系统自动轮播使用 3000ms 慢速过渡
    const transitionDuration = isManual ? 600 : 3000;
    
    if (isManual) {
      mainCopyEl.classList.add('fast-transition');
      metaInfoEl.classList.add('fast-transition');
    }
    
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
        if (isManual) {
          mainCopyEl.classList.remove('fast-transition');
          metaInfoEl.classList.remove('fast-transition');
        }
      }, transitionDuration);
    }, transitionDuration);
  }

  /**
   * @brief Schedules the 10-second default auto-carousel loop.
   *        设置 10 秒为周期的自动播放定时器（对应 HSL 冥想呼吸节奏）。
   */
  function startCarousel() {
    if (carouselIntervalId) clearInterval(carouselIntervalId);
    carouselIntervalId = setInterval(carouselTick, 10000);
  }

  // Bind full-screen click event for manual skipping
  // 绑定网页中央背景的点击事件，供用户手动高速切歌切换天体
  broadcasterScreen.addEventListener('click', (e) => {
    if (e.target.closest('.lang-selector-top-right')) return;
    if (!isTransitioning && domeCandidates.length > 1) {
      carouselTick(true);
      startCarousel();
    }
  });

  // Global triggers
  window.triggerZenithUpdate = () => {
    updateTime();
    renderCurrentCandidate();
  };

  window.triggerCarouselTick = () => {
    carouselTick(false);
  };

  /**
   * @brief Refines coordinates into actual geocoded city name.
   *        地理解析：反向拉取位置接口，将经纬度转换为人类可读的城市地名，写入缓存。
   */
  window.triggerGeocodeRefine = function() {
    if (currentLat && currentLon) {
      fetch(`https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${currentLat}&longitude=${currentLon}&localityLanguage=${currentLang}`)
        .then(res => res.json())
        .then(data => {
          cityString = data.city || data.locality || data.principalSubdivision || UI_TRANSLATIONS[currentLang].cityUnknown;
          safeLocalStorageSet('zenith_last_city', cityString);
          isCityDynamic = false;
          updateTime();
        })
        .catch(() => {});
    }
  };

  // Launch initial execution
  // 启动核心解算，切换至播报主体屏幕
  fetchDomeCandidates();
  updateTime();
  renderCurrentCandidate();
  switchScreen(broadcasterScreen);

  // Set refresh intervals
  // 设定时钟的 1.0s 定时更新与 Kepler 轨道每隔 1.0m 的二次刷新
  setInterval(updateTime, 1000);
  setInterval(fetchDomeCandidates, 60000);
  
  setTimeout(() => {
    carouselTick();
    startCarousel();
  }, 2500);

  // Trigger high-precision navigator.geolocation query in background
  // 后台静默发起浏览器的 Geolocation GPS 高精定位刷新
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const freshLat = position.coords.latitude;
        const freshLon = position.coords.longitude;
        
        currentLat = freshLat;
        currentLon = freshLon;
        safeLocalStorageSet('zenith_last_lat', freshLat);
        safeLocalStorageSet('zenith_last_lon', freshLon);

        fetch(`https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${freshLat}&longitude=${freshLon}&localityLanguage=${currentLang}`)
          .then(res => res.json())
          .then(data => {
            cityString = data.city || data.locality || data.principalSubdivision || UI_TRANSLATIONS[currentLang].cityUnknown;
            safeLocalStorageSet('zenith_last_city', cityString);
            isCityDynamic = false;
            updateTime();
          })
          .catch(() => {
            cityString = `${freshLat.toFixed(2)}, ${freshLon.toFixed(2)}`;
            isCityDynamic = false;
            updateTime();
          });
        
        fetchDomeCandidates();
        currentDomeIndex = 0;
        renderCurrentCandidate();
      },
      (error) => {
        if (isDebugActive()) {
          console.warn("Background geolocation refresh failed or was declined.", error);
        }
      },
      { enableHighAccuracy: false, timeout: 15000, maximumAge: 0 }
    );
  }
}

// Start execution once DOM is ready
// 等待 DOM 准备就绪，安全切入生命周期入口
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeZenith);
} else {
  initializeZenith();
}
