import { constellations } from './data/constellations.js';

function getRandomTemplate(templates) {
    return templates[Math.floor(Math.random() * templates.length)];
}

export function generateCopy(celestialObj, lang = 'zh') {
    if (!celestialObj) {
        const emptyTemplates = {
            zh: ["此刻，只有深空。", "你的头顶没有恒星经过。", "只有夜空。", "夜空暂时归于沉寂。"],
            en: ["At this moment, only deep space.", "No stars are passing overhead.", "Only the night sky.", "The night sky temporarily returns to silence."],
            ja: ["今は、深宇宙があるだけだ。", "頭上を通過する星はない。", "ただ、夜空。", "夜空は一時的に静寂に包まれている。"]
        };
        return getRandomTemplate(emptyTemplates[lang]);
    }

    const { name, distanceStr, isPlanet, id, isSatellite, con } = celestialObj;
    
    // Parse pure numbers from distanceStr for Time Echo Layer
    const distanceMatch = distanceStr.match(/[\d.]+/);
    const numericDistance = distanceMatch ? distanceMatch[0] : "";

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
        'ISS (ZARYA)': { zh: '国际空间站', en: 'ISS', ja: '国際宇宙ステーション' },
        'CSS (TIANHE)': { zh: '中国空间站', en: 'CSS', ja: '中国宇宙ステーション' },
        'HST': { zh: '哈勃太空望远镜', en: 'Hubble', ja: 'ハッブル宇宙望遠鏡' }
    };

    let isAnonymousStar = false;

    let conNameZh = "";
    let conNameEn = "";
    let conNameJa = "";

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
        isAnonymousStar = true;
        if (con) {
            const conData = constellations[con];
            if (conData) {
                conNameZh = conData['zh'];
                conNameEn = conData['en'];
                conNameJa = conData['ja'];
            }
        }
        if (lang === 'en') localizedDistance = distanceStr.replace('光年', ' light-years');
        else if (lang === 'ja') localizedDistance = distanceStr.replace('光年', '光年');
    }

    // 1. Sun & Moon Templates
    if (id === 'Sun') {
        const templates = {
            zh: ["太阳正在照耀。"],
            en: ["The Sun is shining."],
            ja: ["太陽が輝いている。"]
        };
        return getRandomTemplate(templates[lang]);
    }
    if (id === 'Moon') {
        const templates = {
            zh: ["月亮位于你的上空。", `38 万公里外，月亮正在缓慢移动。`],
            en: ["The Moon is above you.", `380,000 km away, the Moon is moving slowly.`],
            ja: ["月が上空にある。", `38 万km 先で、月がゆっくりと移動している。`]
        };
        return getRandomTemplate(templates[lang]);
    }

    // 2. Planets Templates
    if (isPlanet) {
        const templates = {
            zh: [
                `${localizedDistance}外，${localizedName}正在缓慢移动。`,
                `${localizedName}位于你头顶附近。`,
                `${localizedName}正在反射太阳的光。`
            ],
            en: [
                `${localizedDistance} away, ${localizedName} is moving slowly.`,
                `${localizedName} is near your zenith.`,
                `${localizedName} is reflecting the Sun's light.`
            ],
            ja: [
                `${localizedDistance}先で、${localizedName}がゆっくりと移動している。`,
                `${localizedName}が頭上付近にある。`,
                `${localizedName}が太陽の光を反射している。`
            ]
        };
        return getRandomTemplate(templates[lang]);
    }

    // 3. Human Orbit Objects (Satellites) Templates
    if (isSatellite) {
        const isManned = id === 'ISS (ZARYA)' || id === 'CSS (TIANHE)';
        const templates = {
            zh: [
                `${localizedDistance}上空，${localizedName}正在高速飞行。`,
                `你的上空，${localizedName}正在移动。`
            ],
            en: [
                `${localizedDistance} above, ${localizedName} is flying at high speed.`,
                `Above you, the ${localizedName} is moving.`
            ],
            ja: [
                `上空 ${localizedDistance}、${localizedName}が高速で飛行している。`,
                `上空を、${localizedName}が移動している。`
            ]
        };
        if (isManned) {
            templates.zh.push(`一座载有人类的空间站（${localizedName}）正在穿越你的头顶。`);
            templates.en.push(`A human-crewed space station (${localizedName}) is passing overhead.`);
            templates.ja.push(`人類を乗せた宇宙ステーション（${localizedName}）が頭上を通過している。`);
        }
        return getRandomTemplate(templates[lang]);
    }

    // 4. Deep Space Stars Templates
    let starTemplates = { zh: [], en: [], ja: [] };

    if (!isAnonymousStar) {
        starTemplates = {
            zh: [
                `${localizedDistance}外，${localizedName}正在经过上空。`,
                `来自${localizedName}的光，飞行了 ${numericDistance} 年。`,
                `此刻，${localizedName}距离你 ${localizedDistance}。`
            ],
            en: [
                `${localizedDistance} away, ${localizedName} is passing overhead.`,
                `The light from ${localizedName} has traveled for ${numericDistance} years.`,
                `At this moment, ${localizedName} is ${localizedDistance} away.`
            ],
            ja: [
                `${localizedDistance}先、${localizedName}が上空を通過している。`,
                `${localizedName}からの光は、${numericDistance} 年の旅を終えた。`,
                `今この瞬間、あなたから ${localizedDistance} 離れた、${localizedName}。`
            ]
        };
    } else if (conNameZh) {
        starTemplates = {
            zh: [
                `你的上空，一颗属于${conNameZh}的恒星正在发光，距离 ${localizedDistance}。`,
                `你现在看到正上方的，是${conNameZh}中一颗恒星在 ${numericDistance} 年前发出的光。`,
                `此刻，${localizedDistance}外，一颗${conNameZh}的暗星正在经过。`
            ],
            en: [
                `Above you, a star in ${conNameEn} is shining, ${localizedDistance} away.`,
                `The light you see directly above was emitted by a star in ${conNameEn} ${numericDistance} years ago.`,
                `At this moment, ${localizedDistance} away, a faint star in ${conNameEn} is passing.`
            ],
            ja: [
                `上空では、${conNameJa}に属する恒星が ${localizedDistance} 先で輝いている。`,
                `現在真上に見えるのは、${conNameJa}の恒星が ${numericDistance} 年前に放った光だ。`,
                `今この瞬間、${localizedDistance}先、${conNameJa}の暗星が通過している。`
            ]
        };
    } else {
        starTemplates = {
            zh: [
                `你的上空，一颗暗星在你上方经过，距离 ${localizedDistance}。`,
                `此刻，${localizedDistance}外，一颗没有名字的恒星正在经过。`
            ],
            en: [
                `Above you, a faint star is passing by, ${localizedDistance} away.`,
                `At this moment, ${localizedDistance} away, a nameless star is passing.`
            ],
            ja: [
                `上空では、暗星があなたの真上を通過している。距離 ${localizedDistance}。`,
                `今この瞬間、${localizedDistance}先、名もなき星が通過している。`
            ]
        };
    }
    
    return getRandomTemplate(starTemplates[lang]);
}
