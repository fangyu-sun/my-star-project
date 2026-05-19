import fs from 'fs';

const url = 'https://raw.githubusercontent.com/astronexus/HYG-Database/main/hyg/CURRENT/hygdata_v41.csv';
const outputFile = 'src/data/hyg_stars.json';

try {
    console.log("Fetching...");
    const res = await fetch(url);
    const text = await res.text();
    const lines = text.split('\n');

    const stars = [];
    for (let i = 1; i < lines.length; i++) {
        const line = lines[i];
        if (!line) continue;
        const parts = line.split(',');
        const mag = parseFloat(parts[13]);
        
        if (mag <= 5.5) {
            const ra = parseFloat(parts[7]);
            const dec = parseFloat(parts[8]);
            const distParsecs = parseFloat(parts[9]);
            const con = parts[29] || '';
            
            if (distParsecs < 100000) {
                stars.push({
                    id: parts[0],
                    ra: ra,
                    dec: dec,
                    distanceLy: Math.round(distParsecs * 3.26156 * 10) / 10,
                    mag: mag,
                    con: con
                });
            }
        }
    }

    console.log(`Found ${stars.length} stars.`);
    fs.writeFileSync(outputFile, JSON.stringify(stars));
} catch (e) {
    console.error(e);
}
