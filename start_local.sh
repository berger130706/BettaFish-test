#!/bin/bash
# 百果园舆情监测系统 - 本地启动脚本

echo "🚀 正在启动百果园舆情监测系统..."
echo "📍 项目目录: $(pwd)"
echo ""

# 使用python -m方式运行streamlit（不需要PATH）
python3 -m streamlit run baiguoyuan_review_app.py --server.port 5000

# 如果上面失败，尝试python
if [ $? -ne 0 ]; then
    echo "尝试使用 python 命令..."
    python -m streamlit run baiguoyuan_review_app.py --server.port 5000
fi
