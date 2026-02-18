@echo off
chcp 65001 >nul
cls
echo.
echo ===============================================
echo    期货数据转换工具 - 打包脚本
echo ===============================================
echo.
echo [1/3] 准备打包环境...
cd /d %~dp0

echo [2/3] 开始打包...
echo.

pyinstaller ^
  --onefile ^
  --windowed ^
  --name "期货数据转换工具" ^
  --clean ^
  --noconfirm ^
  简易版_csv_converter.py

echo.
echo [3/3] 清理临时文件...
if exist build rmdir /s /q build
if exist __pycache__ rmdir /s /q __pycache__
if exist "期货数据转换工具.spec" del "期货数据转换工具.spec"

echo.
echo ===============================================
echo    打包完成！
echo ===============================================
echo.
echo 生成的EXE文件位置:
echo   dist\期货数据转换工具.exe
echo.
echo 使用说明:
echo   1. 双击运行 exe 文件
echo   2. 点击按钮选择CSV文件
echo   3. 自动转换并保存到原文件目录
echo.
pause
