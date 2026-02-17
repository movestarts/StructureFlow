import flet as ft
from datetime import datetime
from typing import Optional, Callable
from models.data_models import TimeFrame
from services.futures_service import FuturesService
from services.stock_service import StockService
from services.crypto_service import CryptoService
from services.forex_service import ForexService
from utils.storage import StorageAdapter


POPULAR_FUTURES = [
    ("RB", "螺纹钢"), ("HC", "热卷"), ("I", "铁矿石"), ("J", "焦炭"),
    ("JM", "焦煤"), ("CU", "铜"), ("AL", "铝"), ("ZN", "锌"),
    ("AU", "黄金"), ("AG", "白银"), ("NI", "镍"), ("SN", "锡"),
    ("PB", "铅"), ("SS", "不锈钢"), ("A", "豆一"), ("M", "豆粕"),
    ("Y", "豆油"), ("P", "棕榈油"), ("C", "玉米"), ("CS", "玉米淀粉"),
    ("SR", "白糖"), ("CF", "棉花"), ("TA", "PTA"), ("MA", "甲醇"),
    ("FG", "玻璃"), ("SA", "纯碱"), ("EG", "乙二醇"), ("PP", "聚丙烯"),
    ("L", "塑料"), ("V", "PVC"), ("FU", "燃料油"), ("SC", "原油"),
]

POPULAR_STOCKS_CN = [
    ("000001", "平安银行"), ("000002", "万科A"), ("000333", "美的集团"),
    ("000651", "格力电器"), ("000858", "五粮液"), ("002594", "比亚迪"),
    ("600000", "浦发银行"), ("600036", "招商银行"), ("600519", "贵州茅台"),
    ("600887", "伊利股份"), ("601318", "中国平安"), ("601398", "工商银行"),
    ("601857", "中国石油"), ("601888", "中国中免"), ("300750", "宁德时代"),
    ("300059", "东方财富"), ("002415", "海康威视"), ("002475", "立讯精密"),
]

POPULAR_STOCKS_US = [
    ("AAPL", "苹果"), ("MSFT", "微软"), ("GOOGL", "谷歌"), ("AMZN", "亚马逊"),
    ("META", "Meta"), ("NVDA", "英伟达"), ("TSLA", "特斯拉"), ("AMD", "AMD"),
    ("INTC", "英特尔"), ("NFLX", "奈飞"), ("DIS", "迪士尼"), ("BA", "波音"),
    ("JPM", "摩根大通"), ("V", "Visa"), ("MA", "万事达"), ("WMT", "沃尔玛"),
]

POPULAR_CRYPTO = [
    ("BTC/USDT", "比特币"), ("ETH/USDT", "以太坊"), ("BNB/USDT", "币安币"),
    ("XRP/USDT", "瑞波币"), ("ADA/USDT", "艾达币"), ("DOGE/USDT", "狗狗币"),
    ("SOL/USDT", "Solana"), ("DOT/USDT", "波卡"), ("MATIC/USDT", "Polygon"),
    ("LINK/USDT", "Chainlink"), ("AVAX/USDT", "Avalanche"), ("ATOM/USDT", "Cosmos"),
    ("UNI/USDT", "Uniswap"), ("LTC/USDT", "莱特币"), ("BCH/USDT", "比特币现金"),
]

POPULAR_FOREX = [
    ("EURUSD", "欧元/美元"), ("GBPUSD", "英镑/美元"), ("USDJPY", "美元/日元"),
    ("USDCHF", "美元/瑞郎"), ("AUDUSD", "澳元/美元"), ("USDCAD", "美元/加元"),
    ("NZDUSD", "纽元/美元"), ("EURGBP", "欧元/英镑"), ("EURJPY", "欧元/日元"),
    ("GBPJPY", "英镑/日元"), ("XAUUSD", "黄金/美元"), ("XAGUSD", "白银/美元"),
]


