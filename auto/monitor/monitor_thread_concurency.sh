#!/bin/bash
user=root
socket=/data/mysqldata/mysql3333/sock/mysql.sock
cmd="mysql -u$user -S $socket"
DATABASE="monitor"
TABLE='thread_concurrency'
HOSTNAME=`$cmd -e "show variables like '%hostname%';" |grep -w hostname |awk '{print $2}'`

function confirm_db_table(){
$cmd << EOF 2>/dev/null
CREATE DATABASE $DATABASE DEFAULT CHARACTER SET utf8mb4;
EOF
[ $? -eq 0 ] && echo "created schema:monitor" || echo "schema:monitor already exists"

$cmd -D $DATABASE<< EOF 2>/dev/null
CREATE TABLE $TABLE (
id bigint not null auto_increment primary key,
host varchar(50) not null,
thread_running int,
monitor_time timestamp
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
EOF
[ $? -eq 0 ] && echo "Created table monitor_load successful" || echo "Table:thread_concurrency already exist" >/dev/null 
}


function monitor_thread_running(){
int=1;
while(( $int<=60 ));
do
    MONITOR_TIME=`$cmd -e "select now();"|tail -1` 
    THREADS_RUNNING=`$cmd -e "show status like 'Threads_running';" |grep -w Threads_running |awk '{print $2}'`
$cmd -D$DATABASE -e "INSERT INTO $TABLE (host,thread_running,monitor_time) VALUES ('${HOSTNAME}','${THREADS_RUNNING}','${MONITOR_TIME}');"
    let "int++";
    # monitor interval
    sleep 1;
done
}

confirm_db_table
monitor_thread_running



root@localhost:monitor 5.7.27-log 10:29:25> select * from thread_concurrency ;
+----+-------------------------+----------------+---------------------+
| id | host | thread_running | monitor_time |
+----+-------------------------+----------------+---------------------+
| 1 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:30 |
| 2 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:31 |
| 3 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:32 |
| 4 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:33 |
| 5 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:34 |
| 6 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:35 |
| 7 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:36 |
| 8 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:37 |
| 9 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:38 |
| 10 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:39 |
| 11 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:40 |
| 12 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:41 |
| 13 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:42 |
| 14 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:43 |
| 15 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:44 |
| 16 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:45 |
| 17 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:46 |
| 18 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:47 |
| 19 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:48 |
| 20 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:49 |
| 21 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:50 |
| 22 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:51 |
| 23 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:52 |
| 24 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:53 |
| 25 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:54 |
| 26 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:55 |
| 27 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:57 |
| 28 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:58 |
| 29 | dba-virtual-host-220122 | 2 | 2019-11-01 10:29:59 |
| 30 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:00 |
| 31 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:01 |
| 32 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:02 |
| 33 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:03 |
| 34 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:04 |
| 35 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:05 |
| 36 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:06 |
| 37 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:07 |
| 38 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:08 |
| 39 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:09 |
| 40 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:10 |
| 41 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:11 |
| 42 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:12 |
| 43 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:13 |
| 44 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:14 |
| 45 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:15 |
| 46 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:16 |
| 47 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:17 |
| 48 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:18 |
| 49 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:19 |
| 50 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:20 |
| 51 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:21 |
| 52 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:22 |
| 53 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:23 |
| 54 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:24 |
| 55 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:25 |
| 56 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:26 |
| 57 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:27 |
| 58 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:28 |
| 59 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:29 |
| 60 | dba-virtual-host-220122 | 2 | 2019-11-01 10:30:30 |
+----+-------------------------+----------------+---------------------+
60 rows in set (0.00 sec)
