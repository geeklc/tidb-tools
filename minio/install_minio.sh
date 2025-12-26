#!/bin/bash
set -e

# ================== 可配置参数 ==================
# 控制台访问账号
MINIO_USER="minioadmin"
# 控制台访问密码（至少8位）
MINIO_PASSWORD="Minio@123456"
# 指定的数据目录
MINIO_DATA_DIR="/data/minio"
# 安装包的二进制路径
MINIO_BIN="/data/soft/minio/minio_x86"
# minio service的名称
MINIO_SERVICE="minio"
# 指定api的端口
MINIO_PORT="9000"
# 指定控制台的端口
MINIO_CONSOLE_PORT="9001"
# =================================================

echo ">>> 开始安装 MinIO..."

# 1. 创建数据目录
mkdir -p ${MINIO_DATA_DIR}
chmod 755 ${MINIO_DATA_DIR}

# 2. 下载 MinIO
if [ ! -f "${MINIO_BIN}" ]; then
  echo ">>> 无效的minio安装包路径..."
  return 0
else
  echo ">>> MinIO 已存在，跳过下载"
fi

# 3. 创建 minio 用户（如不存在）
if ! id minio &>/dev/null; then
  echo ">>> 创建 minio 系统用户"
  useradd -r minio -s /sbin/nologin
fi

chown -R minio:minio ${MINIO_DATA_DIR}
chown -R minio:minio ${MINIO_BIN}
chmod +x ${MINIO_BIN}

# 4. 创建环境变量配置文件
cat > /etc/default/minio <<EOF
MINIO_ROOT_USER=${MINIO_USER}
MINIO_ROOT_PASSWORD=${MINIO_PASSWORD}
MINIO_VOLUMES="${MINIO_DATA_DIR}"
MINIO_OPTS="--address :${MINIO_PORT} --console-address :${MINIO_CONSOLE_PORT}"
EOF

chmod 600 /etc/default/minio

# 5. 创建 systemd 服务文件
cat > /etc/systemd/system/${MINIO_SERVICE}.service <<EOF
[Unit]
Description=MinIO
Documentation=https://min.io/docs/
After=network-online.target
Wants=network-online.target

[Service]
User=minio
Group=minio
EnvironmentFile=/etc/default/minio
ExecStart=${MINIO_BIN} server \$MINIO_VOLUMES \$MINIO_OPTS
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# 6. 启动服务
systemctl daemon-reload
systemctl enable ${MINIO_SERVICE}
systemctl restart ${MINIO_SERVICE}

echo ">>> MinIO 安装完成"
echo "------------------------------------------"
echo "API 地址:      http://<服务器IP>:${MINIO_PORT}"
echo "Console 地址:  http://<服务器IP>:${MINIO_CONSOLE_PORT}"
echo "用户名:        ${MINIO_USER}"
echo "密码:          ${MINIO_PASSWORD}"
echo "------------------------------------------"
