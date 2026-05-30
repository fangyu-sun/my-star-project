import '../style.css'
import { getZenithCandidates, updateCandidateAltitude } from './astronomy.js'
import { generateCopy } from './copywriter.js'
import tzlookup from 'tz-lookup'
import { UI_TRANSLATIONS } from './i18n.js'

// Helper function to check if debug mode is active (always false on web unless configured)
function isDebugActive() {
  return false;
}

// Global scope module-level variables
let currentLang;
let introScreen;
let loadingScreen;
let broadcasterScreen;
let mainCopyEl;
let metaInfoEl;
let locationTimeInfoEl;
let startBtn;
let activeSatellites = [];

function safeLocalStorageGet(key, fallback = null) {
  try {
    if (typeof window === 'undefined' || !window.localStorage) return fallback;
    const value = window.localStorage.getItem(key);
    return value === null ? fallback : value;
  } catch (e) {
    return fallback;
  }
}

function safeLocalStorageSet(key, value) {
  try {
    if (typeof window === 'undefined' || !window.localStorage) return false;
    window.localStorage.setItem(key, value);
    return true;
  } catch (e) {
    return false;
  }
}

async function loadActiveSatellites() {
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

function applyLanguage() {
  const t = UI_TRANSLATIONS[currentLang];
  
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
  
  document.querySelectorAll('.lang-inline-opt').forEach(btn => {
    if (btn.getAttribute('data-lang') === currentLang) {
      btn.classList.add('active');
    } else {
      btn.classList.remove('active');
    }
  });
}

function switchScreen(screenEl) {
  document.querySelectorAll('.screen').forEach(el => el.classList.remove('active'));
  if (screenEl) screenEl.classList.add('active');
}

function initializeZenith() {
  loadActiveSatellites();

  currentLang = safeLocalStorageGet('zenith_lang', 'zh');

  introScreen = document.getElementById('intro');
  loadingScreen = document.getElementById('loading');
  broadcasterScreen = document.getElementById('broadcaster');

  mainCopyEl = document.getElementById('main-copy');
  metaInfoEl = document.getElementById('meta-info');
  locationTimeInfoEl = document.getElementById('location-time-info');
  startBtn = document.getElementById('start-btn');

  applyLanguage();

  // Event listeners for inline language selector option buttons
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
      const mainCopyEl = document.getElementById('main-copy');
      const locationTimeInfoEl = document.getElementById('location-time-info');
      const metaInfoEl = document.getElementById('meta-info');
      
      const elementsToFade = [introTextEl, startBtnEl, mainCopyEl, locationTimeInfoEl, metaInfoEl];
      
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

function startBroadcasterSession() {
  const t = UI_TRANSLATIONS[currentLang];
  let currentLat, currentLon, cityString, isCityDynamic, resolvedTimezone;
  let cachedLatStr = safeLocalStorageGet('zenith_last_lat');
  let cachedLonStr = safeLocalStorageGet('zenith_last_lon');
  
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

  let carouselIntervalId = null;
  let isTransitioning = false;

  function carouselTick(isManual = false) {
    if (domeCandidates.length <= 1 || isTransitioning) return;
    
    isTransitioning = true;
    
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

  function startCarousel() {
    if (carouselIntervalId) clearInterval(carouselIntervalId);
    carouselIntervalId = setInterval(carouselTick, 10000); // 10s default frequency for web
  }

  broadcasterScreen.addEventListener('click', (e) => {
    if (e.target.closest('.lang-selector-top-right')) return;
    if (!isTransitioning && domeCandidates.length > 1) {
      carouselTick(true);
      startCarousel();
    }
  });

  window.triggerZenithUpdate = () => {
    updateTime();
    renderCurrentCandidate();
  };

  window.triggerCarouselTick = () => {
    carouselTick(false);
  };

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

  fetchDomeCandidates();
  updateTime();
  renderCurrentCandidate();
  switchScreen(broadcasterScreen);

  setInterval(updateTime, 1000);
  setInterval(fetchDomeCandidates, 60000);
  
  setTimeout(() => {
    carouselTick();
    startCarousel();
  }, 2500);

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
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeZenith);
} else {
  initializeZenith();
}
