# FluxJobMonit_Slack
[README Japanese](https://github.com/AoiToSouma/FluxJobMonit_Slack/blob/main/README_jp.md)

Monitor the execution status of Plugin FluxMonitor and notify Slack if a problem occurs.
This program runs as a pm2 process.
## premise
Get the webhook URL to use Slack's Incoming Webhooks.<br><br>
Please see below for how to register for Slack.<br>
https://qiita.com/11ppm/private/c23f1bf19043fa6e3afb

## procedure
### Installing jq, bc package
```
sudo apt install jq bc
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
Read the instructions in the file and set your preferences.<br><br>
If you want to detect errors from pm2 logs, define them using blacklists and whitelists.
```
nano grep_black_list.txt
```
Blacklists pick up a wide range of errors.
```
nano grep_white_list.txt
```
Even among messages extracted using the blacklist, <br>
messages that contain other words that do not need to be detected can be excluded using the whitelist.<br>
<br>
If you want to detect Network errors from pm2 logs, edit net_err_list.txt.
```
nano net_err_list.txt
```
The default settings already define error messages for WS/RPC errors and block synchronization delays.

### PostgreSQL permission settings
Set permissions to connect to PostgreSQL without using the sudo command.
```
sudo -u postgres -i psql -c "CREATE ROLE \"$(whoami)\" LOGIN;"
sudo -u postgres -i psql -c "ALTER ROLE \"$(whoami)\" WITH LOGIN;"
sudo -u postgres -i psql -c "GRANT USAGE ON SCHEMA public To \"$(whoami)\";"
sudo -u postgres -i psql -d plugin_mainnet_db -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"$(whoami)\";"
```

### Starting the monitoring process
```
pm2 start FluxJobMonit_Slack.sh
pm2 save
```
