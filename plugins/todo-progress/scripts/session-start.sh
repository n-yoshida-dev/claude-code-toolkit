#!/usr/bin/env bash
# SessionStart フック — 進捗表と TODO.md の未完タスクを Claude の context に流し込む
#
# stdout に書いた内容が Claude の context に入る（ユーザーの画面には出ないので、進捗表を最初の返答に貼るよう Claude に頼む）。
# 未完一覧は先頭レベルの `- [ ]` だけを出す。進捗表（progress.sh）は字下げした子項目も数えるので、件数は一致しないことがある。
# 公開の節（見出しに「公開」を含む最初のフェーズ）の未完は、見出しを分けて先に出す。公開の節が TODO の末尾にあっても目に入るようにするため。
# 見出しを分けるのは、着手の順（上から）と取り違えないようにするため。
# context を圧迫しないよう、一覧は合わせて 12 件までにする。
#
# 進捗表の集計は progress.sh（同じディレクトリ）が行う。ここは呼ぶだけ。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # config.sh は同じフォルダにある。CI は -x なしで回すので中までは追わない
. "$HERE/config.sh"

# 読むプロジェクトを決める。フックの入力（標準入力の JSON）の cwd を優先する。
# worktree に入ったセッションでは、/clear・再開・要約のあとも CLAUDE_PROJECT_DIR が元のフォルダを指したままで、cwd だけが今の作業フォルダを指すため。
# cwd とその Git のルートに TODO.md が無ければ、CLAUDE_PROJECT_DIR（無ければカレントディレクトリ）を使う
hook_cwd() {
  [ -t 0 ] && return 0
  local input
  input="$(cat)"
  if command -v jq >/dev/null 2>&1; then
    jq -r '.cwd // empty' <<< "$input" 2>/dev/null || true
  else
    sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' <<< "$input" | head -n 1
  fi
}
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CWD="$(hook_cwd)"
if [ -n "$CWD" ] && [ -d "$CWD" ]; then
  for candidate in "$CWD" "$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)"; do
    if [ -n "$candidate" ] && [ -f "$candidate/$TP_TODO_FILE" ]; then
      PROJECT_DIR="$candidate"
      break
    fi
  done
fi
TODO="$PROJECT_DIR/$TP_TODO_FILE"
[ -f "$TODO" ] || exit 0

LIMIT=12

echo "## セッション開始時の状況（$TP_TODO_FILE より自動抽出） / Session start: status from $TP_TODO_FILE"
echo
echo "### 進捗 / Progress"
echo
bash "$HERE/progress.sh" "$PROJECT_DIR"
echo
echo "**この進捗表は、最初の返答の冒頭にコードブロックのまま貼ってユーザーに見せること。** 数値を書き換えたり要約したりしない（フックの出力はユーザーの画面に出ないため）。"
echo "**Paste this progress table, unchanged and as a code block, at the top of your first reply.** Hook output is not shown to the user."
echo

# 先頭レベルの未完を「R:行番号:行」（公開の節）か「O:行番号:行」（ほか）の形で上から出し、最後の行に公開の節の見出し（無ければ空）を出す
TAGGED=$(tp_awk '
  /^## / {
    s = $0; sub(/^## +/, "", s)
    in_release = (name == "" && is_release(s))
    if (in_release) name = s
    next
  }
  /^[-*+] \[ \]/ { print (in_release ? "R" : "O") ":" NR ":" $0 }
  END { print "release=" name }
' "$TODO")
RELEASE_NAME=$(printf '%s\n' "$TAGGED" | tail -n 1 | sed 's/^release=//')
RELEASE_TASKS=$(printf '%s\n' "$TAGGED" | sed -n 's/^R://p' | head -n "$LIMIT")
OTHER_TASKS=$(printf '%s\n' "$TAGGED" | sed -n 's/^O://p')
TOTAL=$(printf '%s\n' "$TAGGED" | grep -c '^[RO]:')

# 「行番号:- [ ] 本文」を「  - (TODO.md:行番号) 本文」にする
format_tasks() {
  awk -v f="$TP_TODO_FILE" '{
    n = index($0, ":"); rest = substr($0, n + 1); sub(/^[-*+] \[ \] /, "", rest)
    print "  - (" f ":" substr($0, 1, n - 1) ") " rest
  }'
}

# 公開の節の未完を先に、見出しを分けて出す（着手の順ではなく、公開に何が残っているかを見せるため）
if [ -n "$RELEASE_TASKS" ]; then
  RELEASE_COUNT=$(printf '%s\n' "$RELEASE_TASKS" | grep -c .)
  echo "### 公開の節（${RELEASE_NAME}）の未完 ${RELEASE_COUNT} 件 / Open tasks in the release section"
  echo
  printf '%s\n' "$RELEASE_TASKS" | format_tasks
  echo
  LIMIT=$((LIMIT - RELEASE_COUNT))
fi
if [ -n "$OTHER_TASKS" ] && [ "$LIMIT" -gt 0 ]; then
  if [ -n "$RELEASE_TASKS" ]; then
    echo "### ほかの未完タスク（先頭レベルのみ。未完は全部で ${TOTAL} 件）。上から ${LIMIT} 件まで / Other open tasks, first ${LIMIT}"
  else
    echo "### 未完タスク（先頭レベルのみ）${TOTAL} 件。上から ${LIMIT} 件まで / Open tasks, first ${LIMIT} of ${TOTAL}"
  fi
  echo
  printf '%s\n' "$OTHER_TASKS" | head -n "$LIMIT" | format_tasks
  echo
fi
exit 0
