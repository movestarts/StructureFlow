from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import Optional
import pandas as pd


class MarketType(Enum):
    FUTURES = "futures"
    STOCKS = "stocks"
    CRYPTO = "crypto"
    FOREX = "forex"


class TimeFrame(Enum):
    DAILY = "daily"
    HOUR_1 = "1h"
    MINUTE_15 = "15m"
    MINUTE_5 = "5m"
    MINUTE_1 = "1m"


@dataclass
class MarketData:
    symbol: str
    market_type: MarketType
    timeframe: TimeFrame
    df: pd.DataFrame

    def to_standard_csv(self) -> pd.DataFrame:
        standard_df = pd.DataFrame()
        standard_df['datetime'] = self.df['datetime'].apply(self._format_datetime)
        standard_df['open'] = self.df['open']
        standard_df['high'] = self.df['high']
        standard_df['low'] = self.df['low']
        standard_df['close'] = self.df['close']
        standard_df['volume'] = self.df.get('volume', 0)
        standard_df['amount'] = self.df.get('amount', 0)
        standard_df['position'] = self.df.get('position', 0)
        standard_df['symbol'] = self.symbol
        return standard_df

    @staticmethod
    def _format_datetime(dt) -> str:
        if isinstance(dt, str):
            try:
                dt = pd.to_datetime(dt)
            except:
                return dt
        if isinstance(dt, pd.Timestamp):
            return f"{dt.year}/{dt.month}/{dt.day} {dt.hour}:{dt.minute:02d}:{dt.second:02d}"
        if isinstance(dt, datetime):
            return f"{dt.year}/{dt.month}/{dt.day} {dt.hour}:{dt.minute:02d}:{dt.second:02d}"
        return str(dt)


COLUMN_MAPPING = {
    'datetime': ['datetime', 'date', '日期', '时间', 'timestamp', 'time'],
    'open': ['open', '开盘', '开盘价', 'Open'],
    'high': ['high', '最高', '最高价', 'High'],
    'low': ['low', '最低', '最低价', 'Low'],
    'close': ['close', '收盘', '收盘价', 'Close'],
    'volume': ['volume', '成交量', 'Vol', 'Volume', 'vol'],
    'amount': ['amount', '成交额', 'turnover', 'Turnover'],
    'position': ['position', '持仓量', 'open_interest', 'Open Interest', '持仓']
}


def normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    df.columns = df.columns.str.strip()
    renamed = {}
    for standard_name, possible_names in COLUMN_MAPPING.items():
        for col in df.columns:
            if str(col).strip() in possible_names or str(col).lower().strip() in [n.lower() for n in possible_names]:
                renamed[col] = standard_name
                break
    return df.rename(columns=renamed)


def ensure_columns(df: pd.DataFrame, symbol: str) -> pd.DataFrame:
    required = ['datetime', 'open', 'high', 'low', 'close', 'volume', 'amount', 'position']
    for col in required:
        if col not in df.columns:
            if col in ['volume', 'amount', 'position']:
                df[col] = 0
            else:
                raise ValueError(f"Missing required column: {col}")
    if 'symbol' not in df.columns:
        df['symbol'] = symbol
    return df
