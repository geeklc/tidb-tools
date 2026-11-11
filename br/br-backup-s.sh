#!/usr/bin/env bash

set -u
set -o pipefail

###### 参数 #########
# S3 对象存储的访问密钥
s3_access_key=IDQOHVYZTYAEAUPYSFJK
# S3 对象存储的私有密钥
s3_secret_access_key=jf8sl3iILWjBbIwpibkgyLTXS9tXYl9uQc9mCd6f
# S3 对象存储的 bucket
s3_bucket_name=yshjwgjc
# s3的前缀配置
s3_prefix_path=tidb-backup
# S3 对象存储的地址，格式为 http://host:port
s3_server=http://192.168.0.188:1999
# BR 执行文件所在目录
br_path=/data1/soft/br
# 本地执行日志目录
log_path=/data1/soft/br
# MinIO 客户端 mc 的完整路径
mc_bin=/opt/soft/mc
# mc 中使用的对象存储别名
mc_alias=s3-host
# TiDB PD 地址，多个地址用英文逗号分隔
pd_path=10.247.66.56:2379

# 快照备份周期：0 周日、1 周一、2 周二、3 周三、4 周四、5 周五、6 周六。
# 多个日期用英文逗号分隔；留空表示每天备份。
# 需要通过 cron 每天固定时间执行一次 "$0 task"，脚本会根据此配置判断当天是否备份。
backup_period="0,1,2,3,4,5,6"

# 需要备份的数据库名称，多个数据库用英文逗号分隔。
# 这里只填写库名，不需要填写 .*；留空表示备份全部数据库。
backup_databases=""

# BR 备份限速，单位为 MiB/s；设置为 0 表示不限速。
backup_rate_limit=128

# 快照保留策略：保留今天，以及指定天数前的快照日期。
# 例如 1,2,4,7 表示保留今天、1 天前、2 天前、4 天前和 7 天前的数据，
# 其他更早或中间日期的快照会由 mc 删除；留空表示不自动删除快照。
backup_retention_days="1,2,4,7"


br_bin="${br_path%/}/br"
log_dir="${log_path%/}"
run_date=$(date +%Y%m%d)
run_log="${log_dir}/backup_${run_date}.log"
declare -a database_filter_args=()


# 去掉字符串首尾空白。
trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}


# 记录脚本执行日志。
log_file() {
  local msg="$1"
  local ts
  ts=$(date +"%Y-%m-%d %H:%M:%S.%3N")
  printf '%s  %s\n' "$ts" "$msg" | tee -a "$run_log"
}


# 检查配置，并把数据库名称转换为 BR filter 参数。
validate_config() {
  local day
  local database
  local -a configured_days=()
  local -a configured_databases=()

  if [ ! -x "$br_bin" ]; then
    printf 'ERROR: BR 执行文件不存在或不可执行：%s\n' "$br_bin" >&2
    return 1
  fi

  if ! [[ "$backup_rate_limit" =~ ^[0-9]+$ ]]; then
    printf 'ERROR: backup_rate_limit 必须是大于或等于 0 的整数。\n' >&2
    return 1
  fi

  if [ -n "$backup_period" ]; then
    IFS=',' read -r -a configured_days <<< "$backup_period"
    for day in "${configured_days[@]}"; do
      day=$(trim "$day")
      if ! [[ "$day" =~ ^[0-6]$ ]]; then
        printf 'ERROR: backup_period 中的日期必须是 0 到 6，当前值：%s\n' "$day" >&2
        return 1
      fi
    done
  fi

  if [ -n "$backup_databases" ]; then
    IFS=',' read -r -a configured_databases <<< "$backup_databases"
    for database in "${configured_databases[@]}"; do
      database=$(trim "$database")
      if [ -z "$database" ]; then
        printf 'ERROR: backup_databases 中存在空的数据库名称。\n' >&2
        return 1
      fi
      database_filter_args+=(--filter "${database}.*")
    done
  fi

  if [ -n "$backup_retention_days" ]; then
    IFS=',' read -r -a configured_days <<< "$backup_retention_days"
    for day in "${configured_days[@]}"; do
      day=$(trim "$day")
      if ! [[ "$day" =~ ^[0-9]+$ ]]; then
        printf 'ERROR: backup_retention_days 中只能填写非负整数，当前值：%s\n' "$day" >&2
        return 1
      fi
    done
    if [ ! -x "$mc_bin" ]; then
      printf 'ERROR: mc 执行文件不存在或不可执行：%s\n' "$mc_bin" >&2
      return 1
    fi
  fi
}


# 判断今天是否在配置的备份周期中。
is_backup_day() {
  local today
  local day
  local -a configured_days=()

  if [ -z "$backup_period" ]; then
    return 0
  fi

  today=$(date +%w)
  IFS=',' read -r -a configured_days <<< "$backup_period"
  for day in "${configured_days[@]}"; do
    day=$(trim "$day")
    if [ "$today" = "$day" ]; then
      return 0
    fi
  done

  return 1
}


