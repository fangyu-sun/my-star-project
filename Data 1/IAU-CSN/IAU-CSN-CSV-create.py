import csv
import os

# 输入输出文件路径
input_file = 'IAU-CSN.txt'
output_file = 'IAU-CSN.csv'

# 检查文件是否存在
if not os.path.isfile(input_file):
    raise FileNotFoundError(f"找不到文件: {input_file}，请确认路径是否正确。")

# 存储数据
stars_data = []

# 读取文件
with open(input_file, 'r', encoding='utf-8') as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('#'):
            continue

        parts = line.split()

        if len(parts) < 15:
            continue

        stars_data.append(parts[:15])

# 定义表头
headers = [
    'Name_ASCII', 'Name_UTF8', 'ID', 'Bayer_Flamsteed', 'Bayer_UTF8',
    'Constellation', 'WDS', 'Magnitude', 'Band', 'HIP',
    'HD', 'RA_deg', 'Dec_deg', 'Approval_Date', 'Notes'
]

# 写CSV
with open(output_file, 'w', newline='', encoding='utf-8') as csvfile:
    writer = csv.writer(csvfile)
    writer.writerow(headers)
    writer.writerows(stars_data)

print(f"成功生成 CSV 文件：{output_file}")

# 测试
if __name__ == "__main__":
    if os.path.isfile(input_file):
        print("测试通过：输入文件存在。")
    else:
        print("测试失败：找不到输入文件。")

    if os.path.isfile(output_file):
        print("测试通过：CSV 文件成功生成。")
    else:
        print("测试失败：CSV 文件未生成。")
