
一、在新盘上创建LVM,挂载到临时目录

# 新盘初始化为物理卷
pvcreate /dev/sdd

# 创建卷组
vgcreate vg_tikv /dev/sdd

# 创建普通逻辑卷，使用该卷组当前全部可用空间
lvcreate -n lv_data -l 100%FREE vg_tikv

# 仅格式化新建的逻辑卷
mkfs.ext4 /dev/vg_tikv/lv_data

# 临时挂载，供迁移使用
mkdir -p /data2
mount /dev/vg_tikv/lv_data /data2

df -hT /data2


二、停止tidb
tiup cluster display
tiup cluster stop <cluster_name> --node


三、迁移原数据盘的数据到新路径。
# 复制数据到/data2
cp -a -x /data1/. /data2/
# 紧接着检查复制退出码：0 表示成功
echo $?

# 将缓存中的写入刷到磁盘
sync


四、把逻辑卷目录挂载到原来的/data1下
cd /

# 卸载新卷的临时挂载
umount /data2

# 卸载旧盘
umount /data1

# 将新逻辑卷挂载到原路径
mount /dev/vg_tikv/lv_data /data1

findmnt -T /data1
df -hT /data1


五、配置开机挂载

# 查看逻辑卷的UUID
blkid /dev/vg_tikv/lv_data

# 备份 /etc/fstab，把原来 /data 对应的旧盘条目替换为新文件系统 UUID
UUID=<新文件系统的UUID>  /data1  ext4 defaults,nodelalloc,noatime 0 2


六、启动tikv
tiup cluster display
tiup cluster start <cluster_name> --node



七、把原来旧目录挂载到逻辑卷中

# 清除掉之前旧目录的数据，如果是新的磁盘就不需要该步骤
fdisk /dev/sdb
wipefs --all --backup /dev/sdb


# 把该目录创建物理卷
pvcreate /dev/sdb

vgextend vg_tikv /dev/sdb
lvextend -l +100%FREE /dev/vg_tikv/lv_data
resize2fs /dev/vg_tikv/lv_data
