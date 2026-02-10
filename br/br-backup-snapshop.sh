#!/bin/bash

######参数#########
# s3对象存储的秘钥key
s3_access_key=xljtCAbfSIWeKJHBv3az
# s3对象存储的秘钥value
s3_secret_access_key=r9KwGrIii26aB23sKTQZajCYAHAcqDRd7XfuXY02
# s3对象存储的bucket
s3_bucket_name=backup
# s3对象存储的文件名称
s3_path_name=snapshot-20260210
# s3对象存储的地址 http://host:port
s3_server=http://192.168.0.188:9000
# br执行文件的路径，结尾带/
br_path=/opt/soft/
# 执行log地址，结尾带/
log_path=/opt/soft/
# tidb的pd地址ip:port，多个端口用英文逗号分隔
pd_path=192.168.0.175:2379
# 需要备份的数据库，比如foo.*,表示备份foo库下的所有表，多个条件用英文逗号分隔，设置为空时则不做过滤条件
filters="db_monitor.*,demo.*"
# 备份数据加密方法：aes128-ctr、aes192-ctr 和 aes256-ctr，日志加密仅在v8.4.0后版本才支持，当设置为空时，则不需要加密
crypt_method=
# 加密密钥，十六进制字符串格式，aes128-ctr 对应 128 位（16 字节）密钥长度，aes192-ctr 为 24 字节，aes256-ctr 为 32 字节
crypt_key=


# 记录日志的方法
log_file() {
    local msg="$1"
    # 获取当前时间，格式：YYYY-MM-DD HH:MM:SS.mmm
    local ts
    ts=$(date +"%Y-%m-%d %H:%M:%S.%3N")
    # 输出到终端和日志文件
    echo "${ts}  ${msg}" | tee -a "${log_path}backup.log"
}

# 快照备份方法
backup_snapshot(){
  # 获取日期格式串
  dateT=$(date +%Y%m%d)

  cmd="${br_path}br backup full --pd=\"${pd_path}\" --storage=\"s3://${s3_bucket_name}/${s3_path_name}?access-key=${s3_access_key}&secret-access-key=${s3_secret_access_key}\" --ratelimit 128 --s3.endpoint \"${s3_server}\" --log-file \"${log_path}backup_snapshot_${dateT}.log\""
  if [ -n "${crypt_method}" ]; then
    cmd="$cmd --crypter.method ${crypt_method} --crypter.key ${crypt_key} "
  fi
  # 用逗号分隔，逐个拼接 -f 参数
  if [ -n "${filters}" ]; then
    IFS=',' read -ra arr <<< "$filters"
    for f in "${arr[@]}"; do
      cmd="$cmd --filter '$f'"
    done
  fi
  cmd="$cmd --ratelimit 128"
  # 拼接存储参数
  log_file "执行命令：$cmd"
  eval "$cmd"
  log_file "全量备份结束...."
}
