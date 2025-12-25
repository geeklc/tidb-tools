#!/bin/bash

#指定minio或s3的相关key和秘钥
export AWS_ACCESS_KEY_ID=nXl4EgFuVYk5jZjq
export AWS_SECRET_ACCESS_KEY=A1aeZwuynRX47TSe31d9SFlHq6H0d89J

# 安装包的二进制路径
LIGHTNING_BIN="/home/tidb/tidb-toolkit-v8.5.2-linux-amd64/bin/tidb-lightning"
CONFIG_PATH="/home/tidb/tidb-toolkit-v8.5.2-linux-amd64/conf/tidb_lightning_remote.toml"


# 执行信息
nohup ${LIGHTNING_BIN} --config ${CONFIG_PATH} > nohup.out &