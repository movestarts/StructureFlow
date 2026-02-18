# Android APK 打包指南

## 🚀 快速打包（推荐）

### 方法一：使用打包脚本

1. **双击运行**打包脚本：
   ```
   build_apk.bat
   ```

2. **选择构建类型**：
   - `1` - Debug APK（测试用，快速）
   - `2` - Release APK（发布用，优化）
   - `3` - App Bundle（Google Play用）

3. **等待完成**（约3-5分钟）

4. **获取APK**：
   - Debug: `build\app\outputs\flutter-apk\app-debug.apk`
   - Release: `build\app\outputs\flutter-apk\app-release.apk`
   - Bundle: `build\app\outputs\bundle\release\app-release.aab`

---

## 📱 手动打包（命令行）

### 前置要求

确保已安装：
- ✅ Flutter SDK
- ✅ Android SDK
- ✅ Java JDK

验证环境：
```bash
flutter doctor
```

### 步骤 1: 清理项目

```bash
cd d:\code\trend\futures_replay
flutter clean
```

### 步骤 2: 获取依赖

```bash
flutter pub get
```

### 步骤 3: 构建 APK

#### 构建 Debug APK（测试用）

```bash
flutter build apk --debug
```

**特点**：
- ✅ 构建速度快（约2分钟）
- ✅ 可调试
- ❌ 文件较大（约80-100MB）
- ❌ 未优化性能

**输出位置**：
```
build\app\outputs\flutter-apk\app-debug.apk
```

#### 构建 Release APK（发布用）⭐

```bash
flutter build apk --release
```

**特点**：
- ✅ 代码混淆和优化
- ✅ 文件较小（约40-60MB）
- ✅ 性能最优
- ❌ 构建时间稍长（约3-5分钟）

**输出位置**：
```
build\app\outputs\flutter-apk\app-release.apk
```

#### 构建 App Bundle（Google Play）

```bash
flutter build appbundle --release
```

**特点**：
- ✅ 支持动态交付
- ✅ 文件最小
- ✅ 适合应用商店
- ⚠️ 需要签名

**输出位置**：
```
build\app\outputs\bundle\release\app-release.aab
```

---

## 🔐 应用签名（发布必需）

### 为什么需要签名？

- ✅ Google Play 要求
- ✅ 用户信任
- ✅ 应用更新验证

### 步骤 1: 生成签名密钥

```bash
keytool -genkey -v -keystore d:\code\trend\futures_replay\android\app\keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias futures_replay
```

**填写信息**：
- 密码：`请设置一个安全的密码`
- 名字：`您的名字或公司名`
- 组织：`您的组织`
- 城市/国家等

⚠️ **重要**：妥善保管密钥文件和密码！丢失将无法更新应用！

### 步骤 2: 配置签名

创建 `android/key.properties`：

```properties
storePassword=您的密钥库密码
keyPassword=您的密钥密码
keyAlias=futures_replay
storeFile=keystore.jks
```

⚠️ **安全提示**：将 `key.properties` 添加到 `.gitignore`，不要上传到Git！

### 步骤 3: 更新 build.gradle

编辑 `android/app/build.gradle`，在 `android {` 前添加：

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

在 `android {` 中的 `buildTypes` 前添加：

```gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
```

修改 `buildTypes` 中的 `release`：

```gradle
buildTypes {
    release {
        signingConfig signingConfigs.release  // ← 改这里
        minifyEnabled true
        shrinkResources true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```

### 步骤 4: 构建签名的 APK

```bash
flutter build apk --release
```

---

## 📦 不同构建类型对比

| 类型 | 大小 | 速度 | 用途 | 命令 |
|-----|------|------|------|------|
| **Debug APK** | ~100MB | ⚡ 快 | 开发测试 | `flutter build apk --debug` |
| **Release APK** | ~50MB | 🐌 中 | 分发安装 | `flutter build apk --release` |
| **Split APKs** | ~30MB | 🐢 慢 | 多架构优化 | `flutter build apk --split-per-abi` |
| **App Bundle** | ~40MB | 🐢 慢 | Google Play | `flutter build appbundle` |

### Split APKs（推荐用于分发）

```bash
flutter build apk --split-per-abi --release
```

**优势**：
- ✅ 每个架构单独APK
- ✅ 文件更小（约20-30MB）
- ✅ 用户只下载适合的版本

**输出**：
```
build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk  (32位)
build\app\outputs\flutter-apk\app-arm64-v8a-release.apk    (64位，推荐)
build\app\outputs\flutter-apk\app-x86_64-release.apk       (模拟器)
```

