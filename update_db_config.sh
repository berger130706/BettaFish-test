#!/bin/bash
#
# 更新服务器数据库配置脚本
# 使用方法: ./update_db_config.sh
#
# 执行前请先填写下面的数据库信息
#

# ========== 在这里填写阿里云数据库信息 ==========
DB_HOST="your-db-host.mysql.rds.aliyuncs.com"   # 数据库地址
DB_PORT="3306"                                   # 端口 (MySQL: 3306, PostgreSQL: 5432)
DB_USER="your_db_user"                          # 数据库用户名
DB_PASSWORD="your_db_password"                  # 数据库密码
DB_NAME="baiguoyuan_sentiment"                  # 数据库名称
DB_DIALECT="mysql"                              # 数据库类型: mysql 或 postgresql
# ============================================

SERVER_IP="101.201.214.42"
SERVER_PASSWORD="qwer.123"
PROJECT_DIR="/root/BettaFish-test"

echo "========================================="
echo "  百果园舆情系统 - 数据库配置更新工具"
echo "========================================="
echo ""

# 检查是否已填写配置
if [ "$DB_HOST" = "your-db-host.mysql.rds.aliyuncs.com" ]; then
    echo "❌ 错误: 请先在脚本中填写数据库配置信息!"
    echo ""
    echo "请编辑此脚本,修改以下变量:"
    echo "  - DB_HOST"
    echo "  - DB_PORT"
    echo "  - DB_USER"
    echo "  - DB_PASSWORD"
    echo "  - DB_NAME"
    echo "  - DB_DIALECT"
    exit 1
fi

echo "即将更新以下数据库配置:"
echo "  数据库地址: $DB_HOST"
echo "  端口号: $DB_PORT"
echo "  用户名: $DB_USER"
echo "  密码: ${DB_PASSWORD:0:3}*** (已隐藏)"
echo "  数据库名: $DB_NAME"
echo "  数据库类型: $DB_DIALECT"
echo ""
read -p "确认更新? (y/n): " confirm

if [ "$confirm" != "y" ]; then
    echo "已取消更新"
    exit 0
fi

echo ""
echo "正在更新服务器配置..."

# 使用SSH更新.env文件中的数据库配置
sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no root@$SERVER_IP << ENDSSH
cd $PROJECT_DIR

# 备份原配置
cp .env .env.backup.\$(date +%Y%m%d_%H%M%S)

# 更新数据库配置
sed -i "s/^DB_HOST=.*/DB_HOST=$DB_HOST/" .env
sed -i "s/^DB_PORT=.*/DB_PORT=$DB_PORT/" .env
sed -i "s/^DB_USER=.*/DB_USER=$DB_USER/" .env
sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" .env
sed -i "s/^DB_NAME=.*/DB_NAME=$DB_NAME/" .env
sed -i "s/^DB_DIALECT=.*/DB_DIALECT=$DB_DIALECT/" .env

echo "✅ 配置已更新"
echo ""
echo "当前数据库配置:"
grep "^DB_" .env
ENDSSH

echo ""
echo "========================================="
echo "✅ 数据库配置更新完成!"
echo "========================================="
echo ""
echo "下一步:"
echo "1. 测试数据库连接"
echo "2. 启动服务"
echo ""
