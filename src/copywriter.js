import { constellations } from './data/constellations.js';

export function generateCopy(celestialObj, lang = 'zh') {
    if (!celestialObj) {
        if (lang === 'zh') return "此刻的天顶深处，仅余无垠暗空。";
        if (lang === 'en') return "At this moment, only infinite dark space remains at your zenith.";
        if (lang === 'ja') return "今この瞬間、あなたの天頂の深淵には、無限の暗黒宇宙だけが広がっています。";
    }

    const { name, distanceStr, isPlanet, id, altitude, isSatellite, con } = celestialObj;
    
    // Determine the position description based on altitude
    let positionPhrase = "";
    if (lang === 'zh') {
        if (altitude > 75) positionPhrase = "正高悬于你的天顶";
        else if (altitude > 45) positionPhrase = "正经过你的上空";
        else if (altitude > 20) positionPhrase = "正在你的远方穿行";
        else positionPhrase = "正在地平线附近徘徊";
    } else if (lang === 'en') {
        if (altitude > 75) positionPhrase = "is hanging directly overhead at your zenith";
        else if (altitude > 45) positionPhrase = "is passing high above you";
        else if (altitude > 20) positionPhrase = "is traversing in the distance";
        else positionPhrase = "is hovering near the horizon";
    } else if (lang === 'ja') {
        if (altitude > 75) positionPhrase = "があなたの天頂に高く懸かっています";
        else if (altitude > 45) positionPhrase = "があなたの真上を通過しています";
        else if (altitude > 20) positionPhrase = "が遠方の宇宙を横切っています";
        else positionPhrase = "が地平線近くを漂っています";
    }

    // Localize Planet / Star / Satellite Names and Distance
    let localizedName = name;
    let localizedDistance = distanceStr;

    // Translate Planets
    const planetMap = {
        'Sun': { zh: '太阳', en: 'the Sun', ja: '太陽' },
        'Moon': { zh: '月亮', en: 'the Moon', ja: '月' },
        'Jupiter': { zh: '木星', en: 'Jupiter', ja: '木星' },
        'Venus': { zh: '金星', en: 'Venus', ja: '金星' },
        'Mars': { zh: '火星', en: 'Mars', ja: '火星' },
        'Saturn': { zh: '土星', en: 'Saturn', ja: '土星' }
    };

    // Translate Famous Stars
    const starMap = {
        'sirius': { zh: '天狼星', en: 'Sirius', ja: 'シリウス' },
        'canopus': { zh: '老人星', en: 'Canopus', ja: 'カノープス' },
        'vega': { zh: '织女星', en: 'Vega', ja: 'ベガ' },
        'arcturus': { zh: '大角星', en: 'Arcturus', ja: 'アークトゥルス' },
        'rigel': { zh: '参宿七', en: 'Rigel', ja: 'リゲル' },
        'betelgeuse': { zh: '参宿四', en: 'Betelgeuse', ja: 'ベテルギウス' },
        'procyon': { zh: '南河三', en: 'Procyon', ja: 'プロキオン' },
        'achernar': { zh: '水委一', en: 'Achernar', ja: 'アケルナル' },
        'altair': { zh: '牛郎星', en: 'Altair', ja: 'アルタイル' },
        'aldebaran': { zh: '毕宿五', en: 'Aldebaran', ja: 'アルデバラン' },
        'antares': { zh: '心宿二', en: 'Antares', ja: 'アンタレス' },
        'spica': { zh: '角宿一', en: 'Spica', ja: 'スピカ' },
        'pollux': { zh: '北河三', en: 'Pollux', ja: 'ポルックス' },
        'fomalhaut': { zh: '北落师门', en: 'Fomalhaut', ja: 'フォーマルハウト' },
        'deneb': { zh: '天津四', en: 'Deneb', ja: 'デネブ' }
    };

    const satMap = {
        'ISS (ZARYA)': { zh: '国际空间站', en: 'International Space Station (ISS)', ja: '国際宇宙ステーション (ISS)' },
        'CSS (TIANHE)': { zh: '中国空间站', en: 'Tiangong Space Station (CSS)', ja: '天宮宇宙ステーション (CSS)' },
        'HST': { zh: '哈勃太空望远镜', en: 'Hubble Space Telescope (HST)', ja: 'ハッブル宇宙望遠鏡 (HST)' }
    };

    if (isPlanet && planetMap[id]) {
        localizedName = planetMap[id][lang];
        if (lang === 'en') {
            localizedDistance = distanceStr.replace('亿公里', '00 million km').replace('万公里', '0,000 km').replace('公里', ' km');
        } else if (lang === 'ja') {
            localizedDistance = distanceStr.replace('亿公里', '億km').replace('万公里', '万km').replace('公里', 'km');
        }
    } else if (starMap[id]) {
        localizedName = starMap[id][lang];
        if (lang === 'en') localizedDistance = distanceStr.replace('光年', ' light-years');
        else if (lang === 'ja') localizedDistance = distanceStr.replace('光年', '光年');
    } else if (isSatellite) {
        let cleanName = name.trim();
        if (satMap[cleanName]) {
            localizedName = satMap[cleanName][lang];
        } else if (cleanName.startsWith('STARLINK')) {
            if (lang === 'zh') localizedName = cleanName.replace('STARLINK', '星链');
            else if (lang === 'ja') localizedName = cleanName.replace('STARLINK', 'スターリンク');
        }
        if (lang === 'en') localizedDistance = distanceStr.replace('公里', ' km');
        else if (lang === 'ja') localizedDistance = distanceStr.replace('公里', 'km');
    } else {
        // HYG Star (constellation mapping)
        if (con) {
            const conData = constellations[con];
            if (conData) {
                const conLocalized = conData[lang];
                if (lang === 'zh') {
                    localizedName = `位于${conLocalized}的恒星`;
                } else if (lang === 'en') {
                    localizedName = `a star in the constellation ${conLocalized}`;
                } else if (lang === 'ja') {
                    localizedName = `${conLocalized}にある恒星`;
                }
            } else {
                if (lang === 'zh') localizedName = '一颗暗星';
                else if (lang === 'en') localizedName = 'a faint star';
                else if (lang === 'ja') localizedName = 'かすかな恒星';
            }
        }
        if (lang === 'en') localizedDistance = distanceStr.replace('光年', ' light-years');
        else if (lang === 'ja') localizedDistance = distanceStr.replace('光年', '光年');
    }

    // Generate language-specific copy
    if (id === 'Sun') {
        if (lang === 'zh') return `此刻，太阳${positionPhrase}。`;
        if (lang === 'en') return `At this moment, the Sun ${positionPhrase}.`;
        if (lang === 'ja') return `今この瞬間、太陽${positionPhrase}。`;
    } else if (id === 'Moon') {
        if (lang === 'zh') return `此刻，月亮${positionPhrase}。`;
        if (lang === 'en') return `At this moment, the Moon ${positionPhrase}.`;
        if (lang === 'ja') return `今この瞬間、月${positionPhrase}。`;
    } else if (isPlanet) {
        if (lang === 'zh') return `距离地球 ${localizedDistance} 的${localizedName}，${positionPhrase}。`;
        if (lang === 'en') return `${localizedName}, located ${localizedDistance} from Earth, ${positionPhrase}.`;
        if (lang === 'ja') return `地球から ${localizedDistance} 離れた${localizedName}${positionPhrase}。`;
    } else if (isSatellite) {
        if (lang === 'zh') return `此刻，运行于地球上方 ${localizedDistance} 的${localizedName}，正疾速掠过你的天顶。`;
        if (lang === 'en') return `At this moment, the ${localizedName}, orbiting ${localizedDistance} above Earth, is rapidly passing directly overhead at your zenith.`;
        if (lang === 'ja') return `今この瞬間、地球の上空 ${localizedDistance} を周回する${localizedName}が、あなたの天頂を急速に通過しています。`;
    } else {
        if (lang === 'zh') return `此刻，一颗 ${localizedDistance} 外的${localizedName}，${positionPhrase}。`;
        if (lang === 'en') return `At this moment, ${localizedName}, located ${localizedDistance} away, ${positionPhrase}.`;
        if (lang === 'ja') return `今この瞬間、${localizedDistance} 先にある${localizedName}${positionPhrase}。`;
    }
}
