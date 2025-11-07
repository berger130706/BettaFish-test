#!/bin/bash

#完成部署 - 创建虚拟环境、安装依赖并启动服务

echo "🔧 完成云端部署..."
echo ""

expect << 'EXPECT_SCRIPT'
set timeout 600
set server "101.201.214.42"
set user "root"
set password "qwer.123"
set remote_dir "/root/baiguoyuan"

spawn ssh -o StrictHostKeyChecking=no ${user}@${server}
expect "password:"
send "${password}\r"

expect "#"
send "cd ${remote_dir}\r"
expect "#"

send "echo '🔧 创建虚拟环境...'\r"
expect "#"

send "rm -rf venv && python3 -m venv venv\r"
expect "#"

send "echo '✅ 虚拟环境创建成功'\r"
expect "#"

send "echo ''\r"
expect "#"

send "echo '📥 安装Python依赖（大约需要3-5分钟，请耐心等待）...'\r"
expect "#"

send "source venv/bin/activate && pip install --upgrade pip -q\r"
expect {
    "#" { }
    timeout {
        send "\r"
        exp_continue
    }
}

send "source venv/bin/activate && pip install streamlit -q\r"
expect {
    "#" { }
    timeout {
        send "\r"
        exp_continue
    }
}

send "source venv/bin/activate && pip install pandas openai schedule requests beautifulsoup4 selenium -q\r"
expect {
    "#" { }
    timeout {
        send "\r"
        exp_continue
    }
}

send "echo '✅ 依赖安装完成'\r"
expect "#"

send "echo ''\r"
expect "#"

send "echo '🚀 启动服务...'\r"
expect "#"

send "pkill -f 'streamlit run baiguoyuan_review_app.py' 2>/dev/null\r"
expect "#"

send "sleep 2\r"
expect "#"

send "source venv/bin/activate && nohup streamlit run baiguoyuan_review_app.py --server.port 5000 --server.address 0.0.0.0 --server.headless true > app.log 2>&1 &\r"
expect "#"

send "sleep 5\r"
expect "#"

send "echo ''\r"
expect "#"

send "echo '✅ 服务已启动'\r"
expect "#"

send "echo ''\r"
expect "#"

send "echo '🔍 验证服务状态...'\r"
expect "#"

send "ps aux | grep streamlit | grep -v grep | head -n 3\r"
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

send "echo ''\r"
expect "#"

send "echo '💡 提示: 如果无法访问，请确保：'\r"
expect "#"

send "echo '  1. 阿里云安全组已开放5000端口'\r"
expect "#"

send "echo '  2. 服务器防火墙允许5000端口'\r"
expect "#"

send "echo '  3. 查看日志: tail -f ${remote_dir}/app.log'\r"
expect "#"

send "echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'\r"
expect "#"

send "exit\r"
expect eof
EXPECT_SCRIPT

echo ""
echo "🎉 部署完成！"
echo ""
echo "✅ 现在可以访问: http://101.201.214.42:5000"
echo ""
echo "⚠️ 如果无法访问，请检查阿里云安全组是否开放了5000端口！"
echo ""
