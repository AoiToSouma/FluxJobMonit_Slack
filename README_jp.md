# FluxJobMonit_Slack
[README English](https://github.com/AoiToSouma/FluxJobMonit_Slack/blob/main/README.md)

Plugin FluxMonitorの実行状況を監視し、問題が発生した場合はSlackに通知します。
このプログラムは pm2 プロセスとして実行されます。

## 前提
SlackのIncoming Webhooks機能を使うため、Webhook URLを取得してください。<br><br>
Slackの登録方法は以下をご覧ください。<br>
https://qiita.com/11ppm/private/c23f1bf19043fa6e3afb

## 手順
### jq, bc パッケージのインストール
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
### 設定ファイルの編集
```
nano slack.conf
```
### slack.confの説明
Flux Monitorを健全に保つための通知機能を提供します。<br>
問題が発生した場合、内容はSlackに通知され、Validatorは即座に問題の発生を認識できます。<br>
下記の設定を適切に行い、各種監視機能を有効化してください。
### 0.通知のための基本設定
|設定項目|項目の説明|
|---|---|
|SLACK_WEBHOOK_URL|Slackのwebhook URLを指定|
|MONITOR_NAME|通知に表示するサーバ名|
|POLLING_INTERVAL|監視間隔（秒）<br>連続実行の負荷を下げるためのsleep時間|

### 1.JOBで発生したエラー情報をPostgreSQLから検出する機能
前回のチェック以降に発生した各JOBのエラーを検出できます。
|設定項目|項目の説明|
|---|---|
|DB_ERROR_TIMER|DB(テーブル名：job_spec_errors）からエラーレコードを検出する間隔（秒）<br>0を指定した場合、通知は無効|

### 2.Plugin Nodeで発生した種々のエラーをログファイルから検出する機能
前回のチェック以降にログファイルに出力されたエラーメッセージを検出できます。<br>
下記のワードが含まれている場合にエラーとして検出し、結果をファイルに出力します。<br>
検索ワードはGREP_PATTERN_FILEで指定されたファイルに記載します。<br>
例）<br>
    error<br>
    fail<br>
    prefix<br>
<br>
検索ワードを編集したい場合はGREP_PATTERN_FILEで指定されたファイルを編集します。
```
nano fm_err_pattern.txt
```
<br>
ファイルだけ定期的に出力し、通知は行わない設定も可能です。
|設定項目|項目の説明|
|---|---|
|LOG_ERROR_TIMER|ログファイルからエラーメッセージを検出する間隔 (秒)<br>前回確認した以降にエラーログが発生している場合に、検出したログをファイルに記録<br>0を指定した場合、通知は無効|
|LOG_ERROR_NOTICE|エラーログ検出時に通知するかどうか(trueまたはfalse)<br>LOG_ERROR_TIMERが0でない場合のみ有効<br>trueの場合、エラーログを検出した際に通知<br>falseの場合、エラーログをファイル出力するのみ|
|PLI_LOG_FILE|検索対象のログファイル<br>LOG_ERROR_TIMER が0以外の場合は必須|
|LOG_DIR|エラーログを出力するディレクトリ<br>LOG_ERROR_TIMER が0以外の場合は必須|
|ERR_LOG_PREFIX|作成するエラー ログの接頭辞<br>LOG_ERROR_TIMER が0以外の場合は必須|

### 3.JOB実行の停滞を検知する機能
最新のJOBが実行されてから経過時間をチェックし、設定したしきい値を超えていた場合に通知します。<br>
チェックする間隔と、しきい値の2つのパラメータで監視を行います。<br>
しきい値はFlux MonitorのidleTimerPeriod(またはdrumbeatSchedule)+maxTaskDurationの合計時間以上を推奨します。
|設定項目|項目の説明|
|---|---|
|ROUND_STAGNATION_TIMER|ラウンド停滞通知間隔（秒）<br>最新のJOBラウンドが実行されてからSTAGNATION_THRESHOLDの時間を経過した場合に通知<br>0を指定した場合、通知は無効|
|STAGNATION_THRESHOLD|最新のJOBラウンドが実行されてからの経過時間のしきい値<br>IdleTimer+maxTaskDuration 相当の時間を想定<br>ROUND_STAGNATION_TIMER が0以外の場合は必須|

### 4.JOB実行状況を定期的に通知する機能
エラーに関係なく、最新のJOBの処理IDを通知します。<br>
健全なNodeほどエラー通知がないため、定期的に通知することで死活監視の役目を負います。<br>
|設定項目|項目の説明|
|---|---|
|PERIODIC_NOTICE_TIMER|定期的なジョブ実行状況通知 (秒)<br>ジョブの停止にかかわらずラウンドを通知<br>0を指定した場合、通知は無効|

### 5.Nodeアドレスの残高を通知する機能
Nodeアドレスの残高(XDC)が設定したしきい値を下回った際に通知します。<br>
残高が不足するとオンチェーン操作ができなくなるため、適切な補充を促します。<br>
|設定項目|項目の説明|
|---|---|
|ADR_BLC_TIMER|アドレス残高通知間隔 (秒)<br>通知するアドレスは一番最初に登録されたもののみ<br>0を指定した場合、通知は無効|
|ADR_BLC_THRESHOLD|アドレス残高がこの値を下回ったときに通知<br>ADR_BLC_TIMERが0以外の場合は必須|

### PostgreSQL 権限設定
sudo コマンドを使用せずに PostgreSQL に接続するための権限を設定します。
```
sudo -u postgres -i psql -c "CREATE ROLE \"$(whoami)\" LOGIN;"
sudo -u postgres -i psql -c "ALTER ROLE \"$(whoami)\" WITH LOGIN;"
sudo -u postgres -i psql -c "GRANT USAGE ON SCHEMA public To \"$(whoami)\";"
sudo -u postgres -i psql -d plugin_mainnet_db -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"$(whoami)\";"
```

### 監視プロセスの開始
```
pm2 start FluxJobMonit_Slack.sh
pm2 save
```
