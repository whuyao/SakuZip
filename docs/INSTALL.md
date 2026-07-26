# SakuZip 安装说明

## 系统要求

- Apple Silicon Mac（M1、M2、M3、M4 或更新芯片）
- macOS 13 Ventura 或更高版本
- 安装包约 1.6 MB，实际运行不需要联网

当前发布包仅包含 `arm64` 架构，不支持 Intel Mac。

## 安装步骤

1. 下载
   [`SakuZip-macOS-arm64.zip`](https://github.com/whuyao/SakuZip/releases/latest/download/SakuZip-macOS-arm64.zip)。
2. 双击 ZIP 解压，得到 `SakuZip.app`。
3. 将 `SakuZip.app` 拖到 Finder 的“应用程序”文件夹。
4. 第一次启动时，按住 Control 点击或右键点击 `SakuZip.app`，选择“打开”。
5. 在 macOS 的确认窗口中再次选择“打开”。

之后可以像普通 App 一样从 Launchpad、Spotlight 或“应用程序”文件夹启动。

也可以从同一个 Release 下载 `SakuZip-0.2.1-macOS-arm64.dmg`：打开 DMG 后，
将 `SakuZip.app` 拖到其中的“Applications”快捷方式即可。

## 从 YCompress 升级

SakuZip 首次启动时会自动导入旧版 YCompress 保存的界面语言和工作流设置。
确认 SakuZip 工作正常后，可以删除“应用程序”文件夹中的 `YCompress.app`；
旧 App 的删除不会影响已经生成的压缩或解压文件。

## 为什么首次启动需要右键打开

当前版本使用本机 ad-hoc 签名，没有 Apple Developer ID 公证。macOS Gatekeeper
可能会阻止直接双击启动。这不代表 App 已损坏；所有源码都可以在公开仓库中审查，
App 也不会上传文件或发起网络请求。

不要关闭整个系统的 Gatekeeper。优先使用上面的“右键 → 打开”方式。

如果 macOS 仍提示 App 已损坏，并且安装包来自本仓库的 GitHub Release，可以执行：

```bash
xattr -cr /Applications/SakuZip.app
```

该命令只移除 SakuZip 的下载隔离属性，不会修改全局安全设置。

## 校验安装包

在终端进入安装包所在目录后运行：

```bash
shasum -a 256 SakuZip-macOS-arm64.zip
# 或同时校验同一批次的 ZIP 与 DMG
shasum -a 256 -c SHA256SUMS
```

版本 `0.2.1` 的预期值记录在同一 Release 附带的 `SHA256SUMS` 中；项目的 `dist/`
也保存一份。DMG 与 ZIP 每次重新打包后的字节可能不同，应以同一批次生成的
`SHA256SUMS` 为准。

如果结果不同，请重新从 GitHub Release 下载，不要继续安装来源不明的文件。

## 卸载

1. 退出 SakuZip。
2. 将 `/Applications/SakuZip.app` 移到废纸篓。
3. 如需同时清除自定义工作流设置，可在终端执行：

```bash
defaults delete net.urbancomp.sakuzip
```

删除偏好设置不会删除已经压缩或解压的文件。

## 从源码构建

需要安装 Xcode。克隆仓库后运行：

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

生成的 App 位于 `.build/SakuZip.app`。

## 开发团队

SakuZip 由 [UrbanComp](https://urbancomp.net) 团队开发与维护。App 侧栏、设置页及
“帮助”菜单均提供团队网站入口。
