#!/usr/bin/env bash
# 進捗表（progress.sh）と起動時の知らせ（session-start.sh）の回帰テスト
#
# 使い方： bash test-progress.sh
# 見本の TODO.md を一時フォルダに作って 2 本を動かす
# 確かめること：「公開まで残り」が公開の節とその上の節の未完を数えるか（公開の節の後ろと「公開後」は数えない）、
#               「公開後」「保留」「確認待ち」の節が合計から外れるか、公開の節が無ければ「公開まで残り」を出さないか、
#               起動時の一覧が公開の節の未完を見出しを分けて先に出すか、英語の見出しと利用者が変えた見出し語でも同じに数えるか、
#               `キー=値` の引数で設定を渡せるか、前回の区切りからの増減を出すか
# 出力：  1 件ごとに ok / NG。NG が 1 件でもあれば exit 1
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRESS="$SCRIPT_DIR/progress.sh"
BRIEFING="$SCRIPT_DIR/session-start.sh"
failures=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 利用者の環境の設定がテストに混ざらないようにする
unset CLAUDE_PLUGIN_OPTION_TODO_FILE CLAUDE_PLUGIN_OPTION_CHECKPOINT_FILE CLAUDE_PLUGIN_OPTION_RELEASE_WORDS \
  CLAUDE_PLUGIN_OPTION_AFTER_RELEASE_WORDS CLAUDE_PLUGIN_OPTION_HOLD_WORDS CLAUDE_PLUGIN_OPTION_WAITING_WORDS CLAUDE_PROJECT_DIR

# 結果を 1 行で出し、NG を数える
check() {
  local name="$1"; shift
  if "$@"; then
    echo "ok  $name"
  else
    echo "NG  $name"
    failures=$((failures + 1))
  fi
}

# 出力に指定の文字列があるか
has() { grep -qF -- "$2" <<< "$1"; }
# 出力に指定の文字列が無いか
lacks() { ! grep -qF -- "$2" <<< "$1"; }

# 雛形の並び（設計 → 最初の画面 → 公開 → 公開後 → 確認待ち）。公開の後ろに、公開後でない節も 1 つ置く
mkdir -p "$WORK/ordered"
cat > "$WORK/ordered/TODO.md" <<'EOF'
# TODO

## フェーズ1：設計

- [x] PLAN.md を書く
- [ ] SPEC.md を書く
  - [ ] 子項目も数える

## フェーズ2：最初の画面を 1 つ通す

- [ ] 画面の骨組み

## フェーズ3：公開

- [ ] Pages に出す
- [x] README を書く

## フェーズ4：公開のあとに足す機能

- [ ] 公開の節の後ろなので「公開まで」には数えない

## 公開後の改善

- [ ] 色を直す
- [x] 余白を直す

## 小さな候補（保留）

- [ ] いつか

## 確認待ち

- [ ] 名前を決める
EOF

OUT=$(bash "$PROGRESS" "$WORK/ordered")
check "公開まで残り：公開の節とその上の未完（子項目を含む 4 件）を数える" has "$OUT" "公開まで残り 4 件（上から「フェーズ3：公開」の節まで） / 4 open until release"
check "合計：公開後・保留・確認待ちを外し、公開の後ろの節は入れる（未完 5 / 7）" has "$OUT" "   5 / 7     合計 / Total"
check "フェーズの行：未完 / 全体と名前" has "$OUT" "   2 / 3     フェーズ1：設計"
check "公開後の節を別枠で出す" has "$OUT" "公開後（合計に含めない）：1 件（済み 1 件） / After release (not in total): 1 open, 1 done"
check "公開後の節をフェーズの行に出さない" lacks "$OUT" "公開後の改善"
check "保留の節を別枠で出す" has "$OUT" "保留（合計に含めない）：1 件（済み 0 件）"
check "確認待ちの節を別枠で出す" has "$OUT" "回答待ち：1 件（回答済み 0 件）"
check "コードブロックで囲む" test "$(head -n 1 <<< "$OUT")" = '```'

