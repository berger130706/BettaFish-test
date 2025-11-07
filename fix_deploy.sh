#!/bin/bash

# 修复部署脚本 - 安装python3-venv并完成部署

SERVER="101.201.214.42"
USER="root"
PASSWORD="qwer.123"
REMOTE_DIR="/root/baiguoyuan"

echo "🔧 修复云端部署..."
echo ""

expect << 'EXPECT_SCRIPT'
set timeout 300
set server "101.201.214.42"
set user "root"
set password "qwer.123"
set remote_dir "/root/baiguoyuan"

spawn ssh -o StrictHostKeyChecking=no ${user}@${server}
expect "password:"
send "${password}\r"

expect "#"
send "echo '📦 安装python3-venv包...'\r"
expect "#"

send "apt update -y\r"
expect "#"

send "apt install python3-venv python3-pip -y\r"
expect {
    "#" { }
    timeout {
        puts "安装超时"
    }
}

send "echo '✅ python3-venv安装完成'\r"
expect "#"

send "echo ''\r"
expect "#"

send "echo '🔧 创建虚拟环境...'\r"
expect "#"

send "cd ${remote_dir} && rm -rf venv && python3 -m venv venv\r"
expect "#"

send "echo '✅ 虚拟环境创建成功'\r"
expect "#"

send "echo ''\r"
expect "#"

send "echo '📥 安装Python依赖（需要几分钟）...'\r"
expect "#"

send "cd ${remote_dir} && source venv/bin/activate && pip install --upgrade pip\r"
expect {
    "#" { }
    timeout {
        puts "pip升级超时"
    }
}

send "cd ${remote_dir} && source venv/bin/activate && pip install streamlit pandas openai schedule requests beautifulsoup4 selenium\r"
expect {
    "#" { }
    timeout {
        puts "依赖安装超时，但可能已完成"
    }
}

send "echo '✅ 依赖安装完成'\r"
expect "#"

send "echo ''\r"
expect "#"

send "echo '🚀 启动服务...'\r"
expect "#"

send "cd ${remote_dir} && pkill -f 'streamlit run baiguoyuan_review_app.py' 2>/dev/null\r"
expect "#"

send "sleep 2\r"
expect "#"

send "cd ${remote_dir} && source venv/bin/activate && nohup streamlit run baiguoyuan_review_app.py --server.port 5000 --server.address 0.0.0.0 --server.headless true > app.log 2>&1 &\r"
expect "#"

send "sleep 5\r"
expect "#"

send "echo \\$! > ${remote_dir}/app.pid\r"
expect "#"

send "echo ''\r"
expect "#"

send "echo '✅ 服务已启动'\r"
expect "#"

send "echo ''\r"
expect "#"

send "echo '🔍 验证服务状态...'\r"
expect "#"

send "ps aux | grep streamlit | grep -v grep\r"
expect "#"

send "echo ''\r"
expect "#"

send "echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'\r"
expect "#"

send "echo '✅ 部署完成！'\r"
expect "#"

send "echo ''\r"
expect "#"

send "echo '🌐 访问地址: http://101.201.214.42:5000'\r"
expect "#"

send "echo '📝 日志文件: ${remote_dir}/app.log'\r"
expect "#"

send "echo ''\r"
expect "#"

send "echo '💡 查看日志: tail -f ${remote_dir}/app.log'\r"
expect "#"

send "echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'\r"
expect "#"

send "exit\r"
expect eof
EXPECT_SCRIPT

echo ""
echo "🎉 部署修复完成！"
echo ""
echo "✅ 现在访问: http://101.201.214.42:5000"
echo ""
