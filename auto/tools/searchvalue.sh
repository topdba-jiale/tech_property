-- 找出MySQL数据库中某个字段值包含某个值，所在的库表字段（例如找出某个字段内容包含com,所在的表和字段）
#!/bin/bash
IFS='
'
DBUSER=root
DBPASS=root@qunje
#DBSOCK="/tmp/mysql.sock"
DBSOCK=`ps -ef|grep mysqld |grep port |awk '{print $(NF-1)}' |awk -F'=' '{print $2}'`
read -p  "Which database do you want to search in (press 0 to see all databases,press string to see specified database):" dbname
read -p  "Which string do you want to search: " search_key
if [ "$dbname" == "0" ] ;then 
DB=`mysql -u$DBUSER -p$DBPASS -S$DBSOCK -s -e "show databases;" |grep -v -E "information_schema|Database|performance_schema|sys"`
elif [ "$dbname" != "0" ] ;then 
DB="$dbname"
fi

for h in $DB 
do 
for i in `mysql -u$DBUSER -p$DBPASS -S$DBSOCK -D$h -e "show tables" | grep -v \`mysql -u$DBUSER -p$DBPASS -S$DBSOCK -D$h -e "show tables" | head -1\``
do
for k in `mysql -u$DBUSER -p$DBPASS -S$DBSOCK -D$h -e "desc $i" | grep -v \`mysql -u$DBUSER -p$DBPASS -S$DBSOCK -D$h  -e "desc $i" | head -1\` | grep -v int | awk '{print $1}'`
do
if [ `mysql -u$DBUSER -p$DBPASS -S$DBSOCK -D$h -e """Select * from $i where `{$k}` like '%"$search_key"%'""" | wc -l` -gt 1 ] 
then
echo " Your searchstring was found in schema:$h in table $i, column $k"
fi
done
done
done