class FuturesTab:
    def __init__(self, on_log: Callable, page: ft.Page):
        self.on_log = on_log
        self.page = page
        self.service = FuturesService()
        self.storage = StorageAdapter()
        self.variety_dropdown = ft.Dropdown(
            label="选择品种",
            width=200,
            options=[
                ft.dropdown.Option(key=code, text=f"{code} - {name}")
                for code, name in POPULAR_FUTURES
            ],
            on_select=self._on_variety_change
        )
        self.contract_dropdown = ft.Dropdown(
            label="选择合约",
            width=280,
            options=[],
            disabled=True
        )
        self.loading_text = ft.Text("请先选择品种", color=ft.Colors.GREY_500)
        self.timeframe_dropdown = ft.Dropdown(
            label="周期",
            width=150,
            options=[
                ft.dropdown.Option(key="daily", text="日线"),
                ft.dropdown.Option(key="1h", text="1小时"),
                ft.dropdown.Option(key="15m", text="15分钟"),
                ft.dropdown.Option(key="5m", text="5分钟"),
            ],
            value="daily"
        )
        self.start_date = ft.TextField(
            label="开始日期",
            hint_text="YYYY-MM-DD (可选)",
            width=150
        )
        self.end_date = ft.TextField(
            label="结束日期",
            hint_text="YYYY-MM-DD (可选)",
            width=150
        )
        self.progress = ft.ProgressBar(width=400, visible=False)
        self.fetch_btn = ft.ElevatedButton(
            "获取并导出",
            on_click=self._on_fetch,
            width=150,
            style=ft.ButtonStyle(bgcolor=ft.Colors.BLUE_500, color=ft.Colors.WHITE),
            disabled=True
        )

    def _on_variety_change(self, e):
        variety = self.variety_dropdown.value
        if not variety:
            return
        self.loading_text.value = "正在加载合约列表..."
        self.loading_text.color = ft.Colors.ORANGE_500
        self.contract_dropdown.disabled = True
        self.contract_dropdown.options = []
        self.fetch_btn.disabled = True
        self.page.update()
        try:
            contracts = self.service.get_contracts_by_variety(variety)
            if contracts:
                self.contract_dropdown.options = [
                    ft.dropdown.Option(key=symbol, text=f"{symbol} - {name}")
                    for symbol, name in contracts
                ]
                self.contract_dropdown.disabled = False
                self.loading_text.value = f"已加载 {len(contracts)} 个合约"
                self.loading_text.color = ft.Colors.GREEN_500
            else:
                self.loading_text.value = "未找到合约，请手动输入"
                self.loading_text.color = ft.Colors.RED_500
        except Exception as ex:
            self.loading_text.value = f"加载失败: {str(ex)}"
            self.loading_text.color = ft.Colors.RED_500
        self.page.update()

    def _on_contract_change(self, e):
        self.fetch_btn.disabled = not self.contract_dropdown.value
        self.page.update()

    def _on_fetch(self, e):
        symbol = self.contract_dropdown.value
        if not symbol:
            self.on_log("错误: 请选择合约")
            return
        self.progress.visible = True
        self.fetch_btn.disabled = True
        self.page.update()
        try:
            timeframe = TimeFrame(self.timeframe_dropdown.value)
            start = None
            end = None
            if self.start_date.value:
                start = datetime.strptime(self.start_date.value, "%Y-%m-%d")
            if self.end_date.value:
                end = datetime.strptime(self.end_date.value, "%Y-%m-%d")
            self.on_log(f"正在获取期货数据: {symbol}...")
            market_data = self.service.fetch_data(symbol, timeframe, start, end)
            self.on_log(f"获取到 {len(market_data.df)} 条数据")
            path = self.storage.save_csv(market_data)
            self.on_log(f"成功导出至: {path}")
        except Exception as ex:
            self.on_log(f"错误: {str(ex)}")
        finally:
            self.progress.visible = False
            self.fetch_btn.disabled = False
            self.page.update()

    def build(self) -> ft.Control:
        self.contract_dropdown.on_select = self._on_contract_change
        return ft.Column(
            [
                ft.Text("期货数据获取", size=16, weight=ft.FontWeight.BOLD),
                ft.Divider(),
                ft.Text("第一步: 选择品种", color=ft.Colors.GREY_700),
                ft.Row([self.variety_dropdown]),
                ft.Text("第二步: 选择合约", color=ft.Colors.GREY_700),
                ft.Row([self.contract_dropdown]),
                self.loading_text,
                ft.Divider(),
                ft.Text("周期设置", color=ft.Colors.GREY_700),
                ft.Row([self.timeframe_dropdown]),
                ft.Text("日期范围 (可选)", color=ft.Colors.GREY_700),
                ft.Row([self.start_date, self.end_date]),
                ft.Row([self.fetch_btn]),
                self.progress,
            ],
            spacing=10
        )


