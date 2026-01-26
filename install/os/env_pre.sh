#!/bin/bash


#指定磁盘
disk=/dev/vdc
#指定挂载目录
path=/data1
#指定tidb用户密码
tidbpass=tidb


#1、挂载指定磁盘到指定目录
#创建磁盘分区
parted -s -a optimal ${disk} mklabel gpt -- mkpart primary ext4 1 -1

sleep 1

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


#2、修改I/O调度器
#2.1、定义磁盘
diskname=${disk#*/dev/}
#2.2、修改该磁盘的I/O调度器
echo noop > /sys/block/${diskname}/queue/scheduler



#3、 创建tidb用户
#3.1、以root用户依次登录到部署目标机器创建tidb用户并设置登录密码
useradd tidb
echo $tidbpass | sudo passwd tidb --stdin  &>/dev/null
#3.2、执行以下命令，将tidbALL=(ALL)NOPASSWD:ALL添加到文件末尾，即配置好sudo免密码
sed -i "/^tidb/d" /etc/sudoers
echo "tidb ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers


#4、关闭防火墙
systemctl stop firewalld.service
systemctl disable firewalld.service


#5、检测及安装ntp服务
#yum install ntp ntpdate && \
#systemctl start ntpd.service && \
#systemctl enable ntpd.service && \
#ntpdate pool.ntp.org

#6、关闭swap
#6.1、替换参数
sed -i '/^vm.swappiness/d' /etc/sysctl.conf
#6.2、关闭swap
echo "vm.swappiness=0">> /etc/sysctl.conf
swapoff -a && swapon -a
swapoff -a


#7、关闭透明大项
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag


#8、设置系统参数
#8.1、删除原有的参数
sed -i '/^fs.file-max/d' /etc/sysctl.conf
sed -i '/^net.core.somaxconn/d' /etc/sysctl.conf
sed -i '/^net.ipv4.tcp_tw_recycle/d' /etc/sysctl.conf
sed -i '/^net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
sed -i '/^vm.overcommit_memory/d' /etc/sysctl.conf
#8.2、设置系统参数
echo "fs.file-max=1000000">> /etc/sysctl.conf
echo "net.core.somaxconn=32768">> /etc/sysctl.conf
echo "net.ipv4.tcp_tw_recycle=0">> /etc/sysctl.conf
echo "net.ipv4.tcp_syncookies=0">> /etc/sysctl.conf
echo "vm.overcommit_memory=1">> /etc/sysctl.conf
sysctl -p

#9、配置用户的limit.conf 参数
#9.1、删除原有的参数
sed -i '/^tidb/d' /etc/security/limits.conf

#9.2、设置limits
cat << EOF >>/etc/security/limits.conf
tidb  soft  nofile  1000000
tidb  hard  nofile  1000000
tidb  soft  stack   32768
tidb  hard  stack   32768
EOF

#10、安装numactl 工具
yum -y install numactl
