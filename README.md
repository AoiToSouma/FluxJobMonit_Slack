# pli_fm_slack
Monitor the execution status of Plugin FluxMonitor and notify Slack if a problem occurs.
This program runs as a pm2 process.
## premise
Get the webhook URL to use Slack's incoming webhook.


Please see below for how to register for Slack.

https://qiita.com/11ppm/private/c23f1bf19043fa6e3afb

## procedure
### Installing jq package
```
sudo apt install jq
```
### git clone
```
git clone https://github.com/AoiToSouma/FluxJobMonit_Slack.git
```
```
cd FluxJobMonit_Slack
chmod +x FluxJobMonit_Slack.sh
```
### Edit configurations
```
nano slack.conf
```

### PostgreSQL permission settings
Set permissions to connect to PostgreSQL without using the sudo command.<br>
NOTICE : Edit your login password.<br>
e.g.)NEW_PASSWORD
```
sudo -u postgres -i psql -c "CREATE ROLE \"$(whoami)\" LOGIN ENCRYPTED PASSWORD 'NEW_PASSWORD';"
sudo -u postgres -i psql -c "ALTER ROLE \"$(whoami)\" WITH LOGIN;"
sudo -u postgres -i psql -c "GRANT USAGE ON SCHEMA public To \"$(whoami)\";"
sudo -u postgres -i psql -d plugin_mainnet_db -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"$(whoami)\";"
```

### Starting the monitoring process
```
pm2 start FluxJobMonit_Slack.sh
pm2 save
```