class StockTab:
    def __init__(self, on_log: Callable):
        self.on_log = on_log
        self.service = StockService()
        self.storage = StorageAdapter()
        self.market_dropdown = ft.Dropdown(
            label="市场",
            width=120,
            options=[
                ft.dropdown.Option(key="cn", text="A股"),
                ft.dropdown.Option(key="us", text="美股"),
            ],
            value="cn"
        )
        self.popular_dropdown = ft.Dropdown(
            label="选择股票",
            width=250,
            options=[
                ft.dropdown.Option(key=code, text=f"{code} - {name}")
                for code, name in POPULAR_STOCKS_CN
            ],
        )
        self.symbol_input = ft.TextField(
            label="股票代码",
            hint_text="可手动输入其他代码",
            width=200
        )
        self.timeframe_dropdown = ft.Dropdown(
            label="周期",
            width=150,
            options=[
                ft.dropdown.Option(key="daily", text="日线"),
                ft.dropdown.Option(key="1h", text="1小时"),
                ft.dropdown.Option(key="15m", text="15分钟"),
            ],
            value="daily"
        )
        self.start_date = ft.TextField(
            label="开始日期",
            hint_text="YYYY-MM-DD (可选)",
            width=150
        )
        self.end_date = ft.TextField(
            label="结束日期",
            hint_text="YYYY-MM-DD (可选)",
            width=150
        )
        self.progress = ft.ProgressBar(width=400, visible=False)
        self.fetch_btn = ft.ElevatedButton(
            "获取并导出",
            on_click=self._on_fetch,
            width=150,
            style=ft.ButtonStyle(bgcolor=ft.Colors.BLUE_500, color=ft.Colors.WHITE)
        )

    def _on_fetch(self, e):
        symbol = self.symbol_input.value.strip()
        if not symbol:
            symbol = self.popular_dropdown.value
        if not symbol:
            self.on_log("错误: 请选择或输入股票代码")
            return
        self.progress.visible = True
        self.fetch_btn.disabled = True
        e.page.update()
        try:
            market = self.market_dropdown.value
            timeframe = TimeFrame(self.timeframe_dropdown.value)
            start = None
            end = None
            if self.start_date.value:
                start = datetime.strptime(self.start_date.value, "%Y-%m-%d")
            if self.end_date.value:
                end = datetime.strptime(self.end_date.value, "%Y-%m-%d")
            self.on_log(f"正在获取股票数据: {symbol} ({market})...")
            market_data = self.service.fetch_data(symbol, market, timeframe, start, end)
            self.on_log(f"获取到 {len(market_data.df)} 条数据")
            path = self.storage.save_csv(market_data)
            self.on_log(f"成功导出至: {path}")
        except Exception as ex:
            self.on_log(f"错误: {str(ex)}")
        finally:
            self.progress.visible = False
            self.fetch_btn.disabled = False
            e.page.update()

    def build(self) -> ft.Control:
        return ft.Column(
            [
                ft.Text("股票数据获取", size=16, weight=ft.FontWeight.BOLD),
                ft.Divider(),
                ft.Text("选择市场", color=ft.Colors.GREY_700),
                ft.Row([self.market_dropdown]),
                ft.Text("方式一: 从列表选择", color=ft.Colors.GREY_700),
                ft.Row([self.popular_dropdown]),
                ft.Text("方式二: 手动输入代码", color=ft.Colors.GREY_700),
                ft.Row([self.symbol_input, self.timeframe_dropdown]),
                ft.Divider(),
                ft.Text("日期范围 (可选)", color=ft.Colors.GREY_700),
                ft.Row([self.start_date, self.end_date]),
                ft.Row([self.fetch_btn]),
                self.progress,
            ],
            spacing=10
        )


