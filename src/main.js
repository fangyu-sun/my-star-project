import './style.css'
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
  switchScreen(loadingScreen);
  
  if (!navigator.geolocation) {
    alert('您的浏览器不支持获取地理位置。');
    switchScreen(introScreen);
    return;
  }

  let cityString = "未知地点";
  let updateInterval;

  function updateBroadcaster(lat, lon) {
    const date = new Date();
    const timeString = date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
    
    if (locationTimeInfoEl) {
      locationTimeInfoEl.textContent = `${cityString} · ${timeString}`;
    }
    
    try {
      const bestObj = getBestZenithObject(lat, lon, date, activeSatellites);
      const copy = generateCopy(bestObj);
      
      if (mainCopyEl.textContent !== copy) {
        mainCopyEl.textContent = copy;
      }
      
      if (bestObj) {
        const offZenith = (90 - bestObj.altitude).toFixed(1);
        if (bestObj.isSatellite) {
          metaInfoEl.innerHTML = `${bestObj.name.toUpperCase()} &nbsp;&middot;&nbsp; ALTITUDE ${bestObj.altitude.toFixed(1)}&deg; &nbsp;&middot;&nbsp; RANGE ${bestObj.distanceStr}`;
        } else {
          metaInfoEl.innerHTML = `${bestObj.id.toUpperCase()} &nbsp;&middot;&nbsp; ALTITUDE ${bestObj.altitude.toFixed(1)}&deg; &nbsp;&middot;&nbsp; ZENITH OFFSET ${offZenith}&deg;`;
        }
      } else {
        metaInfoEl.innerHTML = `LAT ${lat.toFixed(2)} &nbsp;&middot;&nbsp; LON ${lon.toFixed(2)}`;
      }
    } catch (e) {
      console.error(e);
    }
  }

  navigator.geolocation.getCurrentPosition(
    (position) => {
      const lat = position.coords.latitude;
      const lon = position.coords.longitude;
      fetch(`https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${lat}&longitude=${lon}&localityLanguage=zh`)
        .then(res => res.json())
        .then(data => {
          cityString = data.city || data.locality || data.principalSubdivision || '未知地点';
          updateBroadcaster(lat, lon);
        })
        .catch(() => {
          cityString = `${lat.toFixed(2)}, ${lon.toFixed(2)}`;
          updateBroadcaster(lat, lon);
        });
      
      updateBroadcaster(lat, lon);

      if (updateInterval) clearInterval(updateInterval);
      updateInterval = setInterval(() => {
        updateBroadcaster(lat, lon);
      }, 1000);
      
      // Wait a bit to simulate searching and let the animation play out
      setTimeout(() => {
        switchScreen(broadcasterScreen);
      }, 2000);
    },
    (error) => {
      console.error(error);
      alert('无法获取您的位置，请检查权限。');
      switchScreen(introScreen);
    },
    { timeout: 10000, enableHighAccuracy: false }
  );
});
