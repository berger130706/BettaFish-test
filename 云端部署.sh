#!/bin/bash

# 云端服务器配置
SERVER_IP="101.201.214.42"
SERVER_USER="root"
SERVER_PASSWORD="qwer.123"
REMOTE_DIR="/root/baiguoyuan"

echo "🚀 百果园舆情监测系统 - 云端部署脚本"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "服务器: $SERVER_IP"
echo "用户: $SERVER_USER"
echo "目标目录: $REMOTE_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 检查sshpass是否安装
if ! command -v sshpass &> /dev/null; then
    echo "❌ 未安装 sshpass 工具"
    echo ""
    echo "请先安装 sshpass："
    echo "  macOS: brew install hudochenkov/sshpass/sshpass"
    echo "  Ubuntu: sudo apt-get install sshpass"
    echo "  CentOS: sudo yum install sshpass"
    echo ""
    echo "或者手动执行以下步骤："
    echo ""
    echo "1. SSH登录服务器："
    echo "   ssh root@101.201.214.42"
    echo "   密码：qwer.123"
    echo ""
    echo "2. 创建项目目录："
    echo "   mkdir -p /root/baiguoyuan"
    echo ""
    echo "3. 上传项目文件（在本地新终端执行）："
    echo "   cd /Users/xiaoyan/Desktop/舆情/BettaFish-test"
    echo "   scp -r * root@101.201.214.42:/root/baiguoyuan/"
    echo ""
    echo "4. 在服务器上安装依赖："
    echo "   cd /root/baiguoyuan"
    echo "   python3 -m venv venv"
    echo "   source venv/bin/activate"
    echo "   pip install streamlit pandas openai schedule requests beautifulsoup4 selenium"
    echo ""
    echo "5. 启动服务："
    echo "   nohup streamlit run baiguoyuan_review_app.py --server.port 5000 --server.address 0.0.0.0 > app.log 2>&1 &"
    echo ""
    echo "6. 访问界面："
    echo "   http://101.201.214.42:5000"
    echo ""
    exit 1
fi

echo "✅ sshpass 已安装"
echo ""

# 步骤1：测试连接
echo "📡 步骤1：测试服务器连接..."
if sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "echo '连接成功'" &> /dev/null; then
    echo "✅ 服务器连接成功"
else
    echo "❌ 无法连接到服务器，请检查IP、用户名和密码"
    exit 1
fi
echo ""

# 步骤2：创建目录
echo "📁 步骤2：创建远程目录..."
sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "mkdir -p $REMOTE_DIR"
echo "✅ 目录创建完成"
echo ""

# 步骤3：上传文件
echo "📤 步骤3：上传项目文件（这可能需要几分钟）..."
cd /Users/xiaoyan/Desktop/舆情/BettaFish-test

# 打包文件（排除不必要的文件）
tar czf /tmp/baiguoyuan.tar.gz \
    --exclude='venv' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.git' \
    --exclude='logs' \
    --exclude='*.log' \
    --exclude='.DS_Store' \
    .

echo "  正在上传..."
sshpass -p "$SERVER_PASSWORD" scp -o StrictHostKeyChecking=no /tmp/baiguoyuan.tar.gz "$SERVER_USER@$SERVER_IP:$REMOTE_DIR/"

echo "  正在解压..."
sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $REMOTE_DIR && tar xzf baiguoyuan.tar.gz && rm baiguoyuan.tar.gz"

rm /tmp/baiguoyuan.tar.gz
echo "✅ 文件上传完成"
echo ""

# 步骤4：安装依赖
echo "📦 步骤4：安装Python依赖..."
sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" << 'ENDSSH'
cd /root/baiguoyuan

# 创建虚拟环境
if [ ! -d "venv" ]; then
    echo "  创建虚拟环境..."
    python3 -m venv venv
fi

# 激活并安装依赖
source venv/bin/activate
echo "  安装依赖包..."
pip install -q --upgrade pip
pip install -q streamlit pandas openai schedule requests beautifulsoup4 selenium

echo "✅ 依赖安装完成"
ENDSSH
echo ""

# 步骤5：配置防火墙
echo "🔓 步骤5：配置防火墙（开放5000端口）..."
sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" << 'ENDSSH'
# 检查防火墙类型并开放端口
if command -v firewall-cmd &> /dev/null; then
    # CentOS/RHEL
    firewall-cmd --permanent --add-port=5000/tcp
    firewall-cmd --reload
    echo "✅ Firewalld规则已添加"
elif command -v ufw &> /dev/null; then
    # Ubuntu
    ufw allow 5000/tcp
    echo "✅ UFW规则已添加"
else
    echo "⚠️ 未检测到防火墙，请手动确保5000端口开放"
fi
ENDSSH
echo ""

# 步骤6：创建启动脚本
echo "🔧 步骤6：创建自动启动脚本..."
sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" << 'ENDSSH'
cd /root/baiguoyuan

cat > start_service.sh << 'EOF'
#!/bin/bash
cd /root/baiguoyuan
source venv/bin/activate
nohup streamlit run baiguoyuan_review_app.py \
    --server.port 5000 \
    --server.address 0.0.0.0 \
    --server.headless true \
    > app.log 2>&1 &
echo $! > app.pid
echo "✅ 服务已启动，PID: $(cat app.pid)"
echo "📱 访问地址: http://101.201.214.42:5000"
EOF

chmod +x start_service.sh

cat > stop_service.sh << 'EOF'
#!/bin/bash
if [ -f /root/baiguoyuan/app.pid ]; then
    PID=$(cat /root/baiguoyuan/app.pid)
    kill $PID 2>/dev/null
    rm /root/baiguoyuan/app.pid
    echo "✅ 服务已停止"
else
    echo "⚠️ 未找到PID文件，尝试强制停止..."
    pkill -f "streamlit run baiguoyuan_review_app.py"
    echo "✅ 服务已停止"
fi
EOF

chmod +x stop_service.sh
ENDSSH
echo "✅ 启动脚本创建完成"
echo ""

# 步骤7：启动服务
echo "🚀 步骤7：启动服务..."
sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" << 'ENDSSH'
cd /root/baiguoyuan

# 停止已有服务
if [ -f app.pid ]; then
    kill $(cat app.pid) 2>/dev/null
    rm app.pid
fi
pkill -f "streamlit run baiguoyuan_review_app.py" 2>/dev/null

# 启动新服务
./start_service.sh
sleep 3

# 检查服务状态
if pgrep -f "streamlit run baiguoyuan_review_app.py" > /dev/null; then
    echo "✅ 服务运行正常"
else
    echo "❌ 服务启动失败，请检查日志"
    tail -n 20 app.log
fi
ENDSSH
echo ""

# 完成
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 部署完成！"
echo ""
echo "📱 访问地址："
echo "   http://101.201.214.42:5000"
echo ""
echo "🔧 管理命令（SSH登录后执行）："
echo "   启动服务: cd /root/baiguoyuan && ./start_service.sh"
echo "   停止服务: cd /root/baiguoyuan && ./stop_service.sh"
echo "   查看日志: cd /root/baiguoyuan && tail -f app.log"
echo ""
echo "📝 注意事项："
echo "   1. 确保阿里云安全组已开放5000端口"
echo "   2. 服务会在后台运行，重启后需要手动启动"
echo "   3. 如需开机自启动，请配置systemd服务"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
