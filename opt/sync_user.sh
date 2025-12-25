#!/bin/bash

USER="root"
PORT=4000
HOST=127.0.0.1
PASS=123456


mysql_login="mysql -u${USER} -P${PORT} -h${HOST} -p${PASS}"

echo "-- 备份用户信息 " > ./cre_user$(date +"%m%d").sql
# 备份非 root 用户
${mysql_login} -NBe "SELECT concat('create user \"', user,'\"\@\"', host,'\" IDENTIFIED BY PASSWORD \"',authentication_string,'\";') from mysql.user WHERE user NOT IN ('sys','root')" >> ./cre_user$(date +"%m%d").sql
${mysql_login} -NBe "SELECT concat('alter user \"', user,'\"\@\"', host,'\" IDENTIFIED BY PASSWORD \"',authentication_string,'\";') from mysql.user WHERE user = 'root'" >> ./cre_user$(date +"%m%d").sql

echo "-- 资源管控信息 " >> ./cre_user$(date +"%m%d").sql
# 备份资源管控策略
${mysql_login} -NBe "SELECT concat('CREATE RESOURCE GROUP IF NOT EXISTS ',  NAME, case when RU_PER_SEC = 'UNLIMITED' then '' else concat(' RU_PER_SEC =', RU_PER_SEC) end, ' PRIORITY = ', PRIORITY, case when BURSTABLE = 'YES' then ' BURSTABLE' else '' end) as sql_1 FROM INFORMATION_SCHEMA.RESOURCE_GROUPS where NAME not in ('default')" >> ./cre_user$(date +"%m%d").sql

echo "-- 备份用户的权限信息 " >> ./cre_user$(date +"%m%d").sql
# 备份这些用户的权限
#USERS=$(${mysql_login} -NBe "SELECT concat('\"',user,'\"\@\"', host,'\"') from mysql.user WHERE user NOT IN (${SYS_USER})")
USERS=$(${mysql_login} -NBe "SELECT concat('\"',user,'\"\@\"', host,'\"') from mysql.user")
for USER in $USERS
do
  ${mysql_login} -NBe "show grants for ${USER}" >> ./cre_user$(date +"%m%d").sql
done

echo "-- 备份用户的资源管控信息" >> ./cre_user$(date +"%m%d").sql
ATTRIBUTES=$(${mysql_login} -NBe " SELECT concat('\'', user, '\'', '@', '\'', host, '\'') AS user_1, USER_ATTRIBUTES FROM mysql.user WHERE USER_ATTRIBUTES IS NOT NULL;")
echo "$ATTRIBUTES" | while read user json; do
    rg=$(echo "$json" | jq -r '.resource_group')
    echo "ALTER USER $user RESOURCE GROUP \`$rg\`;"  >> ./cre_user$(date +"%m%d").sql
done

sed -i 's#^G$#&;#g' ./cre_user$(date +"%m%d").sql

sed -i '/^GRANT/s/$/;/' ./cre_user$(date +"%m%d").sql

sed -i 's/"/'"'"'/g' ./cre_user$(date +"%m%d").sql
