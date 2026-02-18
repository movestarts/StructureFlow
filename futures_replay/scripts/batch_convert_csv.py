#!/usr/bin/env python3
"""批量转换CSV文件为项目格式"""

import pandas as pd
import os
import glob

def convert_file(input_file):
    """转换单个文件"""
    
    print("=" * 100)
    print(f"处理: {os.path.basename(input_file)}")
    print("=" * 100)
    print()
    
    try:
        # 读取
        df = pd.read_csv(input_file)
        
        print(f"[1/3] 原始数据: {len(df)} 行")
        
        # 找到OHLCV列
        open_col = None
        high_col = None
        low_col = None
        close_col = None
        volume_col = None
        
        for col in df.columns:
            col_lower = col.lower()
            if 'open' in col_lower and 'oi' not in col_lower:
                open_col = col
            elif 'high' in col_lower:
                high_col = col
            elif 'low' in col_lower:
                low_col = col
            elif 'close' in col_lower and 'oi' not in col_lower:
                close_col = col
            elif 'volume' in col_lower:
                volume_col = col
        
        # 检查是否找到所有列
        if not all([open_col, high_col, low_col, close_col, volume_col]):
            print(f"[ERROR] 找不到必要的列")
            print(f"  原始列: {list(df.columns)}")
            return None
        
        # 转换
        df_new = pd.DataFrame({
            'datetime': df['datetime'],
            'open': df[open_col],
            'high': df[high_col],
            'low': df[low_col],
            'close': df[close_col],
            'volume': df[volume_col]
        })
        
        # 过滤无效数据
        df_new = df_new[df_new['close'] > 0].copy()
        
        print(f"[2/3] 转换后: {len(df_new)} 行")
        
        # 生成输出文件名
        base_name = os.path.basename(input_file)
        
        if 'rb' in base_name.lower():
            output_file = 'RB2505.csv'
            contract_name = '螺纹钢主连'
        elif 'm' in base_name and 'dce' in base_name.lower():
            output_file = 'M2505.csv'
            contract_name = '豆粕主连'
        else:
            output_file = 'converted_' + base_name
            contract_name = '未知合约'
        
        # 保存
        df_new.to_csv(output_file, index=False)
        
        print(f"[3/3] 已保存到: {output_file}")
        print(f"      合约: {contract_name}")
        print()
        
        # 预览
        print("数据预览:")
        print(df_new.head(3).to_string(index=False))
        print()
        
        return output_file
        
    except Exception as e:
        print(f"[ERROR] 转换失败: {e}")
        import traceback
        traceback.print_exc()
        return None

def main():
    """批量转换所有CSV文件"""
    
    print("=" * 100)
    print("批量转换CSV文件为项目格式")
    print("=" * 100)
    print()
    
    # 查找所有符合条件的CSV文件
    csv_files = []
    
    # 匹配包含主连和5min的文件
    for pattern in ['*主连*5min*.csv', '*5MIN*.csv']:
        csv_files.extend(glob.glob(pattern))
    
    # 去重
    csv_files = list(set(csv_files))
    
    # 过滤掉已转换的文件（只包含datetime,open等标准列的）
    files_to_convert = []
    for f in csv_files:
        try:
            df_check = pd.read_csv(f, nrows=1)
            # 如果列数大于6，说明是天勤格式，需要转换
            if len(df_check.columns) > 6:
                files_to_convert.append(f)
        except:
            pass
    
    print(f"找到 {len(files_to_convert)} 个需要转换的文件:")
    for f in files_to_convert:
        print(f"  - {os.path.basename(f)}")
    print()
    
    if not files_to_convert:
        print("[INFO] 没有找到需要转换的文件")
        print()
        print("转换规则:")
        print("  - 查找包含'主连'和'5min'的CSV文件")
        print("  - 列数大于6列的文件（天勤格式）")
        return
    
    # 逐个转换
    converted = []
    for f in files_to_convert:
        result = convert_file(f)
        if result:
            converted.append(result)
    
    print()
    print("=" * 100)
    print("批量转换完成！")
    print("=" * 100)
    print()
    print(f"成功转换 {len(converted)} 个文件:")
    for f in converted:
        print(f"  [OK] {f}")
    print()
    print("现在可以在Flutter应用中导入这些文件了！")

if __name__ == '__main__':
    main()
