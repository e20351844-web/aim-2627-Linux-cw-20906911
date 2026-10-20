#!/bin/bash
# Q8：repair 时识别并停止采集器、修复 HTTP 服务；cleanup 时停止修复后的服务。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

action=${3:-repair}

# TODO：删除下方提示和 exit 77，再填写你的命令。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

action=${3:-repair}

# ---------- 读取 process.env ----------
if [ -f "$input/process.env" ]; then
    # shellcheck disable=SC1090
    . "$input/process.env"
fi

TARGET_PID=${TARGET_PID:-}
TARGET_TOKEN=${TARGET_TOKEN:-}
WORKER_LOG=${WORKER_LOG:-}
SERVICE_PID=${SERVICE_PID:-}
TARGET_PORT=${TARGET_PORT:-}
START_TOOL=${START_TOOL:-}

if [ "$action" = "repair" ]; then

    # ---------- A1 记录目标进程 ----------
    line=$(ps -p "$TARGET_PID" -o pid=,user=,stat=,args=)
    read -r p_pid p_user p_stat p_args <<< "$line"

    {
        printf 'PID=%s\n'     "$p_pid"
        printf 'user=%s\n'    "$p_user"
        printf 'state=%s\n'   "$p_stat"
        printf 'command=%s\n' "$p_args"
    } > "$output/process.txt"

    # ---------- A2 采样日志：START 行与最初两条 TICK ----------
    grep -E -m 3 -e 'START' -e 'TICK' "$WORKER_LOG" > "$output/collector-sample.log" || true

    # ---------- A3 只终止目标 PID，另一个采集器保持运行 ----------
    if kill -TERM "$TARGET_PID" 2>/dev/null; then
        tail --pid="$TARGET_PID" -f /dev/null
    fi

    # ---------- B1 正常停止原故障服务 ----------
    if kill -TERM "$SERVICE_PID" 2>/dev/null; then
        tail --pid="$SERVICE_PID" -f /dev/null
    fi

    # ---------- B2 生成修复后的配置，三行顺序固定 ----------
    {
        printf 'bind=127.0.0.1\n'
        printf 'port=%s\n' "$TARGET_PORT"
        printf 'route=/status\n'
    } > "$output/server.conf"

    # ---------- B3 启动修复后的服务（配置路径、服务目录，两个位置参数） ----------
    "$START_TOOL" "$output/server.conf" "$output/service"

    # ---------- B4 有界重试请求，记录真实响应 ----------
    code=$(curl -sS --retry 20 --retry-delay 1 --retry-connrefused --max-time 5 \
                -o "$output/http-body.txt" \
                -w '%{http_code}' \
                "http://127.0.0.1:$TARGET_PORT/status")

    printf '%s\n' "$code" > "$output/http-status.txt"

    body=$(cat "$output/http-body.txt")
    printf '%s\n' "$body" > "$output/http-body.txt"

elif [ "$action" = "cleanup" ]; then

    # ---------- 停止修复后的服务，等待退出与端口释放 ----------
    pid_file="$output/service/pid"

    if [ -f "$pid_file" ]; then
        new_pid=$(cat "$pid_file")
        new_pid=${new_pid%%[!0-9]*}

        if [ -n "$new_pid" ] && kill -TERM "$new_pid" 2>/dev/null; then
            tail --pid="$new_pid" -f /dev/null
        fi
    fi

fi
