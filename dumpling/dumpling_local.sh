#!/bin/bash

dateT=`date +%Y%m%d`
#minio的bucket
#日志保存地址 不需要/结尾
logPath=/home/tidb/backup
#br执行文件的地址
dumplingPath=/home/tidb/tidb-toolkit-v5.4.2-linux-amd64/bin/
#备份存储的路径
backupPath="/data1/backup/"
#连接数据库的host
host="10.247.4.97"
#连接数据库的端口
port=3306
#用户名称
userName=root
#连接密码
passwd=


${dumplingPath}/dumpling \
  -u ${userName}  \
  -P ${port}  \
  -h ${host} \
  -p ${passwd} \
  -r 200000 \
  -o ${backupPath}${dateT} \
  -F 256MiB \
  -t 4 \
  -f 'test.*' \
  -f 'test1.*' \
  -L ${logPath}/backup.log
  
  
cd ${backupPath} && tar -zcvf ${dateT}.tar.gz ${dateT} && rm -rf ${dateT}
  