class CryptoTab:
    def __init__(self, on_log: Callable):
        self.on_log = on_log
        self.service = CryptoService()
        self.storage = StorageAdapter()
        self.exchange_dropdown = ft.Dropdown(
            label="交易所",
            width=150,
            options=[
                ft.dropdown.Option(key="binance", text="Binance"),
                ft.dropdown.Option(key="okx", text="OKX"),
                ft.dropdown.Option(key="gateio", text="Gate.io"),
                ft.dropdown.Option(key="bybit", text="Bybit"),
            ],
            value="binance"
        )
        self.popular_dropdown = ft.Dropdown(
            label="选择交易对",
            width=250,
            options=[
                ft.dropdown.Option(key=symbol, text=f"{symbol} - {name}")
                for symbol, name in POPULAR_CRYPTO
            ],
        )
        self.symbol_input = ft.TextField(
            label="交易对",
            hint_text="例如: BTC/USDT",
            width=200
        )
        self.timeframe_dropdown = ft.Dropdown(
            label="周期",
            width=150,
            options=[
                ft.dropdown.Option(key="daily", text="日线"),
                ft.dropdown.Option(key="1h", text="1小时"),
                ft.dropdown.Option(key="15m", text="15分钟"),
                ft.dropdown.Option(key="5m", text="5分钟"),
                ft.dropdown.Option(key="1m", text="1分钟"),
            ],
            value="daily"
        )
        self.start_date = ft.TextField(
            label="开始日期",
            hint_text="YYYY-MM-DD (可选)",
            width=150
        )
        self.end_date = ft.TextField(
            label="结束日期",
            hint_text="YYYY-MM-DD (可选)",
            width=150
        )
        self.progress = ft.ProgressBar(width=400, visible=False)
        self.fetch_btn = ft.ElevatedButton(
            "获取并导出",
            on_click=self._on_fetch,
            width=150,
            style=ft.ButtonStyle(bgcolor=ft.Colors.BLUE_500, color=ft.Colors.WHITE)
        )

    def _on_fetch(self, e):
        symbol = self.symbol_input.value.strip()
        if not symbol:
            symbol = self.popular_dropdown.value
        if not symbol:
            self.on_log("错误: 请选择或输入交易对")
            return
        self.progress.visible = True
        self.fetch_btn.disabled = True
        e.page.update()
        try:
            exchange = self.exchange_dropdown.value
            timeframe = TimeFrame(self.timeframe_dropdown.value)
            start = None
            end = None
            if self.start_date.value:
                start = datetime.strptime(self.start_date.value, "%Y-%m-%d")
            if self.end_date.value:
                end = datetime.strptime(self.end_date.value, "%Y-%m-%d")
            self.on_log(f"正在获取加密货币数据: {symbol} ({exchange})...")
            market_data = self.service.fetch_data(symbol, timeframe, start, end, exchange)
            self.on_log(f"获取到 {len(market_data.df)} 条数据")
            path = self.storage.save_csv(market_data)
            self.on_log(f"成功导出至: {path}")
        except Exception as ex:
            self.on_log(f"错误: {str(ex)}")
        finally:
            self.progress.visible = False
            self.fetch_btn.disabled = False
            e.page.update()

    def build(self) -> ft.Control:
        return ft.Column(
            [
                ft.Text("加密货币数据获取", size=16, weight=ft.FontWeight.BOLD),
                ft.Divider(),
                ft.Text("选择交易所", color=ft.Colors.GREY_700),
                ft.Row([self.exchange_dropdown]),
                ft.Text("方式一: 从列表选择", color=ft.Colors.GREY_700),
                ft.Row([self.popular_dropdown]),
                ft.Text("方式二: 手动输入交易对", color=ft.Colors.GREY_700),
                ft.Row([self.symbol_input, self.timeframe_dropdown]),
                ft.Divider(),
                ft.Text("日期范围 (可选)", color=ft.Colors.GREY_700),
                ft.Row([self.start_date, self.end_date]),
                ft.Row([self.fetch_btn]),
                self.progress,
            ],
            spacing=10
        )


