#!/bin/sh
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "未知目錄"')
model=$(echo "$input" | jq -r '.model.display_name // "未知模型"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# 目錄：只顯示最後兩層
short_cwd=$(echo "$cwd" | awk -F'[/\\\\]' '{if(NF>=2) print $(NF-1)"/"$NF; else print $NF}')

# 組合輸出
line="目錄：$short_cwd  模型：$model"

if [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  remaining_int=$(printf "%.0f" "$remaining")
  line="$line  上下文：已用 ${used_int}%／剩餘 ${remaining_int}%"
fi

printf "%s" "$line"
