# YCompress 需求与仓库分析

## CompressO 观察

- 技术栈：Tauri 2、Rust、React 18、Vite 6。
- 处理层：FFmpeg 负责视频，pngquant/jpegoptim/gifski 等负责图片，平台二进制随 App 分发。
- 产品能力：单文件与批处理、视频裁剪/分段、音视频参数、字幕、元数据、结果预览与体积统计。
- 状态模型：前端保存批次和媒体状态；Rust 命令并行处理任务，并通过 Tauri events 回传进度。
- 平台：Linux、Windows、macOS；仓库体积较大，二进制资源是主要成本。
- 许可：AGPL-3.0，直接派生和分发需要遵守强 copyleft 条款。

## 首版范围

### 必须完成

1. macOS 原生 App，可拖拽和批量选择。
2. 图片、视频、文件/文件夹压缩。
3. ZIP、TAR、TGZ、TAR.GZ 解压。
4. 混合队列、状态、结果大小和 Finder 定位。
5. 内置与自定义工作流。
6. 无上传、无账户、离线运行。

### 质量要求

- 不覆盖现有输出，自动递增文件名。
- 解压前防御 Zip Slip/路径穿越。
- 单任务失败不阻塞后续队列。
- 不捆绑第三方可执行文件，首版尽量使用 macOS 框架与系统工具。

## 后续建议

1. 引入可选 FFmpeg helper，增加 CRF、编码器、字幕、音轨和进度。
2. 用 Accelerate/Core Image 增强图片缩放，并处理动画 GIF/WebP。
3. 增加合并归档（把多个选中项打入一个 ZIP）和 7z。
4. 持久化历史、工作流步骤编排、Finder Quick Action。
5. 增加 Developer ID 签名、notarization 和 Sparkle 自动更新。
