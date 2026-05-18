from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime, timezone
import math
import logging
import traceback
import astropy.units as u
from astropy.coordinates import SkyCoord
from astroquery.simbad import Simbad
import warnings
from astropy.utils.exceptions import AstropyWarning

# Ignore Astropy warnings
warnings.simplefilter('ignore', category=AstropyWarning)

app = Flask(__name__)
CORS(app)

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# Configure SIMBAD to return extra useful fields
custom_simbad = Simbad()
custom_simbad.add_votable_fields('plx_value', 'otype_txt', 'sp_type')

def gmst_from_utc(utc_time: datetime) -> float:
    """Calculate GMST from UTC"""
    jd = (utc_time - datetime(2000, 1, 1, 12, tzinfo=timezone.utc)).total_seconds() / 86400.0 + 2451545.0
    d = jd - 2451545.0
    gmst = 280.46061837 + 360.98564736629 * d
    return gmst % 360.0

def local_sidereal_time(longitude: float, utc_time: datetime) -> float:
    """Calculate LST from longitude and UTC"""
    gmst = gmst_from_utc(utc_time)
    lst = (gmst + longitude) % 360.0
    return lst

@app.route('/find_star', methods=['POST'])
def find_star():
    try:
        data = request.get_json()
        logger.debug(f"Received data: {data}")
        
        latitude = float(data.get('latitude', 0))
        longitude = float(data.get('longitude', 0))
        
        if not (-90 <= latitude <= 90) or not (-180 <= longitude <= 180):
            return jsonify({'error': 'Invalid coordinates'}), 400

        utc_now = datetime.now(timezone.utc)
        lst_deg = local_sidereal_time(longitude, utc_now)
        
        zenith_ra = lst_deg
        zenith_dec = latitude
        
        logger.debug(f"Calculated Zenith -> RA: {zenith_ra}, Dec: {zenith_dec}")
        
        coord = SkyCoord(ra=zenith_ra, dec=zenith_dec, unit=(u.deg, u.deg), frame='icrs')
        
        # Search radius of 1 degree
        result_table = custom_simbad.query_region(coord, radius=1.0 * u.deg)
        
        if result_table is None or len(result_table) == 0:
            return jsonify({'error': 'No celestial objects found overhead (1° radius). Try again later!'}), 404
            
        # The result_table is sorted by distance from center by default. We'll pick the closest one.
        best_obj = result_table[0]
        
        # Depending on SIMBAD response, these might be byte strings.
        name = best_obj['MAIN_ID']
        if isinstance(name, bytes): name = name.decode('utf-8')
            
        otype = best_obj['OTYPE_txt']
        if isinstance(otype, bytes): otype = otype.decode('utf-8')
            
        sp_type = best_obj['SP_TYPE']
        if isinstance(sp_type, bytes): sp_type = sp_type.decode('utf-8')
        
        distance_str = "Unknown"
        # Check if parallax is valid
        if 'PLX_VALUE' in result_table.colnames and not best_obj.mask['PLX_VALUE']:
            plx_mas = best_obj['PLX_VALUE']
            if plx_mas > 0:
                distance_pc = 1000.0 / plx_mas
                distance_ly = distance_pc * 3.26156
                distance_str = f"{distance_ly:.2f} Light Years"

        # Construct simple human-readable info text
        info_text = f"Name: {name}\nType: {otype}\nDistance: {distance_str}"
        if sp_type:
            info_text += f"\nSpectral Type: {sp_type}"
        
        return jsonify({
            'name': name,
            'type': otype,
            'distance': distance_str,
            'ra': f"{zenith_ra:.4f}°",
            'dec': f"{zenith_dec:.4f}°",
            'info': info_text
        })

    except Exception as e:
        logger.error(f"Error: {e}")
        logger.error(traceback.format_exc())
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, port=5001)
