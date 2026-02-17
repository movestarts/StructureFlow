import ccxt
import pandas as pd
from datetime import datetime
from typing import Optional
from models.data_models import MarketData, MarketType, TimeFrame, ensure_columns


class CryptoService:
    def __init__(self, exchange_id: str = "binance"):
        self.market_type = MarketType.CRYPTO
        self.exchange_id = exchange_id
        self.exchange = self._init_exchange(exchange_id)

    def _init_exchange(self, exchange_id: str):
        exchange_class = getattr(ccxt, exchange_id, None)
        if exchange_class is None:
            raise ValueError(f"不支持的交易所: {exchange_id}")
        return exchange_class({'enableRateLimit': True})

    def fetch_data(
        self,
        symbol: str,
        timeframe: TimeFrame = TimeFrame.DAILY,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
        exchange_id: Optional[str] = None
    ) -> MarketData:
        if exchange_id and exchange_id != self.exchange_id:
            self.exchange = self._init_exchange(exchange_id)
            self.exchange_id = exchange_id

        try:
            tf_map = {
                TimeFrame.DAILY: '1d',
                TimeFrame.HOUR_1: '1h',
                TimeFrame.MINUTE_15: '15m',
                TimeFrame.MINUTE_5: '5m',
                TimeFrame.MINUTE_1: '1m'
            }
            ccxt_timeframe = tf_map.get(timeframe, '1d')
            since = None
            if start_date:
                since = int(start_date.timestamp() * 1000)
            ohlcv = self.exchange.fetch_ohlcv(
                symbol,
                timeframe=ccxt_timeframe,
                since=since,
                limit=1000
            )
            df = pd.DataFrame(
                ohlcv,
                columns=['datetime', 'open', 'high', 'low', 'close', 'volume']
            )
            df['datetime'] = pd.to_datetime(df['datetime'], unit='ms')
            df['amount'] = df['close'] * df['volume']
            df['position'] = 0
            if end_date:
                df = df[pd.to_datetime(df['datetime']) <= end_date]
            df = ensure_columns(df, symbol)
            return MarketData(
                symbol=symbol,
                market_type=self.market_type,
                timeframe=timeframe,
                df=df
            )
        except Exception as e:
            raise Exception(f"获取加密货币数据失败: {str(e)}")

    def get_available_symbols(self) -> list:
        try:
            markets = self.exchange.load_markets()
            return list(markets.keys())
        except:
            return []

    @staticmethod
    def get_supported_exchanges() -> list:
        return ['binance', 'okx', 'huobi', 'gateio', 'bybit']
