#!/bin/bash -x
# monitoring_services.sh


# TIMER -start
res1=$(date +%s.%N)
# measure runtime of this script

DATE=`date +'%m/%d/%Y %H:%M:%S'`
err_msg="not running @$DATE"
ok_msg="OK @$DATE"

flask_path=/home/qqky020/UI/flask_wapi_UAT
cd $flask_path



# Define function to check service status:
services_check()
{

# ACTIVE_IQ
    # not defined yet

# GRAFANA:
    grafana_status()
    {
        #grafana_url="https://grafana.apps.kynprodocp.bmwgroup.net/api/health"  # PROD (port is 443)
        grafana_url="http://itahdnasrep.bmwgroup.net:3000/api/health"  # UAT
        grafana_check="$(curl -s $grafana_url | grep -oh [[:alpha:]]*ok[[:alpha:]]*)"  # checks if status is "ok"
        grafana_latency=$(curl -s -w 'Establish Connection: %{time_connect}s\nTTFB: %{time_starttransfer}s\nTotal: %{time_total}s\n' itahdnasrep.bmwgroup.net:3000/ping/api/health | egrep "Total: [1-9]") ;  # checks if latency is above 1 second
        # log status:
        [ $(eval echo \$"${service}_check") == 'ok' ] && [ -z "$latency" ] || echo -e "\n$DATE\n$grafana_check\n\n###" >> ${service}_high_latency.log && echo "${service} $ok_msg" >> ${service}_uptime.log || echo "${service}" $err_msg >> ${service}_uptime.log
        export grafana_latency
    }

# HARVEST:

# QQ USER NEEDS TO BE ADDED TO REMOTE HOST & set up PWLESS SSH (or info needs to be posted to this host via Ansible...)
    harvest_status()
    {
        harvest_status="$(echo T6HKyg_R5krd43K  | /home/qqky020/scripts/.hrp ssh qqky020@itahdnasuathar 'systemctl status harvest')"
        #harvest_check="$(echo T6HKyg_R5krd43K  | /home/qqky020/scripts/.hrp ssh qqky020@itahdnasuathar 'systemctl status harvest  | sort -u | grep running | wc -l')"
        harvest_check=$(echo "$harvest_status" | sort -u | grep running | wc -l)
        if ! [ "$(echo $harvest_check)" == 1 ]; then echo "${service}" $err_msg >> ${service}_uptime.log; else echo "${service} $ok_msg" >> ${service}_uptime.log; fi
    export harvest_status
    }

# INFLUX:
    influx_status()
    {
        #influx_url="https://influxdb.apps.kynprodocp.bmwgroup.net/health"  # PROD (port is 443)
        influx_url="http://itahdnasrep.bmwgroup.net:8086/health"  # UAT
        influx_check="$(curl -s $influx_url | grep status |  grep -oh [[:alpha:]]*pass[[:alpha:]]*)"  # check if status is "pass"
        influx_latency=$(curl -s -w 'Establish Connection: %{time_connect}s\nTTFB: %{time_starttransfer}s\nTotal: %{time_total}s\n' itahdnasrep.bmwgroup.net:8086 | egrep "Total: [1-9]")
        [ $(eval echo \$"${service}_check") == 'pass' ] && [ -z "$latency" ] || echo -e "\n$DATE\n${service}_check\n\n###" >> ${service}_high_latency.log && echo "${service} $ok_msg" >> ${service}_uptime.log || echo "${service}" $err_msg  >> ${service}_uptime.log
        export influx_latency
    }

# NodeRed
    # not defined yet

# TELEGRAF:
    telegraf_status()
    {
        telegraf_check="$(systemctl | grep telegraf | sort -u | grep -v running | wc -l)"
        if ! [ "$(echo $telegraf_check)" == 0 ]; then echo "${service}" $err_msg >> ${service}_uptime.log; else echo "${service} $ok_msg" >> ${service}_uptime.log; fi
        export telegraf_check
    }

# LOOP OVER SERVICES:
for service in grafana harvest influx telegraf #active_iq harvest nodered
    do
        ${service}_status
    done
}



# send ticket if service is down for 5 consecutive minutes
ticket()
{

# ticket details:
if
    service=grafana; then
    eventID="123456..."
    resource="itahdnasrep"  # UAT
    #state=$(serviceup5min || echo  "OK")
    state=$grafana_check
    latency=$grafana_latency
    severity="1"
    header="Date, Service, Status, EventID, Resource, Severity"
    message="$DATE, $service; $state; $eventID, $resource, $severtiy"
elif
    service=influx; then
    eventID="123456..."
    resource="itahdnasrep"  # UAT
    state=$influx_check
    latency=$influx_latency
    severity="1"
    header="Date, Service, Status, EventID, Resource, Severity"
    message="$DATE, $service; $state; $eventID, $resource, $severtiy"
elif
    service=telegraf; then
    eventID="123456..."
    resource="itahdnasrep"  # UAT
    state=$telegraf_check
    #telegraf_jobs="$telegraf_check"
    severity="1"
    header="Date, Service, Status, EventID, Resource, Severity"
    message="$DATE, $service; $state; $eventID, $resource, $severtiy"
    #...
fi


EPOCHNOW=`date -d "${DATE}" +"%s"`
    # Send info to NodeRed when service is down:
    serviceup5min()
        {
        c=0
        for((i=1;i<=5;++i))
            do
            stat=$(tac ${service}_uptime.log | sed -n "${i},1p")
            dat=$(echo $stat| cut -d@ -f2)
                case $stat in
                OK) return 1 ;;
                not)
                epoch_dat=`date -d "${dat}" +"%s"`
                    if [ "$(echo $EPOCHNOW-$epoch_dat|bc)" -le "360"  ] # less or equal to 360 seconds AKA 6 min (5min +1min grace time due to latency)
                    then c=$((c+1))
                    export c
                    # if [ "$c" == 1 ]; then echo ${service}_down_since "$epoch_dat"; fi
                fi ;;
                esac
            done
        }


    create_ticket()
        {
            file=${service}_monitoring_ticket_`date +\%Y\%m\%d\%H\%M`.json
            if [[ $c -ge 5 ]]; then echo -e "$header"\n"$message" > $file; else echo $DATE $service - OK; fi
        }

    for service in grafana harvest influx telegraf #harvest #ansible nodered
        do
            serviceup5min && create_ticket
        done
    }


    send_ticket()
        {
        echo
        # POST json TO NODERED
        }

    #send_ticket


