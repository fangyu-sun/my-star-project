import csv

def convert_to_csv(input_file, output_file):
    with open(input_file, 'r', encoding='utf-8') as infile, \
         open(output_file, 'w', encoding='utf-8', newline='') as outfile:
        
        # 创建CSV写入器
        writer = csv.writer(outfile)
        
        # 写入CSV头部
        writer.writerow([
            'Name_ASCII', 'Constellation', 'Magnitude', 'HIP', 'HD', 
            'RA_J2000', 'Dec_J2000'
        ])
        
        # 处理每一行
        for line in infile:
            # 跳过注释行和空行
            if line.startswith('#') or line.strip() == '':
                continue
            
            # 将行按空格分割，并过滤掉空字符串
            fields = [x for x in line.split() if x]
            
            if len(fields) >= 7:  # 确保有足够的字段
                # 获取基本字段
                name = fields[0]
                constellation = fields[1]
                magnitude = fields[2]
                hip = fields[3] if fields[3] != '_' else ''
                hd = fields[4] if fields[4] != '_' else ''
                
                # 特殊处理RA和Dec
                ra = fields[5]
                dec = fields[6]
                
                # 如果Dec是负数但没有负号（负号在RA的末尾），则修正
                if ra.endswith('-'):
                    ra = ra[:-1]  # 移除RA末尾的负号
                    dec = '-' + dec  # 将负号添加到Dec的开头
                
                writer.writerow([
                    name,
                    constellation,
                    magnitude,
                    hip,
                    hd,
                    ra,
                    dec
                ])

if __name__ == '__main__':
    input_file = 'Data_1_1/IAU-CSN/IAU-CSN.txt'
    output_file = 'Data_1_1/IAU-CSN/IAU-CSN.csv'
    convert_to_csv(input_file, output_file)
    print(f'转换完成！CSV文件已保存至: {output_file}')