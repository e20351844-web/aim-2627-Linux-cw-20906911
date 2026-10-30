#!/bin/bash
# Q8：repair 时识别并停止采集器、修复 HTTP 服务；cleanup 时停止修复后的服务。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

action=${3:-repair}

# ==================== 常量 ====================
# 修复后服务必须提供的路径与响应体，题面固定这两个值
STATUS_PATH='/status'
EXPECT_BODY='SENTRYREADY'

# HTTP 探测：单次 2 秒上限，最多重试 10 次（总计约 20 秒）
HTTP_TIMEOUT=2
HTTP_RETRIES=10

# 采集器日志里必须出现的两种标记
MARK_START='START'
MARK_TICK='TICK'

# ==================== 读取 process.env ====================
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

# ==================== 工具函数 ====================

# 等进程退出。不能用 tail --pid：目标退出后若父进程没有 wait，
# 它仍是僵尸，kill(pid, 0) 依然成功，tail 会一直等下去。
wait_pid_gone() {
    pid=$1
    count=0
    while [ "$count" -lt 20 ]; do
        state=$(ps -p "$pid" -o stat= 2>/dev/null | tr -d '[:space:]' || true)
        if [ -z "$state" ]; then
            return 0
        fi
        case "$state" in
            Z*) return 0 ;;
        esac
        sleep 0.1
        count=$((count + 1))
    done
    return 0
}

# 正常终止：先 TERM，再等它自己退出
stop_pid() {
    if kill -TERM "$1" 2>/dev/null; then
        wait_pid_gone "$1"
    fi
}

# 读 pid 文件：取首行、去掉换行与多余空白，只保留前导数字
read_pid_file() {
    raw=$(head -n 1 "$1" 2>/dev/null || true)
    printf '%s' "${raw%%[!0-9]*}"
}

# 端口是否仍在监听
port_in_use() {
    [ -n "$(ss -H -ltn "sport = :$1" 2>/dev/null || true)" ]
}

# ==================== repair ====================
do_repair() {

    # ---------- A1 记录目标进程四要素 ----------
    if [ -n "$TARGET_PID" ]; then
        snapshot=$(ps -p "$TARGET_PID" \
                      -o pid=,user=,stat=,args= 2>/dev/null || true)

        if [ -n "$snapshot" ]; then
            read -r p_pid p_user p_stat p_args <<< "$snapshot"

            {
                printf 'pid=%s\n'     "$p_pid"
                printf 'user=%s\n'    "$p_user"
                printf 'state=%s\n'   "$p_stat"
                printf 'command=%s\n' "$p_args"
            } > "$output/process.txt"
        fi
    fi

    # ---------- A2 采样日志：1 条 START + 2 条 TICK ----------
    # 分开取，不依赖两种行在日志里的先后顺序
    if [ -f "$WORKER_LOG" ]; then
        {
            grep -m 1 -F "$MARK_START" "$WORKER_LOG" 2>/dev/null || true
            grep -m 2 -F "$MARK_TICK"  "$WORKER_LOG" 2>/dev/null || true
        } > "$output/collector-sample.log"
    fi

    # ---------- A3 只终止目标采集器 ----------
    # 另一个采集器不在此列，题面要求它继续运行
    if [ -n "$TARGET_PID" ]; then
        stop_pid "$TARGET_PID"
    fi

    # ---------- B1 正常停止原故障服务 ----------
    if [ -n "$SERVICE_PID" ]; then
        stop_pid "$SERVICE_PID"
    fi

    # ---------- B2 生成修复后的配置，三行顺序固定 ----------
    {
        printf 'bind=127.0.0.1\n'
        printf 'port=%s\n' "$TARGET_PORT"
        printf 'route=%s\n' "$STATUS_PATH"
    } > "$output/server.conf"

    # ---------- B3 启动修复后的服务 ----------
    # 两个位置参数：配置路径、服务目录；工具启动后立即返回
    "$START_TOOL" "$output/server.conf" "$output/service"

    # ---------- B4 有界重试请求，记录真实状态码与响应体 ----------
    # --retry-connrefused 覆盖"端口尚未开始监听"的窗口
    http_code=$(curl -sS \
                     --retry "$HTTP_RETRIES" \
                     --retry-delay 1 \
                     --retry-connrefused \
                     --retry-max-time 6 \
                     --max-time "$HTTP_TIMEOUT" \
                     -o "$output/http-body.txt" \
                     -w '%{http_code}' \
                     "http://127.0.0.1:${TARGET_PORT}${STATUS_PATH}") || http_code=000

    printf '%s\n' "$http_code" > "$output/http-status.txt"

    # 归一成"一行 + 换行"
    http_body=$(cat "$output/http-body.txt")
    printf '%s\n' "$http_body" > "$output/http-body.txt"

    # 仅作诊断，不改变已写入的产物
    if [ "$http_code" != "200" ]; then
        printf 'q8: 状态码期望 200，实际 %s\n' "$http_code" >&2
    fi

    if [ "$http_body" != "$EXPECT_BODY" ]; then
        printf 'q8: 响应体期望 %s，实际 %s\n' "$EXPECT_BODY" "$http_body" >&2
    fi

    # 服务在此保持运行，交给 cleanup 收尾
}

# ==================== cleanup ====================
do_cleanup() {

    pid_file="$output/service/pid"

    # ---------- 依据本作业的服务状态记录定位修复后的服务 ----------
    if [ -f "$pid_file" ]; then
        service_pid=$(read_pid_file "$pid_file")

        if [ -n "$service_pid" ]; then
            stop_pid "$service_pid"
        fi
    fi

    # ---------- 确认端口已释放 ----------
    # 进程退出后内核通常立即释放；仍占用时再给一秒
    if [ -n "$TARGET_PORT" ] && port_in_use "$TARGET_PORT"; then
        sleep 1
    fi

    # 已生成的报告保持原样
}

# ==================== 分发 ====================
if [ "$action" = "repair" ]; then
    do_repair
elif [ "$action" = "cleanup" ]; then
    do_cleanup
fi
