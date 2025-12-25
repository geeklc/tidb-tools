#!/bin/bash

# 安装包的二进制路径
LIGHTNING_BIN="/home/tidb/tidb-toolkit-v8.5.2-linux-amd64/bin/tidb-lightning"
CONFIG_PATH="/home/tidb/tidb-toolkit-v8.5.2-linux-amd64/conf/tidb_lightning_local.toml"


# 执行信息
nohup ${LIGHTNING_BIN} --config ${CONFIG_PATH} > nohup.out &