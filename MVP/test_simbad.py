from astroquery.simbad import Simbad
from astropy.coordinates import SkyCoord
import astropy.units as u

# Set up SIMBAD to return extra fields like parallax (for distance) and object type
custom_simbad = Simbad()
custom_simbad.add_votable_fields('plx', 'otype', 'flux(V)')

# Let's say Zenith is RA=12h, Dec=45deg
ra_deg = 180.0
dec_deg = 45.0
coord = SkyCoord(ra=ra_deg, dec=dec_deg, unit=(u.deg, u.deg), frame='icrs')

# Query within 1 degree
result_table = custom_simbad.query_region(coord, radius=1 * u.deg)

if result_table:
    print(result_table)
else:
    print("No objects found.")