###
manage_logs()
    {
        # GENERATE UPTIME LOGS FOR FLASK
        service_uptime()  # Grafana & Influx
        {
                if [[ "$service" = "telegraf" ]]; then
                telegraf_sub_service_upt()
                    {
                    #set -x
                    stat=`systemctl status telegraf_${sub}.service`
                    #echo $stat
                    [[ $(echo "$stat" | grep "running") == *running* ]] && r="Running" || r="Down"
                    since=$(echo $stat | grep -Po ".*; \K(.*)(?= ago)")
                    epoch_since=$(date --date="$since" +"%s")

                    uptime_seconds=`echo $epoch_since - $EPOCHNOW | bc`
                    uptime=$(echo $uptime_seconds/60|bc)  # minutes

                    echo -e "$r $uptime minutes" > telegraf_${sub}_uptime.txt

                    }

                for sub in broadcom cisco storage system traps
                do
                    telegraf_sub_service_upt
                done


                elif [[ "$service" = "harvest" ]]; then
                harvest_service_upt()
                    {
                    #set -x
                    #stat=`systemctl status harvest.service`
                    stat="$harvest_status"
                    #echo $stat
                    [[ $(echo "$stat" | grep "running") == *running* ]] && r="Running" || r="Down"
                    since=$(echo $stat | grep -Po ".*; \K(.*)(?= ago)")
                    epoch_since=$(date --date="$since" +"%s")

                    uptime_seconds=`echo $epoch_since - $EPOCHNOW | bc`
                    uptime=$(echo $uptime_seconds/60|bc)  # minutes

                    echo -e "$r $uptime minutes" > harvest_uptime.txt

                    }

                harvest_service_upt

                else
                #set -x
                last=$(tac ${service}_uptime.log | grep -A1 -m 1 "not")  # sample: grafana OK @08/11/2022 17:28:03
                up=$(echo "$last" | tail -1)
                epoch_up=`date -d "$(echo $up | cut -d@ -f2)" +"%s"`
                down=$(echo "$last" | head -1)
                epoch_down=`date -d "$(echo $down | cut -d@ -f2)" +"%s"`
                prev_down=$(tac ${service}_uptime.log | grep -m 2 "not" | tail -1)
                epoch_prev_down=`date -d "$(echo $prev_down | cut -d@ -f2)" +"%s"`
                #${service}_last_outage=$(echo  $(echo "$epoch_down"-"$epoch_prev_down"|bc)/60|bc)  # minutes

                #minutes=$(echo "$epoch_down"-"$epoch_prev_down"|bc)#/60|bc  # minutes
                seconds=`echo "$epoch_down"-"$epoch_prev_down"|bc`

                if [[ "$seconds" -eq 0 ]]
                        then echo "UNKNOWN" > ${service}_uptime.txt
                else
                #echo $seconds
                        downtime_minutes=$(echo $seconds/60|bc)
                        service_uptime=`echo $(echo "$EPOCHNOW"-"$epoch_up"|bc)/60|bc`
                #last_outage=$(echo "$minutes"/60|bc)
                #service_uptime="echo $(echo $EPOCHNOW-$epoch_up|bc)/60|bc"  # minutes

                #export ${service}_uptime ${service}_last_outage

                        echo -e "Down: $down\nUp:$up\nOutage Time: $last_outage minutes\nUptime: service_uptime" > ${service}_up_since.txt
                fi
            fi
        }

       for service in grafana harvest influx telegraf #.....
        do
          service_uptime
        done


        past_incidents()
        {
            for T in DAYS WEEKS MONTH;
            do declare t=${T,,};
                RANGE=$(date -d "$date -1 ${t}" +"%s");

                ls *uptime.log | xargs cat | grep -v OK | sort -u | while read line;
                do
                    x=$(echo $line |cut -d@ -f2)
                    if ! [[ $x == '' ]]; then
                        y=$(date -d "$x" +"%s")
                        if [ "$RANGE" -le "$y" ]; then  echo $line >> incidents_${t}.csv; fi
                    fi
                done
            done


        mv incidents_days.csv today.csv 2>/dev/null
        mv incidents_weeks.csv weekly.csv 2>/dev/null
        mv incidents_month.csv montly.csv 2>/dev/null
        }

    # call past incidents subfunction
    past_incidents

}

# Run main parts of the script:
services_check
ticket
manage_logs


# TIMER STOP (calculate runtime):
res2=$(date +%s.%N)
dt=$(echo "$res2 - $res1" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)
echo
printf "script run for: %d:%02d:%02d:%02.4f\n" $dd $dh $dm $ds
echo
set +x

#exit 0