#!/bin/bash
set -e

######################################
# 可修改参数
######################################
ISO_PATH="/root/CentOS-7-x86_64-DVD.iso"
MOUNT_DIR="/mnt/localrepo"
REPO_FILE="/etc/yum.repos.d/local.repo"

######################################
# 检查
######################################
if [ ! -f "$ISO_PATH" ]; then
  echo "❌ ISO 文件不存在: $ISO_PATH"
  exit 1
fi

######################################
# 创建挂载目录
######################################
mkdir -p "$MOUNT_DIR"

######################################
# 挂载 ISO（如果未挂载）
######################################
if ! mountpoint -q "$MOUNT_DIR"; then
  echo "🔧 挂载 ISO..."
  mount -o loop "$ISO_PATH" "$MOUNT_DIR"
else
  echo "✅ ISO 已挂载"
fi

######################################
# 写入 /etc/fstab（避免重复）
######################################
if ! grep -q "$ISO_PATH" /etc/fstab; then
  echo "📝 写入 /etc/fstab"
  echo "$ISO_PATH  $MOUNT_DIR  iso9660  loop,ro  0 0" >> /etc/fstab
else
  echo "✅ /etc/fstab 已存在挂载配置"
fi

######################################
# 备份原 yum repo
######################################
if [ ! -d /etc/yum.repos.d/bak ]; then
  echo "📦 备份原 yum repo"
  mkdir -p /etc/yum.repos.d/bak
  mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak/ 2>/dev/null || true
fi

######################################
# 创建本地 repo
######################################
echo "📝 创建本地 yum repo"

cat > "$REPO_FILE" <<EOF
[local]
name=Local ISO Repository
baseurl=file://$MOUNT_DIR
enabled=1
gpgcheck=0
EOF

######################################
# 刷新缓存
######################################
echo "🔄 刷新 yum 缓存"
if command -v dnf >/dev/null 2>&1; then
  dnf clean all
  dnf makecache
else
  yum clean all
  yum makecache
fi

######################################
# 验证
######################################
echo "✅ 本地 yum 源配置完成"
