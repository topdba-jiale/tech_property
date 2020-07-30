#!/bin/bash

m_user='root'
m_passwd='root@qunje'
m_port='3307'
m_host='127.0.0.1'
log="/tmp/sysbench.log"
threds_num='4 8 24 48 64 128 256'

shell_path=$(cd "$(dirname "$0")";pwd)

install_sysbench()

#download https://github.com/akopytov/sysbench/releases/tag/1.0.20
{
tar xzf ./sysbench-1.0.20.tar.gz 
cd sysbench-1.0.20/
./autogen.sh 
./configure --prefix=/usr/local/sysbench --with-mysql-includes=/usr/local/mysql/include --with-mysql-libs=/usr/local/mysql/lib --with-mysql
make && make install
export LD_LIBRARY_PATH=/usr/local/mysql/lib/
echo "LD_LIBRARY_PATH=/usr/local/mysql/lib/" >> ~/.bash_profile 
echo "export LD_LIBRARY_PATH=/usr/local/mysql/lib/" >> ~/.bash_profile 
source ~/.bash_profile
sysbench --version
if [ $? -ne 0 ];then
	echo "sysbench install error"
	exit -1
fi
}

if command -v sysbench >/dev/null 2>&1; then 
	sysbench_version=`sysbench  --version |awk '{print $2}'`
	echo "sysbench command exists and version:$sysbench_version" >$log 
else
	echo "sysbench uninstalled,install sysbench package......"
	install_sysbench
fi


sb_performance() {
mysql -u$m_user -p$m_passwd -P$m_port -h$m_host <<EOF
        create table if not exists test.sysbench_record (
        id bigint unsigned not null auto_increment primary key,
        scenario varchar(15) not null comment '压测场景 如mysql,mariadb,proxysql,maxscale,altas等',
        server_name varchar(15) not null comment '压测服务地址',
        bench_type varchar(15) not null comment '压测类型read-only,read-write,insert等',
        sb_threads int(11) not null default '0' comment 'sysbench测试线程',
        server_load decimal(12,2) not null default '0.00' comment '以当前线程测试完后立刻记录一分钟负载值',
        request_total int(11) not null default '0',
        request_read int(11) not null default '0',
        request_write int(11) not null default '0',
        request_per_second decimal(12,2) not null default '0.00',
        total_time decimal(12,2) not null default '0.00' comment '单位秒',
        95_pct_time decimal(12,2) not null default '0.00' comment '单位毫秒'
        ) engine=innodb default charset=utf8;
EOF

tables_count=16
		for i in {1};do
        	for sb_threds in $threds_num;do
        		if [ "$1" == "read-only" ];then 
            		sysbench --db-driver=mysql --mysql-user="$3" --mysql-password="$4" --mysql-host="$5" --mysql-port="$6" --mysql-db="$7" --range_size=100 --table_size=10000 --tables=10 --threads=$sb_threds --events=0 --time=20 --report-interval=5  --rand-type=uniform  $shell_path/sysbench-1.0.20/src/lua/oltp_read_only.lua run >$log
            	elif [ "$1" == "read-write" ];then 
            		sysbench --db-driver=mysql --mysql-user="$3" --mysql-password="$4" --mysql-host="$5" --mysql-port="$6" --mysql-db="$7" --range_size=100 --table_size=10000 --tables=10 --threads=$sb_threds --events=0 --time=20 --report-interval=5  --rand-type=uniform  $shell_path/sysbench-1.0.20/src/lua/oltp_read_write.lua run >$log
            	fi

            	if [ $? -ne 0 ];then
                	echo -e "sysbench error ,Check $log for more information"
                	exit -1
            	fi

            result=$(cat $log | egrep  "read:|write:|transactions:|total:|total\ time:|95th percentile:" |sed -r -e "s/[0-9]+*\(//g" -e "s/\ per sec\.\)//g" -e "s/m?s$//g" | awk  '{printf("%s ",$NF)}'|sed "s/\ /,/g" | sed "s/,$//g")
			load=$(ssh -p22 "$5" bash -c  "uptime |awk '{print \$(NF-2)}' |sed 's/,//g'" 2>/dev/null)
			mysql -u$m_user -p$m_passwd -P$m_port -h$m_host <<EOF 2>>$log
            insert into test.sysbench_record (scenario,server_name,bench_type,sb_threads,server_load,request_read,request_write,request_total,request_per_second,total_time,95_pct_time) values ('$2','$5','$1','$sb_threds','$load',$result);
EOF
    
            if [ $? -ne 0 ];then
                echo -e "\n----------$sb_threds:$sb_threds $i insert into test.sysbench_record failed----------"
                exit -2
            fi
            sleep 30    
        	done

    	done
}


