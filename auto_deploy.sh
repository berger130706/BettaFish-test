#!/bin/bash

# 云端自动部署脚本（使用expect）
SERVER="101.201.214.42"
USER="root"
PASSWORD="qwer.123"
REMOTE_DIR="/root/baiguoyuan"
LOCAL_DIR="/Users/xiaoyan/Desktop/舆情/BettaFish-test"

echo "🚀 百果园舆情监测系统 - 云端自动部署"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 步骤1：打包项目文件
echo "📦 步骤1：打包项目文件..."
cd "$LOCAL_DIR"
tar czf /tmp/baiguoyuan_deploy.tar.gz \
    --exclude='venv' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.git' \
    --exclude='logs' \
    --exclude='*.log' \
    --exclude='.DS_Store' \
    --exclude='MindSpider' \
    baiguoyuan_review_app.py \
    scheduler_daemon.py \
    config.py \
    app.py \
    server_start.sh \
    server_stop.sh \
    *.md \
    2>/dev/null

echo "✅ 文件打包完成"
echo ""

# 步骤2：使用expect上传文件和执行命令
echo "📤 步骤2：上传文件到服务器..."

expect << 'EXPECT_SCRIPT'
set timeout 120
set server "101.201.214.42"
set user "root"
set password "qwer.123"
set remote_dir "/root/baiguoyuan"

# 上传文件
spawn scp -o StrictHostKeyChecking=no /tmp/baiguoyuan_deploy.tar.gz ${user}@${server}:/tmp/
expect {
    "password:" {
        send "${password}\r"
        expect eof
    }
    timeout {
        puts "上传超时"
        exit 1
    }
}

puts "\n✅ 文件上传完成\n"

# 连接服务器并执行部署
spawn ssh -o StrictHostKeyChecking=no ${user}@${server}
expect "password:"
send "${password}\r"

expect "#"
send "echo '步骤3：创建项目目录...'\r"
expect "#"

send "mkdir -p ${remote_dir}\r"
expect "#"

send "echo '✅ 目录创建完成'\r"
expect "#"

send "echo ''\r"
expect "#"

send "echo '步骤4：解压项目文件...'\r"
expect "#"

send "cd ${remote_dir} && tar xzf /tmp/baiguoyuan_deploy.tar.gz\r"
expect "#"

send "rm /tmp/baiguoyuan_deploy.tar.gz\r"
expect "#"

send "echo '✅ 文件解压完成'\r"
expect "#"

send "echo ''\r"
expect "#"

send "echo '步骤5：创建虚拟环境...'\r"
expect "#"

send "cd ${remote_dir} && python3 -m venv venv\r"
expect "#"

send "echo '✅ 虚拟环境创建完成'\r"
expect "#"

send "echo ''\r"
expect "#"

send "echo '步骤6：安装Python依赖（这需要几分钟）...'\r"
expect "#"

send "cd ${remote_dir} && source venv/bin/activate && pip install --upgrade pip -q\r"
expect "#"

send "cd ${remote_dir} && source venv/bin/activate && pip install streamlit pandas openai schedule requests beautifulsoup4 selenium -q\r"
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

send "echo '步骤7：配置防火墙...'\r"
expect "#"

send "command -v firewall-cmd > /dev/null && firewall-cmd --permanent --add-port=5000/tcp && firewall-cmd --reload || echo '防火墙已配置或不存在'\r"
expect "#"

send "command -v ufw > /dev/null && ufw allow 5000/tcp || true\r"
expect "#"

send "echo '✅ 防火墙配置完成'\r"
expect "#"

send "echo ''\r"
expect "#"

send "echo '步骤8：停止旧服务...'\r"
expect "#"

send "pkill -f 'streamlit run baiguoyuan_review_app.py' 2>/dev/null || true\r"
expect "#"

send "sleep 2\r"
expect "#"

send "echo '✅ 旧服务已停止'\r"
expect "#"

send "echo ''\r"
expect "#"

send "echo '步骤9：启动服务...'\r"
expect "#"

send "cd ${remote_dir} && source venv/bin/activate && nohup streamlit run baiguoyuan_review_app.py --server.port 5000 --server.address 0.0.0.0 --server.headless true > app.log 2>&1 &\r"
expect "#"

send "sleep 3\r"
expect "#"

send "echo \\$! > ${remote_dir}/app.pid\r"
expect "#"

send "echo ''\r"
expect "#"

send "echo '步骤10：验证服务状态...'\r"
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

send "echo '🌐 访问地址：http://101.201.214.42:5000'\r"
expect "#"

send "echo '📝 日志文件：${remote_dir}/app.log'\r"
expect "#"

send "echo ''\r"
expect "#"

send "echo '💡 管理命令：'\r"
expect "#"

send "echo '  查看日志: tail -f ${remote_dir}/app.log'\r"
expect "#"

send "echo '  停止服务: kill \\$(cat ${remote_dir}/app.pid)'\r"
expect "#"

send "echo '  重启服务: cd ${remote_dir} && ./server_start.sh'\r"
expect "#"

send "echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'\r"
expect "#"

send "exit\r"
expect eof
EXPECT_SCRIPT

# 清理临时文件
rm /tmp/baiguoyuan_deploy.tar.gz 2>/dev/null

echo ""
echo "🎉 部署脚本执行完成！"
echo ""
echo "现在请访问：http://101.201.214.42:5000"
echo ""
echo "⚠️ 重要提示：确保在阿里云控制台的安全组中开放了5000端口！"
echo ""
