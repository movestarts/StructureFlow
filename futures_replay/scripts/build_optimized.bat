@echo off
chcp 65001 >nul
cls
echo.
echo ===============================================
echo    期货数据转换工具 - 优化打包
echo ===============================================
echo.
echo [提示] 此版本排除不必要的库，体积更小，速度更快！
echo.
echo [1/3] 准备打包环境...
cd /d %~dp0

echo [2/3] 开始打包（预计2-3分钟）...
echo.

pyinstaller ^
  --onefile ^
  --windowed ^
  --name "期货数据转换工具" ^
  --clean ^
  --noconfirm ^
  --exclude-module matplotlib ^
  --exclude-module scipy ^
  --exclude-module IPython ^
  --exclude-module pytest ^
  --exclude-module sphinx ^
  --exclude-module PIL ^
  --exclude-module cv2 ^
  --exclude-module tensorflow ^
  --exclude-module torch ^
  --exclude-module sklearn ^
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
echo 文件大小: 
dir /B "dist\期货数据转换工具.exe" 2>nul && (
    for %%A in ("dist\期货数据转换工具.exe") do echo   约 %%~zA 字节
)
echo.
pause
