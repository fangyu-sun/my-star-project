import './style.css'
import { getBestZenithObject } from './astronomy.js'
import { generateCopy } from './copywriter.js'

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
  let currentBest;

  function displayBest(obj) {
    if (!obj) {
      mainCopyEl.textContent = "此刻的天顶深处，仅余无垠暗空。";
      metaInfoEl.innerHTML = "";
      return;
    }
    const copy = generateCopy(obj);
    // If the object changed, fade out/in
    if (!currentBest || obj.id !== currentBest.id) {
      // fade out
      mainCopyEl.style.opacity = '0';
      metaInfoEl.style.opacity = '0';
      setTimeout(() => {
        mainCopyEl.textContent = copy;
        mainCopyEl.style.opacity = '1';
        // Update meta info immediately after fade-in
        const offZenith = (90 - obj.altitude).toFixed(1);
        metaInfoEl.innerHTML = `${obj.id.toUpperCase()} &nbsp;&middot; ALTITUDE ${obj.altitude.toFixed(1)}° &nbsp;&middot; ZENITH OFFSET ${offZenith}°`;
        metaInfoEl.style.opacity = '1';
        currentBest = obj;
      }, 500);
    } else {
      // same object, just update altitude & offset
      mainCopyEl.textContent = copy;
      const offZenith = (90 - obj.altitude).toFixed(1);
      metaInfoEl.innerHTML = `${obj.id.toUpperCase()} &nbsp;&middot; ALTITUDE ${obj.altitude.toFixed(1)}° &nbsp;&middot; ZENITH OFFSET ${offZenith}°`;
    }
  }

  function updateBroadcaster(lat, lon) {
    const date = new Date();
    const timeString = date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
    if (locationTimeInfoEl) {
      locationTimeInfoEl.textContent = `${cityString} · ${timeString}`;
    }
    const bestObj = getBestZenithObject(lat, lon, date);
    displayBest(bestObj);
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
        // Define a helper to start interval updates
        function startUpdates(lat, lon) {
          // Ensure only one interval runs
          if (updateInterval) clearInterval(updateInterval);
          updateInterval = setInterval(() => {
            updateBroadcaster(lat, lon);
          }, 5000);
          // Initial display
          updateBroadcaster(lat, lon);
        }
        startUpdates(lat, lon);
      // Wait a bit to simulate searching and let the animation play out
      setTimeout(() => {
        switchScreen(broadcasterScreen);
      }, 2000);
    },
    (error) => {
      console.error(error);
      // Fallback to Beijing coordinates
      const lat = 39.9042;
      const lon = 116.4074;
      cityString = '北京';
      startUpdates(lat, lon);
      // Switch to broadcaster after brief delay
      setTimeout(() => {
        switchScreen(broadcasterScreen);
      }, 2000);
    },
    { timeout: 10000, enableHighAccuracy: false }
  );
});
