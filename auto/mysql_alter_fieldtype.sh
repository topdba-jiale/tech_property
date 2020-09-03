#!/bin/bash
#auth by zhangjiale
set -o nounset

mysql_user='root'
mysql_passwd='root@qunje'
mysql_socket='/tmp/mysql_3309.sock'
mysql_schema="qjweb_remould"
mysql=$(which mysql)
shell_path=$(cd "$(dirname "$0")";pwd)
log="$shell_path/mysql_alter_fieldtype.log"


function can_null() {
$mysql -u$mysql_user -p$mysql_passwd -S$mysql_socket -B -N -e "select concat(TABLE_SCHEMA,'.',TABLE_NAME),COLUMN_NAME,COLUMN_DEFAULT,IS_NULLABLE,data_type from information_schema.COLUMNS where table_schema='${mysql_schema}' and data_type='tinyint' and IS_NULLABLE='YES';" | while read tablename columnname columndefault nullable datatype
do 
sleep 2
starttime=`date +"%Y-%m-%d %H:%M:%S"`
echo "alter table ${tablename} modify column ${columnname} tinyint >>> smallint"
$mysql -u$mysql_user -p$mysql_passwd -S$mysql_socket -e "alter table ${tablename} modify column \`${columnname}\` smallint default ${columndefault};"
endtime=`date +"%Y-%m-%d %H:%M:%S"`
begin_date=`date -d "$starttime" +%s`
end_date=`date -d "$endtime" +%s`
spendtime=`expr $end_date - $begin_date`
echo "modify column ${tablename}.${columnname} from tinyint to smallint cost $spendtime seconds " >>$log
done
}

can_null

function forbid_null_existdefault() {
$mysql -u$mysql_user -p$mysql_passwd -S$mysql_socket -B -N -e "select concat(TABLE_SCHEMA,'.',TABLE_NAME),COLUMN_NAME,COLUMN_DEFAULT,IS_NULLABLE,data_type from information_schema.COLUMNS where table_schema='${mysql_schema}' and data_type='tinyint' and IS_NULLABLE='NO' and COLUMN_DEFAULT is not null;" | while read tablename columnname columndefault nullable datatype
do 
sleep 2
starttime=`date +"%Y-%m-%d %H:%M:%S"`
echo "alter table ${tablename} modify column ${columnname} tinyint >>> smallint"
$mysql -u$mysql_user -p$mysql_passwd -S$mysql_socket -e "alter table ${tablename} modify column \`${columnname}\` smallint not null default ${columndefault};"
endtime=`date +"%Y-%m-%d %H:%M:%S"`
begin_date=`date -d "$starttime" +%s`
end_date=`date -d "$endtime" +%s`
spendtime=`expr $end_date - $begin_date`
echo "modify column ${tablename}.${columnname} from tinyint to smallint cost $spendtime seconds " >>$log
done
}

forbid_null_existdefault

function forbid_null_nodefault() {
$mysql -u$mysql_user -p$mysql_passwd -S$mysql_socket -B -N -e "select concat(TABLE_SCHEMA,'.',TABLE_NAME),COLUMN_NAME,COLUMN_DEFAULT,IS_NULLABLE,data_type from information_schema.COLUMNS where table_schema='${mysql_schema}' and data_type='tinyint' and IS_NULLABLE='NO' and COLUMN_DEFAULT is null;" | while read tablename columnname columndefault nullable datatype
do 
sleep 2
starttime=`date +"%Y-%m-%d %H:%M:%S"`
echo "alter table ${tablename} modify column ${columnname} tinyint >>> smallint"
$mysql -u$mysql_user -p$mysql_passwd -S$mysql_socket -e "alter table ${tablename} modify column \`${columnname}\` smallint not null;"
endtime=`date +"%Y-%m-%d %H:%M:%S"`
begin_date=`date -d "$starttime" +%s`
end_date=`date -d "$endtime" +%s`
spendtime=`expr $end_date - $begin_date`
echo "modify column ${tablename}.${columnname} from tinyint to smallint cost $spendtime seconds " >>$log
done
}

forbid_null_nodefault






