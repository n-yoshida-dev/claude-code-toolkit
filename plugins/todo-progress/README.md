# todo-progress

**English:** A Claude Code plugin that counts the checkboxes in your `TODO.md` per `##` heading and shows a progress table:
progress bars, open/total per phase, tasks left until the release section, and what changed since your last checkpoint.
The table is handed to Claude at every session start (Claude shows it at the top of its first reply), and `/todo-progress:progress` prints it any time.
Heading words for "release", "after release", "on hold" and "waiting" are configurable and match both Japanese and English headings by default.

---

`TODO.md` のチェックボックスを見出し（フェーズ）ごとに数えて、進捗バー・残り件数・公開までの残り・前回の区切りからの増減を表にする Claude Code のプラグインです。
セッションを始めるたびに表を Claude に渡し、Claude が最初の返答の冒頭で見せます。途中で見たいときは `/todo-progress:progress` で出せます。

![Claude の返答に進捗表が表示された画面](../../docs/images/todo-progress.png)

（イメージ。作者の環境での以前の表示で、表の書式・項目・言葉は今の版と一部違います。今の版の出力は下のとおりです）

```
進捗（TODO.md より自動集計・2026-10-20） / Progress from TODO.md

                     完了率  残り/全体  フェーズ   (done %, open/total, phase)
████████████████████  100%     0 / 2     フェーズ1：設計
█████████████░░░░░░░   66%     1 / 3     フェーズ2：最初の画面を 1 つ通す
░░░░░░░░░░░░░░░░░░░░    0%     2 / 2     フェーズ3：公開
███████████░░░░░░░░░   57%     3 / 7     合計 / Total
公開まで残り 3 件（上から「フェーズ3：公開」の節まで） / 3 open until release
回答待ち：1 件（回答済み 0 件） / Waiting: 1 open, 0 answered
公開後（合計に含めない）：1 件（済み 0 件） / After release (not in total): 1 open, 0 done

前回の区切り（2026-10-20）から：完了 +1 件、タスクの数 +1 件 / Since last checkpoint (2026-10-20): done +1, tasks +1
```

## 入っているもの

| 種類 | 名前 | いつ動くか | すること |
|---|---|---|---|
| フック | SessionStart | セッションの開始・再開・`/clear`・要約のあと | 進捗表と、先頭レベルの未完タスク（公開の節の分を先に）を最大 12 件、Claude に渡す |
| スキル | `/todo-progress:progress` | 呼んだとき。「どこまで進んだ？」と聞いたときも Claude が使う | 進捗表を出し、次に着手するタスクを 1〜3 行で添える |

## 導入

Claude Code のセッションの中で：

```
/plugin marketplace add n-yoshida-dev/claude-code-toolkit
/plugin install todo-progress@yoshida-toolkit
```

ターミナルからなら：

```bash
claude plugin marketplace add n-yoshida-dev/claude-code-toolkit
claude plugin install todo-progress@yoshida-toolkit
```

チームで使うリポジトリなら、`.claude/settings.json` に書いておくと、フォルダを信頼したときに入れるよう案内が出ます。

```json
{
  "extraKnownMarketplaces": {
    "yoshida-toolkit": {
      "source": { "source": "github", "repo": "n-yoshida-dev/claude-code-toolkit" }
    }
  },
  "enabledPlugins": {
    "todo-progress@yoshida-toolkit": true
  }
}
```

## なぜ作ったか

Claude Code で個人開発を続けていると、セッションを開くたびに「どこまで進んだか」を自分で TODO.md から読み直すか、Claude に読ませて数えさせることになります。
Claude に数えさせると、字下げした子項目の数え漏れや、保留にした項目を残りに入れてしまう間違いが起きます。
そこで、数えるのはスクリプトに任せ、その結果を毎回同じ形で最初に見せるようにしました。

## どんな人におすすめか

- Claude Code で、`TODO.md` にチェックボックス（`- [ ]` / `- [x]`）でタスクを書きながら開発している
- セッションをまたいで作業を続けることが多く、開いた直後に現在地を知りたい
- 「公開まで」と「公開のあとでよい改善」を分けて、公開が後回しにならないようにしたい

## 機能

