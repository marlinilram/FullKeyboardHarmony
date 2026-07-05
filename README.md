# FullKeyboard HarmonyOS 移植版

本项目是将 Android 输入法 **FullKeyboard** 移植到 HarmonyOS（OpenHarmony）的原生 ArkTS 实现，目标 API 版本为 **12**。

## 目录说明

```
FullKeyboardHarmony/
├── AppScope/              # 应用级配置与资源
├── entry/                 # 输入法入口模块
│   ├── src/main/ets/
│   │   ├── ServiceExtAbility/FullKeyboardAbility.ets   # 输入法 ExtensionAbility
│   │   ├── model/FullKeyboardController.ets             # 面板/输入/事件控制
│   │   ├── model/KeyData.ets                            # 键盘布局数据
│   │   └── pages/Index.ets                              # 键盘 UI
│   └── src/main/resources/ # 颜色、字符串、图标等资源
├── docker/                # 容器化构建
│   ├── Dockerfile
│   └── build.sh
├── hvigor/                # Hvigor wrapper
├── build-profile.json5
├── oh-package.json5
└── hvigorw
```

## 应用包名

```
com.marlinilram.devkeyboard
```

包名符合华为应用分发规范（三段式、无保留字符、以英文字母开头）。

## 构建方式

当前使用 **DevEco Studio 6.1.1** 直接在 macOS 上构建、签名并安装。

1. 使用 DevEco Studio 打开 `FullKeyboardHarmony` 目录。
2. 等待工程同步完成。
3. 在 `File > Project Structure > Signing Configs` 中勾选 **Automatically generate signing**，让 DevEco 根据新的包名重新生成签名材料。
4. 连接鸿蒙真机，点击 Run 安装运行。

> 注：项目初期提供的 Docker 容器构建脚本基于 OpenHarmony 5.0.0 Public SDK，与当前 DevEco 6.x / HarmonyOS SDK 配置不兼容，暂时未启用。

构建成功后，产物位于：

```
FullKeyboardHarmony/entry/build/default/outputs/default/entry-default-signed.hap
```

## 已知限制

- 鸿蒙输入法框架没有提供向目标应用注入原始 `KeyEvent`/scanCode 的公开接口，因此远程桌面场景的原始按键无法 1:1 还原。
- 当前实现通过 `InputClient.insertText` / `moveCursor` / `deleteBackward` / `sendExtendAction` 等接口完成文本与编辑操作；**Ctrl+字母（A/C/V/X 除外）会发送对应的 C0 控制字符**（如 Ctrl+B 发送 `0x02`），以便在 Web 终端 / tmux / xterm.js 等场景中使用。
- 悬浮/拖拽面板目前使用近似坐标计算，拖动体验有限。

## 运行要求

- HarmonyOS API 12+（当前配置为 `6.1.1(24)`）
- 需要系统输入法权限
- 需要正确签名