class ForexTab:
    def __init__(self, on_log: Callable):
        self.on_log = on_log
        self.service = ForexService()
        self.storage = StorageAdapter()
        self.popular_dropdown = ft.Dropdown(
            label="选择货币对",
            width=250,
            options=[
                ft.dropdown.Option(key=symbol, text=f"{symbol} - {name}")
                for symbol, name in POPULAR_FOREX
            ],
        )
        self.symbol_input = ft.TextField(
            label="货币对",
            hint_text="例如: EURUSD",
            width=200
        )
        self.timeframe_dropdown = ft.Dropdown(
            label="周期",
            width=150,
            options=[
                ft.dropdown.Option(key="daily", text="日线"),
                ft.dropdown.Option(key="1h", text="1小时"),
                ft.dropdown.Option(key="15m", text="15分钟"),
            ],
            value="daily"
        )
        self.start_date = ft.TextField(
            label="开始日期",
            hint_text="YYYY-MM-DD (可选)",
            width=150
        )
        self.end_date = ft.TextField(
            label="结束日期",
            hint_text="YYYY-MM-DD (可选)",
            width=150
        )
        self.progress = ft.ProgressBar(width=400, visible=False)
        self.fetch_btn = ft.ElevatedButton(
            "获取并导出",
            on_click=self._on_fetch,
            width=150,
            style=ft.ButtonStyle(bgcolor=ft.Colors.BLUE_500, color=ft.Colors.WHITE)
        )

    def _on_fetch(self, e):
        symbol = self.symbol_input.value.strip()
        if not symbol:
            symbol = self.popular_dropdown.value
        if not symbol:
            self.on_log("错误: 请选择或输入货币对")
            return
        self.progress.visible = True
        self.fetch_btn.disabled = True
        e.page.update()
        try:
            timeframe = TimeFrame(self.timeframe_dropdown.value)
            start = None
            end = None
            if self.start_date.value:
                start = datetime.strptime(self.start_date.value, "%Y-%m-%d")
            if self.end_date.value:
                end = datetime.strptime(self.end_date.value, "%Y-%m-%d")
            self.on_log(f"正在获取外汇数据: {symbol}...")
            market_data = self.service.fetch_data(symbol, timeframe, start, end)
            self.on_log(f"获取到 {len(market_data.df)} 条数据")
            path = self.storage.save_csv(market_data)
            self.on_log(f"成功导出至: {path}")
        except Exception as ex:
            self.on_log(f"错误: {str(ex)}")
        finally:
            self.progress.visible = False
            self.fetch_btn.disabled = False
            e.page.update()

    def build(self) -> ft.Control:
        return ft.Column(
            [
                ft.Text("外汇数据获取", size=16, weight=ft.FontWeight.BOLD),
                ft.Divider(),
                ft.Text("方式一: 从列表选择", color=ft.Colors.GREY_700),
                ft.Row([self.popular_dropdown]),
                ft.Text("方式二: 手动输入货币对", color=ft.Colors.GREY_700),
                ft.Row([self.symbol_input, self.timeframe_dropdown]),
                ft.Divider(),
                ft.Text("日期范围 (可选)", color=ft.Colors.GREY_700),
                ft.Row([self.start_date, self.end_date]),
                ft.Row([self.fetch_btn]),
                self.progress,
            ],
            spacing=10
        )


class MainUI:
    def __init__(self, page: ft.Page):
        self.page = page
        self.current_tab = 0
        self.log_text = ft.Text(value="", size=12, color=ft.Colors.GREY_600)
        self.log_container = ft.Container(
            content=ft.Column([self.log_text], scroll=ft.ScrollMode.AUTO),
            height=150,
            bgcolor=ft.Colors.GREY_50,
            padding=10,
            border_radius=5
        )
        self.futures_tab = FuturesTab(self._log, page)
        self.stock_tab = StockTab(self._log)
        self.crypto_tab = CryptoTab(self._log)
        self.forex_tab = ForexTab(self._log)
        self.tab_content = ft.Column()
        self.tab_buttons = [
            ft.ElevatedButton("期货", on_click=lambda e: self._switch_tab(0), width=100),
            ft.ElevatedButton("股票", on_click=lambda e: self._switch_tab(1), width=100),
            ft.ElevatedButton("加密货币", on_click=lambda e: self._switch_tab(2), width=100),
            ft.ElevatedButton("外汇", on_click=lambda e: self._switch_tab(3), width=100),
        ]
        self._update_tab_content()
        self._update_button_styles()

    def _log(self, message: str):
        timestamp = datetime.now().strftime("%H:%M:%S")
        current = self.log_text.value or ""
        self.log_text.value = f"[{timestamp}] {message}\n{current}"
        self.page.update()

    def _update_tab_content(self):
        tabs = [self.futures_tab, self.stock_tab, self.crypto_tab, self.forex_tab]
        self.tab_content.controls = [tabs[self.current_tab].build()]

    def _update_button_styles(self):
        for i, btn in enumerate(self.tab_buttons):
            if i == self.current_tab:
                btn.style = ft.ButtonStyle(
                    bgcolor=ft.Colors.BLUE_500,
                    color=ft.Colors.WHITE
                )
            else:
                btn.style = ft.ButtonStyle(
                    bgcolor=ft.Colors.GREY_200,
                    color=ft.Colors.BLACK
                )

    def _switch_tab(self, index: int):
        self.current_tab = index
        self._update_tab_content()
        self._update_button_styles()
        self.page.update()

    def build(self) -> ft.Control:
        return ft.Column(
            [
                ft.Row(self.tab_buttons, alignment=ft.MainAxisAlignment.CENTER),
                ft.Divider(),
                self.tab_content,
                ft.Divider(),
                ft.Text("操作日志", size=14, weight=ft.FontWeight.BOLD),
                self.log_container,
            ],
            expand=True
        )
