#!/bin/bash
set -e

###### 参数 #########
s3_access_key="xljtCAbfSIWeKJHBv3az"
s3_secret_access_key="r9KwGrIii26aB23sKTQZajCYAHAcqDRd7XfuXY02"
s3_bucket_name="backup"
s3_server="http://192.168.0.188:9000"

br_path="/opt/soft/"
log_path="/opt/soft/"
pd_path="192.168.0.175:2379"

filters="!INFORMATION_SCHEMA.*,!METRICS_SCHEMA.*,!PERFORMANCE_SCHEMA.*,!mysql.*,!sys.*"

crypt_method="aes128-ctr"
crypt_key="fc125f1d7ca3a51d1a02eefe3941d86f"

snapshot_file_name="snapshot-"
log_file_name=""

# 恢复时间点
restored_ts="2025-05-15 18:00:00+0800"

######################################
# 构造加密参数
######################################
extra_args_log=()
if [ -n "$crypt_method" ]; then
  extra_args_log+=(
    --log.crypter.method "$crypt_method"
    --log.crypter.key "$crypt_key"
    --crypter.method "$crypt_method"
    --crypter.key "$crypt_key"
  )
fi

######################################
# 构造过滤参数
######################################
extra_filters=()
if [ -n "$filters" ]; then
  IFS=',' read -ra arr <<< "$filters"
  for f in "${arr[@]}"; do
    extra_filters+=(--filter "$f")
  done
fi


######################################
# 执行恢复
######################################
"${br_path}br" restore point \
  --pd="$pd_path" \
  --storage="s3://${s3_bucket_name}/log-backup?access-key=${s3_access_key}&secret-access-key=${s3_secret_access_key}" \
  --full-backup-storage="s3://${s3_bucket_name}/${snapshot_file_name}?access-key=${s3_access_key}&secret-access-key=${s3_secret_access_key}" \
  --restored-ts="$restored_ts" \
  --s3.endpoint="$s3_server" \
  "${extra_args_log[@]}" \
  "${extra_filters[@]}" \
  --log-file="${log_path}restore_log.log" \
  --ddl-batch-size=32 \
  --ratelimit=128
