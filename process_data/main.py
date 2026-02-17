import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import flet as ft
from ui.main_ui import MainUI


def main(page: ft.Page):
    page.title = "UniData-Fetcher 通用行情获取器"
    page.window.width = 800
    page.window.height = 600
    page.window.min_width = 600
    page.window.min_height = 400
    page.theme_mode = ft.ThemeMode.LIGHT
    page.padding = 20
    ui = MainUI(page)
    page.add(ui.build())


if __name__ == "__main__":
    ft.app(target=main)
