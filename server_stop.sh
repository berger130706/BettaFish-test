#!/bin/bash
# 服务器端停止脚本

echo "🛑 停止百果园舆情监测系统..."
echo ""

cd /root/baiguoyuan || { echo "❌ 项目目录不存在"; exit 1; }

# 方法1：使用PID文件
if [ -f app.pid ]; then
    PID=$(cat app.pid)
    if ps -p $PID > /dev/null 2>&1; then
        kill $PID
        echo "✅ 已停止服务 (PID: $PID)"
        rm app.pid
    else
        echo "⚠️ PID文件存在但进程不存在"
        rm app.pid
    fi
fi

# 方法2：强制停止所有streamlit进程
PIDS=$(pgrep -f "streamlit run baiguoyuan_review_app.py")
if [ ! -z "$PIDS" ]; then
    echo "🔍 发现运行中的进程: $PIDS"
    pkill -f "streamlit run baiguoyuan_review_app.py"
    echo "✅ 已强制停止所有相关进程"
else
    echo "✅ 没有运行中的服务"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 服务已停止"
echo ""
echo "💡 如需重新启动，请执行："
echo "   ./server_start.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
