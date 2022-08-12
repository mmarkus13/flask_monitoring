#!/bin/bash
# monitng_services.sh

# TIMER -start
res1=$(date +%s.%N)


DATE=`date +'%m/%d/%Y %H:%M:%S'`
err_msg="not running @$DATE"
ok_msg="OK @$DATE"

flask_path=/home/qqky020/UI/flask_wapi_UAT
cd $flask_path


services_check()
{

# Check status if services are running:


# GRAFANA:
        grafana_status()
        {
                #grafana_check="$(curl -sL -I itahdnasrep.bmwgroup.net:3000/ping/api/health | grep HTTP | grep 200 | awk '{print $2}')";  # echo "$grafana_check"
		grafana_check="$(curl -s http://itahdnasrep.bmwgroup.net:3000/api/health | grep -oh [[:alpha:]]*ok[[:alpha:]]*)"
		grafana_latency=$(curl -s -w 'Establish Connection: %{time_connect}s\nTTFB: %{time_starttransfer}s\nTotal: %{time_total}s\n' itahdnasrep.bmwgroup.net:3000/ping/api/health | egrep "Total: [1-9]") ;  # echo $grafana_latency  # test with 0
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
                #influx_check="$(curl -sL -I itahdnasrep.bmwgroup.net:8086 | grep HTTP | grep 200 | awk '{print $2}')"
         	influx_check="$(curl -s http://itahdnasrep.bmwgroup.net:8086/health | grep status |  grep -oh [[:alpha:]]*pass[[:alpha:]]*)"
	 	influx_latency=$(curl -s -w 'Establish Connection: %{time_connect}s\nTTFB: %{time_starttransfer}s\nTotal: %{time_total}s\n' itahdnasrep.bmwgroup.net:8086 | egrep "Total: [3-9]")  # test with 0
                [ $(eval echo \$"${service}_check") == 'pass' ] && [ -z "$latency" ] || echo -e "\n$DATE\n${service}_check\n\n###" >> ${service}_high_latency.log && echo "${service} $ok_msg" >> ${service}_uptime.log || echo "${service}" $err_msg  >> ${service}_uptime.log
			export influx_latency
	}


###

#declare {nodered,ansible}="echo not configured yet "  # CURRENTLY NOT SET

###


# TELEGRAF:

        telegraf_status()
        {
                telegraf_check="$(systemctl | grep telegraf | sort -u | grep -v running | wc -l)"
                if ! [ "$(echo $telegraf_check)" == 0 ]; then echo "${service}" $err_msg >> ${service}_uptime.log; else echo "${service} $ok_msg" >> ${service}_uptime.log; fi
		export telegraf_check
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

serviceup5min()    
{
c=0
for((i=1;i<=5;++i))
	do
	
	#echo $stat	
	stat=$(tac ${service}_uptime.log | sed -n "${i},1p")
	#echo $stat	
    	#echo $dat
	    dat=$(echo $stat| cut -d@ -f2)
	   # [[ "OK" == *"$stat"* ]] && return 1 || \
	    case $stat in
		OK) return 1 ;;
		not)
                epoch_dat=`date -d "${dat}" +"%s"`

                if [ "$(echo $EPOCHNOW-$epoch_dat|bc)" -le "360"  ] # less or equal to 360 seconds AKA 6 min (5min +1min grace time due to latency)
                    then c=$((c+1))
		    export c
    #                if [ "$c" == 1 ]; then echo ${service}_down_since "$epoch_dat"; fi
                fi ;;
	    esac
        done
}

	

if
 service=grafana; then
 	eventID="123456..."
 	resource="itahdnasrep"
#	state=$(serviceup5min || echo  "OK")
	state=$grafana_check
	latency=$grafana_latency
	severity="1"
	header="Date, Service, Status, EventID, Resource, Severity"
	message="$DATE, $service; $state; $eventID, $resource, $severtiy"

elif
 service=influx; then
 	eventID="123456..."
        resource="itahdnasrep"
        state=$influx_check
	latency=$influx_latency
        severity="1"
        header="Date, Service, Status, EventID, Resource, Severity"
        message="$DATE, $service; $state; $eventID, $resource, $severtiy"


elif
 service=telegraf; then
        eventID="123456..."
        resource="itahdnasrep"
        state=$telegraf_check
#	telegraf_jobs="$telegraf_check"
        severity="1"
        header="Date, Service, Status, EventID, Resource, Severity"
        message="$DATE, $service; $state; $eventID, $resource, $severtiy"
#...

fi

create_ticket()
{
	file=${service}_monitoring_ticket_`date +\%Y\%m\%d\%H\%M\%S`.json
	if [[ $c -ge 5 ]]; then echo -e "$header"\n"$message" > $file; else echo $DATE $service - OK; fi
}
# static IDs; variables to NodeRed via json: https://atc.bmwgroup.net/confluence/download/attachments/2076532016/InterfaceContract_EventMgmt_NAS_final.pdf?version=2&modificationDate=1646741380958&api=v2


for service in grafana influx telegraf #harvest #ansible nodered
    do
	serviceup5min && create_ticket
	    #        serviceup5min; [ $c -ge 5 ] && create_ticket; echo TICKET || echo NO TICKET
    done   


# static IDs; variables to NodeRed via json: https://atc.bmwgroup.net/confluence/download/attachments/2076532016/InterfaceContract_EventMgmt_NAS_final.pdf?version=2&modificationDate=1646741380958&api=v2

}


manage_logs()
{

# PAST INCIDENTS:
    # either use pwless ssh; or copy files to telegraf via Ansible playbook

#rm incidents_*.csv 2>/dev/null

servce_uptime()
{

tac ${service}_uptime.log | grep -A1 -m 1 "not"  | tail -1 > ${service}_up_since.txt

}

for service in grafana influx telegraf #.....
    do
	servce_uptime
    done


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
            #if [[ $x == ?(-)+([0-9])  ]]; then  # x is NOT a number because "/" characters in time format!
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

}


# Run main parts of the script:
services_check
ticket
manage_logs


# TIMER STOP:
res2=$(date +%s.%N)
dt=$(echo "$res2 - $res1" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

printf "script run for: %d:%02d:%02d:%02.4f\n" $dd $dh $dm $ds
echo

exit 0

