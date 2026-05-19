import '../style.css'
import { getBestZenithObject } from './astronomy.js'
import { generateCopy } from './copywriter.js'

let activeSatellites = [];

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
    console.warn("Failed to fetch dynamic TLEs, falling back to local database.", e);
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
    console.warn("Failed to fetch Starlink TLEs.", err);
  }
}

// Start loading immediately on page load
loadActiveSatellites();

// --------------------- i18n Localization ---------------------
const UI_TRANSLATIONS = {
  zh: {
    introText: "此应用需要获取地理位置，<br>以计算此时此刻您上方的宇宙状态。",
    startBtn: "开启连接",
    fallbackCity: "北京 (默认位置)",
    cachedCity: "缓存位置",
    geoError: "您的浏览器不支持获取地理位置。",
    cityUnknown: "未知地点"
  },
  en: {
    introText: "This application requires location access<br>to calculate the cosmic state directly above you right now.",
    startBtn: "Connect",
    fallbackCity: "Beijing (Default Location)",
    cachedCity: "Cached Location",
    geoError: "Your browser does not support geolocation.",
    cityUnknown: "Unknown Location"
  },
  ja: {
    introText: "このアプリは現在地情報を取得し、<br>今この瞬間にあなたの真上にある宇宙の状態を计算します。",
    startBtn: "接続開始",
    fallbackCity: "北京 (デフォルト位置)",
    cachedCity: "キャッシュされた位置",
    geoError: "お使いのブラウザは位置情報の取得に対応していません。",
    cityUnknown: "未知の場所"
  }
};

let currentLang = localStorage.getItem('zenith_lang') || 'zh';

function applyLanguage() {
  const t = UI_TRANSLATIONS[currentLang];
  
  // Set lang class on body to allow styling changes based on language
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
  
  // Highlight active inline language selector option
  document.querySelectorAll('.lang-inline-opt').forEach(btn => {
    if (btn.getAttribute('data-lang') === currentLang) {
      btn.classList.add('active');
    } else {
      btn.classList.remove('active');
    }
  });
}

// --------------------- DOM Elements & Routing ---------------------
const introScreen = document.getElementById('intro');
const loadingScreen = document.getElementById('loading');
const broadcasterScreen = document.getElementById('broadcaster');

const mainCopyEl = document.getElementById('main-copy');
const metaInfoEl = document.getElementById('meta-info');
const locationTimeInfoEl = document.getElementById('location-time-info');
const startBtn = document.getElementById('start-btn');

function switchScreen(screenEl) {
  document.querySelectorAll('.screen').forEach(el => el.classList.remove('active'));
  screenEl.classList.add('active');
}

// Initialize language representation
applyLanguage();

// Event listeners for inline language option buttons
document.querySelectorAll('.lang-inline-opt').forEach(btn => {
  btn.addEventListener('click', (e) => {
    const selectedLang = e.currentTarget.getAttribute('data-lang');
    if (selectedLang === currentLang) return; // Ignore clicks on the already active language
    
    // Visually toggle active class immediately on the clicked item for instant tactile response
    document.querySelectorAll('.lang-inline-opt').forEach(b => b.classList.remove('active'));
    e.currentTarget.classList.add('active');
    
    currentLang = selectedLang;
    localStorage.setItem('zenith_lang', selectedLang);
    
    // Smooth slow breathing transition for the main text elements
    const introTextEl = document.getElementById('intro-text');
    const startBtnEl = document.getElementById('start-btn');
    
    if (introTextEl) introTextEl.classList.add('text-breath-out');
    if (startBtnEl) startBtnEl.classList.add('text-breath-out');
    
    // Wait for the slow fade-out breathing curve (800ms) to complete before changing text and fading back in
    setTimeout(() => {
      applyLanguage();
      if (introTextEl) introTextEl.classList.remove('text-breath-out');
      if (startBtnEl) startBtnEl.classList.remove('text-breath-out');
    }, 800);
  });
});

