#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
  cat <<'EOF'
使い方:
  check-helix-p4d.sh --container <Helix P4D の Docker コンテナ名>

オプション:
  -c, --container  Helix P4D の Docker コンテナ名（必須）
  -h, --help       このヘルプを表示
EOF
}

container_name=''
container_type='p4d'

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--container)
      container_name="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "不明な引数です: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$container_name" ]]; then
  echo "--container を指定してください。" >&2
  usage >&2
  exit 2
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker をインストールし、PATH から実行できる必要があります。" >&2
  exit 1
fi

if ! docker container inspect "$container_name" >/dev/null 2>&1; then
  echo "コンテナ '$container_name' が存在しないか、アクセスできません。" >&2
  exit 1
fi

section() {
  printf '\n=== %s ===\n' "$1"
}

section "コンテナ状態"
cat <<'EOF'
見方の例:
  - Running=true と表示される: コンテナは起動中です。
  - Health=healthy と表示される: ヘルスチェックも正常です。
  - Health=not-configured と表示される: ヘルスチェック未設定であり、異常とは限りません。
  - Running=false、exited、restarting と表示される: コンテナログを確認してください。
  - docker stats の CPU または MEM % が長時間 80% 以上: 負荷を調査してください。
EOF
docker inspect --format \
  'Name={{.Name}} Status={{.State.Status}} Running={{.State.Running}} Started={{.State.StartedAt}}' \
  "$container_name"
docker inspect --format \
  '{{if .State.Health}}Health={{.State.Health.Status}}{{else}}Health=not-configured{{end}}' \
  "$container_name"
docker stats --no-stream "$container_name"

section "オープンファイル上限"
if [[ "$container_type" == 'proxy' ]]; then
  cat <<'EOF'
見方の例:
  - soft / hard がともに 65536 以上: Helix Proxy の現在の推奨設定です。
  - soft が 1024: 同時接続が増えたときに Too many open files の原因になり得ます。
  - hard より soft が低い: 実際にプロセスが使える上限は soft の値です。
EOF
else
  cat <<'EOF'
見方の例:
  - soft / hard がともに 1048576: 現在の Helix P4D と同等の十分な上限です。
  - 現在値が 65536 より大きい: 実測上の理由なく下げないでください。
  - soft が 1024: 接続やデータベースファイルが多い場合の制約になり得ます。
EOF
fi
docker exec "$container_name" sh -c '
  printf "シェルの ulimit -n: "
  ulimit -n
  grep -i "open files" /proc/1/limits
'

section "コンテナプロセス"
if [[ "$container_type" == 'proxy' ]]; then
  echo "例: p4p と cron が表示されれば通常の構成です。想定外のプロセスが増え続ける場合は確認してください。"
else
  echo "例: p4d のプロセスが表示されれば通常の構成です。想定外のプロセスが増え続ける場合は確認してください。"
fi
docker top "$container_name"

section "ホストのリソース"
cat <<'EOF'
見方の例:
  - 4 コアのホストで load average が 1 未満: 十分な CPU 余裕があります。
  - 4 コアのホストで load average が 4 以上の状態が続く: CPU または I/O 待ちを調査してください。
  - free -h の available に数 GiB 以上ある: 通常はメモリに余裕があります。
  - df -h の Use% が 80% 未満: 通常はディスク容量に余裕があります。
EOF
uptime
free -h
df -h /
cat <<'EOF'
TCP の見方の例:
  - orphaned が 0 件または少数: 通常は問題ありません。
  - timewait が一時的に増える: クライアントの再接続後には起こり得ます。
  - orphaned や timewait が数百件以上で減らずに増え続ける: ネットワークやクライアントを調査してください。
EOF
ss -s

section "Docker サービスのファイル上限"
cat <<'EOF'
見方の例:
  - LimitNOFILE=524288: SIN / ROD の Docker ホストで確認できた十分な値です。
  - コンテナの /proc/1/limits に表示された値を優先して確認してください。
  - この値が低く、コンテナの hard 上限より低い場合: Docker サービス設定を調査してください。
EOF
systemctl show docker --property=LimitNOFILE

if command -v iostat >/dev/null 2>&1; then
  section "ディスク I/O サンプル（1 秒間隔）"
  cat <<'EOF'
最初のレポートは起動以降の平均値、2 番目は 1 秒間の実測値です。
見方の例:
  - %util が 80% 未満、%iowait が 10% 未満: 通常はディスクに余裕があります。
  - キャッシュ作成時に wkB/s や w_await が一時的に増える: 起こり得ます。
  - %util が 80% 以上、%iowait が 10% 以上、await が数百 ms以上で数分間続く: ディスク性能を調査してください。
EOF
  iostat -xz 1 2
else
  echo "iostat を実行できません。ディスク I/O を計測するには sysstat をインストールしてください。"
fi

if [[ "$container_type" == 'proxy' ]]; then
  section "Proxy キャッシュ削除スケジュール"
  cat <<'EOF'
見方の例:
  - cron プロセスが表示され、定義に P4P_CACHE_PURGE_DAYS または purge が含まれる: 削除スケジュールは設定されています。
  - crontab が未設定でも /etc/cron.d に定義がある: 正常です。
  - cron プロセスも削除定義も見つからない: キャッシュ削除は動かないため、イメージ設定を確認してください。
EOF
  docker exec "$container_name" sh -c '
    echo "-- crontab --"
    if ! crontab -l; then
      echo "コンテナユーザーの crontab は設定されていません。"
    fi
    echo "-- cron プロセス --"
    if ! ps aux | grep -E "[c]ron|[c]rond"; then
      echo "cron プロセスは起動していません。"
    fi
    echo "-- キャッシュ削除の定義 --"
    if ! grep -RniE "purge|P4P_CACHE_PURGE_DAYS" /etc/cron* /opt/perforce 2>/dev/null; then
      echo "キャッシュ削除の定義が見つかりません。"
    fi
  '

  section "Proxy 接続"
  cat <<'EOF'
見方の例:
  - 誰も利用していない時間帯: ESTAB が 0 件なら正常です。
  - 数人が同期・取得している時間帯: ESTAB が利用中のクライアント数とおおむね同程度なら正常です。
  - 操作していないのに ESTAB が増え続ける、または数百件以上で減らない場合: クライアントまたはネットワークを調査してください。
EOF
  ss -tn '( sport = :1777 )'
fi

section "コンテナの直近ログ"
cat <<'EOF'
見方の例:
  - 起動直後の初期化メッセージだけ: 通常は問題ありません。
  - fatal、connection refused、authentication failed、Too many open files が繰り返される: 原因を調査してください。
  - 同じエラーが短時間に何度も出る: コンテナ再起動前にエラー内容を保存してください。
EOF
docker logs --tail 100 "$container_name"
