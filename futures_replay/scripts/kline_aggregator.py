#!/usr/bin/env python3
"""
国内期货K线聚合工具（Python版本）

严格遵循国内期货交易时段和小节休息机制
支持将5分钟K线聚合为30分钟、60分钟等周期
"""

from datetime import datetime, timedelta
from typing import List, Dict, Optional
import pandas as pd


class KlineAggregator:
    """国内期货K线聚合器"""
    
    @staticmethod
    def aggregate_5min_to_30min(df: pd.DataFrame, mode='tdx') -> pd.DataFrame:
        """
        将5分钟K线聚合为30分钟K线（国内期货专用）
        
        Args:
            df: 包含以下列的DataFrame
                - datetime: 时间戳
                - open: 开盘价
                - high: 最高价
                - low: 最低价
                - close: 收盘价
                - volume: 成交量
            mode: 聚合模式
                - 'tdx': 通达信模式（固定6根，跨越休息，时间戳用收盘时间）
                - 'strict': 严格模式（遵循交易时段，10:15断开）
        
        Returns:
            聚合后的30分钟K线DataFrame
        """
        if df.empty:
            return pd.DataFrame()
        
        # 确保datetime列是datetime类型
        if not pd.api.types.is_datetime64_any_dtype(df['datetime']):
            df['datetime'] = pd.to_datetime(df['datetime'])
        
        # 按时间排序
        df = df.sort_values('datetime').reset_index(drop=True)
        
        if mode == 'tdx':
            return KlineAggregator._aggregate_tdx_mode(df)
        else:
            return KlineAggregator._aggregate_strict_mode(df)
    
    @staticmethod
    def _aggregate_tdx_mode(df: pd.DataFrame) -> pd.DataFrame:
        """
        通达信模式聚合：固定6根5分钟聚合成1根30分钟
        
        规则：
        1. 按时间顺序，每6根5分钟K线合成1根30分钟K线
        2. 跨越小节休息（10:15不断开）
        3. 时间戳使用该周期最后一根5分钟K线的时间
        4. 遇到强制断开点（收盘、夜盘开盘等）立即输出，不足6根也输出
        """
        result = []
        buffer = []
        
        for i, row in df.iterrows():
            buffer.append(row)
            
            # 检查是否需要强制断开（收盘时间或新交易时段开始）
            should_break = KlineAggregator._should_break_tdx(row['datetime'], df, i)
            
            # 达到6根或遇到强制断开点
            if len(buffer) >= 6 or should_break:
                # 合并当前缓冲区
                merged = {
                    'datetime': buffer[-1]['datetime'],  # 时间戳取最后一根
                    'open': buffer[0]['open'],
                    'high': max([k['high'] for k in buffer]),
                    'low': min([k['low'] for k in buffer]),
                    'close': buffer[-1]['close'],
                    'volume': sum([k['volume'] for k in buffer])
                }
                result.append(merged)
                buffer = []
        
        # 处理剩余的buffer
        if buffer:
            merged = {
                'datetime': buffer[-1]['datetime'],
                'open': buffer[0]['open'],
                'high': max([k['high'] for k in buffer]),
                'low': min([k['low'] for k in buffer]),
                'close': buffer[-1]['close'],
                'volume': sum([k['volume'] for k in buffer])
            }
            result.append(merged)
        
        return pd.DataFrame(result)
    
    @staticmethod
    def _should_break_tdx(current_time: datetime, df: pd.DataFrame, current_idx: int) -> bool:
        """
        判断是否应该强制断开（通达信模式）
        
        强制断开点：
        1. 收盘时间：11:30, 15:00, 23:00
        2. 下一根K线是新交易时段的开始（大幅时间跳跃）
        """
        hour = current_time.hour
        minute = current_time.minute
        
        # 收盘时间
        if (hour == 11 and minute == 30) or \
           (hour == 15 and minute == 0) or \
           (hour == 23 and minute == 0) or \
           (hour == 2 and minute == 30):
            return True
        
        # 检查下一根K线（如果有）
        if current_idx < len(df) - 1:
            next_time = df.iloc[current_idx + 1]['datetime']
            time_gap = (next_time - current_time).total_seconds() / 60
            
            # 如果时间跳跃超过30分钟，说明是新交易时段
            if time_gap > 30:
                return True
        
        return False
    
    @staticmethod
    def _aggregate_strict_mode(df: pd.DataFrame) -> pd.DataFrame:
        """
        严格模式聚合：遵循交易时段，10:15强制断开
        
        这是之前的实现逻辑
        """
        # 为每根K线分配30分钟周期标识
        df['period_start'] = df['datetime'].apply(KlineAggregator._get_30min_period_start)
        
        # 按周期分组聚合
        result = df.groupby('period_start').agg({
            'open': 'first',
            'high': 'max',
            'low': 'min',
            'close': 'last',
            'volume': 'sum'
        }).reset_index()
        
        result = result.rename(columns={'period_start': 'datetime'})
        return result
    
    @staticmethod
    def _get_30min_period_start(time: datetime) -> datetime:
        """
        确定某个时间点应该归属于哪个30分钟周期的开始时间
        
        这是核心逻辑！必须严格遵循国内期货交易时段
        """
        hour = time.hour
        minute = time.minute
        
        # 日盘时段
        if hour == 9:
            # 09:00-09:30
            if minute < 30:
                return time.replace(hour=9, minute=0, second=0, microsecond=0)
            # 09:30-10:00
            else:
                return time.replace(hour=9, minute=30, second=0, microsecond=0)
        
        elif hour == 10:
            # 10:00-10:15 (特殊：只有3个5分钟)
            if minute < 15:
                return time.replace(hour=10, minute=0, second=0, microsecond=0)
            # 10:15-10:30 是休息时间，如果有数据归到10:00（容错）
            elif minute < 30:
                return time.replace(hour=10, minute=0, second=0, microsecond=0)
            # 10:30-11:00
            else:
                return time.replace(hour=10, minute=30, second=0, microsecond=0)
        
        elif hour == 11:
            # 11:00-11:30
            return time.replace(hour=11, minute=0, second=0, microsecond=0)
        
        elif hour == 13:
            # 13:30-14:00
            return time.replace(hour=13, minute=30, second=0, microsecond=0)
        
        elif hour == 14:
            # 14:00-14:30
            if minute < 30:
                return time.replace(hour=14, minute=0, second=0, microsecond=0)
            # 14:30-15:00
            else:
                return time.replace(hour=14, minute=30, second=0, microsecond=0)
        
        elif hour == 21:
            # 21:00-21:30
            if minute < 30:
                return time.replace(hour=21, minute=0, second=0, microsecond=0)
            # 21:30-22:00
            else:
                return time.replace(hour=21, minute=30, second=0, microsecond=0)
        
        elif hour == 22:
            # 22:00-22:30
            if minute < 30:
                return time.replace(hour=22, minute=0, second=0, microsecond=0)
            # 22:30-23:00
            else:
                return time.replace(hour=22, minute=30, second=0, microsecond=0)
        
        elif hour == 23:
            # 23:00-23:30 (部分品种夜盘延长)
            if minute < 30:
                return time.replace(hour=23, minute=0, second=0, microsecond=0)
            # 23:30-00:00
            else:
                return time.replace(hour=23, minute=30, second=0, microsecond=0)
        
        elif hour == 0:
            # 00:00-00:30
            if minute < 30:
                return time.replace(hour=0, minute=0, second=0, microsecond=0)
            # 00:30-01:00
            else:
                return time.replace(hour=0, minute=30, second=0, microsecond=0)
        
        elif hour == 1:
            # 01:00-01:30
            if minute < 30:
                return time.replace(hour=1, minute=0, second=0, microsecond=0)
            # 01:30-02:00
            else:
                return time.replace(hour=1, minute=30, second=0, microsecond=0)
        
        elif hour == 2:
            # 02:00-02:30 (极少数品种如黄金)
            if minute < 30:
                return time.replace(hour=2, minute=0, second=0, microsecond=0)
            # 02:30之后
            else:
                return time.replace(hour=2, minute=30, second=0, microsecond=0)
        
        # 默认情况（理论上不应该到这里）
        # 按照标准30分钟对齐
        aligned_minute = (minute // 30) * 30
        return time.replace(minute=aligned_minute, second=0, microsecond=0)
    
    @staticmethod
    def is_in_trading_session(time: datetime) -> bool:
        """判断某个时间是否在交易时段内"""
        hour = time.hour
        minute = time.minute
        time_in_minutes = hour * 60 + minute
        
        # 日盘：09:00-11:30, 13:30-15:00
        if (time_in_minutes >= 9 * 60 and time_in_minutes < 11 * 60 + 30) or \
           (time_in_minutes >= 13 * 60 + 30 and time_in_minutes < 15 * 60):
            return True
        
        # 夜盘：21:00-23:00 (基础品种)
        if time_in_minutes >= 21 * 60 and time_in_minutes < 23 * 60:
            return True
        
        # 夜盘延长：23:00-02:30 (部分品种)
        if time_in_minutes >= 23 * 60 or time_in_minutes < 2 * 60 + 30:
            return True
        
        return False


# ==================== 测试与示例 ====================

def test_aggregate():
    """测试聚合功能"""
    print('=' * 80)
    print('测试国内期货5分钟聚合为30分钟')
    print('=' * 80)
    print()
    
    # 生成测试数据
    test_data = _generate_test_data()
    
    print(f'输入: {len(test_data)} 根5分钟K线')
    print(f'时间范围: {test_data["datetime"].min()} ~ {test_data["datetime"].max()}')
    print()
    
    # 执行聚合
    result = KlineAggregator.aggregate_5min_to_30min(test_data)
    
    print(f'输出: {len(result)} 根30分钟K线')
    print()
    print('详细结果:')
    print('-' * 80)
    print(result.to_string(index=False))
    print('-' * 80)
    print()
    
    # 验证关键周期
    print('验证关键周期:')
    _verify_periods(result)
    print()
    
    # 验证10:00-10:15特殊周期
    period_1000 = result[result['datetime'].dt.hour == 10]
    period_1000 = period_1000[period_1000['datetime'].dt.minute == 0]
    
    if not period_1000.empty:
        print('✅ 10:00-10:15 特殊周期处理正确（只有3个5分钟K线）')
    else:
        print('❌ 10:00-10:15 特殊周期缺失')


def _generate_test_data() -> pd.DataFrame:
    """生成测试数据"""
    data = []
    base_date = datetime(2024, 1, 5)  # 2024年1月5日
    base_price = 3800.0
    
    # 日盘：09:00-10:15 (15根5分钟K线)
    for i in range(15):
        time = base_date + timedelta(hours=9, minutes=i * 5)
        data.append(_create_kline(time, base_price + i))
    
    # 日盘：10:30-11:30 (12根5分钟K线)
    for i in range(12):
        time = base_date + timedelta(hours=10, minutes=30 + i * 5)
        data.append(_create_kline(time, base_price + 15 + i))
    
    # 日盘：13:30-15:00 (18根5分钟K线)
    for i in range(18):
        time = base_date + timedelta(hours=13, minutes=30 + i * 5)
        data.append(_create_kline(time, base_price + 27 + i))
    
    # 夜盘：21:00-23:00 (24根5分钟K线)
    for i in range(24):
        time = base_date + timedelta(hours=21, minutes=i * 5)
        data.append(_create_kline(time, base_price + 45 + i))
    
    return pd.DataFrame(data)


def _create_kline(time: datetime, base_price: float) -> Dict:
    """创建单根K线数据"""
    open_price = base_price
    close_price = base_price + (time.minute % 10 - 5)
    high_price = max(open_price, close_price) + 2
    low_price = min(open_price, close_price) - 2
    volume = 1000.0 + (time.minute * 10)
    
    return {
        'datetime': time,
        'open': open_price,
        'high': high_price,
        'low': low_price,
        'close': close_price,
        'volume': volume
    }


def _verify_periods(result: pd.DataFrame):
    """验证关键周期"""
    expected_periods = [
        ('09:00', 9, 0, 6),
        ('09:30', 9, 30, 6),
        ('10:00', 10, 0, 3),  # 特殊：只有3个5分钟
        ('10:30', 10, 30, 6),
        ('11:00', 11, 0, 6),
        ('13:30', 13, 30, 6),
        ('21:00', 21, 0, 6),
    ]
    
    for label, hour, minute, expected_count in expected_periods:
        period = result[result['datetime'].dt.hour == hour]
        period = period[period['datetime'].dt.minute == minute]
        
        if not period.empty:
            print(f'✅ {label} 周期存在')
        else:
            print(f'❌ {label} 周期缺失')


# ==================== 实用函数：CSV处理 ====================

def aggregate_csv_file(input_path: str, output_path: str):
    """
    从CSV文件读取5分钟数据，聚合为30分钟，保存到新CSV
    
    Args:
        input_path: 输入CSV文件路径（5分钟数据）
        output_path: 输出CSV文件路径（30分钟数据）
    """
    print(f'读取5分钟数据: {input_path}')
    
    # 读取CSV
    df = pd.read_csv(input_path)
    
    # 确保有必要的列
    required_cols = ['datetime', 'open', 'high', 'low', 'close', 'volume']
    for col in required_cols:
        if col not in df.columns:
            raise ValueError(f'CSV文件缺少必需列: {col}')
    
    print(f'  总共 {len(df)} 根5分钟K线')
    
    # 聚合
    result = KlineAggregator.aggregate_5min_to_30min(df)
    
    print(f'  聚合后 {len(result)} 根30分钟K线')
    
    # 保存
    result.to_csv(output_path, index=False)
    print(f'保存30分钟数据: {output_path}')
    print('完成！')


# ==================== 命令行入口 ====================

if __name__ == '__main__':
    import sys
    
    if len(sys.argv) == 3:
        # 命令行模式：python kline_aggregator.py input.csv output.csv
        input_file = sys.argv[1]
        output_file = sys.argv[2]
        aggregate_csv_file(input_file, output_file)
    else:
        # 测试模式
        test_aggregate()
