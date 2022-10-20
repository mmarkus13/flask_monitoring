# Flask monitoring infra solution (guide)

Includes:
- <b>backend scripts</b> (code within the `jupyter notebook`) to *collect and analyze status regarding monitoring services*: <mark>grafana / harvest / influx / nodered / telegraf</mark> and *send ticket to Remedy*
- <b>UI</b> (flask repository included under `/UI` folder)
![Alt text](/UI/infra.png?raw=true "Home Page")
![Alt text](/UI/pastincidents.png?raw=true "past incidents")
![Alt text](/UI/maintenance.png?raw=true "maintenance")

<b>TLDR</b>: 
> The main backend script is to be scheduled to run every minute; when any service is down for 5 consequite minutes then a ticket is sent to the specified endpoint via curl (failover included).

> For more detailed information see the notebook `Monitoring Infra.ipynb`
