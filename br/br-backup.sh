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
# minio客户端地址，需要新版本的客户端，结尾带/
minio_client_path=/opt/soft/
# br执行文件的路径，结尾带/
br_path=/opt/soft/
# 执行log地址，结尾带/
log_path=/opt/soft/
# tidb的pd地址ip:port，多个端口用英文逗号分隔
pd_path=192.168.0.175:2379
# 快照备份周期，0周日、 1周一、 2周二、 3周三、 4周四、 5周五、 6周六， 多个日期用英文逗号分隔
backup_period=0,3,4
# 保留日志的时长，单位天
keep_days=1
# 需要备份的数据库，比如foo.*,表示备份foo库下的所有表，多个条件用英文逗号分隔，设置为空时则不做过滤条件
filters="db_monitor.*,kb_info.*,rag_test.*,zhql.*"
# 备份数据加密方法：aes128-ctr、aes192-ctr 和 aes256-ctr，日志加密仅在v8.4.0后版本才支持，当设置为空时，则不需要加密
crypt_method=aes128-ctr
# 加密密钥，十六进制字符串格式，aes128-ctr 对应 128 位（16 字节）密钥长度，aes192-ctr 为 24 字节，aes256-ctr 为 32 字节
crypt_key=fc125f1d7ca3a51d1a02eefe3941d86f




# log备份的任务名称
log_task_name=pitr
mc_host_name=s3-host


# 判断今天是否在配置的周期里
is_backup_day() {
  # 如果配置为空，直接返回成功
  if [ -z "$backup_period" ]; then
      return 0
  fi

  local today
  today=$(date +%w)  # 获取今天周几
  IFS=',' read -ra days <<< "$backup_period"

  for d in "${days[@]}"; do
      if [ "$today" -eq "$d" ]; then
          return 0   # 匹配成功
      fi
  done
  return 1   # 没匹配到
}

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

  cmd="${br_path}br backup full --pd=\"${pd_path}\" --storage=\"s3://${s3_bucket_name}/snapshot-${dateT}?access-key=${s3_access_key}&secret-access-key=${s3_secret_access_key}\" --ratelimit 128 --s3.endpoint \"${s3_server}\" --log-file \"${log_path}backup_snapshot_${dateT}.log\""
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
  # 拼接存储参数
  log_file "执行命令：$cmd"
  eval "$cmd"
  log_file "全量备份结束...."
}

# 获取快照的ts时间戳
log_snapshot_ts(){
  # 获取该次全量备份的时间戳
  log_file "获取快照备份时间戳"
  # 构造可选参数
  extra_args=""
  if [ -n "${crypt_method}" ]; then
    extra_args="--crypter.method ${crypt_method} --crypter.key ${crypt_key}"
  fi
  FULL_BACKUP_TS=`${br_path}br validate decode --field="end-version" --storage "s3://${s3_bucket_name}/snapshot-${dateT}?access-key=${s3_access_key}&secret-access-key=${s3_secret_access_key}" --s3.endpoint "${s3_server}" ${extra_args} | tail -n1`
  echo "${dateT},${FULL_BACKUP_TS}" >> "${log_path}full_backup_ts"
  log_file "快照备份时间戳为：${FULL_BACKUP_TS}"
}


# log备份方法
backup_log(){
  # 判断log备份的状态
  output=`${br_path}/br log status --task-name=${log_task_name} --pd ${pd_path}`
  if echo "$output" | grep -q "NORMAL"; then
    log_file "log 备份已开启"
  else
    # 构造可选加密参数
    local extra_args_log=""
    if [ -n "${crypt_method}" ]; then
      extra_args_log="--log.crypter.method ${crypt_method} --log.crypter.key ${crypt_key}"
    fi

    # 构造表过滤条件
    local extra_filters=""
    if [ -n "${filters}" ]; then
      # 用逗号分隔，逐个拼接 -f 参数
      IFS=',' read -ra arr <<< "$filters"
      for f in "${arr[@]}"; do
        extra_filters="$extra_filters --filter '$f'"
      done
    fi

    # 备份命令
    # 拼接完整命令
    cmd="${br_path}br log start \
      --task-name=${log_task_name} --pd \"${pd_path}\" \
      --storage \"s3://${s3_bucket_name}/log-backup?access-key=${s3_access_key}&secret-access-key=${s3_secret_access_key}\" \
      --s3.endpoint \"${s3_server}\" \
      ${extra_args_log} ${extra_filters} \
      --log-file \"${log_path}backup_log.log\""

    log_file "开启日志备份的命令：$cmd"
    eval "$cmd"
    #
    sleep 1
    # 判断log备份的状态
    output=`${br_path}/br log status --task-name=${log_task_name} --pd ${pd_path}`
    if echo "$output" | grep -q "NORMAL"; then
      log_file "log 备份已开启"
    else
      log_file "log 开启失败，异常信息：${output}"
      exit 1
    fi
  fi

}

