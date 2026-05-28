const fs = require('fs');
const https = require('https');
const zlib = require('zlib');
const readline = require('readline');

// URL for cities with population > 15000 from GeoNames
const url = 'https://download.geonames.org/export/dump/cities15000.zip';
const zipDest = './cities15000.zip';
const txtDest = './cities15000.txt';
const jsonDest = './macos-saver/Resources/cities.json';

// Ensure dir exists
if (!fs.existsSync('./macos-saver/Resources')) {
  fs.mkdirSync('./macos-saver/Resources', { recursive: true });
}

// Country code mapping fallback (a small mapping of major country names for display)
const countryMap = new Intl.DisplayNames(['en'], { type: 'region' });

async function downloadFile(url, dest) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest);
    https.get(url, function(response) {
      if (response.statusCode === 302 || response.statusCode === 301) {
        // Handle redirect
        downloadFile(response.headers.location, dest).then(resolve).catch(reject);
      } else {
        response.pipe(file);
        file.on('finish', function() {
          file.close(resolve);
        });
      }
    }).on('error', function(err) {
      fs.unlink(dest, () => reject(err));
    });
  });
}

async function extractZip() {
  const { execSync } = require('child_process');
  console.log('Extracting zip...');
  execSync(`unzip -o ${zipDest}`);
}

async function parseTSV() {
  console.log('Parsing TSV...');
  const fileStream = fs.createReadStream(txtDest);
  const rl = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity
  });

  const cities = [];

  for await (const line of rl) {
    const cols = line.split('\t');
    /*
      GeoNames TSV format:
      0: geonameid
      1: name
      2: asciiname
      3: alternatenames
      4: latitude
      5: longitude
      6: feature class
      7: feature code
      8: country code
      ...
      14: population
      ...
      17: timezone
    */
    
    const asciiName = cols[2];
    const name = cols[1];
    const alternates = cols[3] ? cols[3].split(',') : [];
    const lat = parseFloat(cols[4]);
    const lon = parseFloat(cols[5]);
    const countryCode = cols[8];
    const population = parseInt(cols[14], 10) || 0;
    const timezone = cols[17] || '';
    
    // We want relatively significant cities to keep size down, > 50,000 population.
    // Or we just take all 15k, but let's filter slightly to keep JSON < 2MB.
    if (population > 50000) {
      let countryName = countryCode;
      try {
        countryName = countryMap.of(countryCode) || countryCode;
      } catch (e) {}

      // Grab some common alternatenames (limit to 3 to save space)
      // Preferably taking non-english ones that look like Chinese/Japanese or common names
      let usefulAlternates = [];
      for (let alt of alternates) {
        if (/[\u3400-\u9FBF]/.test(alt) || /[\u3040-\u30FF]/.test(alt)) { // CJK
            usefulAlternates.push(alt);
        }
      }
      
      // Pad to max 2 if needed
      if (usefulAlternates.length === 0 && alternates.length > 0) {
        usefulAlternates.push(alternates[0]);
      }
      usefulAlternates = usefulAlternates.slice(0, 2);

      cities.push({
        c: name,            // cityName
        a: asciiName,       // asciiName
        alt: usefulAlternates,
        cc: countryCode,
        cn: countryName,
        lat: lat,
        lon: lon,
        tz: timezone,
        p: population
      });
    }
  }

  // Sort by population descending so search hits biggest cities first
  cities.sort((a, b) => b.p - a.p);
  
  console.log(`Parsed ${cities.length} cities. Writing JSON...`);
  fs.writeFileSync(jsonDest, JSON.stringify(cities));
  console.log(`Saved to ${jsonDest}`);
}

async function main() {
  try {
    console.log(`Downloading ${url}...`);
    await downloadFile(url, zipDest);
    await extractZip();
    await parseTSV();
    
    // Cleanup
    fs.unlinkSync(zipDest);
    fs.unlinkSync(txtDest);
    if (fs.existsSync('readme.txt')) fs.unlinkSync('readme.txt');
    console.log('Done!');
  } catch (err) {
    console.error('Error:', err);
  }
}

main();
