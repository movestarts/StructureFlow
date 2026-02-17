# 打包 Android APK 脚本
# 用法: .\build_apk.ps1          普通输出
#       .\build_apk.ps1 -Verbose  显示详细打包信息（Gradle/NDK 等）

param([switch]$Verbose)

$env:ANDROID_HOME = "C:\Users\Administrator\AppData\Local\Android\Sdk"
$flutter = "D:\flutter\flutter\bin\flutter.bat"

Set-Location $PSScriptRoot
# 先停止已有 Gradle 守护进程，避免 build logic queue 被占用
if (Test-Path "android\gradlew.bat") {
    & "android\gradlew.bat" --stop 2>$null
}
$args = @("build", "apk", "--release")
if ($Verbose) { $args += "--verbose" }
& $flutter @args

if ($LASTEXITCODE -eq 0) {
    $apk = Join-Path $PSScriptRoot "build\app\outputs\flutter-apk\app-release.apk"
    Write-Host "`nAPK 已生成: $apk" -ForegroundColor Green
}
