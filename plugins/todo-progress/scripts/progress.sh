#!/usr/bin/env bash
# 進捗表 — TODO.md のチェックボックスをフェーズ（## 見出し）ごとに数え、進捗バーと残り件数を出す
#
# 使い方： bash progress.sh [プロジェクトのディレクトリ] [キー=値 ...]
#          ディレクトリの省略時は $CLAUDE_PROJECT_DIR、それも無ければカレントディレクトリ。キー=値は config.sh を参照
# 呼び元： SessionStart フック（session-start.sh）、/todo-progress:progress
# 出力：  Markdown のコードブロック 1 つ。そのまま画面や引き継ぎの文書に貼れる形。TODO.md が無ければ何も出さない
#
# 数え方（見出し語は userConfig で変えられる。下の「 」は既定値の日本語）：
#   - `## ` 見出しを 1 フェーズとする。`### ` 以下の小見出しは親フェーズに含める
#   - `- [x]` を完了、`- [ ]` を未完として数える（`*` `+` の箇条書きも同じ）。字下げした子項目も 1 件と数える
#   - 見出しに「確認待ち」「保留」「公開後」を含む節は、合計に入れず別枠で出す
#   - 見出しに「公開」を含む最初のフェーズを公開の節とし、TODO の上からその節までの未完を「公開まで残り」として出す。
#     上の節（設計・最初の画面）が終わらないと公開できないので、それも数える。公開の節が無ければこの行は出さない
#   - タスクが 0 件のフェーズは「タスク未定義」と表示し、合計の隣に数を添える（100% でも後ろに未定義の段階が残ることを見せる）
#   - 「前回の区切りから」は、区切りのファイル（既定 HANDOFF.md）を最後にコミットした時点の TODO.md と比べる。
#     区切り以降に TODO.md が変わっていなければ（セッション開始直後など）、ひとつ前の区切りと比べて前回のセッション分を出す
#
# 件数は工数ではない。1 タスクの大きさを揃えて（たとえば PR 1 本ずつ）使うと意味を持つ。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # config.sh は同じフォルダにある。CI は -x なしで回すので中までは追わない
. "$HERE/config.sh"

DIR="${TP_ARGS[0]:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
TODO="$DIR/$TP_TODO_FILE"
[ -f "$TODO" ] || exit 0

# フェーズ別に集計して表を描く。フェーズ名は全角で幅が揃わないので行末に置く
render_table() {
  tp_awk '
    function bar(d, t,    f, k, s) {
      f = (t > 0) ? int(W * d / t) : 0; s = ""
      for (k = 0; k < W; k++) s = s (k < f ? "█" : "░")
      return s
    }
    function pct(d, t) { return (t > 0) ? int(100 * d / t) : 0 }
    function register(s) { if (!(s in seen)) { seen[s] = 1; order[++n] = s } }
    BEGIN { W = 20; kind = "phase"; sec = "（見出しなし / no heading）"; release = "" }
    /^## / {
      # 公開の節を抜けたら、そこから後ろの未完は「公開まで残り」に数えない
      if (in_release) past_release = 1
      sec = $0; sub(/^## +/, "", sec)
      kind = kind_of(sec)
      in_release = 0
      if (kind == "phase") {
        register(sec)
        if (release == "" && is_release(sec)) { release = sec; in_release = 1 }
      }
      next
    }
    /^[ \t]*[-*+] \[[xX]\]/ {
      if (kind == "ask") ask_done++; else if (kind == "hold") hold_done++; else if (kind == "after") after_done++; else { register(sec); done[sec]++ }
      next
    }
    /^[ \t]*[-*+] \[ \]/ {
      if (kind == "ask") ask_open++; else if (kind == "hold") hold_open++; else if (kind == "after") after_open++; else { register(sec); open[sec]++; if (!past_release) release_open++ }
      next
    }
    END {
      printf "%-20s 完了率  残り/全体  フェーズ   (done %%, open/total, phase)\n", ""
      for (i = 1; i <= n; i++) {
        s = order[i]; d = done[s] + 0; o = open[s] + 0; t = d + o
        if (t == 0) { undefined++; printf "%s    -   タスク未定義 / no tasks  %s\n", bar(0, 0), s; continue }
        td += d; to += o
        printf "%s %4d%%  %4d / %-4d  %s\n", bar(d, t), pct(d, t), o, t, s
      }
      t = td + to
      printf "%s %4d%%  %4d / %-4d  合計 / Total", bar(td, t), pct(td, t), to, t
      if (undefined > 0) printf "（ほかに未定義のフェーズ %d / %d more phases without tasks）", undefined, undefined
      printf "\n"
      if (release != "") printf "公開まで残り %d 件（上から「%s」の節まで） / %d open until release\n", release_open, release, release_open
      if (ask_open + ask_done > 0) printf "回答待ち：%d 件（回答済み %d 件） / Waiting: %d open, %d answered\n", ask_open, ask_done, ask_open, ask_done
      if (hold_open + hold_done > 0) printf "保留（合計に含めない）：%d 件（済み %d 件） / On hold (not in total): %d open, %d done\n", hold_open, hold_done, hold_open, hold_done
      if (after_open + after_done > 0) printf "公開後（合計に含めない）：%d 件（済み %d 件） / After release (not in total): %d open, %d done\n", after_open, after_done, after_open, after_done
    }
  ' "$1"
}

