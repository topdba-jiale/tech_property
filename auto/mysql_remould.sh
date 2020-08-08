#!/bin/bash
#auth by zhangjiale

set -o nounset
set -o errexit

shell_path=$(cd "$(dirname "$0")";pwd)
backup_date=`date +%Y%m%d`
log="$shell_path/mysql_remould.log"
format_time=`date +"%Y-%m-%d_%H:%M:%S"`
starttime=`date +"%Y-%m-%d %H:%M:%S"`

if [ $# -ne 4 ] || [ $1 == "-h" -o $1 == "--help" ];then
    echo -e "Usage: sh $0 {mysql_user mysql_password mysql_port dbname} \n"
    echo -e "Example: sh $0 root 123456 3306 qjweb"
    exit -1
fi

# 判断数据库mysql版本是不是大于5.5，否则无法使用参数关闭 --set-gtid-purged=OFF 
m_version=`mysqldump --version |awk '{print $5}' |awk -F'-' '{print $1}' |awk '{print $1+$2}'`
if [ $(echo "$m_version > 5.5" | bc) = 1 ];then
	echo "mysql or mysqldump available" >$log
else
	echo "mysql or mysqldump unavailable" >$log
	exit -1
fi


gtid_mode=$(mysql -u$1 -p$2 -h127.0.0.1 -P$3 -B -N -e "show variables like 'gtid_mode';" |awk '{print $2}')


# 备份改造前（老）数据库
if command -v mysqlpump >/dev/null 2>&1; then 
	if [[ $gtid_mode == "ON" ]];then
		if [[ $(mysqlpump  --version  |awk '{print $5}'  |awk -F '.' '{print $3}' |sed 's/\,//g') -ge 11 ]] ;then
			mysqlpump -u$1 -p$2 -h127.0.0.1 -P$3 --events --triggers --complete-insert --add-drop-table --single-transaction --set-gtid-purged=OFF  --skip-definer -B $4 --parallel-schemas=2:$4 > $shell_path/backup_$4_pump_$backup_date.sql
		else
			mysqlpump -u$1 -p$2 -h127.0.0.1 -P$3 --events --triggers --complete-insert --add-drop-table --single-transaction --set-gtid-purged=OFF  --skip-definer -B $4 --default-parallelism=0 > $shell_path/backup_$4_pump_$backup_date.sql
		fi
	else
		mysqlpump -u$1 -p$2 -h127.0.0.1 -P$3 --events --triggers --complete-insert --add-drop-table --single-transaction --skip-definer -B $4 --default-parallelism=0 > $shell_path/backup_$4_pump_$backup_date.sql
	fi

	if [ $? -ne 0 ];then
		echo "mysqlpump olddata error" >>$log
		exit -1
	fi

else
	if [[ $gtid_mode == "ON" ]];then
		mysqldump -u$1 -p$2 -h127.0.0.1 -P$3 --events --triggers --complete-insert --add-drop-table --single-transaction --set-gtid-purged=OFF  -B $4 > $shell_path/backup_$4_dump_$backup_date.sql
	else
		mysqldump -u$1 -p$2 -h127.0.0.1 -P$3 --events --triggers --complete-insert --add-drop-table --single-transaction  -B $4 > $shell_path/backup_$4_dump_$backup_date.sql
	fi

	if [ $? -ne 0 ];then
		echo "mysqldump olddata error" >>$log
		exit -1
	fi
fi


if [ $? -eq 0 ];then
	echo -e "backup schema:$4 successfully" >>$log
else 
	echo -e "backup schema:$4 failed" >>$log
	exit -1
fi

# 导出老库数据。使用完整插入字段方式，没有建表语句. 不加--databases 即不会有create database语句。
if [[ $gtid_mode == "ON" ]];then
	mysqldump -u$1 -p$2 -h127.0.0.1 -P$3 -E -R --triggers -c -t --single-transaction --set-gtid-purged=OFF --insert-ignore --default-character-set=utf8 $4 >$shell_path/dump_olddata_$4_$backup_date.sql
else
	mysqldump -u$1 -p$2 -h127.0.0.1 -P$3 -E -R --triggers -c -t --single-transaction  --insert-ignore --default-character-set=utf8 $4 >$shell_path/dump_olddata_$4_$backup_date.sql
fi

# 删除老库，并新建库名
mysql -u$1 -p$2 -P$3 -h127.0.0.1 <<EOF 2>>$log
  drop database if exists $4 ;
  create database $4 default character set utf8;
EOF


# 把改造后的表结构导入新的schema
mysql -u$1 -p$2 -h127.0.0.1 -P$3 --default-character-set=utf8 $4 <$shell_path/standard_remould_struc.sql >>$log 2>&1


# 拷贝老数据至新库
mysql -u$1 -p$2 -h127.0.0.1 -P$3 --force --default-character-set=utf8 $4 <$shell_path/dump_olddata_$4_$backup_date.sql >>$log 2>&1
if [ $? -eq 0 ];then
	echo -e "import remould data successfully" >>$log
else 
	echo -e "import remould data failed,rollback data ing......" >>$log
	mysql -u$1 -p$2 -h127.0.0.1 -P$3 --force --default-character-set=utf8 $4 <$shell_path/backup_$4_*_$backup_date.sql >>$log 2>&1
	if [ $? -eq 0 ];then
	echo -e "rollback data finished" >>$log
	fi
fi

endtime=`date +"%Y-%m-%d %H:%M:%S"`
begin_date=`date -d "$starttime" +%s`
end_date=`date -d "$endtime" +%s`
spendtime=`expr $end_date - $begin_date`
echo "AT $format_time: takes $spendtime sec for remould operation successfully" >>$log

