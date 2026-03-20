# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

BiliAudio Clipper — 从 Bilibili 视频提取、裁剪音频并上传到网易云音乐的 Flutter 跨平台应用（Android / iOS / Web）。

## 常用命令

```bash
flutter pub get          # 安装依赖
flutter test             # 运行全部测试
flutter test test/models/video_info_test.dart  # 运行单个测试文件
flutter analyze          # 静态分析
flutter build apk --release  # 构建 Release APK
flutter run              # 调试运行
```

## 架构

### 分层结构（Services → Providers → Widgets）

- **Services**（`lib/services/`）：API 调用与业务逻辑，通过 Dio 进行 HTTP 请求
  - `bilibili_service.dart` — Bilibili WBI 签名认证、视频解析、扫码登录
  - `audio_service.dart` — 通过 MethodChannel 桥接 Android 原生音频裁剪
  - `netease_service.dart` — 网易云音乐登录与上传
- **Providers**（`lib/providers/`）：基于 Provider（ChangeNotifier）的状态管理
  - `bilibili_provider.dart`、`audio_provider.dart`、`netease_provider.dart`
- **Widgets**（`lib/widgets/`）：UI 组件
- **Pages**（`lib/pages/`）：页面级组件（`home_page.dart`、`settings_page.dart`）

### 关键技术细节

- **UI 风格**：Cupertino（iOS 风格），不是 Material
- **音频裁剪**：Android 原生 MediaExtractor/MediaMuxer 实现，通过 MethodChannel `"com.biliaudioclipper/audio_trimmer"` 桥接
- **Bilibili 认证**：WBI 签名算法（MD5 + 64 位置换表），403 时自动刷新密钥重试
- **敏感存储**：Cookie 存 FlutterSecureStorage，设置存 SharedPreferences

### Android 原生代码

- 入口：`android/app/src/main/kotlin/.../MainActivity.kt`
- 音频裁剪方法：`trimAudio(inputPath, outputPath, startUs, endUs)`，微秒精度
- 构建需要 Java 17，签名配置读取 `android/app/key.properties`

## CI/CD

GitHub Actions（`.github/workflows/build.yml`）：推送 `v*` 标签触发，Flutter 3.41.5 + Java 17，自动构建 APK 并创建 Release。

## 约定

- Git 提交信息使用中文
