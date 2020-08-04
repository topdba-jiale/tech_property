#!/bin/sh 
set -u

#需要根据实际情况，调整数据库用户名，密码，本地主机IP，远程主机IP
DB_USER="backup" 
DB_PASS="Backup@qunje"
hostip="192.168.2.220"
remote_backup_server="192.168.2.221"

#检测存活MySQL端口
#port=3306
ports=`netstat -ntpl |grep mysqld |awk '{print $4}' |awk -F":" '{print $(NF)}'`

#定义备份日志
backuplog="/backup/backup.log"
mysql=$(which mysql)

for port in $ports ;do
mycmd="$mysql -u$DB_USER -p$DB_PASS -P$port -h$hostip"
DB_NAME=`$mycmd -e "show databases;" |sed '1,2d' |egrep -v "mysql|schema|test|sys"|awk BEGIN{RS=EOF}'{gsub(/\n/," ");print}'`

DATE_NAME=`date +%Y%m%d.%H%M%S`
DAY_NAME=`date +%Y%m%d`

#创建备份目录和文件夹
if [ ! -d "/backup/${DAY_NAME}" ]; then
  mkdir -p /backup/${DAY_NAME}/
fi


BIN_DIR="/usr/local/mysql/bin" 

#保留最近60天备份文件
DEL_UNTIL_DATE=`date --date='60 day ago' +%Y.%m%d`
/bin/rm -rf /backup/${DEL_UNTIL_DATE}

#判断最近五分钟负载
last5_load=`sar -q |tail -1 |awk '{print $4}'`
#判断当前负载
attime_load=`uptime |awk '{print $(NF-2)}'|sed 's/\,//g'`

#如果当前负载高于五分钟前1.5倍，暂停十秒。
if [ $(echo "${attime_load} >= 1.5 * ${last5_load}"|bc) = 1 ]; then 
	sleep 10
else 
	echo "load is OK "
fi
BEGINTIME=`date +"%Y-%m-%d %H:%M:%S"`
# 备份开始时间，写入日志。
echo "backup start at $(date +[%Y/%m/%d/%H:%M:%S])" >>$backuplog

#备份数据库
$BIN_DIR/mysqldump --default-character-set=utf8 --opt -u$DB_USER -p$DB_PASS -h$hostip -P$port --master-data=2 --single-transaction --triggers --routines --events --opt --databases $DB_NAME >/backup/${DAY_NAME}/${hostip}_${port}_${DATE_NAME}.sql 
if [ "$?" -eq "0" ] ;then 
	ENDTIME=`date +"%Y-%m-%d %H:%M:%S"`
	begin_date=`date -d "$BEGINTIME" +%s`
	end_date=`date -d "$ENDTIME" +%s`
	spendtime=`expr $end_date - $begin_date`
	
	if [ $spendtime -le 300 ];then
		echo "$hostip:$port [successful completion backup] at:$(date +[%Y/%m/%d/%H:%M:%S]),total cost:$spendtime seconds" >> $backuplog
        #传输备份完成的文件至远程服务器，前提远程服务器存在/backup 目录
		scp -r /backup/${DAY_NAME}/${hostip}_${port}_${DAY_NAME}.*.sql root@${remote_backup_server}:/backup
		 
	else 
		#成功完成备份，但是耗时在300秒以上。
		echo "$hostip:$port [successful completion backup] at:$(date +[%Y/%m/%d/%H:%M:%S]),But total cost:$spendtime seconds. you must check the instance in conntrol" >> $backuplog
		
	fi

else 
	#备份失败，写入日志。
	echo "$hostip:$port [failed backup] at $(date +[%Y/%m/%d/%H:%M:%S])" >> $backuplog

fi

done 