sb_analyse() {
     mysql -u$m_user -p$m_passwd -h$m_host -P$m_port <<EOF 2> $log
        select
        scenario, 
        server_name,
        bench_type,
        sb_threads,
        convert(avg(server_load),decimal(12,2)) as server_load,
        convert(avg(request_total),decimal(12,0)) as request_total,
        convert(avg(request_read),decimal(12,0)) as request_read,
        convert(avg(request_write),decimal(12,0)) as request_write,
        convert(avg(request_per_second),decimal(12,2)) as request_per_second,
        convert(avg(total_time),decimal(12,2)) as total_time,
        convert(avg(95_pct_time),decimal(12,2)) as 95_pct_time
        from test.sysbench_record group by scenario,server_name,bench_type,sb_threads
EOF
}


sb_chart() {
    sb_analyse > /tmp/mysql_oltp.dat

    for chart_type in "request_per_second" "total_time" "95_pct_time";do    

        col_num=0    
        for col_name in `cat /tmp/mysql_oltp.dat |awk 'NR<2 {print}'`;do
            let col_num++
            if [ $col_name == $chart_type ];then break;fi
        done
        
        if [ $chart_type == "request_per_second" ];then
            key_pos="bottom right"
            unit=""
        elif [ $chart_type == "total_time" ];then
            key_pos="top right"
            unit="(s)"
        elif [ $chart_type == "95_pct_time" ];then
            key_pos="top left"
            unit="(ms)"
        fi

        plot_cmd="set term png size 800,600;set output '/tmp/$chart_type.png';set title '$chart_type $unit';set grid;set key $key_pos;plot "
        
        if [ $# -eq 0 ];then
            for scenario in `mysql -u$m_user -p$m_passwd -h$m_host -P$m_port -s -e "select distinct(scenario) from test.sysbench_record" 2>/dev/null`;do
                sb_analyse | awk -v scenario=$scenario '$1 == scenario {print}' > /tmp/"$scenario.dat"
                plot_cmd=${plot_cmd}"'/tmp/"$scenario.dat"' using $col_num:xtic(4) title '$scenario' with linespoints lw 2,"
            done
            plot_cmd=$(echo $plot_cmd | sed 's/,$//g')
            echo $plot_cmd | gnuplot
        else

            for scenario in $*;do
                sb_analyse | awk -v scenario=$scenario '$1 == scenario {print}' > /tmp/"$scenario.dat"
                plot_cmd=${plot_cmd}"'/tmp/"$scenario.dat"' using $col_num:xtic(4) title '$scenario' with linespoints lw 2,"
            done
            plot_cmd=$(echo $plot_cmd | sed 's/,$//g')
            echo "$plot_cmd" | gnuplot
        fi
    done
}


if [ $# -eq 1 ] && [ $1 == "-h" -o $1 == "--help" ];then
    echo -e "Usage: $0 {bench_type scenario mysql_user mysql_password mysql_host mysql_port mysql_dbname} | {analyse} | {chart [scenario]...}\n"
    exit -1
elif [ "$1" == "read-only" -a  $# -eq 7 ];then
    sb_performance $1 $2 $3 $4 $5 $6 $7 
elif [ "$1" == "read-write" -a  $# -eq 7 ];then
	sb_performance $1 $2 $3 $4 $5 $6 $7 
elif [ "$1" == "analyse" -a $# -eq 1 ];then
    sb_analyse
elif [ "$1" == "chart" ];then
    arg=($*)
    arg_len=${#arg[@]}
    sb_chart ${arg[@]:1:$arg_len-1}
else
    echo -e "Usage: $0 {bench_type scenario mysql_user mysql_password mysql_host mysql_port mysql_dbname} | {analyse} | {chart [scenario]...}\n"
    echo -e "Example: sh $0 {read-only direct_mysql|proxsql|maxscale root 123456 192.168.2.220 3307 jiale} | {analyse} | {chart [scenario]...}"
fi
