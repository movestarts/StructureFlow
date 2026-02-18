#!/usr/bin/env python3
"""CSV Format Converter Tool - Simple GUI Version"""

import tkinter as tk
from tkinter import filedialog, messagebox, scrolledtext
import pandas as pd
import os
import threading

class SimpleCSVConverter:
    def __init__(self, root):
        self.root = root
        self.root.title("期货数据转换工具 v1.0")
        self.root.geometry("700x550")
        
        self.setup_ui()
        
    def setup_ui(self):
        """设置UI"""
        
        # 标题
        title_frame = tk.Frame(self.root, bg="#2c3e50", height=60)
        title_frame.pack(fill=tk.X)
        
        title_label = tk.Label(
            title_frame,
            text="期货K线数据格式转换工具",
            font=("Microsoft YaHei", 16, "bold"),
            bg="#2c3e50",
            fg="white"
        )
        title_label.pack(pady=15)
        
        # 主容器
        main_frame = tk.Frame(self.root, bg="#ecf0f1")
        main_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # 说明
        info_text = """
支持格式：天勤SDK、通达信、AkShare等多种格式
输出格式：datetime, open, high, low, close, volume
        """
        info_label = tk.Label(
            main_frame,
            text=info_text,
            font=("Microsoft YaHei", 10),
            bg="#ecf0f1",
            fg="#555",
            justify=tk.LEFT
        )
        info_label.pack(pady=10)
        
        # 按钮区域
        button_frame = tk.Frame(main_frame, bg="#ecf0f1")
        button_frame.pack(pady=10)
        
        # 选择单个文件
        select_single_btn = tk.Button(
            button_frame,
            text="选择单个文件",
            font=("Microsoft YaHei", 11),
            bg="#3498db",
            fg="white",
            padx=20,
            pady=10,
            command=self.select_single_file,
            relief=tk.FLAT
        )
        select_single_btn.pack(side=tk.LEFT, padx=5)
        
        # 选择多个文件
        select_multi_btn = tk.Button(
            button_frame,
            text="选择多个文件",
            font=("Microsoft YaHei", 11),
            bg="#27ae60",
            fg="white",
            padx=20,
            pady=10,
            command=self.select_multiple_files,
            relief=tk.FLAT
        )
        select_multi_btn.pack(side=tk.LEFT, padx=5)
        
        # 清空日志
        clear_btn = tk.Button(
            button_frame,
            text="清空日志",
            font=("Microsoft YaHei", 11),
            bg="#95a5a6",
            fg="white",
            padx=20,
            pady=10,
            command=self.clear_log,
            relief=tk.FLAT
        )
        clear_btn.pack(side=tk.LEFT, padx=5)
        
        # 日志区域
        log_label = tk.Label(
            main_frame,
            text="处理日志:",
            font=("Microsoft YaHei", 10, "bold"),
            bg="#ecf0f1",
            anchor=tk.W
        )
        log_label.pack(fill=tk.X, pady=(10, 5))
        
        self.log_text = scrolledtext.ScrolledText(
            main_frame,
            font=("Consolas", 9),
            bg="#2c3e50",
            fg="#ecf0f1",
            height=15,
            wrap=tk.WORD
        )
        self.log_text.pack(fill=tk.BOTH, expand=True)
        
        # 底部
        footer = tk.Label(
            self.root,
            text="输出格式: datetime, open, high, low, close, volume | 作者: Futures Replay Team",
            font=("Microsoft YaHei", 9),
            bg="#ecf0f1",
            fg="#7f8c8d"
        )
        footer.pack(side=tk.BOTTOM, pady=10)
        
        # 初始日志
        self.log("=" * 80)
        self.log("欢迎使用期货数据转换工具！")
        self.log("=" * 80)
        self.log("")
        self.log("使用说明:")
        self.log("  1. 点击'选择单个文件'或'选择多个文件'按钮")
        self.log("  2. 选择需要转换的CSV文件")
        self.log("  3. 自动转换并保存到原文件目录")
        self.log("  4. 生成的文件可直接在Flutter应用中使用")
        self.log("")
        self.log("支持的合约:")
        self.log("  - RB (螺纹钢) -> 输出: RB2505.csv")
        self.log("  - M (豆粕) -> 输出: M2505.csv")
        self.log("  - 其他合约 -> 输出: converted_原文件名.csv")
        self.log("")
        self.log("-" * 80)
    
    def log(self, message):
        """添加日志"""
        self.log_text.insert(tk.END, message + "\n")
        self.log_text.see(tk.END)
        self.root.update()
    
    def clear_log(self):
        """清空日志"""
        self.log_text.delete(1.0, tk.END)
        self.log("[INFO] 日志已清空")
    
    def select_single_file(self):
        """选择单个文件"""
        file = filedialog.askopenfilename(
            title="选择CSV文件",
            filetypes=[("CSV文件", "*.csv"), ("所有文件", "*.*")]
        )
        
        if file:
            self.process_files([file])
    
    def select_multiple_files(self):
        """选择多个文件"""
        files = filedialog.askopenfilenames(
            title="选择CSV文件（可多选）",
            filetypes=[("CSV文件", "*.csv"), ("所有文件", "*.*")]
        )
        
        if files:
            self.process_files(list(files))
    
    def process_files(self, files):
        """处理文件列表"""
        thread = threading.Thread(target=self._convert_files, args=(files,))
        thread.daemon = True
        thread.start()
    
    def _convert_files(self, files):
        """转换文件（后台线程）"""
        
        success_count = 0
        fail_count = 0
        
        for file_path in files:
            result = self.convert_single_file(file_path)
            if result:
                success_count += 1
            else:
                fail_count += 1
        
        self.log("")
        self.log("=" * 80)
        self.log(f"批量转换完成！成功: {success_count}, 失败: {fail_count}")
        self.log("=" * 80)
        
        if success_count > 0:
            messagebox.showinfo("完成", f"成功转换 {success_count} 个文件！")
    
    def convert_single_file(self, input_file):
        """转换单个文件"""
        
        file_name = os.path.basename(input_file)
        self.log("")
        self.log(f"[处理] {file_name}")
        
        try:
            # 读取
            df = pd.read_csv(input_file)
            
            # 识别列
            open_col = None
            high_col = None
            low_col = None
            close_col = None
            volume_col = None
            datetime_col = None
            
            for col in df.columns:
                col_lower = col.lower()
                if 'datetime' in col_lower or 'time' in col_lower:
                    if datetime_col is None:
                        datetime_col = col
                elif 'open' in col_lower and 'oi' not in col_lower:
                    open_col = col
                elif 'high' in col_lower:
                    high_col = col
                elif 'low' in col_lower:
                    low_col = col
                elif 'close' in col_lower and 'oi' not in col_lower:
                    close_col = col
                elif 'volume' in col_lower:
                    volume_col = col
            
            # 检查
            if not all([datetime_col, open_col, high_col, low_col, close_col, volume_col]):
                self.log(f"  [失败] 找不到必要的列")
                return False
            
            # 转换
            df_new = pd.DataFrame({
                'datetime': df[datetime_col],
                'open': df[open_col],
                'high': df[high_col],
                'low': df[low_col],
                'close': df[close_col],
                'volume': df[volume_col]
            })
            
            # 过滤无效数据
            df_new = df_new[df_new['close'] > 0].copy()
            
            # 生成输出文件名
            dir_name = os.path.dirname(input_file)
            base_name = os.path.basename(input_file)
            
            # 自动识别合约
            if 'rb' in base_name.lower():
                output_name = 'RB2505.csv'
            elif 'm' in base_name.lower():
                output_name = 'M2505.csv'
            elif 'au' in base_name.lower():
                output_name = 'AU2506.csv'
            elif 'ag' in base_name.lower():
                output_name = 'AG2506.csv'
            else:
                output_name = 'converted_' + base_name
            
            output_file = os.path.join(dir_name, output_name)
            
            # 保存
            df_new.to_csv(output_file, index=False)
            
            self.log(f"  [成功] 已保存: {output_name} ({len(df_new)} 行)")
            
            return True
            
        except Exception as e:
            self.log(f"  [失败] {str(e)}")
            return False

def main():
    root = tk.Tk()
    app = SimpleCSVConverter(root)
    root.mainloop()

if __name__ == '__main__':
    main()
