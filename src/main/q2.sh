#!/bin/bash
# Q2：创建 sentry_ws 四个子目录、两个空文件以及指定脚本和配置。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

# TODO：删除下方提示和 exit 77，再填写你的命令。
cd $output
mkdir sentry_ws
cd sentry_ws
mkdir scripts
cd scripts
touch hello.sh
cat hello.sh > "#!/bin/bash"
cat hello.sh > "echo 'Hello, AIM Linux!'"
cd sentry_ws
mkdir config
cd config
touch robot.conf
cat robot.conf > robot=sentry
cat robot.conf > mode=training
cat robot.conf > log_level=INFO
cd sentry_ws
mkdir logs
touch .keep
cd sentry_ws
mkdir tmp
cd tmp
touch scratch.txt


