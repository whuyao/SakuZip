# Distribution

本目录用于在本地项目中集中保存可安装构建：

- `YCompress.app`：可直接拖入“应用程序”的 App Bundle。
- `YCompress-macOS-arm64.zip`：Apple Silicon、macOS 13+ 安装包。
- `YCompress-<版本>-macOS-arm64.dmg`：包含 App、应用程序快捷方式和中文文档的磁盘映像。
- `SHA256SUMS`：安装包完整性校验值。

App Bundle、ZIP 与 DMG 安装包均提交到仓库。公开版本也通过
[GitHub Releases](https://github.com/whuyao/YCompress/releases) 发布。

重新构建：

```bash
./scripts/package-release.sh
```

脚本会同时更新本目录，并把同一批发布文件放在项目根目录，方便本机直接查找。