# 获取log备份的状态
get_log_backup_status(){
    log_file "获取log备份状态"
    output=`${br_path}/br log status --task-name=${log_task_name} --pd ${pd_path}`
    log_file "$output"
}


# 清除日志备份，清除上次全量备份之前的日志备份
delete_log_backup() {
    local ts1="$1"
    log_file "删除日志备份的时间戳为：$ts1"
    # 清除上次全量备份之前的日志
    ${br_path}br log truncate --until=${ts1} \
    --storage "s3://${s3_bucket_name}/log-backup?access-key=${s3_access_key}&secret-access-key=${s3_secret_access_key}" \
    --s3.endpoint "${s3_server}" \
    --yes
}


# 获取最老的一次备份记录
get_oldest_ts() {
  # 获取文件中第一行的数据
  local line
  line=$(head -n 1 "${log_path}full_backup_ts")
  # 拆分出日期和时间戳
  IFS=',' read -r date_val ts_val <<< "$line"
  #获取需要删除的日期
  day=$(date -d "${keep_days} days ago" +"%Y%m%d")
  # 如果记录的日期小于等于需要删除的日期，则删除记录里的数据，否则忽略
  if (( date_val <= day )); then
    log_file "删除最旧的一条记录：${line}"
    sed -i '1d' "${log_path}full_backup_ts"
  fi
  echo "$line"
}


# 先初始化本地mc的参数
init_mc_local(){
  # 老版本minio客户端mc为 mc config host list
  output=`${minio_client_path}mc alias list`
  if echo "$output" | grep -q "${mc_host_name}"; then
    log_file "mc host已存在...."
    return 0
  else
	# 老版本minio客户端mc为 mc config host add
    ${minio_client_path}mc alias set ${mc_host_name} ${s3_server} ${s3_access_key} ${s3_secret_access_key} --api s3v4
	# 老版本minio客户端mc为 mc config host list
    output=`${minio_client_path}mc alias list`
    if echo "$output" | grep -q "${mc_host_name}"; then
      log_file "mc host创建成功"
    else
      log_file "mc host创建失败，失败信息：${output}"
      exit 1
    fi
  fi
}

# 清除日志备份，清除上次全量备份之前的日志备份
delete_full_backup(){
  day=$(date -d "${keep_days} days ago" +"%Y%m%d")
  if init_mc_local; then
    log_file "开始删除快照备份....."
    # 获取日期列表
    output=`${minio_client_path}mc ls ${mc_host_name}/${s3_bucket_name}/`
    if echo "$output" | grep -q "snapshot-${day}"; then
      ${minio_client_path}mc rm --recursive --force ${mc_host_name}/${s3_bucket_name}/snapshot-${day}/
      log_file "备份删除成功....."
    else
      log_file "没有相关的全量备份....，忽略删除....."
    fi
  else
    log_file "ERROR  初始化mc host失败....."
    exit 1
  fi
}


# 检查log备份的状态
task_backup(){
  log_file "............任务备份开始............"
  # 先判断log备份是否正常
  output=`${br_path}/br log status --task-name=${log_task_name} --pd ${pd_path}`
  if echo "$output" | grep -q "NORMAL"; then
      log_file "log 备份检查正常...."
  else
       log_file "${log_task_name} 没有在运行中，创建一个log任务"
       backup_log
  fi
  # 运行快照备份，先检查是否在设定的时间点内
  if is_backup_day; then
      log_file "快照备份开始...."
      backup_snapshot
      log_file "快照备份结束...."
      log_snapshot_ts
  else
      log_file "今天不是快照备份日，忽略快照备份......."
  fi
  # 获取最老的一次备份记录
  local data_line="$(get_oldest_ts)"
  log_file "获取文件的最后数据：${data_line}"
  IFS=',' read -r v1 v2 <<< "$data_line"
  log_file "获取文件的日期，日期：${v1}，时间戳：${v2}"
  # 删除日志备份
  delete_log_backup "${v2}"
  # 删除快照备份
  delete_full_backup
}


# 读取第一个参数
action=$1

# 判断执行哪个函数
case ${action} in
    logstart)
        backup_log
        ;;
    logstatus)
        get_log_backup_status
        ;;
    snapshot)
        backup_snapshot
        ;;
    task)
        task_backup
        ;;
    *)
        echo "用法: $0 {logstart|logstatus|snapshot|task}"
        exit 1
        ;;
esac