---

## 🧪 安装和测试

### 方法 1: ADB 安装（推荐）

```bash
# 连接手机，开启USB调试
adb devices

# 安装APK
adb install build\app\outputs\flutter-apk\app-release.apk

# 如果已安装，覆盖安装
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

### 方法 2: 直接安装

1. 将APK文件复制到手机
2. 打开文件管理器
3. 点击APK文件
4. 允许安装未知来源应用
5. 点击安装

### 测试清单

安装后测试：

- [ ] 应用正常启动
- [ ] 内置数据自动导入
- [ ] 可以选择内置数据进行训练
- [ ] 文件选择功能（权限请求）
- [ ] CSV导入功能
- [ ] 截图保存功能
- [ ] 分享功能
- [ ] 横竖屏切换
- [ ] 数据库读写
- [ ] 网络功能（AI分析）

---

## 🐛 常见问题

### Q1: 提示 "flutter 不是内部或外部命令"

**解决**：
1. 确认已安装 Flutter SDK
2. 将 Flutter SDK 的 `bin` 目录添加到系统 PATH
3. 重启命令行窗口

验证：
```bash
flutter --version
```

### Q2: 构建失败，提示 "Gradle task assembleRelease failed"

**可能原因**：
1. ❌ Android SDK 未正确配置
2. ❌ 缺少依赖
3. ❌ 代码错误

**解决**：
```bash
# 清理项目
flutter clean

# 重新获取依赖
flutter pub get

# 查看详细错误
flutter build apk --release -v
```

### Q3: APK 安装失败

**可能原因**：
1. ❌ 签名冲突（如果之前安装过不同签名的版本）
2. ❌ 系统版本不兼容（需要 Android 6.0+）
3. ❌ 权限限制

**解决**：
```bash
# 卸载旧版本
adb uninstall com.example.futures_replay

# 重新安装
adb install build\app\outputs\flutter-apk\app-release.apk
```

### Q4: APK 体积过大

**优化方法**：

1. **使用 Split APKs**：
   ```bash
   flutter build apk --split-per-abi --release
   ```

2. **启用混淆**（已配置）：
   - ProGuard 规则在 `android/app/proguard-rules.pro`

3. **移除未使用的资源**（已启用）：
   - `shrinkResources = true` in build.gradle

### Q5: 权限请求不弹出

**检查**：
1. AndroidManifest.xml 中是否声明权限
2. 是否调用 `PermissionHelper.requestStoragePermission()`
3. Android 版本（Android 13+ 不需要存储权限）

---

## 📊 构建时间参考

| 构建类型 | 首次构建 | 增量构建 |
|---------|---------|---------|
| Debug | 3-5分钟 | 1-2分钟 |
| Release | 5-8分钟 | 2-3分钟 |
| Bundle | 6-10分钟 | 2-4分钟 |

*时间取决于电脑性能和网络速度

---

## 🚀 发布准备

### 发布前检查清单

- [ ] 应用签名配置完成
- [ ] 版本号更新（pubspec.yaml）
- [ ] 测试所有功能
- [ ] 准备应用图标（多种尺寸）
- [ ] 准备应用截图（5-8张）
- [ ] 编写应用描述
- [ ] 隐私政策（如需要）
- [ ] 用户协议（如需要）

### Google Play 发布

1. **注册开发者账号**（$25 一次性费用）
2. **创建应用**
3. **上传 App Bundle**
4. **填写商店信息**
5. **提交审核**

### 第三方应用商店

国内常见渠道：
- 应用宝（腾讯）
- 华为应用市场
- 小米应用商店
- OPPO软件商店
- vivo应用商店
- 百度手机助手
- 360手机助手

每个商店都有自己的审核流程和要求。

---

## 📝 更新日志模板

`android/app/src/main/play/release-notes/zh-CN/default.txt`:

```
版本 1.0.1 更新内容：

✨ 新功能
- 内置螺纹钢和豆粕示例数据
- 支持从数据库快速加载数据

🐛 修复
- 修复Android权限请求问题
- 优化数据库性能

🎨 优化
- 改进UI交互体验
- 提升应用启动速度
```

---

## 🔗 相关资源

- [Flutter 官方文档](https://flutter.dev/docs/deployment/android)
- [Android 应用签名](https://developer.android.com/studio/publish/app-signing)
- [Google Play 发布指南](https://play.google.com/console/about/guides/releasewithconfidence/)

---

**最后更新**: 2026-02-17  
**适用版本**: v1.0.1+4  
**状态**: ✅ 可以开始打包
