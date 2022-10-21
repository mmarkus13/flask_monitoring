# Flask monitoring infra solution (guide)

Includes:
- <b>backend scripts</b> (code within the jupyter notebook `Monitoring Infra.ipynb`) to *collect and analyze status regarding monitoring services*: <mark>grafana / harvest / influx / nodered / telegraf</mark> and *send ticket to Remedy*
- <b>UI</b> (flask repository included under `/UI` folder)
![Alt text](/UI/infra.png?raw=true "Home Page")
![Alt text](/UI/pastincidents.png?raw=true "past incidents")
![Alt text](/UI/maintenance.png?raw=true "maintenance")

<b>TLDR</b>: 
> This is designed to be installed on the Telegraf host, which is being checked locally by systemctl deamon. 
> Harvest is also checked via systemctl, however it is done remotely (as in my case we have several harvest instances running across different hosts). 
> Grafana, Influx and NodeRed are being checked via curl.

> The main backend script is to be scheduled (cron) to run every minute; <b>when any service is down for 5 consequite minutes then a ticket is sent to the specified endpoint</b> via curl (failover included).

> For more detailed information see the notebook.
