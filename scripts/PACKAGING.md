# Magic 打包说明

## 本机已完成

- **macOS arm64**：`dist/Magic-1.18.9-macos-arm64.dmg`
- **Android arm64**：`dist/Magic-1.18.9-android-arm64-v8a.apk`（applicationId=`abc.n123.xyz`，因 Android 包名段不能以数字开头）
- 内核：`libclash/macos/MagicCore`、`libclash/android/arm64-v8a/`

## 一键脚本（本机）

```bash
export PATH="/opt/homebrew/bin:$HOME/.pub-cache/bin:$PATH"
export JAVA_HOME="$HOME/.jdks/temurin-17.jdk/Contents/Home"
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export ANDROID_SDK_ROOT=$ANDROID_HOME
export ANDROID_NDK=$ANDROID_HOME/ndk/28.2.13676358

./scripts/package.sh macos arm64
./scripts/package.sh android arm64
```

## 平台限制

| 平台 | 本机 macOS | 推荐方式 |
|------|------------|----------|
| macOS | ✅ | 本地 `dart setup.dart macos --arch arm64` |
| Android | ✅（需 JDK/SDK/NDK） | 本地或 CI |
| Windows | ❌ 需 Windows | GitHub Actions |
| Linux | ❌ 需 Linux | GitHub Actions |

## 用 GitHub Actions 打 Windows / Linux（及全平台）

本机 macOS **无法**交叉打包 Windows/Linux，需走 CI：

1. 提交并推送当前改动到 `origin`
2. 登录：`gh auth login`
3. 任选其一：
   - 打 tag：`git tag v1.18.9-magic && git push origin v1.18.9-magic`
   - 或 Actions 页面手动 `workflow_dispatch`（已加）

产物在 Actions Artifacts（`Magic-*`）/ Release。

Android 正式签名需在仓库 Secrets 配置：`KEYSTORE`、`KEY_ALIAS`、`STORE_PASSWORD`、`KEY_PASSWORD`。
无签名时本机 release 会回退 debug 签名，仅供自测。

### 包名说明

| 平台 | ID |
|------|-----|
| macOS / Windows / Linux | `abc.123.xyz` |
| Android | `abc.n123.xyz`（AAPT 不允许段以数字开头） |
