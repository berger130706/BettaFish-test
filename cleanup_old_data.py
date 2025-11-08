#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
百果园舆情系统 - 历史数据清理脚本
功能: 自动删除14天前的舆情数据,并备份
"""

import sqlite3
import shutil
from datetime import datetime, timedelta
from pathlib import Path
import logging

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# 配置
DB_PATH = "baiguoyuan_sentiment.db"
RETENTION_DAYS = 14  # 保留14天
BACKUP_DIR = Path("backups")


def create_backup():
    """创建数据库备份"""
    try:
        # 创建备份目录
        BACKUP_DIR.mkdir(exist_ok=True)

        # 备份文件名: baiguoyuan_sentiment_backup_20250108_120000.db
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_path = BACKUP_DIR / f"baiguoyuan_sentiment_backup_{timestamp}.db"

        # 复制数据库文件
        shutil.copy2(DB_PATH, backup_path)

        logger.info(f"✅ 数据库备份成功: {backup_path}")
        return True
    except Exception as e:
        logger.error(f"❌ 数据库备份失败: {e}")
        return False


def cleanup_old_backups(keep_days=30):
    """清理超过30天的备份文件"""
    try:
        if not BACKUP_DIR.exists():
            return

        cutoff_date = datetime.now() - timedelta(days=keep_days)
        deleted_count = 0

        for backup_file in BACKUP_DIR.glob("baiguoyuan_sentiment_backup_*.db"):
            # 获取文件修改时间
            mtime = datetime.fromtimestamp(backup_file.stat().st_mtime)

            if mtime < cutoff_date:
                backup_file.unlink()
                deleted_count += 1
                logger.info(f"🗑️  删除旧备份: {backup_file.name}")

        if deleted_count > 0:
            logger.info(f"✅ 清理了 {deleted_count} 个超过{keep_days}天的备份文件")
    except Exception as e:
        logger.error(f"❌ 清理旧备份失败: {e}")


def cleanup_old_data():
    """删除14天前的舆情数据"""
    try:
        # 计算截止日期
        cutoff_date = datetime.now() - timedelta(days=RETENTION_DAYS)
        cutoff_str = cutoff_date.strftime('%Y-%m-%d %H:%M:%S')

        logger.info("=" * 60)
        logger.info("开始清理历史舆情数据")
        logger.info(f"当前时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        logger.info(f"保留天数: {RETENTION_DAYS}天")
        logger.info(f"截止日期: {cutoff_str}")
        logger.info("=" * 60)

        # 连接数据库
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()

        # 查询要删除的数据数量
        cursor.execute("""
            SELECT COUNT(*) FROM sentiment_data
            WHERE created_at < ?
        """, (cutoff_str,))

        to_delete_count = cursor.fetchone()[0]

        if to_delete_count == 0:
            logger.info("ℹ️  没有需要清理的数据")
            conn.close()
            return 0

        logger.info(f"📊 待删除数据: {to_delete_count} 条")

        # 先备份再删除
        logger.info("📦 正在备份数据库...")
        if not create_backup():
            logger.warning("⚠️  备份失败,但继续执行清理...")

        # 执行删除
        logger.info("🗑️  正在删除旧数据...")
        cursor.execute("""
            DELETE FROM sentiment_data
            WHERE created_at < ?
        """, (cutoff_str,))

        deleted = cursor.rowcount
        conn.commit()

        # 优化数据库(回收空间)
        logger.info("🔧 正在优化数据库...")
        cursor.execute("VACUUM")
        conn.commit()

        conn.close()

        logger.info("=" * 60)
        logger.info(f"✅ 清理完成!")
        logger.info(f"删除数据: {deleted} 条")
        logger.info(f"数据库已优化")
        logger.info("=" * 60)

        # 清理旧备份
        cleanup_old_backups(keep_days=30)

        return deleted

    except Exception as e:
        logger.error(f"❌ 清理失败: {e}")
        return -1


def get_database_stats():
    """获取数据库统计信息"""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()

        # 总数据量
        cursor.execute("SELECT COUNT(*) FROM sentiment_data")
        total_count = cursor.fetchone()[0]

        # 最早数据时间
        cursor.execute("SELECT MIN(created_at) FROM sentiment_data")
        earliest = cursor.fetchone()[0]

        # 最新数据时间
        cursor.execute("SELECT MAX(created_at) FROM sentiment_data")
        latest = cursor.fetchone()[0]

        # 数据库文件大小
        db_size = Path(DB_PATH).stat().st_size / 1024 / 1024  # MB

        conn.close()

        logger.info("\n" + "=" * 60)
        logger.info("📊 数据库统计信息")
        logger.info("=" * 60)
        logger.info(f"总数据量: {total_count:,} 条")
        logger.info(f"最早数据: {earliest or '无'}")
        logger.info(f"最新数据: {latest or '无'}")
        logger.info(f"数据库大小: {db_size:.2f} MB")
        logger.info("=" * 60 + "\n")

    except Exception as e:
        logger.error(f"❌ 获取统计信息失败: {e}")


def main():
    """主函数"""
    logger.info("\n🚀 百果园舆情数据清理脚本启动\n")

    # 检查数据库文件
    if not Path(DB_PATH).exists():
        logger.error(f"❌ 数据库文件不存在: {DB_PATH}")
        return

    # 显示清理前统计
    logger.info("📊 清理前数据统计:")
    get_database_stats()

    # 执行清理
    deleted = cleanup_old_data()

    if deleted >= 0:
        # 显示清理后统计
        logger.info("\n📊 清理后数据统计:")
        get_database_stats()
        logger.info("✅ 所有任务完成!\n")
    else:
        logger.error("❌ 清理任务失败!\n")


if __name__ == "__main__":
    main()