BRIEF=$(CLAUDE_PROJECT_DIR="$WORK/ordered" bash "$BRIEFING")
FIRST=$(grep -m 1 '(TODO.md:' <<< "$BRIEF")
check "起動時：進捗表を含む" has "$BRIEF" "公開まで残り 4 件"
check "起動時：最初の返答に貼る指示を日英で出す" has "$BRIEF" "Paste this progress table"
check "起動時の一覧：公開の節の未完を先頭に出す" has "$FIRST" "Pages に出す"
check "起動時の一覧：公開の節の見出しを分けて出す" has "$BRIEF" "### 公開の節（フェーズ3：公開）の未完 1 件"
check "起動時の一覧：ほかの未完は別の見出しで上から出す" has "$BRIEF" "### ほかの未完タスク（先頭レベルのみ。未完は全部で 7 件）。上から 11 件まで"
check "起動時の一覧：公開の節のタスクを二度出さない" test "$(grep -c 'Pages に出す' <<< "$BRIEF")" -eq 1
SECOND=$(grep '(TODO.md:' <<< "$BRIEF" | sed -n 2p)
check "起動時の一覧：ほかの未完の先頭は TODO の上から" has "$SECOND" "(TODO.md:6) SPEC.md を書く"
check "起動時の一覧：子項目は一覧に出さない" lacks "$BRIEF" "子項目も数える"

# 公開の節が末尾にある並び。公開の節の未完は先に出し、「公開まで」は全部を数える
mkdir -p "$WORK/old"
cat > "$WORK/old/TODO.md" <<'EOF'
## フェーズ1：実装

- [ ] 機能 A
- [ ] 機能 B

## フェーズ2：公開・記事化

- [ ] 公開する
EOF
OUT=$(bash "$PROGRESS" "$WORK/old")
check "公開の節が末尾：公開まで残りは上の節を含めて数える" has "$OUT" "公開まで残り 3 件"
BRIEF=$(CLAUDE_PROJECT_DIR="$WORK/old" bash "$BRIEFING")
FIRST=$(grep -m 1 '(TODO.md:' <<< "$BRIEF")
check "公開の節が末尾：その未完を先頭に出す" has "$FIRST" "(TODO.md:8) 公開する"

# 公開の節が無い TODO。公開まで残りは出さない
mkdir -p "$WORK/none"
cat > "$WORK/none/TODO.md" <<'EOF'
## フェーズ1：実装

- [x] 機能 A
- [ ] 機能 B

## 公開後の改善

- [ ] 色を直す
EOF
OUT=$(bash "$PROGRESS" "$WORK/none")
check "公開の節が無ければ（公開後だけでも）公開まで残りを出さない" lacks "$OUT" "公開まで残り"
check "公開の節が無くても表は出す（未完 1 / 2）" has "$OUT" "   1 / 2     合計 / Total"
BRIEF=$(CLAUDE_PROJECT_DIR="$WORK/none" bash "$BRIEFING")
check "公開の節が無ければ一覧の見出しは 1 つ" has "$BRIEF" "### 未完タスク（先頭レベルのみ）2 件。上から 12 件まで"
check "公開の節が無ければ公開の節の見出しを出さない" lacks "$BRIEF" "### 公開の節"

# 英語の見出し。既定の見出し語は英語にも当たる（大文字と小文字は区別しない）
mkdir -p "$WORK/english"
cat > "$WORK/english/TODO.md" <<'EOF'
## Phase 1: Design

- [x] Write the plan
* [ ] Write the spec

## Phase 2: release

- [ ] Deploy

## After release

- [ ] Polish

## On hold

- [ ] Someday

## Waiting for answers

- [ ] Pick a name
EOF
OUT=$(bash "$PROGRESS" "$WORK/english")
check "英語：公開の節を見つける（* の箇条書きも数える）" has "$OUT" "2 open until release"
check "英語：合計（未完 2 / 3）" has "$OUT" "   2 / 3     合計 / Total"
check "英語：After release を別枠にする" has "$OUT" "After release (not in total): 1 open, 0 done"
check "英語：On hold を別枠にする" has "$OUT" "On hold (not in total): 1 open, 0 done"
check "英語：Waiting を別枠にする" has "$OUT" "Waiting: 1 open, 0 answered"