// --------------------- Connection Initiation ---------------------
startBtn.addEventListener('click', () => {
  const t = UI_TRANSLATIONS[currentLang];
  if (!navigator.geolocation) {
    alert(t.geoError);
    return;
  }

  // 1. Immediately read cached or default coordinates
  const cachedLatStr = localStorage.getItem('zenith_last_lat');
  const cachedLonStr = localStorage.getItem('zenith_last_lon');
  
  let currentLat, currentLon;
  let cityString = "";
  
  if (cachedLatStr && cachedLonStr) {
    currentLat = parseFloat(cachedLatStr);
    currentLon = parseFloat(cachedLonStr);
    cityString = localStorage.getItem('zenith_last_city') || t.cachedCity;
  } else {
    // Default to Beijing
    currentLat = 39.9042;
    currentLon = 116.4074;
    cityString = t.fallbackCity;
  }

  // 2. Setup the broadcaster updater function using the active scoped variables
  function updateBroadcaster() {
    const date = new Date();
    const localeStr = currentLang === 'zh' ? 'zh-CN' : currentLang === 'ja' ? 'ja-JP' : 'en-US';
    const timeString = date.toLocaleTimeString(localeStr, { hour: '2-digit', minute: '2-digit' });
    
    if (locationTimeInfoEl) {
      locationTimeInfoEl.textContent = `${cityString} · ${timeString}`;
    }
    
    try {
      const bestObj = getBestZenithObject(currentLat, currentLon, date, activeSatellites);
      const copy = generateCopy(bestObj, currentLang);
      
      if (mainCopyEl.textContent !== copy) {
        mainCopyEl.textContent = copy;
      }
      
      if (bestObj) {
        const offZenith = (90 - bestObj.altitude).toFixed(3);
        if (bestObj.isSatellite) {
          metaInfoEl.innerHTML = `${bestObj.name.toUpperCase()} &nbsp;&middot;&nbsp; ALTITUDE ${bestObj.altitude.toFixed(3)}&deg; &nbsp;&middot;&nbsp; RANGE ${bestObj.distanceStr}`;
        } else {
          metaInfoEl.innerHTML = `${bestObj.id.toUpperCase()} &nbsp;&middot;&nbsp; ALTITUDE ${bestObj.altitude.toFixed(3)}&deg; &nbsp;&middot;&nbsp; ZENITH OFFSET ${offZenith}&deg;`;
        }
      } else {
        metaInfoEl.innerHTML = `LAT ${currentLat.toFixed(2)} &nbsp;&middot;&nbsp; LON ${currentLon.toFixed(2)}`;
      }
    } catch (e) {
      console.error(e);
    }
  }

  // 3. Immediately render the cached sky state and transition to broadcaster (no loading screen block!)
  updateBroadcaster();
  switchScreen(broadcasterScreen);

  // 4. Start the 1-second ticks using the active coordinates
  let updateInterval = setInterval(updateBroadcaster, 1000);

  // 5. Query for fresh real-time coordinates in the background silently
  navigator.geolocation.getCurrentPosition(
    (position) => {
      const freshLat = position.coords.latitude;
      const freshLon = position.coords.longitude;
      
      // Update active coordinates
      currentLat = freshLat;
      currentLon = freshLon;
      
      localStorage.setItem('zenith_last_lat', freshLat);
      localStorage.setItem('zenith_last_lon', freshLon);

      // Perform background geocoding to refine the city name in the selected language
      fetch(`https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${freshLat}&longitude=${freshLon}&localityLanguage=${currentLang}`)
        .then(res => res.json())
        .then(data => {
          cityString = data.city || data.locality || data.principalSubdivision || t.cityUnknown;
          localStorage.setItem('zenith_last_city', cityString);
          updateBroadcaster();
        })
        .catch(() => {
          cityString = `${freshLat.toFixed(2)}, ${freshLon.toFixed(2)}`;
          updateBroadcaster();
        });
      
      // Instantly trigger an update with the fresh coordinates
      updateBroadcaster();
    },
    (error) => {
      console.warn("Background geolocation refresh failed or was declined.", error);
      // We do not show any annoying error alert since the cached/default location is already running beautifully!
    },
    { enableHighAccuracy: false, timeout: 15000, maximumAge: 0 }
  );
});
