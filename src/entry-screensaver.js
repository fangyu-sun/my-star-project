import '../style.css'
import { getZenithCandidates, updateCandidateAltitude } from './astronomy.js'
import { generateCopy } from './copywriter.js'
import tzlookup from 'tz-lookup'
import { UI_TRANSLATIONS } from './i18n.js'

// Helper function to check if debug mode is active
function isDebugActive() {
  if (typeof window !== 'undefined' && window.MY_UNIVERSE_CONFIG && window.MY_UNIVERSE_CONFIG.debug) {
    return true;
  }
  return false;
}

// Forensics Logging & Handlers for sandboxed debugging
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
let runtimeConfig;
let currentLang;
let broadcasterScreen;
let mainCopyEl;
let metaInfoEl;
let locationTimeInfoEl;
let activeSatellites = []; // Screensaver operates 100% offline for sandbox safety

function getRuntimeConfig() {
  if (typeof window !== 'undefined' && window.MY_UNIVERSE_CONFIG) {
    return window.MY_UNIVERSE_CONFIG;
  }
  return { runtime: 'screensaver' };
}

function safeLocalStorageGet(key, fallback = null) {
  // Prohibit reading disk localStorage inside sandbox
  return fallback;
}

function safeLocalStorageSet(key, value) {
  // Prohibit writing disk localStorage inside sandbox
  return false;
}

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

function initializeZenith() {
  runtimeConfig = getRuntimeConfig();
  currentLang = runtimeConfig.language || 'zh';

  broadcasterScreen = document.getElementById('broadcaster');
  mainCopyEl = document.getElementById('main-copy');
  metaInfoEl = document.getElementById('meta-info');
  locationTimeInfoEl = document.getElementById('location-time-info');

  applyLanguage();

  // Screensaver layout setup
  document.body.classList.add('mode-screensaver');
  
  if (runtimeConfig.brightness) {
    document.body.style.filter = `brightness(${runtimeConfig.brightness})`;
  }

  // Remove onboarding welcoming container completely for zero-blocking visual delivery
  document.getElementById("intro")?.classList.remove("active");

  startBroadcasterSession(runtimeConfig);
}

function startBroadcasterSession(config = {}) {
  const t = UI_TRANSLATIONS[currentLang];
  let currentLat = typeof config.latitude === 'number' ? config.latitude : 51.4779;
  let currentLon = typeof config.longitude === 'number' ? config.longitude : -0.0015;
  let cityString, resolvedTimezone;

  resolvedTimezone = config.timezone && config.timezone !== "" ? config.timezone : tzlookup(currentLat, currentLon);
  
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
  
  // Debug Overlay for Screensaver mode
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

  // Active Native Events Hooks (Driven by Swift native timers to prevent sandbox suspending)
  window.triggerZenithUpdate = () => {
    updateTime();
    renderCurrentCandidate();
  };

  window.triggerCarouselTick = () => {
    carouselTick();
  };

  fetchDomeCandidates();
  updateTime();
  renderCurrentCandidate();
  
  // Show broadcaster screen
  document.querySelectorAll('.screen').forEach(el => el.classList.remove('active'));
  broadcasterScreen.classList.add('active');
}

// Start execution once DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeZenith);
} else {
  initializeZenith();
}
