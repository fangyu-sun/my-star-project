import csv
import re

def convert_to_csv(input_file, output_file):
    with open(input_file, 'r', encoding='utf-8') as infile, \
         open(output_file, 'w', encoding='utf-8', newline='') as outfile:
        
        # 创建CSV写入器
        writer = csv.writer(outfile)
        
        # 写入CSV头部
        writer.writerow([
            'Name_ASCII', 'Name_Diacritics', 'Designation', 'ID', 'ID2', 'Constellation', 
            'Number', 'WDS_J', 'Magnitude', 'Band', 'HIP', 'HD', 'RA_J2000', 
            'Dec_J2000', 'Date', 'Notes'
        ])
        
        # 处理每一行
        for line in infile:
            # 跳过注释行和空行
            if line.startswith('#') or line.strip() == '':
                continue
                
            # 使用正则表达式分割行
            # 考虑到某些字段可能包含空格，我们使用固定宽度分割
            parts = [
                line[0:15].strip(),      # Name/ASCII
                line[15:32].strip(),     # Name/Diacritics
                line[32:45].strip(),     # Designation
                line[45:50].strip(),     # ID
                line[50:55].strip(),     # ID2
                line[55:60].strip(),     # Con
                line[60:65].strip(),     # #
                line[65:75].strip(),     # WDS_J
                line[75:82].strip(),     # mag
                line[82:85].strip(),     # bnd
                line[85:95].strip(),     # HIP
                line[95:105].strip(),    # HD
                line[105:117].strip(),   # RA(J2000)
                line[117:129].strip(),   # Dec(J2000)
                line[129:139].strip(),   # Date
                line[139:].strip()       # Notes
            ]
            
            writer.writerow(parts)

if __name__ == '__main__':
    input_file = 'Data_1_1/IAU-CSN/IAU-CSN.txt'
    output_file = 'Data_1_1/IAU-CSN/IAU-CSN.csv'
    convert_to_csv(input_file, output_file)
    print(f'转换完成！CSV文件已保存至: {output_file}') 