#!/bin/bash

######参数#########
# s3对象存储的秘钥key
s3_access_key=xljtCAbfSIWeKJHBv3az
# s3对象存储的秘钥value
s3_secret_access_key=r9KwGrIii26aB23sKTQZajCYAHAcqDRd7XfuXY02
# s3对象存储的bucket
s3_bucket_name=backup
# s3对象存储的地址 http://host:port
s3_server=http://192.168.0.188:9000
# br执行文件的路径，结尾带/
br_path=/opt/soft/
# 执行log地址，结尾带/
log_path=/opt/soft/
# tidb的pd地址ip:port，多个端口用英文逗号分隔
pd_path=192.168.0.175:2379
# 需要备份的数据库，比如foo.*,表示备份foo库下的所有表，多个条件用英文逗号分隔，设置为空时则不做过滤条件
filters="!INFORMATION_SCHEMA.*,!METRICS_SCHEMA.*,!PERFORMANCE_SCHEMA.*,!mysql.*,!sys.*"
# 备份数据加密方法：aes128-ctr、aes192-ctr 和 aes256-ctr，日志加密仅在v8.4.0后版本才支持，当设置为空时，则不需要加密
crypt_method=aes128-ctr
# 加密密钥，十六进制字符串格式，aes128-ctr 对应 128 位（16 字节）密钥长度，aes192-ctr 为 24 字节，aes256-ctr 为 32 字节
crypt_key=fc125f1d7ca3a51d1a02eefe3941d86f
# 快照备份的名称
snapshot_file_name=snapshot-
# 恢复的时间点 2022-05-15 18:00:00+0800
restored-ts=2025-05-15 18:00:00+0800



# 构造可选加密参数
extra_args_log=()
if [ -n "${crypt_method}" ]; then
  extra_args_log=(--log.crypter.method ${crypt_method} --log.crypter.key ${crypt_key} --crypter.method ${crypt_method} --crypter.key ${crypt_key}")
fi

# 构造表过滤条件
extra_filters=()
if [ -n "${filters}" ]; then
  # 用逗号分隔，逐个拼接 -f 参数
  IFS=',' read -ra arr <<< "$filters"
  for f in "${arr[@]}"; do
	extra_filters += ( --filter '$f'")
  done
fi

# 恢复执行命令
${br_path}br restore point --pd="${pd_path}" \
--storage='s3://${s3_bucket_name}/log-backup?access-key=${s3_access_key}&secret-access-key=${s3_secret_access_key}' \
--full-backup-storage='s3://${s3_bucket_name}/${snapshot_file_name}?access-key=${s3_access_key}&secret-access-key=${s3_secret_access_key}' \
--restored-ts '${restored-ts}'
--s3.endpoint \"${s3_server}\" \
"${extra_args_log[@]}" "${extra_filters[@]}"  \
--log-file \"${log_path}restore_log.log\"" \
--ddl-batch-size=32 \
--ratelimit 128