# 利用者が見出し語と TODO のファイル名を変えたとき（フックには環境変数で届く）
mkdir -p "$WORK/custom"
cat > "$WORK/custom/tasks.md" <<'EOF'
## 準備

- [ ] 下調べ

## リリース

- [ ] 出す

## いつか

- [ ] 余裕があれば
EOF
OUT=$(CLAUDE_PLUGIN_OPTION_TODO_FILE=tasks.md CLAUDE_PLUGIN_OPTION_RELEASE_WORDS="リリース" CLAUDE_PLUGIN_OPTION_HOLD_WORDS="いつか" \
  bash "$PROGRESS" "$WORK/custom")
check "変えた見出し語：公開の節を見つける" has "$OUT" "公開まで残り 2 件（上から「リリース」の節まで）"
check "変えた見出し語：保留の節を別枠にする" has "$OUT" "保留（合計に含めない）：1 件"
check "変えたファイル名：見出しに出す" has "$OUT" "Progress from tasks.md"
BRIEF=$(CLAUDE_PROJECT_DIR="$WORK/custom" CLAUDE_PLUGIN_OPTION_TODO_FILE=tasks.md CLAUDE_PLUGIN_OPTION_RELEASE_WORDS="リリース" bash "$BRIEFING")
check "変えたファイル名：起動時の一覧の行番号に出す" has "$BRIEF" "(tasks.md:7) 出す"

# スキルからは `キー=値` の引数で届く。置き換えが効かなかった ${user_config.…} は未設定として扱う
# shellcheck disable=SC2016  # ${user_config.…} は展開させずにそのまま渡す
OUT=$(cd "$WORK/custom" && bash "$PROGRESS" todo_file=tasks.md release_words=リリース 'hold_words=${user_config.hold_words}')
check "引数の設定：公開の節を見つける" has "$OUT" "公開まで残り 2 件"
check "引数の設定：置き換わっていない値は既定値に戻す（いつか は保留にならない）" lacks "$OUT" "保留"

# 前回の区切りから。区切りのファイル（HANDOFF.md）をコミットした時点の TODO.md と比べる
mkdir -p "$WORK/git"
git -C "$WORK/git" init -q
git -C "$WORK/git" config user.email test@example.com
git -C "$WORK/git" config user.name test
printf '## 作業\n\n- [ ] A\n- [ ] B\n' > "$WORK/git/TODO.md"
echo "区切り" > "$WORK/git/HANDOFF.md"
git -C "$WORK/git" add TODO.md HANDOFF.md
git -C "$WORK/git" commit -q -m "区切り 1"
printf '## 作業\n\n- [x] A\n- [ ] B\n- [ ] C\n' > "$WORK/git/TODO.md"
OUT=$(bash "$PROGRESS" "$WORK/git")
check "区切りから：完了と新しいタスクの増減を出す" has "$OUT" "完了 +1 件、新たに見つかったタスク +1 件 / Since last checkpoint"
OUT=$(CLAUDE_PLUGIN_OPTION_CHECKPOINT_FILE="" bash "$PROGRESS" "$WORK/git")
check "区切りのファイルを空にすると、増減の行を出さない" lacks "$OUT" "Since last checkpoint"

# TODO.md が無いフォルダでは、どちらも何も出さない
mkdir -p "$WORK/empty"
check "TODO.md が無ければ進捗表は何も出さない" test -z "$(bash "$PROGRESS" "$WORK/empty")"
check "TODO.md が無ければ起動時の知らせも何も出さない" test -z "$(CLAUDE_PROJECT_DIR="$WORK/empty" bash "$BRIEFING")"

if [ "$failures" -gt 0 ]; then
  echo "NG が $failures 件"
  exit 1
fi
echo "すべて ok"
