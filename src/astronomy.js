/**
 * @file astronomy.js
 * @brief Astronomy engine & coordinate calculation module (bilingual comments).
 *        天文学解算引擎与天顶星空候选体筛选模块（中英双语注释）。
 */

import { Observer, Body, Equator, Horizon } from 'astronomy-engine';
import famousStars from './data/stars.json';
import hygStars from './data/hyg_stars.json';
import { constellations } from './data/constellations.js';
import { getSatelliteLookAngles } from './satellite_engine.js';
import fallbackSatellites from './data/satellites_fallback.json';

/**
 * @brief Local list of solar system planets evaluated for zenith crossing.
 *        用于参与天顶交会筛选的太阳系内核心天体/行星列表。
 */
const planets = [
    { id: 'Sun', name: '太阳', isPlanet: true },
    { id: 'Moon', name: '月亮', isPlanet: true },
    { id: 'Jupiter', name: '木星', isPlanet: true },
    { id: 'Venus', name: '金星', isPlanet: true },
    { id: 'Mars', name: '火星', isPlanet: true },
    { id: 'Saturn', name: '土星', isPlanet: true }
];

/**
 * @brief Selects celestial objects currently crossing the observer's 60-degree Zenith dome.
 *        筛选出当前正处于观测者正上方 60° 天顶穹顶圆锥内的所有可见天体。
 * @param lat Observer latitude (degrees) / 观测者纬度（度）
 * @param lon Observer longitude (degrees) / 观测者经度（度）
 * @param date Current calculation date object / 当前计算时间对象
 * @param activeSatellites Realtime satellite dynamic TLE list / 实时拉取的动态卫星轨道根数列表
 * @return List of candidates sorted by priority scores / 按权重分数降序排列的候选星体列表
 */
