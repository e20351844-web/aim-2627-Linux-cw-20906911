#!/bin/bash
# Q2：创建 sentry_ws 四个子目录、两个空文件以及指定脚本和配置。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

# TODO：删除下方提示和 exit 77，再填写你的命令。
ws="$output/sentry_ws"   #先将ouput输出目录与sentry_ws联系上绝对路径

mkdir -p "$ws/scripts" "$ws/config" "$ws/logs" "$ws/tmp"   # -p 一次性建出4个子目录
touch "$ws/logs/.keep" "$ws/tmp/scratch.txt"               # 创建空文件夹

cat > "$ws/scripts/hello.sh" <<'EOF'   #意思是到下一行单独EOF之间输出的全都是hello.sh的内容
#!/bin/bash
echo "Hello, AIM Linux!"
EOF

cat > "$ws/config/robot.conf" <<'EOF'
robot=sentry
mode=training
log_level=INFO
EOF


