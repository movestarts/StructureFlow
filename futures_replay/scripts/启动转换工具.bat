@echo off
chcp 65001 >nul
cd /d %~dp0
python 简易版_csv_converter.py
if errorlevel 1 (
    echo.
    echo [错误] 启动失败！请确保已安装Python和pandas
    echo.
    echo 解决方法：
    echo   pip install pandas
    echo.
    pause
)
