#!/bin/bash

user="root"
password="Gepoint"
logfile="/root/innodb_lock_monitor.log"

while true
do
        num=`mysql -u${user} -p${password} -e "select count(*) from information_schema.innodb_lock_waits" |grep -v count`
        if [[ $num -gt 0 ]];then
            date  >> /root/innodb_lock_monitor.log
            mysql -u${user} -p${password} -e  "SELECT r.trx_mysql_thread_id waiting_thread,r.trx_query waiting_query, \
concat(timestampdiff(SECOND,r.trx_wait_started,CURRENT_TIMESTAMP()),'s') AS duration,\
b.trx_mysql_thread_id blocking_thread,t.processlist_command state,b.trx_query blocking_query,e.sql_text \
FROM information_schema.innodb_lock_waits w \
JOIN information_schema.innodb_trx b ON b.trx_id = w.blocking_trx_id \
JOIN information_schema.innodb_trx r ON r.trx_id = w.requesting_trx_id \
JOIN performance_schema.threads t on t.processlist_id = b.trx_mysql_thread_id \
JOIN performance_schema.events_statements_current e USING(thread_id) \G " >> ${logfile}
        fi
        sleep 5
done


--使用 nohup 命令后台运行监控脚本
[root@192-168-188-155 ~]# nohup sh innodb_lock_monitor.sh  &
[2] 31464
nohup: ignoring input and appending output to ‘nohup.out’

--查看 nohup.out 是否出现报错
[root@192-168-188-155 ~]# tail -f nohup.out
mysql: [Warning] Using a password on the command line interface can be insecure.
mysql: [Warning] Using a password on the command line interface can be insecure.
mysql: [Warning] Using a password on the command line interface can be insecure.

--定时查看监控日志是否有输出
[root@192-168-188-155 ~]# tail -f innodb_lock_monitor.log
Wed Feb  5 11:30:11 CST 2020
*************************** 1. row ***************************
 waiting_thread: 112
  waiting_query: delete from emp where id < 10
       duration: 3s
blocking_thread: 111
          state: Sleep
 blocking_query: NULL
       sql_text: select * from emp where id in (select id from emp)