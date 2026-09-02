---
name: fsos-dev
description: "FieldSpec OS の fieldspec-os MCP から確定済み案件仕様を取得し、それを唯一の情報源として README.md、AGENTS.md、docs/ の永続文書7点、初期ステアリングを生成する。FieldSpec OS 案件から仕様駆動の開発文書を作るときに使う。"
---

# fsos-dev：FieldSpec OS 仕様駆動ドキュメント生成

`$dev-docs` の改良版。ヒアリングや手入力で情報源を集める代わりに、**FieldSpec OS の MCP（`fieldspec-os`）から
案件の確定済み仕様を取得し、それを「唯一の情報源（SSOT）」として** README.md / AGENTS.md / 永続的ドキュメント
（`docs/` の7ファイル）を生成する。仕様駆動開発（要求・設計・実装・検証をつなぐ変更管理された情報源）を、
実装リポジトリのドキュメントへ橋渡しするのが目的。

引数: `ユーザーの依頼内容`

- **引数なし** → `list_projects` で案件一覧を提示し、どの案件のドキュメントを生成するかユーザーに選ばせる。
- **案件名 or projectId** → その案件を特定して生成フローに入る。

## 前提：MCP 接続の確認

このスキルは `fieldspec-os` MCP サーバ（tools: `list_projects` / `get_project_status` / `get_project_spec`）に依存する。

- まず `list_projects` を呼べるか確認する。呼べない場合は「MCP 未接続」なので、FieldSpec OS リポジトリの
  README「FieldSpec OS MCP サーバ」節（ユーザースコープ登録手順、PAT 発行）を案内し、中止する。
- MCP は read-only。ここでは**仕様を読むだけ**で、FieldSpec OS 側の成果物は一切書き換えない。

## ステップ 0：案件の特定と仕様取得

1. `list_projects` を呼び、案件一覧（id / 顧客名 / 案件名 / 現在フェーズ / ステータス）を得る。
   - 引数が案件名/idに一致すればそれを採用。曖昧・複数一致・引数なしなら一覧を提示して確認する。
2. 確定した `projectId` で `get_project_spec(projectId)` を呼び、仕様一式を取得する。必要に応じて
   `get_project_status(projectId)` で成果物の作成状況も確認する。
3. **充足チェック**: `requirements`（FR）や `acceptanceCriteria`（AC）が空なら、その案件は 02_要件定義まで
   未生成。ユーザーに知らせ、「ヒアリング/業務設計だけで下書きするか」「FieldSpec OS 側で要件定義を生成してから
   再実行するか」を確認する（薄い仕様から docs を捏造しない）。

`get_project_spec` の出力フィールド（情報源）:

| フィールド | 内容 |
| --- | --- |
| `hearingSheetMarkdown` | ヒアリングシート全文（顧客の一次情報：背景・期待成果・業務フロー・課題・要望・決定事項・制約） |
| `businessDesignSummary` | 業務課題整理（BIZ-xxx）・根本原因分析・As-Is / To-Be 業務フロー |
| `requirements[]` | 要求（FR-xxx：分類・内容・背景根拠・優先度(MoSCoW)・対応AC/論点ID） |
| `acceptanceCriteria[]` | 受け入れ条件（AC-xxx：Given/When/Then・検証方法） |
| `openQuestions[]` | 未確定論点（Q-xxx：論点・選択肢・推奨案・確認先） |
| `requirementsDocMarkdown` | 要件定義書本文（背景・スコープ・用語・機能/非機能要件・制約） |

## ステップ 1：ローカルリポジトリの把握

生成する docs は「**何を作るか**（＝MCP の仕様）」と「**どう作るか**（＝このリポジトリの実態）」の両方を反映する。
`$dev-docs init` と同様、リポジトリを検査して実際の技術スタックを把握する:

- 依存/ビルド定義（`package.json` / `pyproject.toml` / `go.mod` / `Cargo.toml` 等）、Lint/テスト/フォーマット設定、
  既存の `docs/` や `AGENTS.md`、ディレクトリ構成、フレームワーク・言語バージョン。
- 仕様（ヒアリング §10 既存ツール・§13 技術決定）とリポジトリ実態が食い違う場合は、リポジトリ実態を優先し、
  差異はユーザーに確認する。まだ空のリポジトリなら、仕様＋dev-docs 推奨構成から初期構成を提案する。

## ステップ 2：永続的ドキュメント（`docs/` 7点）の生成

**上書き防止**: `docs/` に既存ファイルがあれば、いきなり上書きしない。既存を列挙し「不足分のみ / 作り直し / 中止」を確認する。

`mkdir -p docs .steering` の後、次の順で作成する。**1ファイルごとに作成→承認を得てから次へ**進む
（`$add-feature` 等でまとめて承認する運用に合わせてもよい）。各ファイルは下表の情報源から生成する。

