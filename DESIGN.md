# FluxJobMonit_Slack 設計書

## 1. システム概要

**FluxJobMonit_Slack** は、Plugin FluxMonitor ノードの実行状況を監視し、異常を検知した際に Slack へ通知する監視ツールです。  
pm2 プロセスとして常駐し、定期的にポーリングすることで以下の 6 種類の監視機能を提供します。

| # | 機能 | 概要 |
|---|------|------|
| 1 | DB エラー検知 | PostgreSQL の `job_spec_errors` テーブルからジョブエラーを検出 |
| 2 | ログエラー検知 | pm2 ログファイルをブラック/ホワイトリストでフィルタリングしてエラーを検出 |
| 3 | ラウンド停滞検知 | 最新ジョブ実行からの経過時間が閾値を超えた場合に通知 |
| 4 | 定期通知 | エラー有無に関わらず定期的にジョブ状況を通知（死活監視） |
| 5 | アドレス残高通知 | Nodeアドレスの XDC 残高が閾値を下回った場合に通知 |
| 6 | ネットワーク障害自動回復 | RPC/WS エラー検知時に config.toml を書き換えてノードを自動再起動 |

---

## 2. システム構成

### 2.1 ファイル構成

```
FluxJobMonit_Slack/
├── FluxJobMonit_Slack.sh    # メイン監視スクリプト
├── slack.conf               # 設定ファイル
├── grep_black_list.txt      # エラー検出キーワード（ブラックリスト）
├── grep_white_list.txt      # エラー除外キーワード（ホワイトリスト）
├── net_err_list.txt         # ネットワークエラー検出キーワード
├── .sh/
│   └── netset.sh            # ネットワーク切り替え処理スクリプト
└── fm_log/                  # エラーログ出力ディレクトリ（自動生成）
    └── fm_err_YYYYMMDD_HHMMSS.log
```

### 2.2 外部依存関係

| 依存コンポーネント | 用途 |
|---|---|
| PostgreSQL (`plugin_mainnet_db`) | ジョブ情報・エラー情報の取得 |
| pm2 | プロセス管理・ログ管理 |
| Slack Incoming Webhooks | 通知送信先 |
| `jq` | JSON 構築（Slack メッセージ整形） |
| `bc` | 浮動小数点比較（残高チェック） |
| `curl` | Slack API への POST |
| `plugin` CLI | Node アドレス残高取得 |

---

## 3. アーキテクチャ

### 3.1 処理フロー（全体）

```
起動
 │
 ├─ slack.conf 読み込み
 ├─ netset.sh 読み込み
 ├─ 起動通知を Slack に送信
 │
 └─ [メインループ: POLLING_INTERVAL 秒間隔]
      │
      ├─ PostgreSQL から FluxMonitor ジョブ ID 一覧取得
      │
      ├─ [ジョブ ID ループ]
      │    ├─ ジョブ初回検出時: ジョブ名・最新ラウンド取得 → Slack 通知
      │    ├─ DB エラー検知      (DB_ERROR_TIMER)
      │    ├─ ラウンド停滞検知   (ROUND_STAGNATION_TIMER / STAGNATION_THRESHOLD)
      │    └─ 定期通知           (PERIODIC_NOTICE_TIMER)
      │
      ├─ ログエラー検知          (LOG_ERROR_TIMER)
      ├─ アドレス残高通知        (ADR_BLC_TIMER / ADR_BLC_THRESHOLD)
      └─ ネットワーク障害検知/回復 (NET_ERR_NOTICE_TIMER)
```

### 3.2 Slack 通知メッセージ構造

`post_to_slack` 関数が Slack の Attachments 形式でメッセージを構築します。

| 引数 | Slack フィールド | 内容 |
|------|-----------------|------|
| `$1` | `text` | `検知日時 : MONITOR_NAME` |
| `$2` | `attachments.pretext` | ジョブ名 |
| `$3` | `attachments.color` | `good`（緑）/ `warning`（黄）/ `danger`（赤） |
| `$4` | `attachments.title` | 検知種別（例: "JOB Error occurred!!"） |
| `$5` | `attachments.text` | 詳細情報（エラー内容・ラウンドID など） |
| `$6` | `attachments.footer` | 検知日時 |

---

## 4. 各監視機能の詳細設計

### 4.1 DB エラー検知

