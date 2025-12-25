#!/bin/bash 


#该脚本为部分分析所用的脚本，杜绝生产环境使用。

tidbHost="192.168.0.101"
tidbPort=4000 
tidbUser="root" 
tidbPassword="123456"
# 日志备份路径
log_path=/data

echo "$(date +"%Y-%m-%d %H:%M:%S.%3N") | 开始备份" > ${log_path}/analyzetable.log

# 需要修改指定的库
mysql -h$tidbHost -P$tidbPort -u"$tidbUser" -p"$tidbPassword" -s -e "SHOW STATS_HEALTHY where db_name in ('test', 'test1') and healthy< 80" > ${log_path}/tablelist.txt

echo "$(date +"%Y-%m-%d %H:%M:%S.%3N") | 开始收集数据到集群" > ${log_path}/analyzetable.log

cat ${log_path}/tablelist.txt | while read line

do
  OLD_IFS="$IFS"
  IFS="$IFS" 
  arr=($line)
  IFS="$OLD_IFS"
  #echo "${arr[0]}.${arr[1]}"
  tableName=${arr[1]}
  dbname=${arr[0]}
  mysql -h$tidbHost -P"$tidbPort" -u"$tidbUser" -p"$tidbPassword" -D"${dbname}" -e "set @@session.tidb_index_serial_scan_concurrency=2;set @@session.tidb_build_stats_concurrency=10;analyze table \`$tableName\`"
  echo "$(date +"%Y-%m-%d %H:%M:%S.%3N") | ${dbname}.${tableName} analyze done" >> ${log_path}/analyzetable.log
done 


echo "$(date +"%Y-%m-%d %H:%M:%S.%3N") all finished" >> ${log_path}/analyzetable.log
