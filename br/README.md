br-backup.sh，支持log备份和快照备份，支持如下参数：

* logstart：仅开启日志备份

* logstatus：查看日志备份的状态
* snapshot：仅执行一次快照备份。
* task：任务备份，会自动判断是否开启日志备份，没有的话，会自动开启；根据配置的周期，定期快照备份；根据配置的保留天数，定时删除快照备份和日志备份数据。

即执行./br-backup.sh snapshot

br-restore.sh，支持备份数据的恢复。