**目的:** PostgreSQL の `job_spec_errors` テーブルを定期的に参照し、前回チェック以降に発生したジョブエラーを検出する。

**処理フロー:**
```
経過時間 >= DB_ERROR_TIMER ?
    Yes → SELECT description FROM job_spec_errors
               WHERE updated_at >= '前回チェック時刻'
               AND job_id = '<job_id>'
          エラーレコードあり → Slack 通知 (color: danger)
          前回チェック時刻を更新
```

**設定パラメータ:**

| パラメータ | デフォルト値 | 説明 |
|---|---|---|
| `DB_ERROR_TIMER` | `120`（秒） | チェック間隔。`0` で無効化 |

---

### 4.2 ログエラー検知

**目的:** pm2 が出力するログファイルを差分スキャンし、ブラック/ホワイトリストでフィルタリングしてエラーを検出する。

**処理フロー:**
```
経過時間 >= LOG_ERROR_TIMER ?
    Yes → 前回確認行数から末尾行を取得 (tail -n +N)
          ブラックリストでマッチ (grep -f BLACK_LIST)
          ホワイトリストで除外 (grep -v -f WHITE_LIST)
          結果あり → ファイルに保存 (fm_log/fm_err_YYYYMMDD_HHMMSS.log)
                     LOG_ERROR_NOTICE=true → Slack 通知 (color: danger)
          前回確認行数を更新
ログローテーション対応: cur_line < pre_line の場合、pre_line=1 にリセット
```

**フィルタリングキーワード:**

ブラックリスト（`grep_black_list.txt`）— 広くエラーを捕捉:
```
CRIT / ERROR / fail / 0x prefix / call failed / under min gas price /
Not authorized sender / Dial failed: EVM Node is unreachable /
BLOCK_HISTORY_ESTIMATOR_BLOCK_DELAY
```

ホワイトリスト（`grep_white_list.txt`）— 誤検知を除外:
```
NO_ERROR / session missing or expired... pg /
Failed to fetch block: RPC node returned a missing /
[ERROR] SLOW SQL QUERY / ^primary http.*call failed /
^request failed / fetchAndSaveHead failed
```

**設定パラメータ:**

| パラメータ | デフォルト値 | 説明 |
|---|---|---|
| `LOG_ERROR_TIMER` | `1800`（秒） | チェック間隔。`0` で無効化 |
| `LOG_ERROR_NOTICE` | `true` | `true`: Slack 通知、`false`: ファイル出力のみ |
| `PLI_LOG_FILE` | `~/.pm2/logs/NodeStartPM2-error.log` | 監視対象ログファイル |
| `GREP_BLACK_FILE` | `./grep_black_list.txt` | ブラックリストファイル |
| `GREP_WHITE_FILE` | `./grep_white_list.txt` | ホワイトリストファイル |
| `LOG_DIR` | `./fm_log` | エラーログ出力ディレクトリ |
| `ERR_LOG_PREFIX` | `fm_err_` | エラーログファイル名のプレフィックス |

---

### 4.3 ラウンド停滞検知

**目的:** FluxMonitor ジョブのラウンド実行が一定時間以上停止していないかを検知する。

**処理フロー:**
```
経過時間 >= ROUND_STAGNATION_TIMER ?
    Yes → SELECT MAX(id), MAX(created_at) FROM pipeline_runs
               WHERE pipeline_spec_id = '<job_id>'
          (現在時刻 - created_at) >= STAGNATION_THRESHOLD ?
              Yes → Slack 通知 (color: danger)
                    "job runs id: X / elapsed time: Y(s) / THRESHOLD: Z(s)"
          前回チェック時刻を更新
```

**設定パラメータ:**

| パラメータ | デフォルト値 | 説明 |
|---|---|---|
| `ROUND_STAGNATION_TIMER` | `0`（無効） | チェック間隔（秒） |
| `STAGNATION_THRESHOLD` | `3650`（秒） | 停滞とみなす経過時間の閾値。`idleTimerPeriod + maxTaskDuration` 以上を推奨 |

---

### 4.4 定期通知（死活監視）

**目的:** エラー有無に関わらず定期的に最新ジョブの処理 ID を通知し、ノードが正常稼働していることを確認する。

