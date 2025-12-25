#!/bin/bash


#指定磁盘
disk=/dev/vdc
#指定挂载目录
path=/data1



#1、挂载指定磁盘到指定目录
#创建磁盘分区
parted -s -a optimal ${disk} mklabel gpt -- mkpart primary ext4 1 -1

disk1=${disk}1
#格式化磁盘
mkfs.ext4 ${disk1}

#获取磁盘的UUID
uuid=$( blkid | grep ${disk1} | awk '{print $2}' | cut -d'"' -f2 )

#编辑磁盘信息
cat >> /etc/fstab <<EOF
UUID=${uuid} ${path} ext4 defaults,nodelalloc,noatime 0 2
EOF
#创建目录挂载磁盘
mkdir ${path} && mount -a
#验证是否挂载成功
if [ `mount -t ext4 |grep nodelalloc | grep ext4 | grep ${path} | grep ${disk1} | wc -l` -gt 0 ] ; then
	echo "挂载磁盘成功"
else
	echo "挂载磁盘失败 失败"
fi