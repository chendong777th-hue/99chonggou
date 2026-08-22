#!/bin/sh
# 将 npm 安装的 TIM Web SDK 同步到 web/sdk（供 index.html 静态引用）。
set -e
cd "$(dirname "$0")"
npm install
mkdir -p sdk/modules
cp node_modules/@tencentcloud/chat/index.js sdk/tencentcloud-chat.js
cp node_modules/@tencentcloud/chat/modules/group-module.js sdk/modules/
cp node_modules/@tencentcloud/chat/modules/relationship-module.js sdk/modules/
cp node_modules/@tencentcloud/chat/modules/signaling-module.js sdk/modules/
cp node_modules/tim-upload-plugin/index.js sdk/tim-upload-plugin.js
echo "TIM Web SDK synced to web/sdk/"
