# YCompress

YCompress 是面向 macOS 的原生、离线文件压缩与解压工具。它使用 SwiftUI 构建界面，
使用 ImageIO 处理图片、AVFoundation 处理视频，并调用 macOS 自带的 `ditto`、`unzip`
和 `tar` 完成通用文件归档和解压。

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
- [需求与仓库分析](REQUIREMENTS.md)

`dist/` 同时包含可直接运行的 `YCompress.app`、ZIP 安装包和 SHA-256 校验值；
这些二进制文件也会作为 GitHub Release 附件发布。

## 当前功能

- 图片压缩：JPEG、PNG、HEIC、TIFF、BMP、GIF、WebP（具体解码能力由系统版本决定）
- 视频压缩：MOV、MP4、M4V 等 AVFoundation 可读取格式
- 文件/文件夹压缩：创建 ZIP，保留 macOS 资源信息
- 解压：ZIP、TAR、TGZ、TAR.GZ，并在解压前拦截绝对路径和 `..` 路径穿越
- 批量队列：混合选择图片、视频、文件和目录
- 工作流：5 个内置工作流和自定义工作流；“使用”会直接进入任务页
- 高级参数：输出后缀、失败策略、图片格式/尺寸、视频分辨率、ZIP 元数据和解压目录
- 输出管理：自选输出目录，处理完成后在 Finder 中定位
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

核心检查：

```bash
swift run YCompressCoreChecks
```

完整发布构建：

```bash
chmod +x scripts/package-release.sh
./scripts/package-release.sh
```

该脚本会在项目根目录生成可直接运行的 `YCompress.app`、ZIP、带版本号的 DMG、
`SHA256SUMS`、`安装说明.md` 和 `使用手册.md`，并同步更新 `dist/`。以后发布版本时以
项目根目录的这些文件为本地交付物。

## 设计来源与许可边界

产品范围参考了开源项目
[CompressO](https://github.com/codeforreal1/compressO)：
其批处理队列、质量预设、离线处理和结果对比思路值得借鉴。
CompressO 使用 Tauri + React + Rust，并捆绑 FFmpeg、pngquant、jpegoptim、gifski 等工具，
源代码采用 AGPL-3.0。

YCompress 是独立的原生 Swift 实现，没有复制或链接 CompressO 的源代码或二进制。
如果未来直接移植 CompressO 代码，发布时必须按 AGPL-3.0 提供相应源代码并保留许可声明。

## 已知限制

- 当前视频压缩支持原分辨率、1080p、720p、540p 系统预设，不提供逐编码器、码率、
  音轨和字幕参数。
- GIF/WebP 动画可能在 ImageIO 重新编码后只保留首帧。
- 处理历史目前只保留在本次 App 运行期间。
- 7z/RAR 未纳入首版，因为 macOS 不自带对应解码器。

## License

YCompress 采用 [MIT License](LICENSE)。
