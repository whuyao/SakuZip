# YCompress

[简体中文](README.md) | [English](README.en.md) | [日本語](README.ja.md)

YCompress 是面向 macOS 的原生、离线文件压缩与解压工具。它使用 SwiftUI 构建界面，
使用 ImageIO 处理图片、AVFoundation 处理视频；普通归档调用 macOS 自带的
`ditto`、`unzip` 和 `tar`，密码 ZIP 则由内嵌的 minizip-ng 在进程内完成。

由 [UrbanComp](https://urbancomp.net) 团队开发与维护。

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://www.apple.com/macos/)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

App 图标由 OpenAI ImageGen 生成，项目保留 1254 px PNG 母版，并在构建时生成 macOS
所需的多尺寸 ICNS。

## 下载与文档

- [下载最新版 Apple Silicon 安装包](https://github.com/whuyao/YCompress/releases/latest/download/YCompress-macOS-arm64.zip)
- [安装说明](docs/INSTALL.md)
- [使用手册](docs/USER_GUIDE.md)
- English: [Installation](docs/INSTALL.en.md) · [User Guide](docs/USER_GUIDE.en.md)
- 日本語：[インストール](docs/INSTALL.ja.md) · [ユーザーガイド](docs/USER_GUIDE.ja.md)
- [需求与仓库分析](REQUIREMENTS.md)

`dist/` 同时包含可直接运行的 `YCompress.app`、ZIP 安装包和 SHA-256 校验值；
这些二进制文件也会作为 GitHub Release 附件发布。

## 当前功能

- 图片压缩：JPEG、PNG、HEIC、TIFF、BMP、GIF、WebP（具体解码能力由系统版本决定）
- 视频压缩：MOV、MP4、M4V 等 AVFoundation 可读取格式；压缩前分析源文件并选择不会膨胀的兼容预设
- 文件/文件夹压缩：创建普通 ZIP、AES-256 加密 ZIP或传统兼容密码 ZIP
- 密码安全：密码仅在运行时询问，不写入工作流、命令行参数或日志
- 解压：自动识别普通/加密 ZIP，并支持 TAR、TGZ、TAR.GZ；解压前拦截绝对路径、
  `..` 路径穿越和不安全符号链接
- 批量队列：混合选择图片、视频、文件和目录
- 任务控制：逐文件百分比与阶段提示；加密 ZIP 可在当前条目中暂停/继续，其他任务在
  安全检查点暂停；支持取消并清理未完成输出
- 外部传入：支持 Finder“打开方式”、拖到 App 图标和 `open -a YCompress <文件>`
- 工作流：5 个内置工作流和自定义工作流；“使用”会直接进入任务页
- 高级参数：输出后缀、失败策略、图片格式/尺寸、视频分辨率、ZIP 元数据和解压目录
- 输出管理：默认使用首个来源文件所在目录，也可手动更改并在完成后从 Finder 定位
- 结果定位：查看按钮始终按任务 ID 读取最新输出路径，文件选中、文件夹直接打开
- 结果对比：显示真实节省/增大百分比；视频输出不小于原文件时自动删除无效结果
- 云文件状态：源文件下载后自动刷新真实大小，避免沿用加入队列时的 0 KB 占位值
- 多语言：App、安装说明和使用手册支持简体中文、English、日本語；首次跟随 macOS，
  之后可在设置中记住所选语言
- 隐私：完全本地处理，不发起网络请求

## 构建

需要 macOS 13 或更高版本和 Xcode。

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

生成结果位于 `.build/YCompress.app`。构建脚本会执行 ad-hoc 签名，适合本机运行；
对外分发仍需使用 Apple Developer 证书签名并完成 notarization。

开发运行：

```bash
swift run YCompress
```

核心与加密归档检查：

```bash
swift run YCompressCoreChecks
swift run YCompressArchiveChecks
```

完整发布构建：

```bash
chmod +x scripts/package-release.sh
./scripts/package-release.sh
```

该脚本会把可直接运行的 `YCompress.app`、ZIP、带版本号的 DMG 和 `SHA256SUMS`
统一生成到 `dist/`。安装说明和使用手册保存在 `docs/`，同时会打包进 DMG。

## 设计来源与许可边界

产品范围参考了开源项目
[CompressO](https://github.com/codeforreal1/compressO)：
其批处理队列、质量预设、离线处理和结果对比思路值得借鉴。
CompressO 使用 Tauri + React + Rust，并捆绑 FFmpeg、pngquant、jpegoptim、gifski 等工具，
源代码采用 AGPL-3.0。

YCompress 是独立的原生 Swift 实现，没有复制或链接 CompressO 的源代码或二进制。
如果未来直接移植 CompressO 代码，发布时必须按 AGPL-3.0 提供相应源代码并保留许可声明。

密码 ZIP 使用 [minizip-ng](https://github.com/zlib-ng/minizip-ng) 4.2.2，
遵循 zlib 许可证。详情见 [第三方许可声明](THIRD_PARTY_NOTICES.md)。

## 已知限制

- 当前视频压缩使用 AVFoundation 的离散兼容预设，并根据源文件大小、质量档位和预计
  输出大小自动选择；不提供逐编码器、精确码率、音轨和字幕参数。
- GIF/WebP 动画可能在 ImageIO 重新编码后只保留首帧。
- 处理历史目前只保留在本次 App 运行期间。
- 标准 ZIP 加密保护文件内容，但文件名和目录结构仍可能可见；TAR/TGZ 不提供密码功能。
- 7z/RAR 未纳入首版，因为 macOS 不自带对应解码器。

## License

YCompress 采用 [MIT License](LICENSE)。