# 引数のファイル（- なら標準入力）について「完了 未完」の 2 数を出す。確認待ち・保留・公開後は除く
count_phase() {
  tp_awk '
    BEGIN { kind = "phase" }
    /^## / { s = $0; sub(/^## +/, "", s); kind = kind_of(s); next }
    kind == "phase" && /^[ \t]*[-*+] \[[xX]\]/ { d++ }
    kind == "phase" && /^[ \t]*[-*+] \[ \]/ { o++ }
    END { print d + 0, o + 0 }
  ' "$1"
}

# 前回の区切り（区切りのファイルの最終コミット）からの増減を 1 行で出す。Git 管理外・区切りが無いときは何も出さない
delta_line() {
  [ -n "$TP_CHECKPOINT_FILE" ] || return 0
  git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  local marks=()
  mapfile -t marks < <(git -C "$DIR" log -2 --format=%H -- "$TP_CHECKPOINT_FILE" 2>/dev/null)
  [ "${#marks[@]}" -ge 1 ] || return 0

  # git show に渡す TODO.md のパス（リポジトリのルートからの相対）
  local rel
  rel="$(git -C "$DIR" rev-parse --show-prefix 2>/dev/null)$TP_TODO_FILE"

  local base label_ja label_en
  # 区切り以降に TODO.md が変わっていなければ、ひとつ前の区切りと比べて「前回のセッション分」を出す
  if [ "${#marks[@]}" -ge 2 ] && git -C "$DIR" show "${marks[0]}:$rel" 2>/dev/null | cmp -s - "$TODO"; then
    base="${marks[1]}"
    local from to
    from="$(git -C "$DIR" log -1 --format=%cd --date=short "${marks[1]}")"
    to="$(git -C "$DIR" log -1 --format=%cd --date=short "${marks[0]}")"
    label_ja="前回のセッション（$from → $to）で"
    label_en="Last session ($from → $to)"
  else
    base="${marks[0]}"
    local at
    at="$(git -C "$DIR" log -1 --format=%cd --date=short "${marks[0]}")"
    label_ja="前回の区切り（$at）から"
    label_en="Since last checkpoint ($at)"
  fi

  local base_counts now_counts
  base_counts=$(git -C "$DIR" show "$base:$rel" 2>/dev/null | count_phase -) || return 0
  [ -n "$base_counts" ] || return 0
  now_counts=$(count_phase "$TODO")

  local bd bo nd no
  read -r bd bo <<< "$base_counts"
  read -r nd no <<< "$now_counts"
  local plus_done=$((nd - bd)) plus_new=$(((nd + no) - (bd + bo)))
  # タスクを消したり完了を戻したりすると減るので、符号を付けて出す
  printf '%s：完了 %+d 件、タスクの数 %+d 件 / %s: done %+d, tasks %+d\n' \
    "$label_ja" "$plus_done" "$plus_new" "$label_en" "$plus_done" "$plus_new"
}

echo '```'
echo "進捗（$TP_TODO_FILE より自動集計・$(date +%Y-%m-%d)） / Progress from $TP_TODO_FILE"
echo
render_table "$TODO"
DELTA=$(delta_line)
if [ -n "$DELTA" ]; then
  echo
  echo "$DELTA"
fi
echo '```'
