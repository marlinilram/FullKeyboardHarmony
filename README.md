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

## 构建方式

全部构建在 Docker 容器中进行，不依赖宿主机的 DevEco Studio。

```bash
cd FullKeyboardHarmony/docker
./build.sh
```

或在仓库根目录执行：

```bash
cd FullKeyboardHarmony
./docker/build.sh
```

构建成功后，产物位于：

```
FullKeyboardHarmony/entry/build/default/outputs/default/entry-default-unsigned.hap
```

## 已知限制

- 鸿蒙输入法框架没有提供向目标应用注入原始 `KeyEvent`/scanCode 的公开接口，因此远程桌面场景的原始按键无法 1:1 还原。当前实现通过 `InputClient.insertText` / `moveCursor` / `deleteBackward` 等接口完成文本与编辑操作。
- 输出的是 **未签名 HAP**，需要在 DevEco Studio 或命令行中配置签名后才能在真机/模拟器上安装运行。
- 悬浮/拖拽面板目前使用近似坐标计算，拖动体验有限。

## 运行要求

- OpenHarmony / HarmonyOS API 12+
- 需要系统输入法权限
- 需要正确签名
