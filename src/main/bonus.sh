#!/bin/bash
# Bonus：start 时创建分离的 tmux 会话和采集器；stop 时正常停止采集器并结束会话。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

action=${3:-start}

# TODO：删除下方提示和 exit 77，再填写你的命令。
if [ -f "$input/bonus.env" ]; then
    # shellcheck disable=SC1090
    . "$input/bonus.env"
fi

TMUX_SOCKET=${TMUX_SOCKET:-}
SESSION=${SESSION:-}
TOKEN=${TOKEN:-}
WORKER_TOOL=${WORKER_TOOL:-}

if [ "$action" = "start" ]; then

    # 全程只启动一个实例：会话已存在就不再新建
    if ! tmux -L "$TMUX_SOCKET" has-session -t "$SESSION" 2>/dev/null; then

        cmd="python3 $(printf '%q' "$WORKER_TOOL") --token $(printf '%q' "$TOKEN") --log $(printf '%q' "$output/bonus.log")"

        # -d 分离创建：脚本返回时没有附着客户端，采集器继续运行、日志继续增长
        tmux -L "$TMUX_SOCKET" new-session -d -s "$SESSION" "$cmd"

    fi

elif [ "$action" = "stop" ]; then

    if tmux -L "$TMUX_SOCKET" has-session -t "$SESSION" 2>/dev/null; then

        # 先正常停止会话内的采集器
        tmux -L "$TMUX_SOCKET" send-keys -t "$SESSION" C-c

        # 等它真正退出，避免带着运行中的进程销毁会话
        pane_pid=$(tmux -L "$TMUX_SOCKET" list-panes -t "$SESSION" -F '#{pane_pid}' | head -n 1)
        if [ -n "$pane_pid" ]; then
            tail --pid="$pane_pid" -f /dev/null 2>/dev/null || true
        fi

        # 只结束指定会话，其他会话不受影响
        tmux -L "$TMUX_SOCKET" kill-session -t "$SESSION"

    fi

fi
