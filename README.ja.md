# YCompress

[简体中文](README.md) | [English](README.en.md) | [日本語](README.ja.md)

YCompressは、macOS向けのネイティブかつオフラインで動作する圧縮・解凍アプリです。
UIにはSwiftUI、画像処理にはImageIO、動画処理にはAVFoundationを使用し、
通常のアーカイブにはmacOS標準の`ditto`、`unzip`、`tar`を利用し、暗号化ZIPは
同梱したminizip-ngを使ってApp内で処理します。

[UrbanComp](https://urbancomp.net)チームが開発・保守しています。

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://www.apple.com/macos/)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## ダウンロードとドキュメント

- [最新のApple Silicon版をダウンロード](https://github.com/whuyao/YCompress/releases/latest/download/YCompress-macOS-arm64.zip)
- [インストールガイド](docs/INSTALL.ja.md)
- [ユーザーガイド](docs/USER_GUIDE.ja.md)
- [中国語の要件・リポジトリ分析](REQUIREMENTS.md)

`dist/`には、実行可能な`YCompress.app`、ZIPインストーラ、バージョン付きDMG、
SHA-256チェックサムが含まれます。インストーラはGitHub Releaseにも添付されます。

## 主な機能

- 画像圧縮：JPEG、PNG、HEIC、TIFF、BMP、GIF、WebP。実際の対応範囲はmacOSの
  デコード機能に依存します。
- 動画圧縮：MOV、MP4、M4Vなど、AVFoundationで読み込める形式。元ファイルを分析し、
  サイズ削減が見込める互換プリセットを選択します。
- ファイル・フォルダ圧縮：通常ZIP、AES-256暗号化ZIP、従来の互換パスワードZIPを
  作成できます。
- パスワード保護：パスワードは実行時だけ要求され、ワークフロー、コマンドライン引数、
  ログへ保存されません。
- 安全な解凍：通常/暗号化ZIPを自動判別し、TAR、TGZ、TAR.GZにも対応します。
  危険なパスとシンボリックリンクを解凍前に拒否します。
- バッチキュー：画像、動画、ファイル、フォルダ、アーカイブを混在して追加できます。
- キュー操作：ファイルごとの進捗率と処理段階を表示します。暗号化ZIPは現在の
  エントリ途中で一時停止でき、その他の処理は安全なチェックポイントで停止します。
  キャンセル時は未完成の出力を削除します。
- 外部入力：Finderの「このアプリケーションで開く」、Appアイコンへのドロップ、
  `open -a YCompress <ファイル>`に対応します。
- ワークフロー：5つの内蔵ワークフローとカスタムワークフロー。画像、動画、ZIP、
  解凍、ファイル名、失敗時動作の詳細設定を提供します。
- 出力管理：既定では元ファイルと同じフォルダを使用し、任意の出力先も選択できます。
- 結果比較：実際の削減率・増加率を表示します。元動画より小さくならない動画出力は
  自動的に削除されます。
- クラウドファイル：ダウンロード完了後に元ファイルサイズを再取得し、古い0バイト
  表示を残しません。
- 多言語：App、インストールガイド、ユーザーガイドは簡体字中国語、英語、日本語に
  対応します。初回はmacOSの言語に従い、設定で選んだ言語は次回以降も保持されます。
- プライバシー：すべてローカルで処理され、アップロードやネットワーク通信を行いません。

## ビルド

macOS 13以降とXcodeが必要です。

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

生成されたAppは`.build/YCompress.app`に配置されます。スクリプトはローカル実行向けの
ad-hoc署名を行います。一般配布にはApple Developer ID署名とnotarizationが必要です。

開発実行：

```bash
swift run YCompress
```

コアチェック：

```bash
swift run YCompressCoreChecks
swift run YCompressArchiveChecks
```

リリースパッケージ：

```bash
chmod +x scripts/package-release.sh
./scripts/package-release.sh
```

App、ZIP、バージョン付きDMG、`SHA256SUMS`は`dist/`に生成されます。DMGには中国語、
英語、日本語のドキュメントが含まれます。

## 設計上の参考とライセンス境界

製品範囲は[CompressO](https://github.com/codeforreal1/compressO)のバッチキュー、
品質プリセット、オフライン処理、結果比較の考え方を参考にしています。CompressOは
Tauri、React、Rustで構築され、FFmpeg、pngquant、jpegoptim、gifskiなどを同梱し、
AGPL-3.0で公開されています。

YCompressは独立したネイティブSwift実装で、CompressOのソースコードやバイナリを
コピー・リンクしていません。将来CompressOのコードを直接移植する場合は、
AGPL-3.0への準拠が必要です。

パスワードZIPにはzlibライセンスの
[minizip-ng](https://github.com/zlib-ng/minizip-ng) 4.2.2を使用しています。
詳細は[第三者ライセンス表記](THIRD_PARTY_NOTICES.md)を参照してください。

## 既知の制限

- 動画圧縮はAVFoundationの離散的な互換プリセットを使用します。正確なビットレート、
  CRF、音声トラック、字幕、エンコーダの指定には対応していません。
- アニメーションGIF/WebPはImageIOによる再エンコードで先頭フレームのみになる場合があります。
- 処理履歴は現在のAppセッション中のみ保持されます。
- 標準ZIP暗号化はファイル内容を保護しますが、ファイル名とフォルダ構造は表示される
  場合があります。TAR/TGZにはパスワード機能がありません。
- macOSにデコーダが含まれないため、7zとRARには対応していません。

## ライセンス

YCompressは[MIT License](LICENSE)で公開されています。
