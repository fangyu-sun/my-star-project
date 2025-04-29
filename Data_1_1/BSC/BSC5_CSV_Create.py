import csv
import os

# 路径配置
input_file = '/Users/sunfangyu/star-tracker/catalog'
output_file = '/Users/sunfangyu/star-tracker/bright_star_catalog_raw.csv'

# 检查文件是否存在
if not os.path.isfile(input_file):
    raise FileNotFoundError(f"找不到文件: {input_file}，请确认路径是否正确。")

# 定义表头
headers = [
    'HR', 'Name', 'DM', 'HD', 'SAO', 'FK5', 'IRflag', 'r_IRflag', 'Multiple',
    'ADS', 'ADScomp', 'VarID',
    'RAh1900', 'RAm1900', 'RAs1900', 'DE-1900', 'DEd1900', 'DEm1900', 'DEs1900',
    'RAh', 'RAm', 'RAs', 'DE-', 'DEd', 'DEm', 'DEs',
    'GLON', 'GLAT', 'Vmag', 'n_Vmag', 'u_Vmag', 'B-V', 'u_B-V', 'U-B', 'u_U-B',
    'R-I', 'n_R-I', 'SpType', 'n_SpType',
    'pmRA', 'pmDE', 'n_Parallax', 'Parallax',
    'RadVel', 'n_RadVel', 'l_RotVel', 'RotVel', 'u_RotVel',
    'Dmag', 'Sep', 'MultID', 'MultCnt', 'NoteFlag'
]

# 字段的起止位置定义（按ReadMe里的Byte范围来，Python从0开始计数）
field_slices = [
    (0,4), (4,14), (14,25), (25,31), (31,37), (37,41), (41,42), (42,43), (43,44),
    (44,49), (49,51), (51,60),
    (60,62), (62,64), (64,68), (68,69), (69,71), (71,73), (73,75),
    (75,77), (77,79), (79,83), (83,84), (84,86), (86,88), (88,90),
    (90,96), (96,102), (102,107), (107,108), (108,109), (109,114), (114,115), (115,120), (120,121),
    (121,126), (126,127), (127,147), (147,148),
    (148,154), (154,160), (160,161), (161,166),
    (166,170), (170,174), (174,176), (176,179), (179,180),
    (180,184), (184,190), (190,194), (194,196), (196,197)
]

# 读取并写入CSV
stars_data = []

with open(input_file, 'r', encoding='utf-8') as f:
    for line in f:
        if not line.strip():
            continue  # 跳过空行
        row = [line[start:end].strip() for start, end in field_slices]
        stars_data.append(row)

# 写入CSV文件
with open(output_file, 'w', newline='', encoding='utf-8') as csvfile:
    writer = csv.writer(csvfile)
    writer.writerow(headers)
    writer.writerows(stars_data)

print(f"成功生成 CSV 文件：{output_file}")

# 测试（简单检查）
if __name__ == "__main__":
    try:
        assert len(stars_data) == 9110, f"行数错误：实际{len(stars_data)}行，预期9110行"
        print("测试通过：行数正确。")
    except AssertionError as e:
        print(e)

    try:
        assert all(len(row) == len(headers) for row in stars_data), "列数不一致"
        print("测试通过：列数正确。")
    except AssertionError as e:
        print(e)
