---
name: fix-dev-env-warnings
description: TypeScript/JavaScript プロジェクトの開発環境エラーや警告を診断して修正する。対象は tsconfig, ESLint, Jest, NestJS, npm scripts, module resolution, editor diagnostics, compiler/linter messages など。deprecated compiler options, missing test globals, floating promises, ESM/CommonJS mismatches, missing type definitions のような設定系警告の説明、原因調査、修正を依頼されたときに使う。アプリ機能バグではなく、開発環境・型チェック・Lint・テスト設定の問題に使う。
---

# Fix Dev Env Warnings

## ワークフロー

設定ファイルから優先して診断する。ユーザーに見えている警告文は症状として扱い、どのツールが出している警告か、どの設定ファイルが支配しているかを特定する。

1. 正確な診断メッセージ、対象ファイル、警告を出したコマンドまたはエディタを確認する。
2. `rg --files` でプロジェクト構成を確認し、必要なファイルだけ読む: `package.json`, `tsconfig*.json`, `eslint.config.*`, `.eslintrc*`, `jest*.config.*`, `nest-cli.json`, 報告されたソースファイル。
3. 診断メッセージを担当ツールに対応づける:
   - `tsconfig`, 未知のグローバル名, module resolution, 非推奨 compiler option: TypeScript。
   - `Promises must be awaited`, unsafe `any`, unused vars, parser errors: ESLint / typescript-eslint。
   - `describe`, `it`, `expect`, e2e config, transform errors: Jest または利用中のテストランナー。
   - `Cannot use import statement outside a module`, `ERR_REQUIRE_ESM`: Node の module 形式、`package.json` の `type`、または TypeScript の module 設定。
4. 警告を黙らせるより、古い設定や不要な設定を取り除くことを優先する。非推奨動作に意図的に依存している場合だけ抑制設定を検討する。
5. 既存プロジェクトの慣習に合わせて、最小の設定変更またはコード変更を行う。
6. まず警告を出した最小コマンドで確認し、必要なら `npm run lint`, `npm run test`, `npm run build` などで広めに確認する。

## 修正方針

以下の順で修正を選ぶ。

1. 根本の設定、依存関係、型定義の不足を直す。
2. ルールが妥当なら、コードをルールに合わせる。
3. 意図を明示する。例: 意図的に待たない Promise には `void promiseReturningCall()` を使う。
4. その 1 行だけルールが合わない場合に限り、局所的な ESLint disable を使う。
5. `ignoreDeprecations`, `skipLibCheck`, ESLint ルールの無効化のような広い抑制は、理由が明確な場合だけ使う。

アプリが起動するだけで警告を安全と判断しない。非同期エラー、テストのグローバル型、module 形式の不一致は、CI や実行時の失敗につながりやすい。

## よく見る確認

TypeScript, ESLint, Jest, NestJS の典型的な警告と推奨修正は `references/typescript-eslint-jest.md` を読む。

確認用コマンド:

```bash
rg -n "baseUrl|paths|types|typeRoots|moduleResolution|module|ignoreDeprecations" tsconfig*.json
rg -n "no-floating-promises|parserOptions|projectService|tseslint|jest|globals" eslint.config.* .eslintrc* package.json
rg -n "describe\\(|it\\(|expect\\(|bootstrap\\(|\\.catch\\(|void " src test
```

ファイルが存在せずコマンドが失敗した場合は、結論を急がず対象ファイルを絞る。プロジェクトによって設定ファイル名は異なる。

## 返答方針

原因を短い日本語の段落で説明し、そのまま修正するか、正確なパッチを示す。抑制より根本修正を選ぶ場合は、その理由も短く説明する。検証していない場合は明記する。
