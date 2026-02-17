import akshare as ak
import pandas as pd
from datetime import datetime
from typing import Optional, List, Tuple
from models.data_models import MarketData, MarketType, TimeFrame, normalize_columns, ensure_columns


FUTURES_CONTRACTS = {
    "RB": [("RB0", "螺纹钢主力"), ("RB2505", "螺纹钢2505"), ("RB2510", "螺纹钢2510"), ("RB2601", "螺纹钢2601")],
    "HC": [("HC0", "热卷主力"), ("HC2505", "热卷2505"), ("HC2510", "热卷2510"), ("HC2601", "热卷2601")],
    "I": [("I0", "铁矿石主力"), ("I2505", "铁矿石2505"), ("I2509", "铁矿石2509"), ("I2601", "铁矿石2601")],
    "J": [("J0", "焦炭主力"), ("J2505", "焦炭2505"), ("J2509", "焦炭2509"), ("J2601", "焦炭2601")],
    "JM": [("JM0", "焦煤主力"), ("JM2505", "焦煤2505"), ("JM2509", "焦煤2509"), ("JM2601", "焦煤2601")],
    "CU": [("CU0", "铜主力"), ("CU2505", "铜2505"), ("CU2506", "铜2506"), ("CU2507", "铜2507")],
    "AL": [("AL0", "铝主力"), ("AL2505", "铝2505"), ("AL2506", "铝2506"), ("AL2507", "铝2507")],
    "ZN": [("ZN0", "锌主力"), ("ZN2505", "锌2505"), ("ZN2506", "锌2506"), ("ZN2507", "锌2507")],
    "AU": [("AU0", "黄金主力"), ("AU2506", "黄金2506"), ("AU2508", "黄金2508"), ("AU2512", "黄金2512")],
    "AG": [("AG0", "白银主力"), ("AG2506", "白银2506"), ("AG2507", "白银2507"), ("AG2512", "白银2512")],
    "NI": [("NI0", "镍主力"), ("NI2505", "镍2505"), ("NI2509", "镍2509"), ("NI2601", "镍2601")],
    "SN": [("SN0", "锡主力"), ("SN2505", "锡2505"), ("SN2506", "锡2506"), ("SN2507", "锡2507")],
    "PB": [("PB0", "铅主力"), ("PB2505", "铅2505"), ("PB2506", "铅2506"), ("PB2507", "铅2507")],
    "SS": [("SS0", "不锈钢主力"), ("SS2505", "不锈钢2505"), ("SS2506", "不锈钢2506"), ("SS2507", "不锈钢2507")],
    "A": [("A0", "豆一主力"), ("A2505", "豆一2505"), ("A2507", "豆一2507"), ("A2509", "豆一2509")],
    "M": [("M0", "豆粕主力"), ("M2505", "豆粕2505"), ("M2509", "豆粕2509"), ("M2601", "豆粕2601")],
    "Y": [("Y0", "豆油主力"), ("Y2505", "豆油2505"), ("Y2509", "豆油2509"), ("Y2601", "豆油2601")],
    "P": [("P0", "棕榈油主力"), ("P2505", "棕榈油2505"), ("P2509", "棕榈油2509"), ("P2601", "棕榈油2601")],
    "C": [("C0", "玉米主力"), ("C2505", "玉米2505"), ("C2507", "玉米2507"), ("C2509", "玉米2509")],
    "CS": [("CS0", "玉米淀粉主力"), ("CS2505", "玉米淀粉2505"), ("CS2507", "玉米淀粉2507"), ("CS2509", "玉米淀粉2509")],
    "SR": [("SR0", "白糖主力"), ("SR2505", "白糖2505"), ("SR2507", "白糖2507"), ("SR2509", "白糖2509")],
    "CF": [("CF0", "棉花主力"), ("CF2505", "棉花2505"), ("CF2507", "棉花2507"), ("CF2509", "棉花2509")],
    "TA": [("TA0", "PTA主力"), ("TA2505", "PTA2505"), ("TA2509", "PTA2509"), ("TA2601", "PTA2601")],
    "MA": [("MA0", "甲醇主力"), ("MA2505", "甲醇2505"), ("MA2509", "甲醇2509"), ("MA2601", "甲醇2601")],
    "FG": [("FG0", "玻璃主力"), ("FG2505", "玻璃2505"), ("FG2509", "玻璃2509"), ("FG2601", "玻璃2601")],
    "SA": [("SA0", "纯碱主力"), ("SA2505", "纯碱2505"), ("SA2509", "纯碱2509"), ("SA2601", "纯碱2601")],
    "EG": [("EG0", "乙二醇主力"), ("EG2505", "乙二醇2505"), ("EG2509", "乙二醇2509"), ("EG2601", "乙二醇2601")],
    "PP": [("PP0", "聚丙烯主力"), ("PP2505", "聚丙烯2505"), ("PP2509", "聚丙烯2509"), ("PP2601", "聚丙烯2601")],
    "L": [("L0", "塑料主力"), ("L2505", "塑料2505"), ("L2509", "塑料2509"), ("L2601", "塑料2601")],
    "V": [("V0", "PVC主力"), ("V2505", "PVC2505"), ("V2509", "PVC2509"), ("V2601", "PVC2601")],
    "FU": [("FU0", "燃料油主力"), ("FU2505", "燃料油2505"), ("FU2509", "燃料油2509"), ("FU2601", "燃料油2601")],
    "SC": [("SC0", "原油主力"), ("SC2506", "原油2506"), ("SC2509", "原油2509"), ("SC2512", "原油2512")],
}


class FuturesService:
    def __init__(self):
        self.market_type = MarketType.FUTURES

    def fetch_data(
        self,
        symbol: str,
        timeframe: TimeFrame = TimeFrame.DAILY,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None
    ) -> MarketData:
        try:
            if timeframe == TimeFrame.DAILY:
                df = ak.futures_zh_daily_sina(symbol=symbol)
            else:
                period_map = {
                    TimeFrame.MINUTE_1: "1",
                    TimeFrame.MINUTE_5: "5",
                    TimeFrame.MINUTE_15: "15",
                    TimeFrame.HOUR_1: "60",
                }
                period = period_map.get(timeframe, "5")
                df = ak.futures_zh_minute_sina(symbol=symbol, period=period)
            
            df = normalize_columns(df)
            df = self._process_futures_data(df)
            
            if start_date:
                df = df[pd.to_datetime(df['datetime']) >= start_date]
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
            raise Exception(f"获取期货数据失败: {str(e)}")

    def _process_futures_data(self, df: pd.DataFrame) -> pd.DataFrame:
        if 'datetime' not in df.columns:
            date_cols = [col for col in df.columns if '日期' in str(col) or 'date' in str(col).lower()]
            if date_cols:
                df['datetime'] = df[date_cols[0]]
        if 'position' not in df.columns:
            position_cols = [col for col in df.columns if '持仓' in str(col) or 'hold' in str(col).lower()]
            if position_cols:
                df['position'] = df[position_cols[0]]
        if 'amount' not in df.columns:
            if 'close' in df.columns and 'volume' in df.columns:
                df['amount'] = df['close'] * df['volume']
            else:
                df['amount'] = 0
        ignore_cols = ['结算价', '动态结算价', 'settlement', 'settle']
        for col in df.columns:
            if any(ignore in str(col).lower() for ignore in ignore_cols):
                df = df.drop(columns=[col])
        return df

    def get_contracts_by_variety(self, variety_code: str) -> List[Tuple[str, str]]:
        return FUTURES_CONTRACTS.get(variety_code, [])
