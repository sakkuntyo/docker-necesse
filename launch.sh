#!/bin/bash

# docker stop 時の保存処理
trap '
echo "docker stop 時の処理(おそらくこの echo 以外は実装されていません。)"
exit 0;
' SIGTERM

# update rustdedicated
steamcmd +login anonymous +force_install_dir /root/necesseserver +app_update 1169370 validate +quit

# exitnode 指定があるなら tailscale を起動 (特権モードが必要)
if [ ! -z "${ENV_TS_EXITNODE_IP}" ]; then
  # デバッグログを出させるが、docker logs -t で時刻を表示できるので時刻部分は sed で削除
  tailscaled -verbose 1 | \
    sed -u 's/^[0-9]\{4\}\/[0-9]\{2\}\/[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\} //g' &
  # そろそろここも if then 形式に変えたいけど、ちゃんと動いてる。。。。
  tailscale status && {
    tailscale up --exit-node="${ENV_TS_EXITNODE_IP}" --hostname=${ENV_TS_HOSTNAME}
    :
  } || {
    tailscale up --auth-key=${ENV_TS_AUTHKEY} --exit-node="${ENV_TS_EXITNODE_IP}" --hostname=${ENV_TS_HOSTNAME}
    :
  }
fi

./StartServer-nogui.sh -world MyWorld &

# 10分後に死活監視を開始
for ((i = 1; i <= 5; i++))
do
  echo "INFO: $(((6 - i))) 分後にヘルスチェックを開始します。。。"
  sleep 60
done

while true; do
  TIMESTAMP=$(date)

  # Tailscaleのチェックが必要かどうかを判断するフラグ
  # ENV_TS_EXITNODE_IP が空でなければ (設定されていれば)、true に設定
  SHOULD_CHECK_TAILSCALED=false
  if [[ -n "${ENV_TS_EXITNODE_IP}" ]]; then
    SHOULD_CHECK_TAILSCALED=true
  fi

  # --- ヘルスチェックの実施 ---
  # 1. tailscaled のチェックが必要であり、かつ tailscaled が起動していない場合
  if [[ "${SHOULD_CHECK_TAILSCALED}" == "true" && -z "$(pgrep tailscaled)" ]]; then
    echo "ERROR: tailscaled が起動していません。コンテナを停止します (必要に応じて自動起動オプションを使用してください)。"
    kill 1
  # 2. RustDedicated プロセスが存在しない場合 (tailscaled のチェックがOKか、スキップされた場合)
  elif ! pgrep java > /dev/null; then
    echo "ERROR: Necesse Server が起動していません。コンテナを停止します (必要に応じて自動起動オプションを使用してください)。"
    kill 1
  # 3. ポート28015がリッスンされていない場合 (両プロセスがOKの場合)
  elif ! netstat -tuln | grep "${ENV_SERVER_PORT:=14159}" > /dev/null; then
    echo "ERROR: ポート ${ENV_SERVER_PORT:=14159} のリッスンがありません。コンテナを停止します (必要に応じて自動起動オプションを使用してください)。"
    kill 1
  # 4. 全てのチェックがOKの場合
  else
    echo "INFO: Health Check: 全てのサービスは正常に稼働中です。"
  fi  
  
  sleep 60
done
