---
name: gh-merge-main
description: "ローカルの変更を安全にcommit・pushし、GitHub Pull Requestの作成、既定ブランチ（通常main）へのマージ、ローカル・リモート作業ブランチの削除まで一貫して行う。ユーザーが変更の公開とPRマージ、または既存PRのマージとブランチ削除を明示的に依頼したときに使用する。"
---

# 変更をPull Requestでmainへマージ

GitHub CLIの`gh`を使い、現在の進捗から安全に再開して、変更のcommit、push、Pull Request作成、既定ブランチへのマージ、作業ブランチ削除まで完了する。既存PRがある場合は重複作成せず、確認とマージから再開する。

## 出力言語

- ユーザーが別の言語を明示しない限り、日本語で出力する。
- 状態確認、停止理由、commit、Pull Request、実行結果を日本語で記述する。
- コマンド、パス、API、識別子、製品・サービスの正式名称は必要な原表記を維持する。

## 承認範囲

- commit、push、PR作成、マージ、ブランチ削除は外部状態を変更する。ユーザーが実行を明示的に依頼した操作だけを行う。
- 既存PRのマージだけを依頼された場合、未承認のローカル変更をcommitまたはpushしない。
- `--admin`、force push、`git reset --hard`、未承認の変更破棄、保護規則の回避、既定ブランチの削除を行わない。

## 事前確認

1. `gh --version`と`gh auth status`でGitHub CLIと認証を確認する。
2. `git remote -v`と`gh repo view --json nameWithOwner,defaultBranchRef`で対象リポジトリと既定ブランチを確認する。
3. `gh repo view`で許可されたマージ方式を確認する。ユーザー指定がなければsquash mergeを優先する。
4. `git status --short --branch`、現在ブランチ、`HEAD`、既定ブランチ、`origin/<default>`の関係を確認する。
5. `git fetch origin --prune`後、既定ブランチがリモートより遅れている、分岐している、または競合がある場合は停止する。stash、rebase、変更破棄で自動解決しない。
6. 変更範囲がユーザー依頼と一致し、シークレット、認証情報、ローカルDB、生成物、無関係な変更を含まないことを確認する。安全に分離できなければ停止する。

## 作業ブランチ

- 既定ブランチ上で作業ツリーが空なら、`git pull --ff-only`で同期してから`codex/<変更内容>`形式の作業ブランチを作る。
- 既定ブランチ上に承認済みの未コミット変更がある場合、ローカル`HEAD`が`origin/<default>`と一致するときだけ、その変更を保持したまま作業ブランチを作る。
- 既定ブランチ以外にいる場合、現在ブランチが今回の変更用であり、既定ブランチをbaseにしていることを確認して使う。別作業のブランチを流用しない。
- ブランチ名が不明瞭な場合は、変更内容から短いkebab-case名を選ぶ。既存リモートブランチと衝突する場合は推測せず停止する。

## commit

1. リポジトリの`AGENTS.md`、開発文書、CI設定から必要な検証コマンドを特定して実行する。
2. `git diff`と`git status --short`で変更全体を確認する。
3. 対象パスを明示して`git add <paths...>`を実行する。`git add .`や`git add -A`で無関係な変更を一括stageしない。
4. `git diff --cached --check`と`git diff --cached`でstage内容を再確認する。
5. 変更目的を表す簡潔なcommitを作る。既存commitの改変やamendは、ユーザーが明示しない限り行わない。
6. commit後に作業ツリーが空であることを確認する。未保存変更が残る場合はpush前に停止する。

## pushとPull Request作成

1. `git push -u origin <head>`で作業ブランチをpushする。force pushしない。
2. `gh pr view <head>`で同じheadのPRが存在するか確認する。OpenなPRがあれば再利用し、重複作成しない。
3. PRがなければ、`gh pr create --base <default> --head <head>`でReadyなPRを作る。タイトルは変更目的、本文は変更概要と実行した検証を記載する。
4. PR URL、base、head、head commit SHAを記録する。

## マージ前の確認

1. `gh pr view`でPRがOpenかつReady、baseが既定ブランチ、headが既定ブランチ以外であることを確認する。
2. head commit SHA、マージ可能性、競合、レビュー状態、マージキューの有無を確認する。
3. `gh pr checks --required`で必須チェックがすべて成功していることを確認する。必須チェックがない場合はその事実を記録する。
4. 必須レビュー、ブランチ保護、マージキューの要件を確認する。未承認、保留、失敗、競合、不明な状態を成功扱いしない。
5. `git status --short`でローカル作業ツリーが空であることを再確認する。
6. push後にhead SHAが変化していないことを確認する。

## マージ

確認済みhead commit SHAを`--match-head-commit`へ指定し、許可された方式でマージする。

```bash
gh pr merge <PR> --squash --delete-branch --match-head-commit <HEAD_SHA>
```

マージキューへ投入されただけの場合は、Mergedと報告せず状態を伝えて停止する。

## マージ後の同期と削除

1. `gh pr view`でPRがMergedであること、マージcommit、マージ時刻を確認する。
2. ローカルの既定ブランチへ切り替え、`git pull --ff-only`で`origin/<default>`を反映する。
3. `git ls-remote --heads origin <head>`でリモートブランチを確認する。残っている場合は、リモートSHAが確認済みhead SHAと一致することを再確認してから`git push origin --delete <head>`を実行する。
4. `git branch --list <head>`でローカルブランチを確認する。残っている場合は、まず`git branch -d <head>`を実行する。
5. squash mergeのため`git branch -d`が拒否した場合、PRがMerged、現在ブランチが既定ブランチ、ローカル作業ブランチのSHAが確認済みhead SHAと完全一致することを再確認する。その条件をすべて満たす場合だけ、旧head SHAを指定した`git update-ref -d refs/heads/<head> <HEAD_SHA>`で参照を削除する。
6. `git fetch origin --prune`後、ローカル・リモート双方に作業ブランチがなく、既定ブランチの作業ツリーが空であることを確認する。

## 完了報告

- commit SHAと件名
- Pull Request URL
- 必須チェック、レビュー、マージ方式
- マージcommitと時刻
- 削除したローカル・リモートブランチ
- 未完了事項または停止理由

## 停止条件

- 対象リポジトリ、変更範囲、base、head、または承認された外部操作が曖昧
- `gh`の認証またはGitHub権限が不足
- 既定ブランチがリモートと分岐、または変更と最新baseを安全に統合できない
- 無関係な変更、シークレット、生成物、未保存変更を安全に分離できない
- 必須チェック、レビュー、競合、マージキューが未完了
- push後にPRのhead SHAが変化した
- 許可されていないマージ方式または保護規則の回避が必要
- マージ後のブランチSHAが確認済みhead SHAと一致せず、安全な削除条件を満たさない