- **フェーズ別の進捗バー**：`## ` の見出しを 1 フェーズとして数えます。`### ` 以下の小見出しは親のフェーズに含め、字下げした子項目も 1 件と数えます
- **公開まで残り**：見出しに「公開」（既定）を含む最初のフェーズを公開の節とし、TODO の上からその節までの未完を数えます。公開の節が無ければこの行は出ません
- **別枠の節**：見出しに「公開後」「保留」「確認待ち」（既定）を含む節は合計に入れず、件数だけを別の行に出します
- **前回の区切りから**：`HANDOFF.md`（既定）を最後にコミットした時点の TODO.md と比べて、完了した数と新しく増えたタスクの数を出します。
  区切りのあとに TODO.md を変えていなければ、ひとつ前の区切りと比べて前回のセッション分を出します。Git で管理していないフォルダでは出ません
- **タスク未定義のフェーズ**：チェックボックスが 0 件のフェーズは「タスク未定義」と出し、100% でも後ろに段階が残っていることを見せます

## 使い方

- 何もしなくても、セッションを始めると Claude が最初の返答の冒頭に表を貼ります
- 途中で見たいときは `/todo-progress:progress` を実行するか、「どこまで進んだ？」と聞きます
- 1 タスクの大きさを揃える（たとえば PR 1 本ずつ）と、件数が進み具合の目安になります

TODO.md の書き方の例：

```markdown
## フェーズ1：設計
- [x] 何を作るかを書く

## フェーズ2：最初の画面を 1 つ通す
- [ ] 一覧の画面
  - [ ] 並べ替え          ← 子項目も 1 件と数える

## フェーズ3：公開         ← 「公開」を含む最初の見出し。ここまでの未完が「公開まで残り」
- [ ] GitHub Pages に出す

## 公開後の改善            ← 合計に入れず別枠
- [ ] ダークモード

## 確認待ち                ← あなたの回答待ちとして別枠
- [ ] アプリの名前を決める
```

## 設定

何も設定しなければ、下の既定値で動きます。変えるときは `/plugin` で todo-progress を選び、Configure options から変えます。
見出し語はカンマ区切りで複数書け、大文字と小文字は区別しません。ターミナルからなら次のように変えられます（書かなかった設定はそのまま）。

```bash
echo '{"release_words":"リリース,Release"}' | claude plugin configure todo-progress@yoshida-toolkit --values-stdin
```

| 設定 | 既定値 | 意味 |
|---|---|---|
| `todo_file` | `TODO.md` | プロジェクトのルートからの TODO のファイル |
| `checkpoint_file` | `HANDOFF.md` | このファイルの最後のコミットと比べて増減を出す。空にすると増減の行を出さない |
| `release_words` | `公開,Release` | 公開の節の見出し語 |
| `after_release_words` | `公開後,After release,Post-release` | 公開後の節の見出し語（合計に入れない） |
| `hold_words` | `保留,On hold` | 保留の節の見出し語（合計に入れない） |
| `waiting_words` | `確認待ち,Waiting` | 回答待ちの節の見出し語（合計に入れない） |

## 事例

作者は個人開発の 7 つのリポジトリで、このプラグインの元になった版（同じ集計）を使っています。
作者のセッション記録の集計では、2026-08-22〜10-18 の 58 日間に、セッション開始時の表が 84 回出ました。
たとえば次のような TODO.md を、開くたびに 1 枚の表で見ています。

- タスクが 100 件を超え、フェーズが 6 つ以上ある TODO.md
- 「確認待ち」（作者の判断を待つ問い）と「保留」（急がない持ち越し）の節を別に持ち、残りの件数に混ぜない TODO.md

## このプラグインが実行するもの

フックは、あなたの権限でシェルスクリプトを実行します。中身は次のとおりです。

- **読むもの**：プロジェクトの `TODO.md`（設定したファイル）、フックに渡される入力（JSON）の `cwd`、
  Git の情報（`git rev-parse` でリポジトリのルート、`git log` / `git show` で区切りのファイルと TODO.md の過去の版）
- **書くもの**：なし（ファイルを作ったり書き換えたりしません）
- **送るもの・取りに行くもの**：なし（ネットワークに接続しません）
- **使うコマンド**：`bash`・`awk`・`sed`・`grep`・`head`・`tail`・`cmp`・`cat`・`dirname`・`date`・`git`、あれば `jq`
- 実行時に動くのは [scripts/](scripts/) の `config.sh`・`progress.sh`・`session-start.sh` の 3 本です（`test-progress.sh` は開発用のテスト）
- TODO.md が無いフォルダでは何も出さずに終わります

## 更新

```bash
claude plugin marketplace update yoshida-toolkit
claude plugin update todo-progress@yoshida-toolkit
```

更新は、開き直したセッションから効きます。

## 開発

```bash
bash plugins/todo-progress/scripts/test-progress.sh   # 回帰テスト
claude plugin validate plugins/todo-progress --strict
```

## License

[MIT](LICENSE)
