#!/usr/bin/env bash
# 設定の読み込み — progress.sh と session-start.sh が source する
#
# 値は、利用者が userConfig（plugin.json）に入れたものを使う。届き方は 2 通り：
#   - フックから呼ばれたとき：Claude Code が CLAUDE_PLUGIN_OPTION_<キーの大文字> の環境変数で渡す
#   - /todo-progress:progress から呼ばれたとき：スキル本文の ${user_config.<キー>} が置き換わり、`キー=値` の引数で渡る
#     （Bash ツールで動くコマンドには環境変数が届く保証が無いため）
# 未設定・空のときは既定値を使う。既定値は日本語と英語の見出しの両方に当たるようにしてある。
# 見出し語はカンマ区切りで複数書ける。大文字と小文字は区別しない。
# shellcheck disable=SC2034  # ここで決めた変数は source した側で使う

# `キー=値` の引数を CLAUDE_PLUGIN_OPTION_<キー> に写し、それ以外の引数（プロジェクトのディレクトリ）を TP_ARGS に残す
TP_ARGS=()
for tp_arg in "$@"; do
  if [[ "$tp_arg" =~ ^([a-z_]+)=(.*)$ ]]; then
    tp_value="${BASH_REMATCH[2]}"
    # 置き換えが効かなかった ${user_config.…} の文字列は、未設定として扱う
    # shellcheck disable=SC2016  # ${user_config.…} は展開させずに文字列として比べる
    [[ "$tp_value" == '${user_config.'* ]] && continue
    export "CLAUDE_PLUGIN_OPTION_${BASH_REMATCH[1]^^}=$tp_value"
  else
    TP_ARGS+=("$tp_arg")
  fi
done
unset tp_arg tp_value

TP_TODO_FILE="${CLAUDE_PLUGIN_OPTION_TODO_FILE:-TODO.md}"
# 区切りのファイルだけは、空にすると「前回の区切りから」の行を出さない（未設定なら既定値）
TP_CHECKPOINT_FILE="${CLAUDE_PLUGIN_OPTION_CHECKPOINT_FILE-HANDOFF.md}"
TP_RELEASE_WORDS="${CLAUDE_PLUGIN_OPTION_RELEASE_WORDS:-公開,Release}"
TP_AFTER_WORDS="${CLAUDE_PLUGIN_OPTION_AFTER_RELEASE_WORDS:-公開後,After release,Post-release}"
TP_HOLD_WORDS="${CLAUDE_PLUGIN_OPTION_HOLD_WORDS:-保留,On hold}"
TP_WAITING_WORDS="${CLAUDE_PLUGIN_OPTION_WAITING_WORDS:-確認待ち,Waiting}"

# 見出しの種類を決める awk の関数。tp_awk で呼ぶと WAITING・HOLD・AFTER・RELEASE（見出し語のカンマ区切り）が渡る
#   kind_of(見出し)    → "ask"（確認待ち）／"hold"（保留）／"after"（公開後）／"phase"（ふつうのフェーズ）
#   is_release(見出し) → ふつうのフェーズで、公開の見出し語を含むか
# 「公開後」は「公開」を含むので、公開の判定より先に見る
TP_AWK_LIB='
function has_word(s, list,    n, i, w, parts) {
  n = split(list, parts, ",")
  for (i = 1; i <= n; i++) {
    w = parts[i]; gsub(/^[ \t]+|[ \t]+$/, "", w)
    if (w != "" && index(tolower(s), tolower(w)) > 0) return 1
  }
  return 0
}
function kind_of(s) {
  if (has_word(s, WAITING)) return "ask"
  if (has_word(s, HOLD)) return "hold"
  if (has_word(s, AFTER)) return "after"
  return "phase"
}
function is_release(s) { return kind_of(s) == "phase" && has_word(s, RELEASE) }
'

# 見出し語と上の関数を付けて awk を動かす。使い方： tp_awk 'awk のプログラム' [ファイル]
tp_awk() {
  local program="$1"; shift
  awk -v WAITING="$TP_WAITING_WORDS" -v HOLD="$TP_HOLD_WORDS" -v AFTER="$TP_AFTER_WORDS" -v RELEASE="$TP_RELEASE_WORDS" \
    "$TP_AWK_LIB$program" "$@"
}