**処理フロー:**
```
経過時間 >= PERIODIC_NOTICE_TIMER ?
    Yes → SELECT MAX(id) FROM pipeline_runs
               WHERE pipeline_spec_id = '<job_id>'
          Slack 通知 (color: good)
          "job runs id: X"
          前回通知時刻を更新
```

**設定パラメータ:**

| パラメータ | デフォルト値 | 説明 |
|---|---|---|
| `PERIODIC_NOTICE_TIMER` | `0`（無効） | 通知間隔（秒）。`0` で無効化 |

---

### 4.5 アドレス残高通知

**目的:** Nodeアドレスの XDC 残高が閾値を下回った際に通知し、残高不足によるオンチェーン操作の停止を防ぐ。

**処理フロー:**
```
経過時間 >= ADR_BLC_TIMER ?
    Yes → plugin admin login
          plugin keys eth list | grep ETH: → 先頭アドレスの残高取得
          残高 < ADR_BLC_THRESHOLD ?
              Yes → Slack 通知 (color: warning)
                    "${残高}XDC"
          前回チェック時刻を更新
```

**設定パラメータ:**

| パラメータ | デフォルト値 | 説明 |
|---|---|---|
| `ADR_BLC_TIMER` | `3600`（秒） | チェック間隔。`0` で無効化 |
| `ADR_BLC_THRESHOLD` | `10.0`（XDC） | 通知を行う残高の閾値 |

---

### 4.6 ネットワーク障害検知・自動回復

**目的:** ネットワークエラーを検知した場合に `config.toml` の RPC/WS URL を自動切り替えし、ノードを再起動して復旧を試みる。

**処理フロー:**
```
経過時間 >= NET_ERR_NOTICE_TIMER ?
    Yes → check_err_log() 実行
          エラーあり？
              No  → 何もしない
              Yes → NET_AUTO_CHANGE=true ?
                        Yes → [最大 CHANGE_COUNT_LIMIT 回繰り返す]
                                  change_network() で config.toml を書き換え
                                  pm2 reset/restart NodeStartPM2
                                  check_err_log()
                                  エラーなし → 成功: Slack 通知 (color: warning)
                                               "Network change success"
                                               break
                              全試行失敗 → Slack 通知 (color: danger)
                                           "Network change failed"
                        No  → Slack 通知 (color: danger)
                               "Network error occurred"
          前回チェック時刻を更新
```

**ネットワークエラー検出キーワード（`net_err_list.txt`）:**
```
Error in new head subscription, unsubscribed
Subscription was terminated
RPC Node is unreachable
No live RPC nodes available
Log subscriber could not create subscription to Ethereum node
Failed to redial RPC node; still unreachable: ...
No EVM primary nodes available: 0/1 nodes are alive
BalanceMonitor: error getting balance...
RPC node returned multiple missing blocks...
Got very old block with number
```

**設定パラメータ:**

| パラメータ | デフォルト値 | 説明 |
|---|---|---|
| `NET_ERR_NOTICE_TIMER` | `0`（無効） | チェック間隔（秒） |
| `CONFIG` | `~/pluginV2/config.toml` | config.toml のパス |
| `NET_ERROR_LIST` | `./net_err_list.txt` | ネットワークエラー検出キーワードファイル |
| `NET_AUTO_CHANGE` | `true` | 自動切り替えの有無 |
| `CHANGE_COUNT_LIMIT` | `4` | 最大切り替え試行回数 |
| `CHECK_ERR_WAIT` | `10`（秒） | エラーログチェック期間 |
| `URL_LIST` | XDC 公式 RPC/WS 3 件 | 切り替え候補 RPC/WS URL リスト |

---

## 5. 状態管理

メインループ内で各ジョブ・機能の「前回チェック時刻」を連想配列で管理します。

| 変数 | 対象 | 内容 |
|------|------|------|
| `pre_det[job_id]` | ジョブごと | 前回 DB エラーチェック時刻 |
| `pre_rst[job_id]` | ジョブごと | 前回ラウンド停滞チェック時刻 |
| `pre_pnt[job_id]` | ジョブごと | 前回定期通知時刻 |
| `pre_job_round[job_id]` | ジョブごと | 前回確認時の最新ラウンド ID |
| `job_name[job_id]` | ジョブごと | ジョブ名（初回取得後キャッシュ） |
| `pre_line` | グローバル | 前回ログ確認行数（ログエラー検知） |
| `pre_let` | グローバル | 前回ログエラーチェック時刻 |
| `pre_abt` | グローバル | 前回残高チェック時刻 |
| `pre_nec` | グローバル | 前回ネットワークエラーチェック時刻 |

