#!/bin/bash
# 百果园舆情系统 - 一键云端部署脚本
# 使用方法: chmod +x 一键部署百果园系统.sh && ./一键部署百果园系统.sh

set -e  # 遇到错误立即退出

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 服务器配置
SERVER_IP="101.201.214.42"
SERVER_USER="root"
SERVER_PASSWORD="qwer.123"
REMOTE_DIR="/root/BettaFish-test"
PORT=5000

echo -e "${GREEN}======================================"
echo "  百果园舆情系统 - 一键云端部署"
echo -e "======================================${NC}"
echo ""

# 步骤1: 检查本地工具
echo -e "${YELLOW}[1/7] 检查本地工具...${NC}"

if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}❌ 未安装 sshpass${NC}"
    echo "请先安装: brew install hudochenkov/sshpass/sshpass"
    exit 1
fi

echo -e "${GREEN}✅ sshpass 已安装${NC}"

# 步骤2: 测试服务器连通性
echo ""
echo -e "${YELLOW}[2/7] 测试服务器连通性...${NC}"

if ping -c 2 $SERVER_IP &> /dev/null; then
    echo -e "${GREEN}✅ 服务器网络连通${NC}"
else
    echo -e "${RED}❌ 无法连接到服务器 $SERVER_IP${NC}"
    exit 1
fi

# 步骤3: 打包代码
echo ""
echo -e "${YELLOW}[3/7] 打包项目代码...${NC}"

tar czf /tmp/baiguoyuan_deploy.tar.gz \
    --exclude='venv' \
    --exclude='venv311' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.git' \
    --exclude='logs/*.log' \
    --exclude='*_streamlit_reports' \
    --exclude='final_reports' \
    --exclude='MindSpider/DeepSentimentCrawling/MediaCrawler/data' \
    -C /Users/xiaoyan/Desktop/舆情/BettaFish-test .

echo -e "${GREEN}✅ 代码打包完成${NC}"

# 步骤4: 上传代码到服务器
echo ""
echo -e "${YELLOW}[4/7] 上传代码到服务器...${NC}"

sshpass -p "$SERVER_PASSWORD" scp /tmp/baiguoyuan_deploy.tar.gz $SERVER_USER@$SERVER_IP:/tmp/

echo -e "${GREEN}✅ 代码上传完成${NC}"

# 步骤5: 在服务器上部署
echo ""
echo -e "${YELLOW}[5/7] 在服务器上解压和配置...${NC}"

sshpass -p "$SERVER_PASSWORD" ssh $SERVER_USER@$SERVER_IP << 'ENDSSH'
set -e

# 备份旧版本
if [ -d "/root/BettaFish-test" ]; then
    echo "备份旧版本..."
    mv /root/BettaFish-test /root/BettaFish-test.backup.$(date +%Y%m%d_%H%M%S) || true
fi

# 创建新目录
mkdir -p /root/BettaFish-test
cd /root/BettaFish-test

# 解压代码
tar xzf /tmp/baiguoyuan_deploy.tar.gz
rm /tmp/baiguoyuan_deploy.tar.gz

echo "✅ 代码解压完成"

# 检查Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 未安装"
    exit 1
fi

echo "✅ Python版本: $(python3 --version)"

# 创建虚拟环境(如果不存在)
if [ ! -d "venv" ]; then
    echo "创建Python虚拟环境..."
    python3 -m venv venv
fi

# 激活虚拟环境
source venv/bin/activate

# 升级pip
pip install --upgrade pip > /dev/null 2>&1

# 安装核心依赖
echo "安装依赖包(可能需要几分钟)..."
pip install streamlit pandas openai schedule requests beautifulsoup4 > /dev/null 2>&1

echo "✅ 环境配置完成"

ENDSSH

echo -e "${GREEN}✅ 服务器环境配置完成${NC}"

# 步骤6: 上传.env配置文件
echo ""
echo -e "${YELLOW}[6/7] 上传配置文件...${NC}"

if [ -f "/Users/xiaoyan/Desktop/舆情/BettaFish-test/.env" ]; then
    sshpass -p "$SERVER_PASSWORD" scp /Users/xiaoyan/Desktop/舆情/BettaFish-test/.env $SERVER_USER@$SERVER_IP:$REMOTE_DIR/
    echo -e "${GREEN}✅ .env 配置文件已上传${NC}"
fi

# 可选:上传数据库文件
if [ -f "/Users/xiaoyan/Desktop/舆情/BettaFish-test/baiguoyuan_sentiment.db" ]; then
    echo "上传SQLite数据库..."
    sshpass -p "$SERVER_PASSWORD" scp /Users/xiaoyan/Desktop/舆情/BettaFish-test/baiguoyuan_sentiment.db $SERVER_USER@$SERVER_IP:$REMOTE_DIR/
    echo -e "${GREEN}✅ 数据库文件已上传${NC}"
fi

# 步骤7: 启动服务
echo ""
echo -e "${YELLOW}[7/7] 启动服务...${NC}"

sshpass -p "$SERVER_PASSWORD" ssh $SERVER_USER@$SERVER_IP << ENDSSH
set -e

cd $REMOTE_DIR

# 停止旧服务
pkill -f "streamlit run baiguoyuan_review_app.py" || true
sleep 2

# 激活环境
source venv/bin/activate

# 启动新服务
nohup streamlit run baiguoyuan_review_app.py \
    --server.port $PORT \
    --server.address 0.0.0.0 \
    --server.headless true \
    > streamlit.log 2>&1 &

# 记录PID
echo \$! > streamlit.pid

# 等待启动
sleep 3

# 检查服务
if pgrep -f "streamlit run baiguoyuan_review_app.py" > /dev/null; then
    echo "✅ 服务启动成功"
    echo "进程ID: \$(cat streamlit.pid)"
else
    echo "❌ 服务启动失败,请查看日志: tail -f $REMOTE_DIR/streamlit.log"
    exit 1
fi

ENDSSH

# 完成
echo ""
echo -e "${GREEN}======================================"
echo "  🎉 部署完成!"
echo -e "======================================${NC}"
echo ""
echo -e "📝 访问地址: ${GREEN}http://$SERVER_IP:$PORT${NC}"
echo ""
echo "🔧 常用命令:"
echo "  查看日志: ssh root@$SERVER_IP 'tail -f $REMOTE_DIR/streamlit.log'"
echo "  停止服务: ssh root@$SERVER_IP 'kill \$(cat $REMOTE_DIR/streamlit.pid)'"
echo "  重启服务: ./一键部署百果园系统.sh"
echo ""
echo -e "${YELLOW}⚠️  重要提示:${NC}"
echo "  1. 确保阿里云安全组已开放 $PORT 端口"
echo "  2. 首次访问可能需要等待10-30秒"
echo "  3. 如无法访问,检查日志或联系技术支持"
echo ""

# 清理临时文件
rm -f /tmp/baiguoyuan_deploy.tar.gz

exit 0
