# catLog.sh
This function analyzes various logs.<br>
様々なログの分析を行う機能です。<br>
<br>
First, give execution permission.<br>
まずは実行権限を与えてください。
```
chmod +x catLog.sh
```

# process
## Latest fm_log (最新のfm_logに関する情報)
```
./catLog.sh -l all
```
Display the latest fm_log contents.<br>
最新のfm_logの内容を表示します。

```
./catLog.sh -l time
```
The time when the error occurred is aggregated and displayed from the latest fm_log.<br>
Some messages may have no time output, which means the time of occurrence cannot be displayed correctly.<br>
最新のfm_logからエラーが発生した時間を集計して表示します。<br>
一部のメッセージは時刻出力がない場合があり、それは正しく発生時刻が表示できません。

```
./catLog.sh -l neterror
```
Only information related to network errors is aggregated and displayed from the latest fm_log.<br>
This means that an error related to RPC/WS was occurring.<br>
最新のfm_logからネットワークエラーに関する情報のみ集計して表示します。<br>
これはRPC/WSに関するエラーが発生していたことを意味します。

## previous day's pm2 log (前日のpm2 logに関する情報)
```
./catLog.sh -p all
```
Display all pm2 logs that occurred the previous day.<br>
However, do not recommend outputting this because it will display a large amount of logs.<br>
前日に発生したすべての pm2 ログを表示します。<br>
ただし、大量のログが表示されるため出力はお勧めしません。

```
./catLog.sh -p analyze
```
Displays the previous day's pm2 log for each message.<br>
Helps analyze messages.<br>
前の日のpm2 logをメッセージごとに集計して表示します。<br>
メッセージの分析に役立ちます。
