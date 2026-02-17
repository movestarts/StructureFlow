import yfinance as yf
import pandas as pd
from datetime import datetime
from typing import Optional
from models.data_models import MarketData, MarketType, TimeFrame, ensure_columns


class ForexService:
    def __init__(self):
        self.market_type = MarketType.FOREX

    def fetch_data(
        self,
        symbol: str,
        timeframe: TimeFrame = TimeFrame.DAILY,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None
    ) -> MarketData:
        try:
            if not symbol.endswith('=X'):
                symbol = f"{symbol}=X"
            interval_map = {
                TimeFrame.DAILY: "1d",
                TimeFrame.HOUR_1: "1h",
                TimeFrame.MINUTE_15: "15m",
                TimeFrame.MINUTE_5: "5m",
                TimeFrame.MINUTE_1: "1m"
            }
            interval = interval_map.get(timeframe, "1d")
            ticker = yf.Ticker(symbol)
            df = ticker.history(
                interval=interval,
                start=start_date,
                end=end_date
            )
            df = df.reset_index()
            df.columns = [str(col).lower().replace(' ', '_') for col in df.columns]
            if 'date' in df.columns:
                df['datetime'] = df['date']
            elif 'datetime' not in df.columns:
                df['datetime'] = df.index
            df['volume'] = 0
            df['amount'] = 0
            df['position'] = 0
            df = ensure_columns(df, symbol.replace('=X', ''))
            return MarketData(
                symbol=symbol.replace('=X', ''),
                market_type=self.market_type,
                timeframe=timeframe,
                df=df
            )
        except Exception as e:
            raise Exception(f"获取外汇数据失败: {str(e)}")

    @staticmethod
    def get_common_pairs() -> list:
        return [
            'EURUSD', 'GBPUSD', 'USDJPY', 'USDCHF',
            'AUDUSD', 'USDCAD', 'NZDUSD', 'EURGBP',
            'EURJPY', 'GBPJPY', 'XAUUSD', 'XAGUSD'
        ]
