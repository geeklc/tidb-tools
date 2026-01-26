# 一、项目介绍

该代码工程是一个tidb工具类的工程，里面汇总了各种工具的脚本和配置文件，包括br的备份和恢复脚本，dm的部署拓扑，dumpling的本地和s3备份的脚本，数据库安装中磁盘挂载、系统参数优化和不同场景的部署拓扑文件，lightning的配置文件和启动脚本（包含从本地或从s3同步），minio的安装脚本，mysql-client的rpm安装包和包括运维中使用的手工收集统计信息和导出数据库用户等脚本。上述都整理成了可执行脚本的方式，和现成的配置文件，可以拿来即用，所有的工具都上传到git上：https://github.com/geeklc/tidb-tools，也欢迎志同道合的同学和我一块维护，可以发邮件联系：df_lichong@163.com

# 二、目录介绍：

## 1.br目录


br-backup.sh，支持log备份和快照备份，支持如下参数：

* logstart：仅开启日志备份
* logstatus：查看日志备份的状态
* snapshot：仅执行一次快照备份。
* task：任务备份，会自动判断是否开启日志备份，没有的话，会自动开启；根据配置的周期，定期快照备份；根据配置的保留天数，定时删除快照备份和日志备份数据。

即执行./br-backup.sh snapshot

br-restore.sh，支持备份数据的恢复。

## 2.dm目录

该目录下暂时上传了一个dm部署的拓扑文件。

## 3. install目录

1. os: 目录下存在2个脚本，一个是磁盘挂载的脚本mountDisk.sh，另一个是对创建tidb用户，对操作系统的参数做相关的优化。
2. topy：该目录下保存了常用部署模式下的不同拓扑文件配置。

**topy配置介绍**

1. topo-sigle.yaml：该系统配置文件主要是针对在一个服务器上快速搭建一个测试环境的配置信息，该文件只配置了一个副本。
2. topoly-prod.yaml: 该配置文件为正式环境多个集群节点进行搭建的配置信息，其中包括3个pd、3个tidb、6个tikv和2tiproxy绑定一个vip.
3. topoly-prod-big-row.yaml: 该配置文件和topoly-prod.yaml的节点数一样，只是该节点增加了几个参数用来针对大单行大数据的配置，比如使用blob类型存储了大的文件内容等，这里也是设置了一个固定的值，如有需要根据实际环境设置。
4. topoly-prod-mach.yaml：该配置文件是针对3个物理机进行混合部署组件的配置。这里是每个物理机分别挂载了2个磁盘，每个组件合理的分配磁盘和对应numa. 注意numa绑核的内存要大于设置的内存，这里包括tikv、tidb节点。

## 4. lightning目录

1. lightning_local.sh：指定tidb-lightning恢复本地的数据到tidb中，调用tidb_lightning_local.toml配置文件。
2. lightning_remote.sh：指定tidb-lightning恢复本地的数据到tidb中，调用tidb_lightning_remote.toml配置文件。

## 5. minio目录

这里本来想维护minio的安装包和mc客户端工具，但是包太大，这里分享百度网盘的下载地址：
链接: https://pan.baidu.com/s/1A636wvyyWw3faGJDbfda5Q 提取码: xr85

## 6. mysql-client目录

这里维护了linux中离线安装mysql client所用的所有rpm安装文件，把压缩包copy到服务器上，执行rpm -ivh --replacefiles --replacepkgs *.rpm即可安装成功。

## 7. opt目录

analyzeTable.sh：手动收集表统计信息的脚本。
sync_user.sh：导出数据库中用户信息、资源管控的语句




