#!/bin/bash
# Q5：运行 launch.env 给定的启动前检查，保存 stdout/stderr、真实退出码和诊断报告。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

# TODO：删除下方提示和 exit 77，再填写你的命令。
env_file="$input/launch.env"
if [ -f "$env_file" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$env_file"
    set +a
fi

LAUNCH_TOOL=${LAUNCH_TOOL:-}
MODEL_PATH=${MODEL_PATH:-}
CAMERA_PATH=${CAMERA_PATH:-}
if "$LAUNCH_TOOL" "$MODEL_PATH" "$CAMERA_PATH" \
        > "$output/stdout.log" \
        2> "$output/stderr.log"; then
    rc=0
else
    rc=$?
fi
printf '%d\n' "$rc" > "$output/exit-code.txt"
result=FAILED
reason=NONE

if [ "$rc" -eq 0 ]; then
    result=SUCCESS
    reason=NONE
elif [ "$rc" -eq 10 ]; then
    reason=MODEL_MISSING
elif [ "$rc" -eq 20 ]; then
    reason=CAMERA_DENIED
fi

{
    printf 'result=%s\n'    "$result"
    printf 'exit_code=%d\n' "$rc"
    printf 'reason=%s\n'    "$reason"
} > "$output/report.txt"
exit 0
