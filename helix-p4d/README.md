# Helix Core (P4D)

Docker で Perforce Helix Core Server (P4D) を起動するための構成です。開発・検証用途を想定しています。本番環境で利用する場合は、認証、ネットワーク制御、証明書の配布とローテーション、バックアップと復旧、監視を個別に設計してください。

## 構成

- SSL でポート `1666` を公開します。
- サーバーデータは Docker の名前付きボリューム `helix-p4d_servers` に永続化されます。
- コンテナーは `172.16.238.0/24` の専用ネットワーク上で `172.16.238.10` を使用します。
- 変更の送信時に大文字・小文字の整合性を確認するトリガーを登録します。

## 前提条件

- Docker
- Docker Compose v2 の `docker compose` コマンド

## 起動

この `helix-p4d` ディレクトリで実行します。

```bash
docker compose up -d
docker compose logs -f
```

初期状態の接続先と管理ユーザー:

- P4PORT: `ssl:localhost:1666`
- ユーザー: `super`
- 初期パスワード: `Passw0rd`

初回接続ではサーバー証明書を信頼します。

```bash
p4 -p ssl:localhost:1666 trust
p4 -p ssl:localhost:1666 -u super login
```

P4V ではサーバーに `ssl:localhost:1666` を指定してください。

## 日常操作

- `docker compose up -d`: コンテナーをバックグラウンドで起動します。
- `docker compose stop`: コンテナーを停止します。
- `docker compose logs -f`: コンテナーログを追跡します。
- `docker exec -it helix-p4d bash`: 実行中のコンテナーで Bash を開きます。
- `docker compose down`: コンテナーと Compose ネットワークを削除します。データボリュームは残ります。
- `docker compose build`: Compose 定義のランタイムイメージをビルドします。
- `docker compose build --no-cache`: キャッシュを使わずにランタイムイメージをビルドします。

サーバー状態は、コンテナー内で確認できます。

```bash
docker exec -it helix-p4d bash
p4dctl status
```

## パスワードの変更

`super` ユーザーのパスワードは、実行中のコンテナーで次の対話コマンドを実行して変更します。

```bash
docker exec -it helix-p4d \
  sudo -H -E -u perforce env P4PORT=ssl:1666 P4USER=super p4 passwd
```

変更後は、利用しているクライアント、環境変数、シークレットに設定した `P4PASSWD` を新しい値へ更新してから再起動してください。

## データの永続化

`docker compose down` やコンテナーの再作成では、`helix-p4d_servers` ボリューム内のデータは削除されません。サーバーを完全に初期化する必要がある場合だけ、停止後にボリュームを削除してください。この操作は元に戻せません。

```bash
docker compose down
docker volume rm helix-p4d_servers
```

既存ボリュームのサーバーパスワードがイメージの設定値と異なる場合でも、サーバー自体は起動します。その場合は、現在のパスワードでログインしてください。

## イメージのビルド

このディレクトリの `p4d/Dockerfile` は公開済みのベースイメージに証明書ダウンロード用コマンドを追加するランタイムイメージです。P4D ベースイメージの再ビルド、設定値、テスト方法は [ビルド用 README](https://github.com/radicalgrimoire/docker-helix-p4/blob/main/build/helix-p4d/README.md) を参照してください。

## 証明書アーカイブの取得

`p4d/download-certs.sh` は GitHub Releases から証明書アーカイブをダウンロードして展開します。

```bash
bash p4d/download-certs.sh --help
```

主なオプション:

- `-r`, `--repo`: `owner/repository` 形式のリポジトリ
- `-t`, `--token`: GitHub トークン
- `-d`, `--dir`: ダウンロード先ディレクトリ
- `-y`, `--yes`: 確認プロンプトを省略

## トラブルシューティング

- 起動しない場合は、ポート `1666` が使用中でないことと `docker compose logs` の出力を確認してください。
- 接続できない場合は、接続先が `ssl:localhost:1666` であることを確認し、`p4 trust` を実行してください。
- コンテナーの状態は `docker ps -a` で確認できます。

## 参照

- [Perforce Helix Core Documentation](https://www.perforce.com/manuals/p4sag/)
- [コンテナーイメージ](https://github.com/radicalgrimoire/docker-helix-p4/pkgs/container/docker-helix-p4%2Fhelix-p4d)
- [Helix Authentication Extension](https://github.com/perforce/helix-authentication-extension)
