---
name: gas-push
description: "ローカルのGoogle Apps Script（GAS）プロジェクトを clasp status で点検し、確認後に clasp push でリモートへ反映する。GASへのpush、リモート反映、スクリプト更新を依頼されたときに使う。リモートからの取得には gas-clone、開発フロー全体には gas-dev を使う。版のデプロイは対象外。"
---

# GASへの反映

ローカルの変更を `clasp status` で点検し、対象と上書きリスクを確認してからリモートのApps Scriptプロジェクトへ反映する。

`clasp push` はリモートの内容をローカルで上書きする。Webエディタ側にしかない変更は失われ得るため、対象点検と承認条件を省略しない。

```text
preflight → push対象点検 → 確認 → push → 結果報告
```

## 同梱スクリプト

- `scripts/preflight.ps1`: clasp、ログイン、`.clasp.json`、push対象をJSONで取得する。
- `scripts/push.ps1 -Confirmed [-Force]`: ガード付きで `clasp push` を実行する。

スクリプトはこのスキルのディレクトリから絶対パスを解決し、対象GASプロジェクトを作業ディレクトリとして実行する。

## 1. Preflight

`scripts/preflight.ps1` のJSONで分岐する。

- `claspInstalled: false`: `npm install -g @google/clasp` を提案し、ユーザーがインストールも依頼している場合だけ実行する。
- `loggedIn: false`: ユーザーに `clasp login` を実行してブラウザ認証を完了してもらう。Google認証、パスワード、CAPTCHAを代行しない。
- `hasClaspJson: false`: claspプロジェクトではないためpushしない。必要なら `$gas-clone` を案内する。
- `warnings`: push前の点検対象として保持する。

## 2. Push対象を点検する

`filesToPush` と `untrackedFiles` を確認する。

1. `filesToPush` が空なら、反映対象がないことを報告して終了する。
2. 今回変更したGASファイルが含まれるか確認する。含まれなければ拡張子、`rootDir`、`.claspignore` を調べる。
3. 一時ファイルなど想定外の対象があればpushせず、除外方法を提案する。
4. `appsscript.json` が含まれる場合は、タイムゾーン、OAuthスコープ、ライブラリ、拡張サービスなどの変更内容を確認する。
5. Gitリポジトリなら `git status --short` と `git diff --stat` を読み取り、ユーザーが変更規模を判断できる要約を添える。

`.gs`、`.js`、`.html`、`appsscript.json` などが通常のpush対象であり、`docs/`、`.steering/`、Markdown、Codex設定が `untrackedFiles` に出ること自体は異常ではない。最終的な対象は `clasp status` の結果を正とする。

## 3. 確認条件

push対象の件数と主なファイル、および「リモート側だけの変更は失われ得る」ことを簡潔に提示する。

- ユーザーが今回の依頼でpushまで明示し、点検に警告や想定外の対象がなく、初回pushでも複数人によるWeb編集運用でもない場合は、提示後そのまま実行できる。
- 依頼が曖昧、警告あり、対象が想定外、初回push、または複数人がWebエディタを使う場合は、ユーザーの明示承認を得るまでpushしない。

`push.ps1` の `-Confirmed` は、この確認条件を満たしたことを表す。条件を満たす前に付けない。

## 4. Pushを実行する

`scripts/push.ps1 -Confirmed` を実行し、JSONで分岐する。

- `pushed: true`: 結果を報告する。
- `needsForce: true`: リモートとローカルのマニフェストが食い違っている可能性がある。ローカルの `appsscript.json` の変更と影響を説明し、ユーザーが上書きを明示承認した場合だけ `-Confirmed -Force` で再実行する。
- その他の失敗: `output` と `notes` からアクセス権、ネットワーク、構文、設定を調査する。修正した場合はpreflightと対象点検からやり直す。

`clasp push --watch` は使用しない。

## 5. 報告

- pushした件数と主なファイルを報告する。
- 実動作確認には `clasp open-script`、トリガーや実行履歴の確認には必要に応じてApps Scriptエディタや `clasp logs` を案内する。
- pushはソースの保存・同期であり、WebアプリやAPI実行可能ファイルの公開版更新ではない。公開版の更新には別途デプロイ操作が必要であることを伝える。デプロイはこのスキルでは実行しない。

## 安全条件

- リモート側の未取得変更が疑われる場合はpushしない。
- 対象点検と確認条件を満たす前に `-Confirmed` を指定しない。
- マニフェスト上書きの影響説明と明示承認なしに `-Force` を指定しない。
- push依頼をデプロイ許可として扱わない。