| # | ファイル | 主な情報源（get_project_spec のフィールド ＋ リポジトリ実態） |
| --- | --- | --- |
| 1 | `product-requirements.md` | `hearingSheetMarkdown`（背景・期待成果・想定ユーザー・課題・要望）／`businessDesignSummary`（BIZ 課題）／`requirements`（機能・非機能要件）／`acceptanceCriteria`（受け入れ条件）／`openQuestions`（未確定論点） |
| 2 | `functional-design.md` | `requirements`（機能要件）／`businessDesignSummary`（As-Is/To-Be＝業務フロー図・ユースケース）／`hearingSheetMarkdown` §8（ユースケース）／`requirementsDocMarkdown`。アーキテクチャ・データモデル・画面はアーキ原則に沿って設計 |
| 3 | `architecture.md` | `hearingSheetMarkdown` §10（既存ツール）・§13（技術決定：例「レイヤード採用」）／`requirements` 非機能／`requirementsDocMarkdown` §6（制約・前提）／**リポジトリ実態**（スタック・バージョン） |
| 4 | `repository-structure.md` | architecture の決定＋リポジトリ実態＋dev-docs 推奨構成（ドメイン駆動 × レイヤード） |
| 5 | `development-guidelines.md` | リポジトリ実態（Lint/テスト/フォーマット/Git）＋dev-docs のアーキテクチャ原則の運用規約 |
| 6 | `glossary.md` | `requirementsDocMarkdown` §3（用語）／`hearingSheetMarkdown`（ドメイン用語）／ID 規約（BIZ/FR/AC/Q） |
| 7 | `development-roadmap.md` | `hearingSheetMarkdown`（期限・MVP 範囲）／`requirements` の優先度（MoSCoW）／`openQuestions`（未決の解消順） |

各ドキュメントの章立て・粒度は `$dev-docs`「永続的ドキュメント」節の定義に従う。

## ステップ 3：AGENTS.md の生成

AGENTS.md を作成（既存なら該当セクションを追記）。記載は次に**限定**し、本スキルや dev-docs の全文を写さない:

1. **ステアリング規則の要約**：`.steering/[YYYYMMDD]-[開発タイトル]/` に requirements/design/tasklist を作ること、命名規則。
2. **プロジェクト固有情報**：確定した技術スタック、ビルド/テスト/lint コマンド、仮想環境の有効化。
3. **仕様の出所（重要）**：「本プロジェクトの仕様の真の情報源は FieldSpec OS の案件
   `<projectId>`（顧客: <…> / 案件: <…>）であり、`fieldspec-os` MCP の `get_project_spec` で参照・再取得する」旨を明記。
4. **プロセス参照**：「開発プロセスの詳細は `$dev-docs`、仕様の再取得は `$fsos-dev` に従う」の1〜2行。

## ステップ 4：README.md の生成

`product-requirements.md` と `architecture.md` を基に、プロダクト概要・目的・主要機能・セットアップ/実行手順・
仕様の参照先（FieldSpec OS 案件 id と MCP）を README にまとめる。

## ステップ 5：ステアリング初期化と実装

`$dev-docs` の「初回セットアップ」に準じ、`.steering/<YYYYMMDD>-initial-implementation/` に
requirements/design/tasklist を作成（日付は `date +%Y%m%d` で取得）。以降の実装は tasklist に従う。

## 生成ルール（品質・トレーサビリティ）

- **SSOT はあくまで FieldSpec OS の仕様**。docs には根拠の ID（BIZ-xxx / FR-xxx / AC-xxx / Q-xxx）を保持し、
  仕様のどの項目に由来するか辿れるようにする（例：機能要件に対応 FR-ID、受け入れ条件に AC-ID を併記）。
- **捏造しない**。仕様に無い数値・固有名詞を作らない。未確定な点は `openQuestions`（Q-xxx）を「未確定論点」として
  そのまま docs に転記し、「（要確認）」と明記する。ヒアリングの「（要確認）」も踏襲する。
- **段階承認**：各永続ドキュメントは作成→承認→次、を守る（`$add-feature` 経由なら一括承認でよい）。
- **アーキテクチャ原則**：`architecture.md` / `functional-design.md` / `repository-structure.md` /
  `development-guidelines.md` は、`$dev-docs`「アーキテクチャ原則」（ドメイン分割・単一責任・一方向依存・疎結合・
  依存性逆転）を**文書上で担保**する。責務・依存方向・ポート定義場所・変換規約まで落とし込む。
- **図表**：ER 図・ユースケース図・業務フロー図・画面遷移図は関連する永続ドキュメント内に Mermaid で記載
  （As-Is/To-Be は `businessDesignSummary` を基にフロー図化）。独立した diagrams フォルダは作らない。
- **再生成**：仕様が更新されたら `get_project_spec` を再取得し、影響する docs を更新する（`generatedAt` で鮮度確認）。
- コード変更後は必ず lint・型チェック・関連テストを実施する。

## 完了時の報告

生成/更新したファイル一覧、参照した案件（id・顧客・案件名・`generatedAt`）、仕様が薄く「（要確認）」で埋めた箇所、
未解決の `openQuestions` を要約して報告する。
