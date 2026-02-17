import os
import platform
from datetime import datetime
from typing import Optional
from models.data_models import MarketData


class StorageAdapter:
    def __init__(self):
        self.platform = platform.system()
        self.base_dir = self._get_base_dir()

    def _get_base_dir(self) -> str:
        cwd = os.getcwd()
        output_dir = os.path.join(cwd, "output")
        return output_dir

    def ensure_dir_exists(self):
        if not os.path.exists(self.base_dir):
            os.makedirs(self.base_dir, exist_ok=True)
        return self.base_dir

    def generate_filename(self, market_data: MarketData) -> str:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        return f"{market_data.symbol}_{market_data.timeframe.value}_{timestamp}.csv"

    def save_csv(self, market_data: MarketData, custom_path: Optional[str] = None) -> str:
        self.ensure_dir_exists()
        filename = self.generate_filename(market_data)
        if custom_path:
            full_path = custom_path
        else:
            full_path = os.path.join(self.base_dir, filename)
        df = market_data.to_standard_csv()
        df.to_csv(full_path, index=False, encoding='utf-8-sig')
        return full_path

    def get_save_directory(self) -> str:
        return self.base_dir
