# Helix Proxy (P4P)

Docker で Perforce Helix Proxy (P4P) を起動するための構成です。Proxy はクライアントと Helix Core Server (P4D) の間でファイルをキャッシュし、P4D への接続を中継します。

公開イメージは `ghcr.io/radicalgrimoire/docker-helix-p4/helix-proxy:latest` です。

## 前提条件

- Docker
- Docker Compose v2 の `docker compose` コマンド
- 接続可能な P4D サーバーと、その管理ユーザーの認証情報

## P4D の接続先を設定する

`P4PORT` には Proxy コンテナーから到達できる P4D の SSL エンドポイントを指定します。Compose 定義の既定値 `ssl:p4d:1666` は、名前 `p4d` を解決できるネットワークでのみ使用できます。

`helix-p4d` と `helix-proxy` は別の Compose プロジェクトで起動するため、リポジトリの既定構成だけではこの名前を共有しません。P4D をホストのポート `1666` に公開している場合の例:

```bash
P4PORT=ssl:host.docker.internal:1666 \
  docker compose up -d
```

リモート P4D または共有 Docker ネットワークを使用する場合は、その環境で Proxy コンテナーから到達できるホスト名または IP アドレスを指定してください。接続先 P4D の認証情報は `P4USER` と `P4PASSWD` で上書きできます。

```bash
P4PORT=ssl:p4d.example.internal:1666 \
P4USER=super \
P4PASSWD=<password> \
docker compose up -d
```

PowerShell では、実行前に環境変数を設定してください。

```powershell
$env:P4PORT = 'ssl:host.docker.internal:1666'
$env:P4USER = 'super'
$env:P4PASSWD = '<password>'
docker compose up -d
```

## 起動と操作

この `helix-proxy` ディレクトリで実行します。

```bash
docker compose up -d
docker compose logs -f
```

Proxy の接続先は `ssl:localhost:1777` です。初回接続時は `p4 trust` を実行してください。

- `docker compose up -d`: コンテナーをバックグラウンドで起動します。
- `docker compose stop`: コンテナーを停止します。
- `docker compose logs -f`: コンテナーログを追跡します。
- `docker exec -it helix-proxy bash`: 実行中のコンテナーで Bash を開きます。
- `docker compose down`: コンテナーと Compose ネットワークを削除します。
- `docker compose build`: Compose 定義のイメージをビルドします。
- `docker compose build --no-cache`: キャッシュを使わずにイメージをビルドします。

## キャッシュの削除

`P4P_CACHE_PURGE_DAYS` は、アクセスされていないキャッシュファイルを削除するまでの日数です。既定値は `30` です。`0` を指定すると削除を無効化できます。削除処理は Asia/Tokyo タイムゾーンの毎日 03:00 に実行されます。

```bash
P4P_CACHE_PURGE_DAYS=7 \
  docker compose up -d
```

この Compose 構成では Proxy キャッシュ用の Docker ボリュームを定義していません。そのため、コンテナーを削除するとキャッシュも失われます。

## イメージのビルド

P4P ベースイメージのビルドとテスト方法は [ビルド用 README](https://github.com/radicalgrimoire/docker-helix-p4/blob/main/build/helix-proxy/README.md) を参照してください。

## トラブルシューティング

- 起動しない場合は `docker compose logs` で、P4D への接続、証明書、認証に関するエラーを確認してください。
- Proxy に接続できない場合は、ポート `1777` が使用中でないことを確認し、`p4 -p ssl:localhost:1777 trust` を実行してください。
- P4D に到達できない場合は、`P4PORT` が Proxy コンテナーから解決・接続できるエンドポイントであることを確認してください。
