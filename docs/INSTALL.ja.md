# YCompress インストールガイド

## システム要件

- Apple Silicon Mac（M1、M2、M3、M4、またはそれ以降）
- macOS 13 Ventura以降
- インストール後の実行にインターネット接続は不要

現在のリリースはarm64専用で、Intel Macには対応していません。

## ZIPからインストール

1. [`YCompress-macOS-arm64.zip`](https://github.com/whuyao/YCompress/releases/latest/download/YCompress-macOS-arm64.zip)
   をダウンロードします。
2. ZIPをダブルクリックして`YCompress.app`を展開します。
3. `YCompress.app`を「アプリケーション」フォルダへドラッグします。
4. 初回起動時は、Controlキーを押しながらクリックするか右クリックし、**開く**を選びます。
5. macOSの確認画面でもう一度**開く**を選びます。

以後はLaunchpad、Spotlight、または「アプリケーション」フォルダから起動できます。

## DMGからインストール

同じReleaseから`YCompress-0.1.7-macOS-arm64.dmg`をダウンロードして開き、
`YCompress.app`をApplicationsショートカットへドラッグします。

## 初回起動で「開く」が必要な理由

現在のビルドはad-hoc署名を使用し、Apple Developer IDによるnotarizationは
行われていません。そのため、Gatekeeperが初回の通常のダブルクリック起動を
ブロックする場合があります。ソースコードは公開されており、Appはファイルの
アップロードやネットワーク通信を行いません。

Gatekeeperをシステム全体で無効にしないでください。上記の右クリックまたは
Controlクリックから**開く**方法を使用してください。

このリポジトリのGitHub Releaseから入手したにもかかわらず、macOSがAppの破損を
表示する場合は、次を実行します。

```bash
xattr -cr /Applications/YCompress.app
```

このコマンドはYCompressのダウンロード隔離属性だけを削除し、Gatekeeperの
システム設定は変更しません。

## インストーラの検証

ターミナルでダウンロード先へ移動し、次を実行します。

```bash
shasum -a 256 YCompress-macOS-arm64.zip
# ZIPとDMGをまとめて検証：
shasum -a 256 -c SHA256SUMS
```

バージョン`0.1.7`の期待値は、同じReleaseに添付された`SHA256SUMS`と、
リポジトリの`dist/`に含まれています。必ず同じリリースパッケージと同時に生成された
チェックサムファイルを使用してください。

検証に失敗した場合はGitHub Releaseから再ダウンロードし、不明な配布元のファイルは
インストールしないでください。

## アンインストール

1. YCompressを終了します。
2. `/Applications/YCompress.app`をゴミ箱へ移動します。
3. カスタムワークフロー設定も削除する場合は、次を実行します。

```bash
defaults delete com.yaoyao.ycompress
```

設定を削除しても、圧縮・解凍済みの出力ファイルは削除されません。

## ソースからビルド

Xcodeをインストールし、リポジトリをクローンして次を実行します。

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

生成されたAppは`.build/YCompress.app`に配置されます。

## 開発チーム

YCompressは[UrbanComp](https://urbancomp.net)チームが開発・保守しています。
チームサイトはAppのサイドバー、設定、ヘルプメニューから開けます。
