@echo off
chcp 65001
echo ========================================
echo 正在打包CSV转换工具...
echo ========================================
echo.

cd /d %~dp0

pyinstaller --onefile --windowed --name "期货数据转换工具" --icon=NONE --add-data "csv_converter_gui.py;." csv_converter_gui.py

echo.
echo ========================================
echo 打包完成！
echo ========================================
echo.
echo 生成的exe文件在: dist\期货数据转换工具.exe
echo.
pause
