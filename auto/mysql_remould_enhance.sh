#!/bin/bash
#auth by zhangjiale

set -o nounset
#set -o errexit

export shell_path=$(cd "$(dirname "$0")";pwd)
export backup_date=`date +%Y%m%d`
export log="$shell_path/mysql_remould.log"
export format_time=`date +"%Y-%m-%d_%H:%M:%S"`
export starttime=`date +"%Y-%m-%d %H:%M:%S"`


if [ $# -ne 4 ] || [ $1 == "-h" -o $1 == "--help" ];then
    echo -e "Usage: sh $0 {mysql_user mysql_password mysql_port dbname} \n"
    echo -e "Example: sh $0 root 123456 3306 qjweb"
    exit -1
fi


read -p "Input current Version:(optional versionn 4,5,6,7)" c_version
read -p "Input want to arrived Version:(optional versionn 5,6,7)" a_version

export mysqluser="$1"
export mysqlpasswd="$2"
export mysqlport="$3"
export mysqldb="$4"
export mysqlpump=$(which mysqlpump)
export mysqldump=$(which mysqldump)
export c_version=$c_version
export a_version=$a_version

# 判断数据库mysql版本是不是大于5.5，否则无法使用参数关闭 --set-gtid-purged=OFF 
m_version=`mysqldump --version |awk '{print $5}' |awk -F'-' '{print $1}' |awk '{print $1+$2}'`
if [ $(echo "$m_version > 5.5" | bc) = 1 ];then
        echo "mysql or mysqldump available" >$log
else
        echo "mysql or mysqldump unavailable" >$log
        exit -1
fi


export gtid_mode=$(mysql -u$mysqluser -p$mysqlpasswd -h127.0.0.1 -P$mysqlport -B -N -e "show variables like 'gtid_mode';" |awk '{print $2}')


# 备份改造前（老）数据库
function backup() {
    if [[ "$gtid_mode" == "ON" ]];then
        $mysqldump -u$mysqluser -p$mysqlpasswd -h127.0.0.1 -P$mysqlport --routines --events --triggers --complete-insert --force --add-drop-table --single-transaction --set-gtid-purged=OFF  -B $mysqldb > $shell_path/backup_${mysqldb}_dump_$backup_date.sql
    else
        $mysqldump -u$mysqluser -p$mysqlpasswd -h127.0.0.1 -P$mysqlport --routines --events --triggers --complete-insert --force --add-drop-table --single-transaction  -B $mysqldb > $shell_path/backup_${mysqldb}_dump_$backup_date.sql
    fi

    if [ $? -ne 0 ];then
        echo "mysqldump olddata error" >>$log
        exit -1
    fi



if [ $? -eq 0 ];then
    echo -e "backup schema:$mysqldb successfully" >>$log
else 
    echo -e "backup schema:$mysqldb failed" >>$log
    exit -1
fi

}

#backup

# 导出老库数据。使用完整插入字段方式，没有建表语句. 不加--databases 即不会有create database语句。
function dump() {
if [[ "$gtid_mode" == "ON" ]];then
    $mysqldump -u$mysqluser -p$mysqlpasswd -h127.0.0.1 -P$mysqlport -E -R --triggers -c -t --single-transaction --set-gtid-purged=OFF --insert-ignore --default-character-set=utf8 $mysqldb >$shell_path/dump_olddata_${mysqldb}_${backup_date}.sql
else
    $mysqldump -u$mysqluser -p$mysqlpasswd -h127.0.0.1 -P$mysqlport -E -R --triggers -c -t --single-transaction  --insert-ignore --default-character-set=utf8 $mysqldb >$shell_path/dump_olddata_${mysqldb}_${backup_date}.sql
fi


if [ $? -eq 0 ];then
# 删除老库，并新建库名
mysql -u$mysqluser -p$mysqlpasswd -P$mysqlport -h127.0.0.1 <<EOF 2>>$log
    drop database if exists $mysqldb ;
    create database $mysqldb default character set utf8;
EOF
else
        exit 1;
fi
}

# 把改造后的表结构导入新的schema
function load() {
mysql -u$mysqluser -p$mysqlpasswd -h127.0.0.1 -P$mysqlport --default-character-set=utf8 $mysqldb <$shell_path/standard_remould_struc.sql >>$log 2>&1

# 拷贝老数据至新库
mysql -u$mysqluser -p$mysqlpasswd -h127.0.0.1 -P$mysqlport --force --default-character-set=utf8 $mysqldb <$shell_path/dump_olddata_${mysqldb}_$backup_date.sql >>$log 2>&1
if [ $? -eq 0 ];then
    echo -e "import remould data successfully" >>$log
else 
    echo -e "import remould data failed,rollback data ing......" >>$log
    mysql -u$mysqluser -p$mysqlpasswd -h127.0.0.1 -P$mysqlport --force --default-character-set=utf8 $mysqldb <$shell_path/backup_${mysqldb}_*_$backup_date.sql >>$log 2>&1
    if [ $? -eq 0 ];then
    	echo -e "rollback data finished" >>$log
    fi
fi
}


function v_5() {
mysql -u$mysqluser -p$mysqlpasswd -h127.0.0.1 -P$mysqlport --force --default-character-set=utf8 $mysqldb -e "source $shell_path/updateDDL_5.sql;"  >>$log 2>&1
mysql -u$mysqluser -p$mysqlpasswd -h127.0.0.1 -P$mysqlport --force --default-character-set=utf8 $mysqldb -e "source $shell_path/updateDML_5.sql;"  >>$log 2>&1
}

function v_6() {
mysql -u$mysqluser -p$mysqlpasswd -h127.0.0.1 -P$mysqlport --force --default-character-set=utf8 $mysqldb -e "source $shell_path/updateDDL_6.sql;"  >>$log 2>&1
mysql -u$mysqluser -p$mysqlpasswd -h127.0.0.1 -P$mysqlport --force --default-character-set=utf8 $mysqldb -e "source $shell_path/updateDML_6.sql;"  >>$log 2>&1
}

function v_7() {
mysql -u$mysqluser -p$mysqlpasswd -h127.0.0.1 -P$mysqlport --force --default-character-set=utf8 $mysqldb -e "source $shell_path/updateDDL_7.sql;"  >>$log 2>&1
mysql -u$mysqluser -p$mysqlpasswd -h127.0.0.1 -P$mysqlport --force --default-character-set=utf8 $mysqldb -e "source $shell_path/updateDML_7.sql;"  >>$log 2>&1
}



if [ "$c_version" -eq "4" -a "$a_version" -eq "5" ];then
	backup
    v_5
elif [ "$c_version" -eq "4" -a "$a_version" -eq "6" ];then
	backup
    v_5
    dump
    load
    v_6
elif [ "$c_version" -eq "4" -a "$a_version" -eq "7" ];then
	backup
    v_5
    dump
    load
    v_6
    v_7
elif [ "$c_version" -eq "5" -a "$a_version" -eq "6" ];then
	backup
    dump
    load
    v_6
elif [ "$c_version" -eq "5" -a "$a_version"-eq "7" ];then
	backup
    dump
    load
    v_6
    v_7
elif [ "$c_version" -eq "6" -a "$a_version" -eq "7" ];then
	backup
    v_7
else 
    echo "Sorry, your choice is not supported at present, please check the rationality of upgrade"
    exit 1
fi


export endtime=`date +"%Y-%m-%d %H:%M:%S"`
export begin_date=`date -d "$starttime" +%s`
export end_date=`date -d "$endtime" +%s`
export spendtime=`expr $end_date - $begin_date`
echo "AT $format_time: takes $spendtime sec for remould From $c_version >>> $a_version operation successfully" >>$log
