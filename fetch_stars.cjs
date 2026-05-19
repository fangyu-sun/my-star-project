const https = require('https');
const fs = require('fs');
const readline = require('readline');

const url = 'https://raw.githubusercontent.com/astronexus/HYG-Database/master/hygdata_v3.csv';
const outputFile = 'src/data/hyg_stars.json';

https.get(url, (res) => {
    const rl = readline.createInterface({
        input: res,
        crlfDelay: Infinity
    });

    let isHeader = true;
    let headers = [];
    const stars = [];

    rl.on('line', (line) => {
        const parts = line.split(',');
        if (isHeader) {
            headers = parts;
            isHeader = false;
            return;
        }

        const mag = parseFloat(parts[13]); // mag is column 14 (index 13)
        // Let's get up to mag 5.5 (about 2800 stars) to guarantee coverage in 10 degrees
        if (mag <= 5.5) {
            const ra = parseFloat(parts[7]); // RA in hours
            const dec = parseFloat(parts[8]); // Dec in degrees
            const distParsecs = parseFloat(parts[9]); // Distance in parsecs
            
            // distance >= 100000 indicates bad data or infinity in HYG
            if (distParsecs < 100000) {
                const distanceLy = distParsecs * 3.26156;
                stars.push({
                    id: parts[0],
                    ra: ra,
                    dec: dec,
                    distanceLy: Math.round(distanceLy * 10) / 10,
                    mag: mag
                });
            }
        }
    });

    rl.on('close', () => {
        console.log(`Found ${stars.length} stars.`);
        fs.writeFileSync(outputFile, JSON.stringify(stars));
        console.log(`Saved to ${outputFile}`);
    });

}).on('error', (e) => {
    console.error(e);
});
