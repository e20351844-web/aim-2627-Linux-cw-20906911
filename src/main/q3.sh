#!/bin/bash
# Q3：复制素材、备份配置、移动草稿、删除 tmp、设定权限并直接运行 hello.sh。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

# TODO：删除下方提示和 exit 77，再填写你的命令。
ws="$output/sentry_ws"
mkdir -p "$ws/scripts" "$ws/config"
cp "$input/hello.sh" "$ws/scripts/hello.sh"
cp "$input/robot.conf" "$ws/config/robot.conf"
cp "$input/draft.conf" "$ws/config/draft.conf"
#因为直接写2，backup不存在，所以要先在ws后面创建一个
mkdir -p "$ws/backup"
cp "$ws/config/robot.conf" "$ws/backup/robot.conf"
mv "$ws/config/draft.conf" "$ws/archive/draft.conf.old"
rm "$ws/tmp"
chmod 750 "$ws/scripts/hello.sh"
chmod 640 "$ws/config/robot.conf"
"$ws/scripts/hello.sh" > "$output/hello-output.txt"
