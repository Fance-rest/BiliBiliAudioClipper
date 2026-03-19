# BiliBili Audio Clipper — 设计文档

## 概述

一个 Flutter Android 应用，用于从B站视频中提取音频，裁剪后上传到网易云音乐云盘。

**核心流程**：粘贴B站链接 → 下载音频 → 裁剪 → 改名 → 传网易云盘

## 技术栈

- **框架**：Flutter（纯客户端方案），最低 Flutter 3.x
- **状态管理**：provider
- **HTTP 客户端**：dio + dio_cookie_manager（管理网易云登录 cookie）
- **音频播放**：just_audio
- **音频处理**：ffmpeg_kit_flutter（使用 `audio` 精简构建变体，减小体积）
- **本地存储**：shared_preferences（设置）、flutter_secure_storage（登录凭据）
- **构建发布**：GitHub Actions → APK → GitHub Release
- **最低 Android 版本**：API 24（Android 7.0），ffmpeg_kit_flutter 要求

## 架构

主操作为单页面线性流程。设置页通过右上角齿轮图标进入（简单的 Navigator.push）。

### 页面布局

```
┌─────────────────────────────┐
│  [⚙] 设置（右上角）          │
├─────────────────────────────┤
│  输入区：链接/BV号输入框     │
│  [解析] 按钮               │
├─────────────────────────────┤
│  信息区：封面图+视频标题+时长 │
│  [下载音频] 按钮 + 进度条   │
├─────────────────────────────┤
│  播放区：播放器控制          │
│  进度条 + 播放/暂停          │
├─────────────────────────────┤
│  裁剪区：                   │
│  开始 [分] : [秒]           │
│  结束 [分] : [秒]           │
│  [标记起点] [标记终点] 按钮  │
│  [裁剪] 按钮                │
├─────────────────────────────┤
│  命名区：文件名输入框        │
│  [上传到网易云盘] 按钮       │
└─────────────────────────────┘
```

## 模块设计

### 1. B站链接解析模块

**输入格式支持：**
- 完整链接：`https://www.bilibili.com/video/BVxxx`
- 短链：`https://b23.tv/xxx`（通过 302 重定向解析）
- 纯 BV 号：`BVxxx`（自动补全为完整链接）
- AV 号：`av12345`（兼容老链接格式）

**解析流程：**
1. 识别输入类型（完整链接 / 短链 / 纯BV号）
2. 短链通过 HEAD 请求获取 302 重定向目标
3. 提取 BV 号（支持 BV/AV 互转，使用标准 Base58 算法）
4. 获取 BUVID 指纹：调用 `https://api.bilibili.com/x/frontend/finger/spi` 获取 `buvid3`/`buvid4`，作为 cookie 附加到后续请求
5. 调用 `https://api.bilibili.com/x/web-interface/wbi/view?bvid=BVxxx`（需 wbi 签名）获取视频信息（标题、时长、cid、封面图 `pic`）
6. 调用 `https://api.bilibili.com/x/player/wbi/playurl?bvid=BVxxx&cid=xxx&fnval=4048&fourk=1`（需 wbi 签名）获取 DASH 音频流地址
7. 从 DASH 响应的 `data.dash.audio` 中取最高音质的流 URL

**WBI 签名（必需）：**
- 登录后调用 `https://api.bilibili.com/x/web-interface/nav` 获取 `wbi.img_url` 和 `wbi.sub_url`，提取 `imgKey` 和 `subKey`
- 将 `imgKey + subKey`（64 字符）通过固定的 64 位置换表生成 32 位 `mixinKey`
- 置换表（hardcoded）：`[46,47,18,2,53,8,23,32,15,50,10,31,58,3,45,35,27,43,5,49,33,9,42,19,29,28,14,39,12,38,41,13,37,48,7,16,24,55,40,61,26,17,0,1,60,51,30,4,22,25,54,21,56,59,6,63,57,62,11,36,20,34,44,52]`
- 签名步骤：添加 `wts`（Unix 时间戳）→ 参数按 key 排序 → 移除值中的 `!'()*` 字符 → URL 编码 → MD5(编码结果 + mixinKey) → 添加 `w_rid` 参数

**WBI 密钥缓存策略：**
- 在内存中缓存 `mixinKey`，app 启动时从 nav 接口刷新
- 当 B站 API 返回 403 或签名错误时，自动重新获取 wbi 密钥并重试请求
- B站定期轮换 wbi 密钥，因此不能仅在登录时获取一次

