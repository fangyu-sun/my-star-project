from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime, timezone
import requests
import math
import logging
import traceback
import json

app = Flask(__name__)
CORS(app)

# 设置日志记录为DEBUG级别
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

def gmst_from_utc(utc_time: datetime) -> float:
    """根据UTC时间计算GMST（单位：度）"""
    jd = (utc_time - datetime(2000, 1, 1, 12, tzinfo=timezone.utc)).total_seconds() / 86400.0 + 2451545.0
    d = jd - 2451545.0
    gmst = 280.46061837 + 360.98564736629 * d
    return gmst % 360.0

def local_sidereal_time(longitude: float, utc_time: datetime) -> float:
    """根据经度和UTC时间计算LST（单位：度）"""
    gmst = gmst_from_utc(utc_time)
    lst = (gmst + longitude) % 360.0
    return lst

def angular_distance(ra1_deg, dec1_deg, ra2_deg, dec2_deg):
    """球面三角公式计算角距离"""
    ra1 = math.radians(ra1_deg)
    dec1 = math.radians(dec1_deg)
    ra2 = math.radians(ra2_deg)
    dec2 = math.radians(dec2_deg)

    cos_d = math.sin(dec1) * math.sin(dec2) + math.cos(dec1) * math.cos(dec2) * math.cos(ra1 - ra2)
    cos_d = min(1.0, max(-1.0, cos_d))  # 防止数值溢出
    d = math.acos(cos_d)
    return math.degrees(d)

def set_stellarium_location(latitude, longitude):
    """设置Stellarium的位置"""
    url = "http://localhost:8090/api/location/setlocationfields"
    data = {
        "latitude": str(latitude),
        "longitude": str(longitude),
        "altitude": "0",
        "name": "User Location"
    }
    headers = {
        "Content-Type": "application/json"
    }
    try:
        logger.debug(f"Setting location with data: {data}")
        response = requests.post(url, json=data, headers=headers)
        logger.debug(f"Location set response: {response.status_code} - {response.text}")
        if response.status_code != 200:
            logger.error(f"Failed to set location: {response.text}")
            return False
        return True
    except Exception as e:
        logger.error(f"Error setting location: {str(e)}")
        logger.error(traceback.format_exc())
        return False

def set_view_to_zenith():
    """设置视角垂直向上（天顶）"""
    url = "http://localhost:8090/api/main/view"
    data = {
        "jNow": [0.0, 0.0, 1.0]
    }
    headers = {
        "Content-Type": "application/json"
    }
    try:
        logger.debug(f"About to POST to Stellarium - URL: {url}")
        logger.debug(f"Request Headers: {headers}")
        logger.debug(f"Request Body (JSON): {json.dumps(data)}")  # 打印发出去的内容，漂亮格式化

        response = requests.post(url, json=data, headers=headers)

        logger.debug(f"View set response: {response.status_code} - {response.text}")
        
        if response.status_code != 200:
            logger.error(f"Failed to set view: {response.text}")
            return False
        return True
    except Exception as e:
        logger.error(f"Error setting view: {str(e)}")
        return False

def focus_on_center():
    """尝试聚焦中心位置的天体"""
    url = "http://localhost:8090/api/main/focus"
    headers = {
        "Content-Type": "application/json"
    }
    try:
        logger.debug("Attempting to focus on center")
        response = requests.post(url, headers=headers)
        logger.debug(f"Focus response: {response.status_code} - {response.text}")
        if response.status_code != 200:
            logger.error(f"Failed to focus: {response.text}")
            return False
        return True
    except Exception as e:
        logger.error(f"Error focusing: {str(e)}")
        logger.error(traceback.format_exc())
        return False

def get_current_object_info():
    """获取当前选中天体的信息"""
    url = "http://localhost:8090/api/main/status"
    headers = {
        "Content-Type": "application/json"
    }
    try:
        logger.debug("Getting current object info")
        response = requests.get(url, headers=headers)
        logger.debug(f"Status response: {response.status_code} - {response.text}")
        if response.status_code != 200:
            logger.error(f"Failed to get status: {response.text}")
            return None
        return response.json()
    except Exception as e:
        logger.error(f"Error getting status: {str(e)}")
        logger.error(traceback.format_exc())
        return None

@app.route('/find_star', methods=['POST'])
def find_star():
    try:
        data = request.get_json()
        logger.debug(f"Received request data: {data}")
        
        latitude = float(data['latitude'])
        longitude = float(data['longitude'])
        
        # 验证经纬度范围
        if not (-90 <= latitude <= 90) or not (-180 <= longitude <= 180):
            return jsonify({'error': 'Invalid coordinates'}), 400

        # 1. 设置Stellarium位置
        if not set_stellarium_location(latitude, longitude):
            return jsonify({'error': 'Failed to set location in Stellarium'}), 500

        # 2. 设置视角垂直向上
        if not set_view_to_zenith():
            return jsonify({'error': 'Failed to set view to zenith'}), 500

        # 3. 尝试聚焦中心位置的天体
        if not focus_on_center():
            return jsonify({'error': 'Failed to focus on center object'}), 500

        # 4. 获取当前选中天体的信息
        object_info = get_current_object_info()
        if not object_info:
            return jsonify({'error': 'Failed to get object information'}), 500

        # 检查是否成功选中了天体
        if 'selectioninfo' not in object_info or not object_info['selectioninfo'].strip():
            return jsonify({'error': 'No object found at zenith'}), 404

        # 返回天体信息
        return jsonify({
            'info': object_info.get('selectioninfo', 'No information available')
        })

    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        logger.error(traceback.format_exc())
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, port=5001)
