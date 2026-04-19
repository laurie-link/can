# 粤语学习助手 - 打包指南

本指南将帮助您将 Flutter 应用打包成可以在手机上直接安装运行的 APK（Android）或 IPA（iOS）文件。

## 📱 Android 打包指南

### 前置要求

1. **安装 Flutter SDK**
   - 下载并安装 Flutter：https://flutter.dev/docs/get-started/install
   - 确保 Flutter 已添加到系统 PATH
   - 运行 `flutter doctor` 检查环境配置

2. **安装 Android Studio**
   - 下载：https://developer.android.com/studio
   - 安装 Android SDK（通过 Android Studio 的 SDK Manager）
   - 配置 Android SDK 路径

3. **配置 Java JDK**
   - 安装 JDK 11 或更高版本
   - 设置 JAVA_HOME 环境变量

### 打包步骤

#### 1. 检查环境

```bash
# 进入项目目录
cd cantonese_app

# 检查 Flutter 环境
flutter doctor

# 确保所有依赖已安装
flutter pub get
```

#### 2. 配置应用信息

编辑 `android/app/build.gradle.kts` 文件，检查以下配置：

```kotlin
android {
    namespace = "com.example.cantonese_app"
    compileSdk = 34  // 确保版本足够高

    defaultConfig {
        applicationId = "com.example.cantonese_app"  // 修改为您的应用ID
        minSdk = 21
        targetSdk = 34
        versionCode = 1  // 每次发布递增
        versionName = "1.0.0"  // 版本号
    }
}
```

#### 3. 生成签名密钥（首次打包）

```bash
# 在项目根目录执行
keytool -genkey -v -keystore ~/cantonese-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias cantonese

# 按提示输入信息：
# - 密钥库密码
# - 姓名、组织等信息
# - 密钥密码（可与密钥库密码相同）
```

#### 4. 配置签名信息

创建 `android/key.properties` 文件：

```properties
storePassword=您的密钥库密码
keyPassword=您的密钥密码
keyAlias=cantonese
storeFile=../cantonese-key.jks
```

**注意：** 不要将此文件提交到 Git！在 `.gitignore` 中添加：
```
android/key.properties
android/*.jks
```

#### 5. 修改 build.gradle.kts

编辑 `android/app/build.gradle.kts`，在文件开头添加：

```kotlin
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ... 其他配置

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            // 启用代码混淆（可选）
            minifyEnabled false
            shrinkResources false
        }
    }
}
```

#### 6. 构建 APK

```bash
# 构建 Release APK
flutter build apk --release

# 构建 App Bundle（用于 Google Play 发布）
flutter build appbundle --release
```

构建完成后，APK 文件位于：
```
build/app/outputs/flutter-apk/app-release.apk
```

#### 7. 安装到手机

**方法一：通过 USB 连接**
```bash
# 连接手机并启用 USB 调试
flutter install
```

**方法二：直接传输 APK**
1. 将 `app-release.apk` 复制到手机
2. 在手机上打开文件管理器
3. 点击 APK 文件安装
4. 允许"未知来源"安装（如需要）

**方法三：通过 ADB 安装**
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 构建不同架构的 APK

```bash
# 仅构建 ARM64（推荐，兼容性好）
flutter build apk --release --target-platform android-arm64

# 构建所有架构（文件较大）
flutter build apk --release --split-per-abi
```

## 🍎 iOS 打包指南

### 前置要求

1. **macOS 系统**（iOS 打包必须在 macOS 上进行）
2. **安装 Xcode**
   - 从 App Store 安装 Xcode
   - 运行 `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
   - 运行 `sudo xcodebuild -runFirstLaunch`

3. **安装 CocoaPods**
   ```bash
   sudo gem install cocoapods
   ```

4. **Apple Developer 账号**（用于真机测试和发布）

### 打包步骤

#### 1. 配置项目

```bash
cd cantonese_app
flutter pub get
cd ios
pod install
cd ..
```

#### 2. 配置应用信息

编辑 `ios/Runner/Info.plist`，设置：
- Bundle Identifier（应用ID）
- Display Name（应用名称）
- Version（版本号）

#### 3. 配置签名

1. 打开 `ios/Runner.xcworkspace`（不是 .xcodeproj）
2. 选择 Runner 项目
3. 在 Signing & Capabilities 中：
   - 选择您的 Team
   - 设置 Bundle Identifier
   - 确保 "Automatically manage signing" 已勾选

#### 4. 构建 IPA

```bash
# 构建 Release 版本
flutter build ios --release

