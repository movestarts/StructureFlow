import akshare as ak
import yfinance as yf
import pandas as pd
from datetime import datetime
from typing import Optional, Literal
from models.data_models import MarketData, MarketType, TimeFrame, normalize_columns, ensure_columns


class StockService:
    def __init__(self):
        self.market_type = MarketType.STOCKS

    def fetch_a_stock(
        self,
        symbol: str,
        timeframe: TimeFrame = TimeFrame.DAILY,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None
    ) -> MarketData:
        try:
            period_map = {
                TimeFrame.DAILY: "daily",
                TimeFrame.HOUR_1: "60",
                TimeFrame.MINUTE_15: "15",
                TimeFrame.MINUTE_5: "5",
                TimeFrame.MINUTE_1: "1"
            }
            period = period_map.get(timeframe, "daily")
            start_str = start_date.strftime("%Y%m%d") if start_date else "19900101"
            end_str = end_date.strftime("%Y%m%d") if end_date else datetime.now().strftime("%Y%m%d")
            df = ak.stock_zh_a_hist(
                symbol=symbol,
                period=period,
                start_date=start_str,
                end_date=end_str,
                adjust=""
            )
            df = normalize_columns(df)
            df['position'] = 0
            df = ensure_columns(df, symbol)
            return MarketData(
                symbol=symbol,
                market_type=self.market_type,
                timeframe=timeframe,
                df=df
            )
        except Exception as e:
            raise Exception(f"获取A股数据失败: {str(e)}")

    def fetch_us_stock(
        self,
        symbol: str,
        timeframe: TimeFrame = TimeFrame.DAILY,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None
    ) -> MarketData:
        try:
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
            df['amount'] = df.get('volume', 0) * df.get('close', 0)
            df['position'] = 0
            df = normalize_columns(df)
            df = ensure_columns(df, symbol)
            return MarketData(
                symbol=symbol,
                market_type=self.market_type,
                timeframe=timeframe,
                df=df
            )
        except Exception as e:
            raise Exception(f"获取美股数据失败: {str(e)}")

    def fetch_data(
        self,
        symbol: str,
        market: Literal["cn", "us"] = "cn",
        timeframe: TimeFrame = TimeFrame.DAILY,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None
    ) -> MarketData:
        if market == "cn":
            return self.fetch_a_stock(symbol, timeframe, start_date, end_date)
        else:
            return self.fetch_us_stock(symbol, timeframe, start_date, end_date)