**B站登录（QR 码扫码）：**
- 调用 `https://passport.bilibili.com/x/passport-login/web/qrcode/generate` 生成二维码 URL 和 `qrcode_key`
- app 显示二维码，用户用B站 app 扫码
- 轮询 `https://passport.bilibili.com/x/passport-login/web/qrcode/poll?qrcode_key={key}` 直到登录成功
- 提取并持久化登录 cookie（含 SESSDATA）
- 登录后从 nav 接口获取 wbi 密钥

**请求头要求：**
- API 请求：`Referer: https://www.bilibili.com`，`Origin: https://www.bilibili.com`
- 流下载请求：`Origin: https://m.bilibili.com`
- `User-Agent`: `Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36`
- Cookie：登录 cookie + `buvid3` + `buvid4`

**参考实现：** [downkyicore](https://github.com/yaobiao131/downkyicore) 项目的 B站 API 调用和 wbi 签名逻辑

### 2. 音频下载模块

- 使用 `dio` 下载音频流，格式为 `.m4a`
- 显示下载进度条（百分比 + 已下载/总大小）
- 文件临时存储在 app 缓存目录（`getTemporaryDirectory()`）
- 音频流 URL 有时效性，解析后需尽快下载

### 3. 音频播放模块

- 使用 `just_audio` 加载本地 `.m4a` 文件
- 播放控制：播放/暂停按钮
- 显示：进度条 + 当前时间/总时长
- 支持拖动进度条跳转

### 4. 音频裁剪模块

**方式 A — 手动输入：**
- 开始时间：两个输入框 `[分钟] : [秒]`
- 结束时间：两个输入框 `[分钟] : [秒]`
- 输入框内有 placeholder 文字提示（"分钟"、"秒"）
- 输入后可跳转到对应时间试听

**方式 B — 播放标记：**
- 播放过程中点击"标记起点"按钮，记录当前播放时间为开始时间
- 点击"标记终点"按钮，记录当前播放时间为结束时间
- 标记后自动同步填入手动输入框，两种方式互通

**裁剪执行：**
- 使用 `ffmpeg_kit_flutter` 执行：`-i input.m4a -ss 开始时间 -to 结束时间 -c copy output.m4a`
- `-c copy` 直接拷贝流，不重新编码，速度极快
- 注意：`-c copy` 在非关键帧位置裁剪时可能导致开头有短暂音频瑕疵。如出现此问题，可回退为重新编码模式：`-c:a aac`（更慢但精确）
- 如果用户不需要裁剪，跳过此步，直接使用原始文件

### 5. 重命名模块

- 裁剪完成后显示文本输入框
- 默认填入B站视频标题作为文件名
- 用户可自由修改
- 文件扩展名固定为 `.m4a`，不可修改

### 6. 网易云盘上传模块

**API 服务：**
- 用户在闲置 Mac 上部署 [NeteaseCloudMusicApiEnhanced](https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced)
- 通过 Tailscale 组建私有 VPN 网络，Mac 获得固定的 Tailscale IP（如 `100.x.x.x`）
- 手机也安装 Tailscale，即可在任何网络下访问 Mac 上的 API
- app 内设置页配置 API 服务地址（如 `http://100.x.x.x:3000`）

**Android 明文 HTTP 配置：**
- Android 9+ 默认禁止明文 HTTP 请求
- 由于 `network_security_config.xml` 不支持 CIDR IP 段，采用全局允许明文 HTTP：在 `AndroidManifest.xml` 的 `<application>` 标签添加 `android:usesCleartextTraffic="true"`
- 这对个人工具可以接受；如需更精细控制，可使用 Tailscale 的 MagicDNS 域名替代原始 IP

**登录鉴权：**
- 手机号 + 验证码登录（调用 `/captcha/sent` 发送验证码，`/login/cellphone` 登录）
- 如果 API 支持手机号+密码，也可作为备选
- 使用 `dio_cookie_manager` + `PersistCookieJar` 管理和持久化登录 cookie
- 登录凭据使用 `flutter_secure_storage` 安全存储
- 登录状态过期时提示重新登录

**上传流程：**
1. 使用 `dio` 的 `FormData` + `MultipartFile` 构造 multipart 请求
2. 调用 `POST /cloud` 接口，文件字段名为 `songFile`，Content-Type 为 `audio/mp4`
3. 显示上传进度（通过 dio 的 `onSendProgress` 回调）
4. 上传成功响应：`{ code: 200, ... }`；失败时根据 `code` 字段提示原因
5. 上传成功后弹窗：选择"保留本地文件"或"删除本地文件"（指裁剪后的最终音频文件；原始下载的临时文件始终自动清理）
6. 根据用户选择处理本地文件

### 7. 设置页

设置页分三个卡片区域（与 Figma 设计的 iOS grouped-table 风格一致）：

**区域 1 — B站账号**（Figma 设计中缺失，需新增）：
- 未登录状态：显示"未登录"文字 + "扫码登录"按钮
- 点击"扫码登录"后：显示 QR 码图片（200x200）+ "等待扫码..."状态文字 + "取消"按钮
- 已登录状态：显示用户头像（圆形 50x50）+ 用户名 + "退出登录"按钮（红色文字）

**区域 2 — API 服务**（参考 Figma `Settings.tsx`）：
- 服务器地址输入框，placeholder `http://100.x.x.x:3000`

**区域 3 — 网易云账号**（参考 Figma `Settings.tsx`）：
- 未登录：手机号输入 + 验证码输入 + "获取验证码"按钮 + "登录"按钮
- 已登录：头像 + 昵称 + 手机号（部分隐藏）+ "退出登录"按钮

- 使用 `shared_preferences` 持久化存储配置项
- 登录凭据和 cookie 使用 `flutter_secure_storage` 安全存储

## Android 权限

在 `AndroidManifest.xml` 中声明：
- `INTERNET` — 网络访问（下载、上传、API 调用）

不需要存储权限，因为文件操作都在 app 自身目录内完成。

## GitHub Actions 构建

**触发条件：**
- 推送 tag（如 `v1.0.0`）时自动触发
- 支持手动触发（workflow_dispatch）

**构建流程：**
1. checkout 代码
2. 使用 `subosito/flutter-action` 设置 Flutter 环境
3. `flutter build apk --release` 构建 release APK
4. APK 签名使用自签名 keystore（存储在 GitHub Secrets）
5. 构建产物上传为 GitHub Release 附件

**所需 GitHub Secrets：**
- `KEYSTORE_BASE64`：keystore 文件的 base64 编码
- `KEYSTORE_PASSWORD`：keystore 密码
- `KEY_ALIAS`：key 别名
- `KEY_PASSWORD`：key 密码

## 错误处理

- 链接解析失败：提示"无法解析该链接，请检查链接格式"
- 下载失败：提示错误原因，支持重试
- 裁剪时间非法（起点 ≥ 终点 或超出时长）：提示并阻止裁剪
- API 服务不可达：提示检查网络和 API 服务状态
- 上传失败：提示错误原因，文件保留在本地不删除
- B站登录过期：当 B站 API 返回 401 或 cookie 失效时，提示用户前往设置页重新扫码登录
- 网易云登录过期：上传时 API 返回未登录错误，提示用户前往设置页重新登录

## UI 设计参考

Figma 导出的 React 原型位于 `design/` 目录，可用 `npm install && npm run dev` 本地运行查看。

**采用的部分：**
- 主页面（`design/src/app/components/Home.tsx`）：链接输入、视频信息、播放器、裁剪控制、重命名+上传
- 设置页（`design/src/app/components/Settings.tsx`）：API 地址配置、网易云账号登录/登出
- iOS 风格弹窗（`design/src/app/components/IOSAlert.tsx`）：上传成功后的保留/删除选择

**设计风格：** iOS Human Interface 风格，使用 Flutter 的 Cupertino widgets 优先于 Material Design。圆角卡片（16px radius）、系统蓝 `#007AFF`、灰色背景 `#F2F2F7`。

**不采用的部分（Figma AI 过度生成）：**
- "音频质量"选择卡片（B站 DASH 直接取最高音质，无需用户选择）
- "高级选项"卡片（保留元数据、标准化音量、移除静音 — 超出需求范围）
- 底部独立的"提取音频"按钮（与"下载音频"按钮重复）

## 项目结构

```
lib/
├── main.dart                  # 入口
├── models/
│   └── video_info.dart        # B站视频信息模型（标题、时长、cid、封面图URL）
├── services/
│   ├── bilibili_service.dart  # B站链接解析和音频下载
│   ├── audio_service.dart     # 音频裁剪（FFmpeg）
│   └── netease_service.dart   # 网易云API交互
├── providers/
│   ├── bilibili_provider.dart # B站解析/下载状态
│   ├── audio_provider.dart    # 播放/裁剪状态
│   └── netease_provider.dart  # 网易云登录/上传状态
├── pages/
│   ├── home_page.dart         # 主页面（单页线性流程）
│   └── settings_page.dart     # 设置页
└── widgets/
    ├── link_input.dart        # 链接输入组件
    ├── audio_player_widget.dart # 播放器组件
    ├── clip_controls.dart     # 裁剪控制组件
    └── upload_section.dart    # 重命名+上传组件
```