---

## 6. 通知カラーコード

| color | 意味 | 使用シーン |
|-------|------|-----------|
| `good`（緑） | 正常・情報 | 起動通知、監視開始、定期通知 |
| `warning`（黄） | 注意 | 残高不足、ネットワーク切り替え成功 |
| `danger`（赤） | 異常・エラー | DBエラー、ラウンド停滞、ログエラー、ネットワーク障害 |

---

## 7. セットアップ手順

### 7.1 前提条件
- Slack Incoming Webhooks の Webhook URL を取得済みであること
- `jq`、`bc` パッケージがインストール済みであること
- pm2 がインストール済みであること

### 7.2 インストール

```bash
sudo apt install jq bc
git clone https://github.com/AoiToSouma/FluxJobMonit_Slack.git
cd FluxJobMonit_Slack
chmod +x FluxJobMonit_Slack.sh
```

### 7.3 設定ファイル編集

```bash
nano slack.conf              # 基本設定・各監視機能の設定
nano grep_black_list.txt     # エラー検出キーワード
nano grep_white_list.txt     # エラー除外キーワード
nano net_err_list.txt        # ネットワークエラー検出キーワード
```

### 7.4 PostgreSQL 権限設定

```bash
sudo -u postgres -i psql -c "CREATE ROLE \"$(whoami)\" LOGIN;"
sudo -u postgres -i psql -c "ALTER ROLE \"$(whoami)\" WITH LOGIN;"
sudo -u postgres -i psql -c "GRANT USAGE ON SCHEMA public To \"$(whoami)\";"
sudo -u postgres -i psql -d plugin_mainnet_db -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"$(whoami)\";"
```

### 7.5 監視プロセス起動

```bash
pm2 start FluxJobMonit_Slack.sh
pm2 save
```

---

## 8. データベーステーブル参照

| テーブル名 | 使用列 | 用途 |
|---|---|---|
| `jobs` | `id`, `type`, `name` | FluxMonitor ジョブ一覧・ジョブ名取得 |
| `job_spec_errors` | `description`, `updated_at`, `job_id` | ジョブエラー情報取得 |
| `pipeline_runs` | `id`, `created_at`, `pipeline_spec_id` | 最新ラウンド ID・実行時刻取得 |

---

## 9. 設定値一覧（デフォルト値）

| パラメータ | デフォルト値 | カテゴリ |
|---|---|---|
| `SLACK_WEBHOOK_URL` | （要設定） | 基本設定 |
| `MONITOR_NAME` | `{ホスト名}_{IPアドレス}` | 基本設定 |
| `POLLING_INTERVAL` | `30`（秒） | 基本設定 |
| `DB_ERROR_TIMER` | `120`（秒） | DB エラー検知 |
| `LOG_ERROR_TIMER` | `1800`（秒） | ログエラー検知 |
| `LOG_ERROR_NOTICE` | `true` | ログエラー検知 |
| `PLI_LOG_FILE` | `~/.pm2/logs/NodeStartPM2-error.log` | ログエラー検知 |
| `LOG_DIR` | `./fm_log` | ログエラー検知 |
| `ERR_LOG_PREFIX` | `fm_err_` | ログエラー検知 |
| `ROUND_STAGNATION_TIMER` | `0`（無効） | ラウンド停滞検知 |
| `STAGNATION_THRESHOLD` | `3650`（秒） | ラウンド停滞検知 |
| `PERIODIC_NOTICE_TIMER` | `0`（無効） | 定期通知 |
| `ADR_BLC_TIMER` | `3600`（秒） | 残高通知 |
| `ADR_BLC_THRESHOLD` | `10.0`（XDC） | 残高通知 |
| `NET_ERR_NOTICE_TIMER` | `0`（無効） | ネットワーク障害 |
| `CONFIG` | `~/pluginV2/config.toml` | ネットワーク障害 |
| `NET_AUTO_CHANGE` | `true` | ネットワーク障害 |
| `CHANGE_COUNT_LIMIT` | `4` | ネットワーク障害 |
| `CHECK_ERR_WAIT` | `10`（秒） | ネットワーク障害 |
