# create backend script:
vi monitoring_services.sh
# paste the below (to be updated) #current version = v1.02; 2022.08.05 (Author: Michal Márkus)
########################################################################################

#!/bin/bash 
# -x
# monitoring_services.sh


DATE=`date +'%m/%d/%Y %H:%M:%S'`
err_msg="not running @"

flask_path=/home/qqky020/UI/flask_wapi_UAT
cd $flask_path


services_check()
{

# Check status if services are running:


# GRAFANA:
        grafana_status()
        {
                grafana_check="$(curl -sL -I itahdnasrep.bmwgroup.net:3000/ping/api/health | grep HTTP | grep 200 | awk '{print $2}')";  # echo "$grafana_check"
                grafana_latency=$(curl -s -w 'Establish Connection: %{time_connect}s\nTTFB: %{time_starttransfer}s\nTotal: %{time_total}s\n' itahdnasrep.bmwgroup.net:3000/ping/api/health | egrep "Total: [1-9]");  # echo $grafana_latency  # test with 0
                #[ $(eval echo \$"${service}_check") == 200 ] && echo "${service} OK" || echo "${service}" not running $DATE
                [ $(eval echo \$"${service}_check") == 200 ] && [ -z "$latency" ] || echo -e "\n$DATE\n$grafana_check\n\n###" >> ${service}_high_latency.log && echo "${service} OK" >> ${service}_uptime.log || echo "${service}" $err_msg $DATE >> ${service}_uptime.log
        }


# HARVEST:

# QQ USER NEEDS TO BE ADDED TO REMOTE HOST & set up PWLESS SSH (or info needs to be posted to this host via Ansible...)


        harvest_status()
        {
#       service="harvest"

                harvest_check="$(ssh -tt michal@itahdnasuathar.bmwgroup.net 'systemctl status harvest')"  # to be replaced with qq user!
                if [ "$(eval echo \$${service}_check)" | sort -u | grep -v running | wc -l) -gt 0 ]; then echo "${service}" $err_msg $DATE >> ${service}_uptime.log; else echo "${service} OK";fi

        }


# INFLUX:
        influx_status()
        {
                influx_check="$(curl -sL -I itahdnasrep.bmwgroup.net:8086 | grep HTTP | grep 200 | awk '{print $2}')"
                influx_latency=$(curl -s -w 'Establish Connection: %{time_connect}s\nTTFB: %{time_starttransfer}s\nTotal: %{time_total}s\n' itahdnasrep.bmwgroup.net:8086 | egrep "Total: [3-9]")  # test with 0
                [ $(eval echo \$"${service}_check") == 200 ] && [ -z "$latency" ] || echo -e "\n$DATE\n${service}_check\n\n###" >> ${service}_high_latency.log && echo "${service} OK" >> ${service}_uptime.log || echo "${service}" $err_msg $DATE >> ${service}_uptime.log
        }


###

#declare {nodered,ansible}="echo not configured yet "  # CURRENTLY NOT SET

###


# TELEGRAF:

        telegraf_status()
        {
                telegraf_check="$(systemctl | grep ${service})"
                if [ "$(eval echo \$${service}_check) | sort -u | grep -v running | wc -l)" -gt 0 ]; then echo "${service}" $err_msg$DATE >> ${service}_uptime.log; else echo "${service} OK";fi
        }


# LOOP OVER SERVICES:

#for service in grafana harvest influx telegraf ansible nodered
for service in grafana influx telegraf #harvest #ansible nodered
    do
        ${service}_status
    done
}



ticket()
{

# Send info to NodeRed when service is down:
EPOCHNOW=`date -d "${DATE}" +"%s"`

c=0
for((i=1;i<=5;++i))
    do
        dat=$(tac telegraf_uptime.log | sed -n "${i},1p" | cut -d@ -f2)
        epoch_dat=`date -d "${dat}" +"%s"`
        if [ "$(echo $EPOCHNOW-$epoch_dat|bc)" -le "360"  ] # less or equal to 360 seconds AKA 6 min (5min +1min grace time due to latency)
            then c=$((c+1))
            if [ "$c" == "1" ]; then echo ${service}_down_since "$epoch_dat"; fi
            #if [ "$c" == "1" ]; then echo "$epoch_dat" > ${service}_down_since ; fi
        fi
    done

if [[ $c -ge 5 ]]; then echo "PLACEHOLDER for *ticket file with paramenters edited by sed will be passed to NodeRed*" | tee > monitoring_ticket_${DATE}.json; else echo OK; fi

# static IDs; variables to NodeRed via json: https://atc.bmwgroup.net/confluence/download/attachments/2076532016/InterfaceContract_EventMgmt_NAS_final.pdf?version=2&modificationDate=1646741380958&api=v2

}


manage_logs()
{

# PAST INCIDENTS:
    # either use pwless ssh; or copy files to telegraf via Ansible playbook
    
#rm incidents_*.csv 2>/dev/null

for T in DAYS WEEKS MONTH;
    do declare t=${T,,}; echo $t;
        RANGE=$(date -d "$date -1 ${t}" +"%s");

        #cat telegraf_uptime.log | while read line;
        ls *_uptime.log | xargs cat | sort -u | while read line;

        do
            x=$(echo $line |cut -d@ -f2) #  | date +"%s") #  get Date
            y=$(date -d "$x" +"%s")  # convert it to EPOCH format

            #echo $y-$RANGE|bc  # check difference

            if [ "$RANGE" -le "$y" ]; then  echo $line >> incidents_${t}.csv; fi

        done

    done
    
# add when it was restarted started//since when it is running, and how long it runs; was down
# can calculate uptime from last difference 

mv incidents_days.csv today.csv
mv incidents_weeks.csv weekly.csv
mv incidents_month.csv montly.csv

}


services_check
#ticket
#manage_logs
