#!/bin/sh 
set -u
alert(){
if command -v jq >/dev/null 2>&1; then 
	echo 'exists jq' >/dev/null
else 
	wget http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
	rpm -ivh epel-release-latest-7.noarch.rpm >/dev/null
	yum repolist >/dev/null
	yum -y install jq >/dev/null
fi
user="ZhangJiaLe ChenZhen AHeA "
corpid="ww39c8b8269670be92"
corpsecret="NBTAJKbqXkYeFXJn7BB2qORJZdmMixobLLT0kU0UlcM"
agentld=1000002

msg=$*
A=`curl -s https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid=$corpid\&corpsecret=$corpsecret`

token=`echo $A | jq -c '.access_token'`
token=${token#*\"}
token=${token%*\"}

URL="https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=$token"

for u in $user;do
        JSON="{\"touser\": \"$u\",\"msgtype\": \"text\",\"agentid\": \"$agentld\",\"text\": {\"content\": \"$msg\"},\"safe\":0 }"
        curl -d "$JSON" "$URL"
done

exit 0

}

DB_USER="backup" 
DB_PASS="Backup@qunje"
hostip="192.168.2.220"
remote_backup_server="192.168.2.221"
ports=`netstat -ntpl |grep mysqld |awk '{print $4}' |awk -F":" '{print $(NF)}'`
#ports="3306"
backuplog="/backup/backup.log"
mysql=$(which mysql)
for port in $ports ;do
mycmd="$mysql -u$DB_USER -p$DB_PASS -P$port -h$hostip"
DB_NAME=`$mycmd -e "show databases;" |sed '1,2d' |egrep -v "mysql|schema|test|sys"|awk BEGIN{RS=EOF}'{gsub(/\n/," ");print}'`

DATE_NAME=`date +%Y%m%d.%H%M%S`
DAY_NAME=`date +%Y%m%d`
if [ ! -d "/backup/${DAY_NAME}" ]; then
  mkdir -p /backup/${DAY_NAME}/
fi


BIN_DIR="/usr/local/mysql/bin" 

DEL_UNTIL_DATE=`date --date='5 day ago' +%Y.%m%d`
/bin/rm -rf /backup/${DEL_UNTIL_DATE}


last5_load=`sar -q |tail -1 |awk '{print $4}'`
attime_load=`uptime |awk '{print $(NF-2)}'|sed 's/\,//g'`
if [ $(echo "${attime_load} >= 1.5 * ${last5_load}"|bc) = 1 ]; then 
	sleep 10
else 
	echo "load is OK "
fi
BEGINTIME=`date +"%Y-%m-%d %H:%M:%S"`
echo "backup start at $(date +[%Y/%m/%d/%H:%M:%S])" >>$backuplog
$BIN_DIR/mysqldump --default-character-set=utf8 --opt -u$DB_USER -p$DB_PASS -h$hostip -P$port --master-data=2 --single-transaction --triggers --routines --events --opt --databases $DB_NAME >/backup/${DAY_NAME}/${hostip}_${port}_${DATE_NAME}.sql 
if [ "$?" -eq "0" ] ;then 
	ENDTIME=`date +"%Y-%m-%d %H:%M:%S"`
	begin_date=`date -d "$BEGINTIME" +%s`
	end_date=`date -d "$ENDTIME" +%s`
	spendtime=`expr $end_date - $begin_date`
	
	if [ $spendtime -le 300 ];then
		echo "$hostip:$port [successful completion backup] at:$(date +[%Y/%m/%d/%H:%M:%S]),total cost:$spendtime seconds" >> $backuplog

		scp -r /backup/${DAY_NAME}/${hostip}_${port}_${DAY_NAME}.*.sql root@${remote_backup_server}:/backup
		 
	else 
		echo "$hostip:$port [successful completion backup] at:$(date +[%Y/%m/%d/%H:%M:%S]),But total cost:$spendtime seconds. you must check the instance in conntrol" >> $backuplog
		backup_alert_msg="$hostip:$port [successful completion backup] at:$(date +[%Y/%m/%d/%H:%M:%S]),But total cost:$spendtime seconds. you must check the instance in conntrol"
		alert $backup_alert_msg  >> $backuplog
	fi

else 
	backup_failed_msg="$hostip:$port [failed backup] at $(date +[%Y/%m/%d/%H:%M:%S])" 
	alert $backup_failed_msg  >> $backuplog

fi

done 