export function getZenithCandidates(lat, lon, date, activeSatellites) {
    // 1. Initialize Astronomy-Engine observer at sea level (elevation = 0)
    // 1. 初始化天文学引擎观测者，海拔高度设为 0（海平面）
    const observer = new Observer(lat, lon, 0);
    const candidates = [];

    // ==========================================
    // Phase 1: Evaluate Solar System Planets
    // 第一阶段：解算太阳系核心天体（行星）
    // ==========================================
    for (const p of planets) {
        const body = Body[p.id];
        // Calculate geocentric equatorial coordinates (RA/DEC)
        // 计算地心赤道坐标系（赤经 RA / 赤纬 DEC）
        const eq = Equator(body, date, observer, true, true);
        // Transform equatorial coordinates into horizontal system (Alt/Az)
        // 将赤道坐标系转换到地平坐标系，获取仰角 Altitude 与方位角 Azimuth
        const hor = Horizon(date, observer, eq.ra, eq.dec, 'normal');
        
        // Filter by the strict 60-degree Zenith Dome cone threshold
        // 严格遵守 60° 穹顶雷达阈值筛选（仰角 >= 60° 即天顶角 <= 30°）
        if (hor.altitude >= 60) {
            // Convert Astronomical Units (AU) distance to kilometers
            // 将天文学单位 AU 距离转换为公里级 (1 AU = 1.496 * 10^8 km)
            const distKm = eq.dist * 1.496e8;
            let distStr = "";
            if (distKm > 1e8) {
                distStr = (distKm / 1e8).toFixed(1) + " 亿公里";
            } else if (distKm > 1e4) {
                distStr = (distKm / 1e4).toFixed(1) + " 万公里";
            } else {
                distStr = distKm.toFixed(0) + " 公里";
            }

            candidates.push({
                ...p,
                altitude: hor.altitude,
                distanceStr: distStr,
                isPlanet: true
            });
        }
    }

    // ==========================================
    // Phase 2: Evaluate Famous Bright Stars
    // 第二阶段：解算著名/极高亮恒星（如天狼星、织女星等）
    // ==========================================
    for (const star of famousStars) {
        // Convert star's fixed RA/DEC to observer's local Altitude
        // 将恒星的恒定赤经/赤纬直接地平化，获取此时此刻观测点的高度角
        const hor = Horizon(date, observer, star.ra, star.dec, 'normal');
        if (hor.altitude >= 60) {
            candidates.push({
                ...star,
                altitude: hor.altitude,
                distanceStr: star.distance + " 光年",
                isPlanet: false,
                isFamous: true
            });
        }
    }

    // ==========================================
    // Phase 3: Evaluate HYG Background Star Catalog
    // 第三阶段：解算 HYG 暗星/普通背景恒星星表数据
    // ==========================================
    for (const star of hygStars) {
        const hor = Horizon(date, observer, star.ra, star.dec, 'normal');
        if (hor.altitude >= 60) {
            // Retrieve localized constellation name from shared constellations database
            // 从共享星表中提取星座名称，若无对应星座则标记为无名暗星
            const conName = constellations[star.con] ? `位于${constellations[star.con]}的恒星` : '暗星';
            candidates.push({
                ...star,
                name: conName,
                altitude: hor.altitude,
                distanceStr: star.distanceLy + " 光年",
                isPlanet: false,
                isFamous: false
            });
        }
    }
    
    // ==========================================
    // Phase 4: Propagate Artificial Satellites (SGP4)
    // 第四阶段：解算高精度人造空间轨道物（如 ISS, 星链等）
    // ==========================================
    const satsToEvaluate = (activeSatellites && activeSatellites.length > 0) ? activeSatellites : fallbackSatellites;
    for (const sat of satsToEvaluate) {
        // Run SGP4 orbit propagation algorithm via satellite engine
        // 调用卫星物理引擎进行 SGP4 轨道递推，换算顶心高度角、方位角与斜距
        const look = getSatelliteLookAngles(sat.line1, sat.line2, lat, lon, date);
        if (look && look.elevation >= 60) {
            candidates.push({
                id: sat.satelliteId ? `sat_${sat.satelliteId}` : sat.name,
                name: sat.name,
                altitude: look.elevation,
                distanceStr: look.range.toFixed(0) + " 公里",
                isPlanet: false,
                isFamous: false,
                isSatellite: true
            });
        }
    }

    // ==========================================
    // Phase 5: Meditative Scoring & Weight Allocation
    // 第五阶段：冥想优先度加权评分系统
    // ==========================================
    // Base score is normalized altitude: (altitude / 90)
    // Preference is allocated to highly dramatic/rare objects (ISS > Sun/Moon > Planets > Stars)
    // 基础分基于仰角的近天顶比例 (altitude / 90)，
    // 再根据天体的罕见度/戏剧性分配不同加权，让极富故事感的航天太空站、太阳、月球、行星优先轮播。
    candidates.forEach(c => {
        let weight = 1.0;
        if (c.isSatellite) weight = 2.0;               // High dramatic rate / 太空站高速巡航飞越极具动态感
        else if (c.id === 'Moon' || c.id === 'Sun') weight = 1.5; // High emotional anchor / 强情感寄托天体
        else if (c.isPlanet) weight = 1.3;              // Solar System neighbors / 太阳系邻居行星
        else if (c.isFamous) weight = 1.2;              // Named historical stars / 著名历史名星
        else weight = 1.0;                              // Standard deep space background / 普通背景星座暗星

        c.score = (c.altitude / 90) * weight;
    });

    // Sort by priority score descending (Highest score goes to index 0)
    // 按照最终权重分数降序排序，最亮眼/最具故事感的天体将被优先推送到前端展示
    candidates.sort((a, b) => b.score - a.score);

    return candidates;
}

/**
 * @brief Rapidly updates the altitude of a single active object in real-time.
 *        在秒级时钟自转脉冲下，超高速实时重算单个当前展示天体的高度角与距离。
 * @param c Active celestial candidate object / 当前正在播报的星体候选对象
 * @param lat Observer latitude (degrees) / 观测者纬度（度）
 * @param lon Observer longitude (degrees) / 观测者经度（度）
 * @param date Current refreshed date / 当前最新刷新时间
 */
export function updateCandidateAltitude(c, lat, lon, date) {
    const observer = new Observer(lat, lon, 0);
    if (c.isPlanet) {
        const body = Body[c.id];
        const eq = Equator(body, date, observer, true, true);
        const hor = Horizon(date, observer, eq.ra, eq.dec, 'normal');
        c.altitude = hor.altitude;
    } else if (c.isSatellite) {
        const look = getSatelliteLookAngles(c.line1, c.line2, lat, lon, date);
        if (look) {
            c.altitude = look.elevation;
            c.distanceStr = look.range.toFixed(0) + " 公里";
        }
    } else {
        const hor = Horizon(date, observer, c.ra, c.dec, 'normal');
        c.altitude = hor.altitude;
    }
}
