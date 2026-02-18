@echo off
chcp 65001 >nul
cls
echo.
echo ================================================================
echo               期货训练营 - Android APK 打包工具
echo ================================================================
echo.
echo [1/5] 检查 Flutter 环境...
flutter --version
if errorlevel 1 (
    echo.
    echo [错误] Flutter 未安装或未配置环境变量
    echo.
    echo 解决方法：
    echo   1. 确保已安装 Flutter SDK
    echo   2. 将 Flutter SDK 的 bin 目录添加到系统 PATH
    echo   3. 重启命令行窗口
    echo.
    pause
    exit /b 1
)

echo.
echo [2/5] 清理旧的构建文件...
flutter clean

echo.
echo [3/5] 获取依赖包...
flutter pub get

echo.
echo [4/5] 开始构建 APK...
echo.
echo 构建选项：
echo   [1] Debug APK （快速，用于测试）
echo   [2] Release APK （优化，用于分发）
echo   [3] App Bundle （上架 Google Play）
echo.
set /p choice="请选择构建类型 (1/2/3): "

if "%choice%"=="1" (
    echo.
    echo 构建 Debug APK...
    flutter build apk --debug
    set OUTPUT_PATH=build\app\outputs\flutter-apk\app-debug.apk
) else if "%choice%"=="2" (
    echo.
    echo 构建 Release APK...
    flutter build apk --release
    set OUTPUT_PATH=build\app\outputs\flutter-apk\app-release.apk
) else if "%choice%"=="3" (
    echo.
    echo 构建 App Bundle...
    flutter build appbundle --release
    set OUTPUT_PATH=build\app\outputs\bundle\release\app-release.aab
) else (
    echo.
    echo [错误] 无效的选择
    pause
    exit /b 1
)

if errorlevel 1 (
    echo.
    echo [错误] 构建失败，请查看上方错误信息
    echo.
    pause
    exit /b 1
)

echo.
echo ================================================================
echo [5/5] 构建完成！
echo ================================================================
echo.
echo 输出文件位置：
echo   %OUTPUT_PATH%
echo.
echo 文件大小：
for %%A in ("%OUTPUT_PATH%") do echo   %%~zA 字节 (约 %%~zA MB)
echo.
echo 下一步操作：
if "%choice%"=="1" (
    echo   - 安装到手机: adb install "%OUTPUT_PATH%"
    echo   - 或将APK文件复制到手机直接安装
) else if "%choice%"=="2" (
    echo   - 分发给用户
    echo   - 或发布到第三方应用商店
) else (
    echo   - 上传到 Google Play Console
)
echo.
echo 是否打开输出目录？
set /p open="(Y/N): "
if /i "%open%"=="Y" (
    explorer "%CD%\build\app\outputs"
)
echo.
pause