# 或者构建并导出 IPA
flutter build ipa
```

#### 5. 通过 Xcode 打包

1. 打开 `ios/Runner.xcworkspace`
2. 选择 Product > Archive
3. 等待构建完成
4. 在 Organizer 窗口中选择 Archive
5. 点击 "Distribute App"
6. 选择分发方式：
   - **Ad Hoc**：用于测试设备
   - **App Store Connect**：用于 App Store 发布
   - **Enterprise**：企业内部分发
   - **Development**：开发测试

#### 6. 安装到设备

**方法一：通过 Xcode**
1. 连接 iPhone/iPad
2. 在 Xcode 中选择设备
3. 点击运行按钮

**方法二：通过 TestFlight**
1. 上传到 App Store Connect
2. 添加测试用户
3. 通过 TestFlight 安装

**方法三：通过 Ad Hoc 分发**
1. 导出 Ad Hoc IPA
2. 使用 Apple Configurator 2 或第三方工具安装

## 🔧 常见问题

### Android

**Q: 构建失败，提示 SDK 版本问题**
```bash
# 更新 Android SDK
flutter doctor --android-licenses
```

**Q: 签名错误**
- 检查 `key.properties` 文件路径和内容
- 确保密钥文件存在且路径正确

**Q: 安装失败：INSTALL_FAILED_INSUFFICIENT_STORAGE**
- 清理手机存储空间
- 卸载旧版本应用

**Q: 网络请求失败**
- 检查 `api_service.dart` 中的 `baseUrl`
- 确保手机和电脑在同一 WiFi 网络
- 检查后端服务是否运行

### iOS

**Q: 签名错误**
- 检查 Apple Developer 账号是否有效
- 确保 Bundle Identifier 唯一
- 检查证书和配置文件

**Q: 构建失败：CocoaPods 问题**
```bash
cd ios
pod deintegrate
pod install
cd ..
flutter clean
flutter pub get
```

**Q: 真机调试需要开发者账号**
- 免费账号：只能安装到自己的设备，有效期 7 天
- 付费账号（$99/年）：可以发布到 App Store

## 📦 发布到应用商店

### Google Play Store

1. 创建 Google Play Console 账号
2. 创建新应用
3. 上传 App Bundle（`app-release.aab`）
4. 填写应用信息、截图等
5. 提交审核

### Apple App Store

1. 创建 App Store Connect 账号
2. 创建新应用
3. 通过 Xcode 或 Transporter 上传 IPA
4. 填写应用信息、截图等
5. 提交审核

## 🚀 快速打包命令总结

### Android
```bash
# 完整流程
cd cantonese_app
flutter clean
flutter pub get
flutter build apk --release

# APK 位置
# build/app/outputs/flutter-apk/app-release.apk
```

### iOS
```bash
# 完整流程
cd cantonese_app
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ios --release

# 然后通过 Xcode Archive
```

## 📝 注意事项

1. **API 地址配置**
   - 打包前检查 `api_service.dart` 中的 `baseUrl`
   - 生产环境应使用固定 IP 或域名，不要使用 `localhost`

2. **权限配置**
   - Android：检查 `android/app/src/main/AndroidManifest.xml`
   - iOS：检查 `ios/Runner/Info.plist`

3. **版本号管理**
   - 每次发布前更新版本号
   - Android：`versionCode` 和 `versionName`
   - iOS：`CFBundleShortVersionString` 和 `CFBundleVersion`

4. **代码混淆**（可选）
   - Android：在 `build.gradle.kts` 中启用 `minifyEnabled`
   - 创建 `android/app/proguard-rules.pro` 文件

5. **测试**
   - 在真机上充分测试所有功能
   - 测试不同网络环境下的表现
   - 测试离线情况下的错误处理

## 🎯 推荐配置

### 最小 Android SDK
```kotlin
minSdk = 21  // Android 5.0，覆盖 95%+ 设备
```

### 目标 Android SDK
```kotlin
targetSdk = 34  // Android 14
```

### iOS 最低版本
```
iOS 12.0 或更高
```

---

**祝您打包顺利！如有问题，请查看 Flutter 官方文档：**
- https://flutter.dev/docs/deployment/android
- https://flutter.dev/docs/deployment/ios