# 执行指定数据库的快照备份。
backup_snapshot() {
  local snapshot_id
  local storage
  local br_log
  local rc
  local -a cmd=()

  snapshot_id=$(date +%Y%m%d_%H%M%S)
  storage="s3://${s3_bucket_name}/${s3_prefix_path}/snapshot-${snapshot_id}?access-key=${s3_access_key}&secret-access-key=${s3_secret_access_key}"
  br_log="${log_dir}/backup_snapshot_${snapshot_id}.log"

  cmd=(
    "$br_bin" backup full
    --pd "$pd_path"
    --storage "$storage"
    --ratelimit "$backup_rate_limit"
    --s3.endpoint "$s3_server"
    --log-file "$br_log"
  )
  cmd+=("${database_filter_args[@]}")

  if [ -n "$backup_databases" ]; then
    log_file "开始快照备份，数据库：${backup_databases}，目标：s3://${s3_bucket_name}/${s3_prefix_path}/snapshot-${snapshot_id}"
  else
    log_file "开始快照备份全部数据库，目标：s3://${s3_bucket_name}/${s3_prefix_path}/snapshot-${snapshot_id}"
  fi
  if "${cmd[@]}"; then
    log_file "快照备份成功：snapshot-${snapshot_id}"
    return 0
  else
    rc=$?
    log_file "ERROR 快照备份失败，BR 退出码：${rc}，详情见：${br_log}"
    return "$rc"
  fi
}


# 初始化 mc 别名。该操作不会把访问密钥写入脚本日志。
init_mc() {

  if "$mc_bin" alias set "$mc_alias" "$s3_server" "$s3_access_key" "$s3_secret_access_key" --api S3v4 >/dev/null 2>&1; then
    return 0
  fi

  log_file "ERROR mc 别名初始化失败：${mc_alias}"
  return 1
}


# 按备份保留策略删除旧快照。backup_retention_days 为空时不做删除。
cleanup_old_snapshots() {
  local today
  local day
  local snapshot_prefix
  local snapshot_date
  local key
  local listing
  local -a retention_days=()
  local keep_dates=','
  declare -A seen_prefixes=()

  if [ -z "$backup_retention_days" ]; then
    log_file "未配置快照保留策略，跳过旧快照清理。"
    return 0
  fi

  today=$(date +%Y%m%d)
  keep_dates="${keep_dates}${today},"
  IFS=',' read -r -a retention_days <<< "$backup_retention_days"
  for day in "${retention_days[@]}"; do
    day=$(trim "$day")
    snapshot_date=$(date -d "${day} days ago" +%Y%m%d) || {
      log_file "ERROR 无法计算快照保留日期：${day}"
      return 1
    }
    keep_dates="${keep_dates}${snapshot_date},"
  done

  if ! init_mc; then
    return 1
  fi

  listing=$("$mc_bin" ls --json "${mc_alias}/${s3_bucket_name}/${s3_prefix_path}") || {
    log_file "ERROR 无法读取对象存储中的快照列表。"
    return 1
  }

  while IFS= read -r key; do
    [ -n "$key" ] || continue
    snapshot_prefix="${key%%/*}"
    if [[ ! "$snapshot_prefix" =~ ^snapshot-[0-9]{8}_[0-9]{6}$ ]]; then
      continue
    fi
    [ -n "${seen_prefixes[$snapshot_prefix]+x}" ] && continue
    seen_prefixes["$snapshot_prefix"]=1

    snapshot_date="${snapshot_prefix#snapshot-}"
    snapshot_date="${snapshot_date:0:8}"
    # 只删除今天以前、且不在保留日期中的快照；未来日期和今天的数据保留。
    if [[ "$snapshot_date" < "$today" && "$keep_dates" != *",${snapshot_date},"* ]]; then
      log_file "开始删除过期快照：${snapshot_prefix}"
      if "$mc_bin" rm --recursive --force "${mc_alias}/${s3_bucket_name}/${s3_prefix_path}/${snapshot_prefix}/" >/dev/null; then
        log_file "过期快照删除成功：${snapshot_prefix}"
      else
        log_file "ERROR 过期快照删除失败：${snapshot_prefix}"
        return 1
      fi
    else
      log_file "保留快照：${snapshot_prefix}"
    fi
  done < <(printf '%s\n' "$listing" | sed -n 's/.*"key"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
}


# 定时任务入口：按配置的星期执行快照，并清理旧快照。
task_backup() {
  local rc=0

  log_file "............快照备份任务开始............"

  if is_backup_day; then
    backup_snapshot || rc=$?
  else
    log_file "今天不在快照备份周期内，跳过备份。"
  fi

  cleanup_old_snapshots || rc=$?
  log_file "............快照备份任务结束............"
  return "$rc"
}


mkdir -p "$log_dir" || {
  printf 'ERROR: 无法创建日志目录：%s\n' "$log_dir" >&2
  exit 1
}

validate_config || exit 1

action=${1:-}
case "$action" in
  snapshot)
    # 手工立即执行一次快照，不检查 backup_period。
    backup_snapshot
    ;;
  task)
    task_backup
    ;;
  *)
    echo "用法: $0 {snapshot|task}"
    exit 1
    ;;
esac
