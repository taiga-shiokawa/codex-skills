# TypeScript, ESLint, Jest, NestJS の警告パターン

## TypeScript

### `baseUrl` is deprecated

`paths` や絶対 import が `baseUrl` に依存しているか確認する。

- `baseUrl` が使われていなければ削除する。
- `paths` が使われている場合は、可能なら TypeScript 6 以降の移行方針に合わせる。
- `"ignoreDeprecations": "6.0"` は一時的な互換対応としてだけ使う。

### `Cannot find name 'describe'`, `it`, `expect`

TypeScript からテストランナーのグローバル型が見えていない。

推奨修正:

- Jest プロジェクトなら `@types/jest` が入っているか確認する。
- `types` を明示しているプロジェクトでは、該当 tsconfig に `"types": ["node", "jest"]` を追加する。
- テスト専用 tsconfig がある場合は、本番ビルド用 tsconfig ではなくテスト用 tsconfig に Jest 型を入れる。
- エディタがリポジトリ内の正しい tsconfig を見ているか、テストファイルが include 対象か確認する。

Mocha を使っていないなら `@types/mocha` は入れない。

### Module 形式のエラー

`package.json` の `type`、`compilerOptions.module`、`compilerOptions.moduleResolution`、Jest transform 設定、Node バージョンを確認する。

NestJS スターターでは `module` と `moduleResolution` の整合性を保つ。`nodenext` と CommonJS 前提の古い設定を混ぜる場合は、import 形式と package type を確認してから直す。

## ESLint / typescript-eslint

### `Promises must be awaited...`

Promise を返す関数を呼んでいるが、失敗時の扱いが書かれていない。

推奨修正:

```ts
await task();
```

```ts
task().catch((error) => {
  console.error(error);
});
```

```ts
void intentionallyFireAndForget();
```

NestJS の `main.ts` では、起動失敗を拾うために `catch` を付けるのが基本。

```ts
bootstrap().catch((error) => {
  console.error(error);
  process.exit(1);
});
```

`void bootstrap()` は、起動失敗を意図的に無視する方針がある場合だけ使う。

### Unsafe `any` warnings

値が信頼境界を越えているか確認する。例: request body、環境変数、JSON parse、外部 API のレスポンス。

- DTO、validation、明示的な interface、`unknown` と型 narrowing を優先する。
- 生成コードやフレームワーク都合の例外でない限り、`any` への置き換えやルール無効化は避ける。

## Jest / NestJS Tests

### テストランナーの型

NestJS + Jest プロジェクトでは以下を確認する。

- `@types/jest` が `devDependencies` にある。
- `package.json` または Jest config ファイルに Jest 設定がある。
- e2e テストがある場合は `test/jest-e2e.json` が使われている。
- TypeScript テスト用に `ts-jest` が設定されている。

TypeScript 診断がエディタ上だけで出る場合、Jest 実行設定ではなく tsconfig の見え方が原因のことがある。

### build config がテストを除外している

`tsconfig.build.json` が `test` や `**/*.spec.ts` を除外するのは NestJS では普通。テストのグローバル型を見せるためだけに、本番ビルド用の除外設定を外さない。必要ならテスト用 config やエディタ用 config で対応する。

## 依存関係の確認

まず `package.json` を見る。足りない場合だけ必要な依存を入れる。

```bash
npm install -D @types/jest
npm install -D @types/node
npm install @nestjs/config
```

ネットワーク install が必要で環境上の承認が必要な場合は、実行前に承認を取る。
