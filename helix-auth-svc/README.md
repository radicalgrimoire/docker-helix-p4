# Helix Authentication Service

Helix Authentication Service（HAS）をDocker Composeで起動するための試験用構成です。
SAML・OpenID Connectによる外部認証に対応しています。**ログインにはIDプロバイダー（IdP）の設定が必要です。**

- [起動](#起動)
- [SAMLの接続設定](#samlの接続設定)
- [設定の追加・変更](#設定の追加変更)
- [設定リファレンス](#設定リファレンス)
- [構造化設定](#構造化設定)
- [ビルド設定・参考資料](#ビルド設定参考資料)

## 起動

このディレクトリで実行します。

```bash
docker compose up -d
```

アクセス先は `http://localhost:3000`。この段階では起動確認のみ可能で、IdPへのログインはできません。
使用するイメージは [Composeファイル](docker-compose.yml)、ビルド方法は[ビルド用README](../build/helix-auth-svc/README.md)を参照してください。

## SAMLの接続設定

HTTPSリバースプロキシ経由で公開する場合の例です。URL・IPアドレスは実際の値に置き換えてください。

```bash
export SVC_BASE_URI='https://has.example.com'
export SAML_SP_ENTITY_ID='https://has.example.com'
export SAML_IDP_METADATA_URL='https://idp.example.com/metadata.xml'
export TRUST_PROXY='192.0.2.10'

docker compose up -d
```

- IdP側にも、HASのエンティティIDとコールバックURLを登録します。
- HTTPSリバースプロキシは別途用意します。このCompose構成が待ち受けるのはHTTPの3000番ポートです。
- `TRUST_PROXY` は実際のプロキシだけに限定し、コンテナへの直接アクセスも制限してください。

## 設定の追加・変更

### 現在のComposeで渡せる変数

| 変数 | 未指定時 | 渡し方 |
| --- | --- | --- |
| `SVC_BASE_URI` | `http://localhost:3000` | シェル環境変数またはホストの `.env` |
| `SAML_SP_ENTITY_ID` | `dev-auth` | シェル環境変数またはホストの `.env` |
| `SAML_IDP_METADATA_URL` | 未設定 | シェルでエクスポート |
| `TRUST_PROXY` | 未設定 | シェルでエクスポート |

`PROTOCOL=http` と `DEFAULT_PROTOCOL=saml` はCompose内で固定しています。
ホストの `.env` はComposeの変数展開用であり、記載した変数すべてをコンテナへ渡すものではありません。

### ほかの設定を追加する

Composeの `environment:` に追記するか、オーバーライドファイルで指定します。
例えば、既存の `environment:` に次を追加すると、SAMLの再認証を要求できます。

```yaml
SAML_FORCE_AUTHN: "true"
```

変更後は `docker compose up -d` でコンテナを再作成します。`docker compose restart` だけでは環境変数は更新されません。

複数IdPなどの構造化設定には、サービス側の `.env` または `config.toml` を
`/opt/perforce/helix-auth-svc` 配下へマウントして使用します。
ホストのCompose用 `.env` とは別物です。環境変数にJSON風の文字列を渡すだけでは、同じように解析されるとは限りません。

### 共通の注意点

- **ファイルパスはコンテナ内のパス**。相対パスの基準は `/opt/perforce/helix-auth-svc`。参照ファイルをマウントし、`ubuntu` ユーザーに読み取り権限を与えてください。
- **真偽値・数値は引用符で囲む**。存在や空でない値で有効になる設定は、`"false"` ではなく変数自体を省略して無効にします。
- **本番用の証明書・シークレットを用意する**。同梱証明書と開発用の既定シークレットは、本番利用に適しません。

## 設定リファレンス

対象は、[ビルド設定](../build/helix-auth-svc/.env)で指定している **HAS 2026.1**。
`latest` イメージの更新時には[上流資料](#ビルド設定参考資料)も確認してください。
既定値は原則として上流HASの値です。イメージ・Composeで異なるものは明記しています。
既定値の記載がない項目は、利用する連携に応じて設定します。

### 基本設定・待ち受け

- `SVC_BASE_URI`: 公開URL・認証コールバックの基準URI。Compose既定: `http://localhost:3000`
- `PROTOCOL`: 内部の待ち受けプロトコル（`http` / `https`）。公開URLのスキームより優先。イメージ・Compose既定: `http`
- `PORT`: 内部の待ち受けポート。公開URLのポートより優先。イメージ既定: `3000`。変更時はポートマッピングも更新
- `BIND_ADDRESS`: 待ち受けIP。未設定時は `0.0.0.0` または `::`
- `SVC_USER`: ポート確保後に切り替えるユーザー。イメージは `ubuntu` で実行するため、切り替えや特権ポートの使用には追加権限が必要
- `SVC_GROUP`: ポート確保後に切り替えるグループ。適切なコンテナ権限が必要
- `TRUST_PROXY`: 信頼するリバースプロキシのアドレス・範囲など、Expressのtrust proxy設定
- `CORS_ORIGIN`: REST APIで許可するオリジン。既定: URL・待ち受け設定から算出したサービスのベースURI
- `NODE_ENV`: Node.jsの動作モード。イメージ既定: `production`。通常は変更不要

### ログイン・セッション

- `DEFAULT_PROTOCOL`: 既定の認証方式（`saml` / `oidc`）。Composeでは `saml` に固定
- `LOGIN_TIMEOUT`: 認証完了までの制限時間。既定: `60` 秒
- `FORCE_AUTHN`: 空でない値で全プロバイダーの再認証を要求。認証方式別の設定より優先
- `PROMPT_FOR_AUTHORIZATION`: 空でない値でIdPへの遷移前に確認画面を表示
- `SESSION_SECRET`: セッション保護用シークレット。本番では強い秘密の値に変更
- `INSTANCE_ID`: セッション固定用にログインURLへ付ける `instanceId`。既定: `none`
- `HOME_PAGE_ENABLED`: `/` の表示。既定: `true`。無効化時は `/` を参照するヘルスチェックも変更
- `STATUS_ENABLED`: 認証不要の `/status` 診断情報公開。既定: `false`。バージョン・証明書・設定情報を含む
- `VALIDATE_ENABLED`: `/validate/swarm` などの検証用RESTルート。既定: `false`

### SAML：IdPへの接続

- `SAML_IDP_METADATA_URL`: IdPのXMLメタデータURL
- `SAML_IDP_METADATA_FILE`: IdPのXMLメタデータファイル
- `SAML_IDP_METADATA`: IdPのXMLメタデータを直接指定
- `SAML_IDP_SSO_URL`: メタデータを使わず手動設定する場合のSSOエンドポイント
- `SAML_IDP_SLO_URL`: IdPのSLOエンドポイント
- `SAML_IDP_ENTITY_ID`: 受け入れるIdPのエンティティID
- `IDP_CERT_FILE`: IdPの署名検証用証明書ファイル。メタデータから取得できない場合に必要
- `IDP_CERT`: IdPの署名検証用証明書を直接指定
- `SAML_SP_ENTITY_ID`: HASのSPエンティティID。上流既定: `https://has.example.com` / Compose既定: `dev-auth`
- `SAML_SP_AUDIENCE`: SPのAudience制限値
- `SAML_AUTHN_CONTEXT`: 要求する認証コンテキスト。既定: `urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport`
- `SAML_DISABLE_CONTEXT`: 認証コンテキストを要求しない。既定: `false`
- `SAML_FORCE_AUTHN`: SAMLで再認証を要求。既定: `false`
- `SAML_NAMEID_FORMAT`: 要求するNameID形式。既定: `urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified`
- `SAML_WANT_ASSERTION_SIGNED`: アサーションへの署名を必須にする。既定: `true`
- `SAML_WANT_RESPONSE_SIGNED`: レスポンスへの署名を必須にする。既定: `true`。要件を緩和しても、レスポンス・アサーションの少なくとも一方の署名は必要
- `SP_KEY_ALGO`: SAMLリクエストの署名アルゴリズム。既定: `sha256`
- `SAML_INFO_LABEL`: プロバイダー選択画面の表示名

### SAML：証明書・連携先アプリケーション

- `SAML_CERT_FILE`: SAML用のHAS公開証明書。Swarmなどに対してIdPとして動作する場合も使用。未指定時は `CERT_FILE`
- `SAML_KEY_FILE`: SAML用のHAS秘密鍵。未指定時は `KEY_FILE`
- `SAML_NAMEID_FIELD`: OIDC連携などでNameIDがない場合に使用する、ユーザープロファイルのプロパティ名
- `IDP_CONFIG_FILE`: 連携先SPの設定ファイル。既定: `./routes/saml_idp.conf.cjs`
- `IDP_CONFIG`: 連携先SPの構造化設定。TOMLでは `idp_config`

### OpenID Connect

- `OIDC_ISSUER_URI`: ディスカバリー用の発行者URL
- `OIDC_CLIENT_ID`: IdPに登録したクライアントID
- `OIDC_CLIENT_SECRET`: クライアントシークレット
- `OIDC_CLIENT_SECRET_FILE`: クライアントシークレットの読み込み元ファイル
- `OIDC_CLIENT_CERT_FILE`: 秘密鍵JWT方式のクライアント認証に使う公開証明書ファイル
- `OIDC_CLIENT_KEY_FILE`: 対応する秘密鍵ファイル
- `OIDC_CLIENT_CERT`: 秘密鍵JWT方式の公開証明書を直接指定
- `OIDC_CLIENT_KEY`: 秘密鍵を直接指定。可能なら保護したファイルを使用
- `OIDC_TOKEN_SIGNING_ALGO`: IDトークンの署名アルゴリズム。既定: `RS256`
- `OIDC_CODE_CHALLENGE_METHOD`: PKCE方式（`S256` / `plain`）。未指定時は発行者のメタデータから決定
- `OIDC_SELECT_ACCOUNT`: promptに `select_account` を追加。既定: `false`
- `OIDC_MAX_AGE`: 再認証までのIdPセッションの最大経過時間（秒）。IdP側の対応が必要
- `OIDC_INFO_LABEL`: プロバイダー選択画面の表示名

### 複数IdP

- `AUTH_PROVIDERS`: 複数IdPの定義。サービス側の `.env` では `providers` 配列を持つJSON、TOMLでは `[[auth_providers]]`
- `AUTH_PROVIDERS_FILE`: 同じJSON定義の読み込み元ファイル

### TLS・クライアント証明書

- `CERT_FILE`: HASのTLS公開証明書。SAML用の代替証明書も兼ねる。既定: `certs/server.crt`
- `KEY_FILE`: 対応する秘密鍵。既定: `certs/server.key`
- `PFX_FILE`: PKCS#12形式の証明書・秘密鍵。`CERT_FILE` / `KEY_FILE` より優先
- `KEY_PASSPHRASE`: 暗号化した `KEY_FILE` / `PFX_FILE` のパスフレーズ
- `KEY_PASSPHRASE_FILE`: パスフレーズの読み込み元ファイル
- `CA_CERT_FILE`: クライアント証明書検証用のCA証明書。イメージ既定: `certs/ca.crt`
- `CA_CERT_PATH`: 複数のCA証明書を格納する代替ディレクトリ
- `CLIENT_CERT_CN`: 許可するCommon Name・パターン。複数指定: `[cn1,cn2]`
- `CLIENT_CERT_FP`: 許可するSHA-256フィンガープリント。複数指定: `[fp1,fp2]`
- `CLIENT_CERT_HEADER`: プロキシからクライアント証明書を受け取るヘッダー名。プロキシ側で証明書を検証し、外部からの同名ヘッダーを上書き・除去すること

コンテナで直接HTTPSを提供する場合は、証明書のマウントと `PROTOCOL=https` への変更が必要です。
`SVC_BASE_URI` の変更だけでは、内部のTLSは有効になりません。

### キャッシュ・Redis

- `CACHE_TTL`: リクエスト・プロファイルの保持期間。メモリ・Redis共通。既定: `300` 秒
- `REDIS_URL`: セッション・キャッシュ共有用のRedis URL。TLS接続は `rediss://`
- `REDIS_CERT_FILE`: Redis TLS接続用のクライアント証明書。同梱既定: `certs/server.crt`。TLS利用時は明示的に設定
- `REDIS_KEY_FILE`: 対応する秘密鍵。同梱既定: `certs/server.key`
- `SENTINEL_CONFIG_FILE`: Redis Sentinelの設定ファイル。上流の `sentinel.config.cjs` を参照
- `SENTINEL_CONFIG`: Redis Sentinelの構造化設定。TOMLでは `sentinel_config`

### 管理画面

- `ADMIN_ENABLED`: 管理画面の有効化。既定: 無効
- `ADMIN_USERNAME`: ローカル管理者名。既定: `perforce`
- `ADMIN_PASSWD_FILE`: ローカル管理者のパスワードファイル。ローカル認証に必要
- `ADMIN_P4_AUTH`: 値を設定するとローカル認証の代わりに `P4PORT` のHelix Coreで管理者認証。`super` 権限が必要
- `TOKEN_TTL`: サービス発行JWTの有効期間。既定: `3600` 秒
- `LOGIN_RATE_LIMIT`: 同一クライアントからの管理者ログイン試行上限。既定: `10` 回
- `LOGIN_RATE_LIMIT_WINDOW`: 試行回数の集計期間。既定: `900000` ミリ秒（15分）

### Helix Core・SCIM

- `P4PORT`: プロビジョニング・管理者認証に使用するHelix Coreサーバー
- `P4USER`: ユーザー・グループ管理用のPerforceアカウント
- `P4PASSWD`: パスワードまたはチケット
- `P4TICKETS`: チケットファイルのパス
- `P4TRUST`: 信頼ファイルのパス
- `BEARER_TOKEN`: SCIM用の共有Bearerトークン。利用前に開発用既定値から変更
- `BEARER_TOKEN_FILE`: Bearerトークンの読み込み元ファイル
- `ALLOW_USER_RENAME`: 既存ユーザーの名前変更を許可。既定: `false`。有効化は既存運用に影響する可能性あり
- `PROVISIONING`: 複数プロバイダー・サーバーの構造化設定。TOMLでは `provisioning`

このComposeでは連携未設定です。接続先・認証情報・連携に必要な実行時依存関係を別途用意してください。

### OAuth・JWT検証

HASに提示されたトークンの検証用です。IdPログイン用の `OIDC_*` とは別設定です。

- `OAUTH_JWKS_URI`: 検証鍵を取得するJWKSエンドポイント
- `OAUTH_JWKS_KEYID`: トークンヘッダーの `kid` に代わる、明示的な鍵識別子
- `OAUTH_SIGNING_KEY_FILE`: JWKSの代わりに使うローカル公開鍵ファイル
- `OAUTH_ALGORITHM`: 検証するJWTの暗号アルゴリズム
- `OAUTH_AUDIENCE`: 期待する `aud`。設定推奨
- `OAUTH_ISSUER`: 期待する `iss`。設定推奨
- `OAUTH_TENANT_ID`: 許可するテナントID。該当環境では設定推奨

### ログ・診断

- `LOGGING`: ログ設定ファイル・構造化設定。`none` で無効化。`DEBUG` より優先
- `DEBUG`: 空でない値でコンソールのデバッグ出力を有効化
- `DEBUG_PROXY`: 空でない値でOIDC・SAMLのプロキシ情報を追加
- `DEBUG_SCIM`: 空でない値でSCIMリクエストの詳細を追加
- `DEBUG_ADMIN`: 変数の存在で管理設定リクエスト本文をデバッグ出力の対象にする
- `DEBUG_SAML`: 変数の存在でSAMLレスポンスなどをデバッグ出力の対象にする

詳細出力にはデバッグレベルのログ設定も必要です。`DEBUG_ADMIN` / `DEBUG_SAML` は機密情報を含み得るため、通常運用では設定しないでください。

<details>
<summary>互換用の旧設定名・内部用スイッチ</summary>

- `SAML_SP_ISSUER`: `SAML_SP_ENTITY_ID` の旧名
- `SAML_IDP_ISSUER`: `SAML_IDP_ENTITY_ID` の旧名
- `SP_CERT_FILE`: `CERT_FILE` の旧名
- `SP_KEY_FILE`: `KEY_FILE` の旧名
- `ASSUME_CLIENT_AUTHORIZED`: クライアント認可を省略する内部スイッチ。**デプロイ環境では設定禁止**
- `LOGGING_FILE`: ログ設定ファイル管理用の内部値。利用者は `LOGGING` を設定

新規設定では旧名を使わず、現在の設定名を使用してください。

</details>

## 構造化設定

以下はHAS固有のフィールドです。記述形式は[上流のTOML設定例](https://github.com/perforce/helix-authentication-service/blob/2026.1/example.toml)を参照してください。
外部のログ・Redisライブラリ固有の全オプションは対象外です。

### `AUTH_PROVIDERS` / `[[auth_providers]]`

JSONでは以下のcamelCase、TOMLでは対応するsnake_case（例: `issuer_uri`、`sp_entity_id`）を使用します。

- `id`: プロバイダーの識別子。
- `protocol`: `saml` または `oidc`。
- `label`: プロバイダー選択画面の表示ラベル。
- `default`: 既定のプロバイダーにするかどうか。
- OIDC用フィールド：
  - `issuerUri`: 発行者のディスカバリーURL。
  - `clientId`: 登録済みのクライアントID。
  - `clientSecret`, `clientSecretFile`: クライアントシークレットの直接指定、または読み込み元ファイル。
  - `clientCert`, `clientCertFile`: 秘密鍵JWT方式で使用する証明書の直接指定、または読み込み元ファイル。
  - `clientKey`, `clientKeyFile`: 秘密鍵JWT方式で使用する秘密鍵の直接指定、または読み込み元ファイル。
  - `codeChallenge`: PKCEのチャレンジ方式。
  - `maxAge`: 認証からの最大経過時間（秒）。
  - `selectAccount`: アカウント選択を要求するかどうか。
  - `signingAlgo`: IDトークンの署名アルゴリズム。
- SAML用フィールド：
  - `metadata`, `metadataFile`, `metadataUrl`: IdPメタデータの直接指定、ファイル指定、またはURL指定。
  - `signonUrl`, `logoutUrl`: IdPのSSO・SLOエンドポイント。
  - `idpEntityId`: IdPのエンティティID。
  - `spEntityId`: HASのサービスプロバイダーとしてのエンティティID。
  - `idpCert`, `idpCertFile`: IdPの署名検証用証明書の直接指定、または読み込み元ファイル。
  - `audience`: Audience制限。
  - `authnContext`: 要求する認証コンテキスト。
  - `disableContext`: 認証コンテキストの要求を無効にするかどうか。
  - `forceAuthn`: 再認証を要求するかどうか。
  - `nameIdFormat`: NameIDの形式。
  - `wantAssertionSigned`, `wantResponseSigned`: 署名を必須にするかどうか。
  - `keyAlgorithm`: リクエストの署名アルゴリズム。

ファイル指定は運用者が管理する設定用です。管理用HTTP APIは
`clientCertFile`・`clientKeyFile`・`clientSecretFile`・`idpCertFile`・`metadataFile` を受け付けません。
APIでは値を直接指定してください。

### `IDP_CONFIG` / `[idp_config.'<SP entity ID>']`

- テーブルのキー：連携先SPの正確なエンティティID、または対応する照合パターン。
- `acsUrl` / TOML `acs_url`: 許可するアサーションコンシューマーサービス（ACS）のURL。
- `acsUrls` / TOML `acs_urls`: 許可するACS URLの一覧。
- `acsUrlRe` / TOML `acs_url_re`: 許可するACS URLに一致する正規表現。

### `PROVISIONING` / `[provisioning]`

- `providers`: プロビジョニングプロバイダーの一覧（`[[provisioning.providers]]`）。
  - `domain`: プロバイダーのドメイン識別子。
  - `bearerToken` / TOML `bearer_token`: このプロバイダーのSCIM Bearerトークンを直接指定します。
  - `bearerTokenFile` / TOML `bearer_token_file`: トークンを直接記載する代わりに読み込むファイル。
- `servers`: 対象サーバーの一覧（`[[provisioning.servers]]`）。
  - `p4port`, `p4user`, `p4passwd`: 対象サーバーと管理用の認証情報。
  - `p4tickets`, `p4trust`: チケット・信頼ファイルのパス。省略可能です。
  - `domains`: このサーバーが担当するプロバイダードメインの一覧。
  - `leader`: このサーバーがプロビジョニングのリーダーを担当するドメインの一覧。

### ログ・Sentinelのテーブル

- `[logging]`: `level`、`transport` などのロガー設定。
- `[logging.file]`: `filename`、`maxsize`、`maxfiles` などのファイル出力設定。
- `[logging.scim]`, `[logging.scim.file]`: プロビジョニング専用のロガーとファイル出力設定。`format` でJSON出力を選択できます。
- `[sentinel_config]`: `name`、`sentinel_password`、`sentinels`（`host`・`port` を持つオブジェクトの一覧）などのRedis Sentinelクライアント設定。
- `[sentinel_config.tls]`, `[sentinel_config.sentinel_tls]`: `cert`、`key`、`ca`、`reject_unauthorized` などのRedis・Sentinel用TLS設定。本番環境では証明書検証を無効にしないでください。

## ビルド設定・参考資料

以下は**ビルド時のみ**使用します。稼働中のHASの設定とは別です。

- `IMAGE_NAME`: ビルド用 `.env` で指定するローカルのイメージ名。
- `HAS_VERSION`: ビルド用 `.env` で指定する上流HASのソースタグ。
- `NODE_MAJOR`: Node.jsのメジャーバージョンを選択するDockerビルド引数。
- `UBUNTU_IMAGE`: Ubuntuのベースイメージを選択するDockerビルド引数。

手順は[ビルド用README](../build/helix-auth-svc/README.md)を参照してください。
Node.js・Docker・Compose・OS全般の環境変数は、この一覧の対象外です。

### 上流資料（2026.1）

- [2026.1 example.env](https://github.com/perforce/helix-authentication-service/blob/2026.1/example.env): 公式の環境変数設定例。
- [2026.1 defaults.env](https://github.com/perforce/helix-authentication-service/blob/2026.1/defaults.env): 同梱の既定値。
- [2026.1 example.toml](https://github.com/perforce/helix-authentication-service/blob/2026.1/example.toml): 構造化設定の例。
- [2026.1 constants.js](https://github.com/perforce/helix-authentication-service/blob/2026.1/lib/constants.js): プロバイダープロパティとの対応表、および旧設定名。
- [HAS管理者向けドキュメント](https://www.perforce.com/manuals/helix-auth-svc/): デプロイとIDプロバイダー連携の手順。
