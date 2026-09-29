# tools

社内向けユーティリティ集。

## `bin/ecs-exec`

`aws ecs execute-command` を、引数または対話選択で簡単に起動するシェルです。

### 前提

- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [Session Manager Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
- 対象タスクで ECS Exec が有効（`enableExecuteCommand`）かつ IAM / SSM が許可されていること
- 認証済みの AWS プロファイル（または環境変数）

### 使い方

```bash
# フル指定（対話なし）
./bin/ecs-exec \
  --cluster my-cluster \
  --service my-service \
  --container app \
  --region ap-northeast-1

# タスク ARN / ID を直接指定
./bin/ecs-exec --cluster my-cluster --task abcd1234 --container app

# リモートコマンドを指定（既定は /bin/sh）
./bin/ecs-exec --cluster my-cluster --service my-service --container app --command /bin/bash

# 組み立て結果だけ確認（実行しない）
./bin/ecs-exec --cluster my-cluster --service my-service --container app --dry-run

# クラスタ / サービス / RUNNING タスクを一覧
./bin/ecs-exec --list --region ap-northeast-1
```

省略した項目は TTY 上で番号選択します。非対話環境で候補が複数ある場合は明示フラグが必要です。

### テスト

```bash
./tests/ecs-exec_test.sh
```

実 AWS は呼びません（`AWS_CLI` をモックに差し替え）。
