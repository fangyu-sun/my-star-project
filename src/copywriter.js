export function generateCopy(celestialObj) {
    if (!celestialObj) {
        return "此刻的天顶深处，仅余无垠暗空。";
    }

    const { name, distanceStr, isPlanet, id, altitude } = celestialObj;
    
    // Determine the position description based on altitude
    let positionPhrase = "";
    if (altitude > 75) {
        positionPhrase = "正高悬于你的天顶";
    } else if (altitude > 45) {
        positionPhrase = "正经过你的上空";
    } else if (altitude > 20) {
        positionPhrase = "正在你的远方穿行";
    } else {
        positionPhrase = "正在地平线附近徘徊";
    }

    if (id === 'Sun') {
        return `此刻，太阳${positionPhrase}。`;
    } else if (id === 'Moon') {
        return `此刻，月亮${positionPhrase}。`;
    } else if (isPlanet) {
        return `距离地球 ${distanceStr} 的${name}，${positionPhrase}。`;
    } else {
        return `此刻，一颗 ${distanceStr} 外的${name}，${positionPhrase}。`;
    }
}
