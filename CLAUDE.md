# claude-code-toolkit

公開用の Claude Code プラグイン集（マーケットプレイス名 `yoshida-toolkit`）。利用者は他人なので、README と出力は利用者が読んで分かる言葉で書く。

## 構成

- `.claude-plugin/marketplace.json` — 公開しているプラグインの一覧。プラグインを増やしたらここに足す
- `plugins/<name>/` — プラグイン本体。`.claude-plugin/plugin.json` / `hooks/hooks.json` / `scripts/` / `skills/<skill>/SKILL.md` / `README.md` / `LICENSE`
- 単体のスキルを出すときは `skills/<name>/` に平置きし、`marketplace.json` で束ねる（まだ無い）

## 守ること

- **個人の事情を入れない。** 固定パス・見出し語・個人のルールは `userConfig` に出す。絶対パス・実名以外の個人情報・作者の作業記録（logs・引き継ぎ）はコミットしない
- **言語**：README は日本語＋冒頭に英語 1 段落。フックの出力は日英併記。スキル本文は日本語
- **フックの処理はシェルスクリプトに置き、`hooks.json` は登録だけにする。** スクリプトを単体で叩いて試せる形を保つ
- **フックは、プロジェクトに無いもの（TODO.md など）を黙って飛ばす。** エラーを出さない
- **`userConfig` の値**：フックには `CLAUDE_PLUGIN_OPTION_<キーの大文字>` の環境変数で届く。スキル本文では `${user_config.<キー>}` が置き換わる（Bash ツールで動くコマンドには環境変数が届く保証が無いので、引数で渡す）
- **利用者に届ける変更は `plugin.json` の `version` を上げる。** 上げないと届かない
- **README に「このプラグインが実行するもの」（読む・書く・送るもの）を書く。** フックは利用者の権限で動くため
- 変更したら CI と同じ検査を回す：JSON（`jq empty`）、`bash -n` と shellcheck（手元は `npx --yes shellcheck <ファイル>`）、`plugins/*/scripts/test-*.sh`、
  `claude plugin validate . --strict` と `claude plugin validate plugins/<name> --strict`
- プラグイン名は `claude-`・`anthropic-` で始めない。名前は公開後に変えにくい
- コメントは日本語で書く。関数には役割のコメントを付ける
