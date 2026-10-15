#!/bin/bash
# Q4：合并日志，按级别提取，保存首尾片段并统计错误行数。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

# TODO：删除下方提示和 exit 77，再填写你的命令。
cat "boot.log" "run.log" > "all.log"
grep '^ERROR ' all.log > "errors.log"
grep -E '^WARN|ERROR ' > "attention.log"
tail -n 5 "all.log" > "recent.log"
head -n 3 "errors.log" > "first-errors.log"
wc -l < "errors.log" > "error-count.txt"


