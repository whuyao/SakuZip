# Distribution

本目录用于在本地项目中集中保存可安装构建：

- `YCompress.app`：可直接拖入“应用程序”的 App Bundle。
- `YCompress-macOS-arm64.zip`：Apple Silicon、macOS 13+ 安装包。
- `SHA256SUMS`：安装包完整性校验值。

App Bundle 与 ZIP 安装包均提交到仓库。公开版本也通过
[GitHub Releases](https://github.com/whuyao/YCompress/releases) 发布。

重新构建：

```bash
./scripts/build-app.sh
```

然后将 `.build/YCompress.app` 打包并更新本目录校验值。
