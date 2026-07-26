# SakuZip インストールガイド

## システム要件

- Apple Silicon Mac（M1、M2、M3、M4、またはそれ以降）
- macOS 13 Ventura以降
- インストール後の実行にインターネット接続は不要

現在のリリースはarm64専用で、Intel Macには対応していません。

## ZIPからインストール

1. [`SakuZip-macOS-arm64.zip`](https://github.com/whuyao/SakuZip/releases/latest/download/SakuZip-macOS-arm64.zip)
   をダウンロードします。
2. ZIPをダブルクリックして`SakuZip.app`を展開します。
3. `SakuZip.app`を「アプリケーション」フォルダへドラッグします。
4. 初回起動時は、Controlキーを押しながらクリックするか右クリックし、**開く**を選びます。
5. macOSの確認画面でもう一度**開く**を選びます。

以後はLaunchpad、Spotlight、または「アプリケーション」フォルダから起動できます。

## DMGからインストール

同じReleaseから`SakuZip-0.2.1-macOS-arm64.dmg`をダウンロードして開き、
`SakuZip.app`をApplicationsショートカットへドラッグします。

## YCompressからのアップグレード

SakuZipは初回起動時に、YCompressで保存した表示言語とワークフロー設定を自動的に
取り込みます。SakuZipが正常に動作することを確認した後は、「アプリケーション」
フォルダの`YCompress.app`を削除できます。旧Appを削除しても、圧縮・展開済みの
ファイルには影響しません。

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
xattr -cr /Applications/SakuZip.app
```

このコマンドはSakuZipのダウンロード隔離属性だけを削除し、Gatekeeperの
システム設定は変更しません。

## インストーラの検証

ターミナルでダウンロード先へ移動し、次を実行します。

```bash
shasum -a 256 SakuZip-macOS-arm64.zip
# ZIPとDMGをまとめて検証：
shasum -a 256 -c SHA256SUMS
```

バージョン`0.2.1`の期待値は、同じReleaseに添付された`SHA256SUMS`と、
リポジトリの`dist/`に含まれています。必ず同じリリースパッケージと同時に生成された
チェックサムファイルを使用してください。

検証に失敗した場合はGitHub Releaseから再ダウンロードし、不明な配布元のファイルは
インストールしないでください。

## アンインストール

1. SakuZipを終了します。
2. `/Applications/SakuZip.app`をゴミ箱へ移動します。
3. カスタムワークフロー設定も削除する場合は、次を実行します。

```bash
defaults delete net.urbancomp.sakuzip
```

設定を削除しても、圧縮・解凍済みの出力ファイルは削除されません。

## ソースからビルド

Xcodeをインストールし、リポジトリをクローンして次を実行します。

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

生成されたAppは`.build/SakuZip.app`に配置されます。

## 開発チーム

SakuZipは[UrbanComp](https://urbancomp.net)チームが開発・保守しています。
チームサイトはAppのサイドバー、設定、ヘルプメニューから開けます。
