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

startBtn.addEventListener('click', () => {
  if (!navigator.geolocation) {
    alert('您的浏览器不支持获取地理位置。');
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
    cityString = localStorage.getItem('zenith_last_city') || "缓存位置";
  } else {
    // Default to Beijing
    currentLat = 39.9042;
    currentLon = 116.4074;
    cityString = "北京 (默认位置)";
  }

  // 2. Setup the broadcaster updater function using the active scoped variables
  function updateBroadcaster() {
    const date = new Date();
    const timeString = date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
    
    if (locationTimeInfoEl) {
      locationTimeInfoEl.textContent = `${cityString} · ${timeString}`;
    }
    
    try {
      const bestObj = getBestZenithObject(currentLat, currentLon, date, activeSatellites);
      const copy = generateCopy(bestObj);
      
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

      // Perform background geocoding to refine the city name
      fetch(`https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${freshLat}&longitude=${freshLon}&localityLanguage=zh`)
        .then(res => res.json())
        .then(data => {
          cityString = data.city || data.locality || data.principalSubdivision || '未知地点';
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
