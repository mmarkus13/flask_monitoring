#!/bin/bash -x
# monitoring_services.sh


# TIMER -start
res1=$(date +%s.%N)
# measure runtime of this script

DATE=`date +'%m/%d/%Y %H:%M:%S'`; EPOCHNOW=`date -d "${DATE}" +"%s"`
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
        harvest_check="$(ssh -tt michal@itahdnasuathar.bmwgroup.net 'systemctl status harvest')"  # to be replaced with qq user!
        if [ "$(eval echo \$${service}_check) | sort -u | grep -v running | wc -l)" -gt 0 ]; then echo "${service}" $err_msg  >> ${service}_uptime.log; else echo "${service} $ok_msg";fi
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
for service in grafana influx telegraf #active_iq harvest nodered
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

    
#EPOCHNOW=`date -d "${DATE}" +"%s"`
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

    for service in grafana influx telegraf #harvest #ansible nodered
        do
            serviceup5min && create_ticket
        done 
    }


    send_ticket()
        {
        # POST json TO NODERED    
        }

    #send_ticket



manage_logs()
    {
        # GENERATE UPTIME LOGS FOR FLASK
        servce_uptime()  # Grafana & Influx
        {
            # adding telegraf here (since it has more sub-precesses)
            if $service = telegraf; then
                telegraf_sub_service_upt()
                {
                    stat=$(systemctl status telegraf_${sub}.service)
                    [[ $(echo "$stat" | grep running) == running ]] && r="running" || r="down"
                    since=(echo $stat | grep -Po ".*; \K(.*)(?= ago)" 
                    #up_d=$(echo $stat | grep running | cut -d")" -f2)
                    #up_d=$(echo $stat | grep -Po ".*; \K(.*)(?= ago)"
                    epoch_since=$(date --date="$since" +"%s")
                    ${service}_uptime=echo $(echo "$EPOCHNOW"-"$since"|bc)/60|bc  # minutes
                    # ADD DOWNTIME CALC AS WELL!
                    # EHHEZ SZÉT KELL SZEDNI fentebb a 'systemctl | grep telegraf' logokat az alábbi szerint:
                        # systemctl status ITMAgents1.lz.service | grep -Po ".*; \K(.*)(?= ago)"
                        # outputja: "6 months 14 days"

                    echo -e "$r ${service}_uptime minutes" > telegraf_{sub}_uptime.log
                }
            
                for sub in broadcom cisco storage system traps
                do
                    telegraf_sub_service_upt
                done
            
            else
                last=$(tac ${service}_uptime.log | grep -A1 -m 1 "not")  # sample: grafana OK @08/11/2022 17:28:03
                up=$(echo "$last" | tail -1)
                epoch_up=`date -d "$(echo $up | cut -d@ -f2)" +"%s"`
                down=$(echo "$last" | head -1)
                epoch_down=`date -d "$(echo $down | cut -d@ -f2)" +"%s"`
                prev_down=$(tac ${service}_uptime.log | grep -m 2 "not" | tail -1)
                epoch_prev_down=`date -d "$(echo $prev_down | cut -d@ -f2)" +"%s"`
                ${service}_last_outage=echo $(echo "$epoch_down"-"$epoch_prev_down"|bc)/60|bc  # minutes
                ${service}_uptime=echo $(echo "$EPOCHNOW"-"$epoch_up"|bc)/60|bc  # minutes

                #export ${service}_uptime ${service}_last_outage          

                echo -e "Down: $down\nUp:$up\nOutage Time: ${service}_last_outage minutes\nUptime: ${service}_uptime" > ${service}_up_since.txt

                for service in grafana influx #telegraf #.....
                    do
                        servce_uptime
                    done
            fi
        }

        

        past_incidents()
        {
            for T in DAYS WEEKS MONTH;
            do declare t=${T,,}; #echo $t;
                RANGE=$(date -d "$date -1 ${t}" +"%s");

                #cat telegraf_uptime.log | while read line;
                ls *_uptime.log | xargs cat | grep -v OK | sort -u | while read line;
                do
                    x=$(echo $line |cut -d@ -f2)
                    # if x is number number then convert to epoch format (y):
                    #if [[ $x == ?(-)+([0-9])  ]]; then  # x is NOT a number because "/" characters in time format!...
                    if ! [[ $x == '' ]]; then
                        y=$(date -d "$x" +"%s")  # && echo $y-$RANGE|bc;  # check difference
                        if [ "$RANGE" -le "$y" ]; then  echo $line >> incidents_${t}.csv; fi
                    fi
                done
            done

        # add when it was restarted started//since when it is running, and how long it runs; was down
        # can calculate uptime from last difference

        mv incidents_days.csv today.csv 2>/dev/null
        mv incidents_weeks.csv weekly.csv 2>/dev/null
        mv incidents_month.csv montly.csv 2>/dev/null
    }

    # call past incidents subfunction
    past_incidents

###########################################################################################################
# UPTIME CALC:
        
#last down (N/A - UNKNOWN)
#up since 
#running for
#outage duration
"""
telegraf_sub_service_upt()
        {
            systemctl status telegraf_${sub}.service | grep since | cut -d")" -f2 > telegraf_{sub}_uptime.log
            # output sample: "since Tue 2022-06-28 14:52:39 CEST; 1 months 14 days ago"
        }
 
        for sub in broadcom cisco storage system traps
            do
                telegraf_sub_service_upt 
            done
"""
# VISUALIZE THESE LOGS ON PAST INCIDENTS TAB

        
###
# 2 szintu maintenance check:
#        1# local offlne lekérdezés napi 1x
#        2# kikuldés előtt  live ellenőzés
###########################################################################################################
}
    

###########################################################################################################

#--Sandor qq user harvest status lekérdezéshez
#--Michael Flesh maintenance  (ha nem csv akkor tud e adni accesst MSSQL)
    
###########################################################################################################  
    
    
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

exit 0
