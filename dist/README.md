# Distribution

本目录用于在本地项目中集中保存可安装构建：

- `YCompress-macOS-arm64.zip`：Apple Silicon、macOS 13+ 安装包。
- `SHA256SUMS`：安装包完整性校验值。

ZIP 安装包被 `.gitignore` 排除，不直接进入 Git 历史。公开下载通过
[GitHub Releases](https://github.com/whuyao/YCompress/releases) 提供。

重新构建：

```bash
./scripts/build-app.sh
```

然后将 `.build/YCompress.app` 打包并更新本目录校验值。
