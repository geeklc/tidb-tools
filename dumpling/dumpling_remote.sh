#!/bin/bash

export AWS_ACCESS_KEY_ID=nXl4EgFuVYk5jZjq
export AWS_SECRET_ACCESS_KEY=A1aeZwuynRX47TSe31d9SFlHq6H0d89J

#minio的bucket
minioBucket="test"
#日志保存地址 不需要/结尾
logPath=/home/tidb
#minio的路径名称
folder=20220808
#br执行文件的地址
dumplingPath=/home/tidb/tidb-toolkit-v5.4.2-linux-amd64/bin/
#minio服务器地址http://ip:port
minioServer="http://192.168.0.1:9000"
#连接数据库的host
host="192.168.0.101"
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
  -o "s3://${minioBucket}/${folder}" \
  --s3.endpoint ${minioServer} \
  -F 256MiB \
  -t 8 \
  -f test.* \
  -L backup.log
  
  
