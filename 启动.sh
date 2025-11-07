#!/bin/bash

echo "🚀 正在启动百果园舆情监测系统..."
echo ""

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# 检查虚拟环境是否存在
if [ ! -d "venv" ]; then
    echo "📦 首次运行，正在创建虚拟环境..."
    python3 -m venv venv
    echo "✅ 虚拟环境创建完成"
    echo ""
fi

# 激活虚拟环境
echo "🔧 激活虚拟环境..."
source venv/bin/activate

# 检查是否需要安装依赖
if ! python -c "import streamlit" 2>/dev/null; then
    echo "📥 正在安装依赖包（这可能需要几分钟）..."
    pip install streamlit pandas openai schedule requests beautifulsoup4 selenium -q
    echo "✅ 依赖包安装完成"
    echo ""
fi

# 启动应用
echo "🌐 正在启动 Web 界面..."
echo "📱 浏览器将自动打开 http://localhost:5000"
echo ""
echo "💡 使用提示："
echo "   - 按 Ctrl+C 可以停止服务"
echo "   - 关闭终端窗口也会停止服务"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

streamlit run baiguoyuan_review_app.py --server.port 5000
