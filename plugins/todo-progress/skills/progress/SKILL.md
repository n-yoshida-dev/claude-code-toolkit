---
name: progress
description: TODO.md のチェックボックスを見出し（フェーズ）ごとに数え、進捗バー・残り件数・公開までの残り・前回の区切りからの増減を表にして見せる。「どこまで進んだ？」「残りはどれくらい？」「あと何が残ってる？」「公開まであと何件？」と聞かれたとき、作業の区切りで進み具合を報告するとき、引き継ぎの文書に進捗を書くときは、TODO.md を自分で読んで数える前にこのスキルを使う。Use this whenever the user asks how far along the project is, what is left, or wants a progress summary from TODO.md.
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/progress.sh:*)
---

# 進捗表を出す

TODO.md を Claude が目で数えると、子項目の数え漏れや、保留・回答待ちの節を合計に入れてしまう間違いが起きる。
集計は決まった規則で動くスクリプトに任せ、Claude は出力をそのまま見せる。

## やること

1. Bash ツールで次のコマンドを**このまま**実行する（TODO.md を読んで集計するだけで、何も書き換えない）。

   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/progress.sh todo_file='${user_config.todo_file}' checkpoint_file='${user_config.checkpoint_file}' release_words='${user_config.release_words}' after_release_words='${user_config.after_release_words}' hold_words='${user_config.hold_words}' waiting_words='${user_config.waiting_words}'
   ```

   `${…}` の部分は、スキルの読み込み時にプラグインの置き場所と利用者の設定に置き換わる。
   `${CLAUDE_PLUGIN_ROOT}` が置き換わらずに残っているときや、ファイルが無いときは、
   `ls ~/.claude/plugins/cache/*/todo-progress/*/scripts/progress.sh` で探し、いちばん新しい版のものを同じ引数で実行する。
   `${user_config.…}` が置き換わらずに残っていても、スクリプトがその値を既定値に戻すので、そのまま実行してよい

2. 出力された表を、返答の冒頭に**コードブロックのまま**貼る。数値を書き換えない・要約しない・並べ替えない
   （利用者は毎回同じ形の表で進み具合を見比べるため）。出力が空なら、このプロジェクトに TODO.md が無いと伝える

3. そのあと 1〜3 行だけ補足する。

   - 残りが最も多いフェーズと、その中で次に着手するタスク
   - 「公開まで残り」の行があれば、その件数と、公開の節で次に着手するタスク
   - 「回答待ち」が 1 件以上なら、次に動くのは利用者であること
   - 「タスク未定義」のフェーズがあれば、そのフェーズはタスクを書いてから件数が出ること

## 表の読み方（利用者に聞かれたら）

- 件数は工数ではない。1 タスクの大きさを揃える（たとえば PR 1 本ずつ）と意味を持つ
- 「新たに見つかったタスク」が増えると、完了しても率は上がらない。バーが動かない理由はここに出る
- 「保留」「公開後」は合計に含めない。「回答待ち」は利用者の回答待ちで、Claude では進められない
- 「公開まで残り」は、TODO の上から「公開」を含む最初の見出しの節までにある未完の数。上の節が終わらないと公開できないので、それも数える
- 見出し語・TODO のファイル名・区切りのファイルは、プラグインの設定（`/plugin` の todo-progress の Configure options）で変えられる
