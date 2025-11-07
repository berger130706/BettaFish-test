#!/bin/bash
# 服务器端启动脚本 - 上传到服务器后使用

echo "🍎 百果园舆情监测系统 - 服务器启动脚本"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 进入项目目录
cd /root/baiguoyuan || { echo "❌ 项目目录不存在"; exit 1; }

# 停止已有服务
echo "🛑 停止已有服务..."
if [ -f app.pid ]; then
    OLD_PID=$(cat app.pid)
    if ps -p $OLD_PID > /dev/null 2>&1; then
        kill $OLD_PID
        echo "   已停止旧服务 (PID: $OLD_PID)"
    fi
    rm app.pid
fi
pkill -f "streamlit run baiguoyuan_review_app.py" 2>/dev/null

sleep 2

# 检查虚拟环境
if [ ! -d "venv" ]; then
    echo "📦 创建虚拟环境..."
    python3 -m venv venv
fi

# 激活虚拟环境
echo "🔧 激活虚拟环境..."
source venv/bin/activate

# 检查依赖
echo "📋 检查依赖..."
if ! python -c "import streamlit" 2>/dev/null; then
    echo "📥 安装依赖包..."
    pip install -q --upgrade pip
    pip install -q streamlit pandas openai schedule requests beautifulsoup4 selenium
fi

# 清理旧日志
if [ -f app.log ]; then
    mv app.log app.log.old
fi

# 启动服务
echo "🚀 启动服务..."
nohup streamlit run baiguoyuan_review_app.py \
    --server.port 5000 \
    --server.address 0.0.0.0 \
    --server.headless true \
    > app.log 2>&1 &

# 保存PID
echo $! > app.pid

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 服务启动成功！"
echo ""
echo "📌 进程ID: $(cat app.pid)"
echo "🌐 访问地址: http://101.201.214.42:5000"
echo "📝 日志文件: /root/baiguoyuan/app.log"
echo ""
echo "💡 管理命令："
echo "   查看日志: tail -f app.log"
echo "   停止服务: kill \$(cat app.pid)"
echo "   查看状态: ps aux | grep streamlit"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 等待几秒让服务启动
sleep 3

# 检查服务状态
if pgrep -f "streamlit run baiguoyuan_review_app.py" > /dev/null; then
    echo "✅ 服务运行正常"
    echo ""
    echo "🎉 部署完成！现在可以访问："
    echo "   http://101.201.214.42:5000"
else
    echo "❌ 服务启动失败，请查看日志："
    echo "   tail -f app.log"
fi
