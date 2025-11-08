"""
百果园舆情监测系统 - 定时任务守护进程
每天自动执行3次爬取：早上8点、中午13点、晚上20点
"""

import schedule
import time
import subprocess
import os
from datetime import datetime
from pathlib import Path
import logging

# 配置日志
log_dir = Path("logs")
log_dir.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_dir / "scheduler.log", encoding='utf-8'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

# 百果园关键词配置
KEYWORDS = [
    "百果园&贵",
    "百果园&刺客",
    "百果园&吃不起",
    "百果园&2万元",
    "百果园&2万元吃不起",
    "百果园"
]

# 监测平台
PLATFORMS = ["xhs", "dy", "wb", "bili"]  # 小红书、抖音、微博、B站

def run_crawl_task():
    """执行一次爬取任务"""
    logger.info("=" * 60)
    logger.info("开始执行百果园舆情监测爬取任务")
    logger.info(f"时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    logger.info(f"监测平台: {', '.join(PLATFORMS)}")
    logger.info(f"关键词数量: {len(KEYWORDS)}")
    logger.info("=" * 60)

    # 进入MindSpider目录
    mindspider_dir = Path(__file__).parent / "MindSpider"
    os.chdir(mindspider_dir)

    success_count = 0
    fail_count = 0

    # 对每个平台执行爬取
    for platform in PLATFORMS:
        platform_name = {
            "xhs": "小红书",
            "dy": "抖音",
            "wb": "微博",
            "bili": "B站"
        }.get(platform, platform)

        logger.info(f"\n{'*' * 40}")
        logger.info(f"正在爬取平台: {platform_name} ({platform})")
        logger.info(f"{'*' * 40}")

        try:
            # 构建爬取命令
            # 使用--test参数表示测试模式（少量数据）
            # 实际运行时可以去掉--test，或者调整max-notes参数
            cmd = [
                "python", "main.py",
                "--deep-sentiment",
                "--platforms", platform,
                "--max-keywords", "10",  # 每次爬取10个关键词
                "--max-notes", "20"  # 每个关键词爬取20条内容
            ]

            logger.info(f"执行命令: {' '.join(cmd)}")

            # 执行爬取
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                encoding='utf-8',
                timeout=600  # 10分钟超时
            )

            if result.returncode == 0:
                logger.info(f"✅ {platform_name} 爬取成功")
                success_count += 1
            else:
                logger.error(f"❌ {platform_name} 爬取失败")
                logger.error(f"错误信息: {result.stderr}")
                fail_count += 1

        except subprocess.TimeoutExpired:
            logger.error(f"❌ {platform_name} 爬取超时（超过10分钟）")
            fail_count += 1
        except Exception as e:
            logger.error(f"❌ {platform_name} 爬取异常: {str(e)}")
            fail_count += 1

    # 任务总结
    logger.info("\n" + "=" * 60)
    logger.info("百果园舆情监测爬取任务完成")
    logger.info(f"成功: {success_count}个平台")
    logger.info(f"失败: {fail_count}个平台")
    logger.info(f"结束时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    logger.info("=" * 60 + "\n")

def morning_task():
    """早上8点任务"""
    logger.info("🌅 执行早上定时任务（08:00）")
    run_crawl_task()

def noon_task():
    """中午13点任务"""
    logger.info("🌤️ 执行中午定时任务（13:00）")
    run_crawl_task()

def evening_task():
    """晚上20点任务"""
    logger.info("🌙 执行晚上定时任务（20:00）")
    run_crawl_task()

def cleanup_data_task():
    """凌晨2点数据清理任务"""
    logger.info("🗑️  执行数据清理任务(02:00)")
    logger.info("=" * 60)

    try:
        # 调用清理脚本
        result = subprocess.run(
            ["python", "cleanup_old_data.py"],
            capture_output=True,
            text=True,
            encoding='utf-8',
            timeout=300  # 5分钟超时
        )

        if result.returncode == 0:
            logger.info("✅ 数据清理任务完成")
            logger.info(result.stdout)
        else:
            logger.error("❌ 数据清理任务失败")
            logger.error(result.stderr)
    except subprocess.TimeoutExpired:
        logger.error("❌ 数据清理任务超时(超过5分钟)")
    except Exception as e:
        logger.error(f"❌ 数据清理任务异常: {str(e)}")

    logger.info("=" * 60)

def main():
    """主函数"""
    logger.info("🚀 百果园舆情监测定时任务守护进程启动")
    logger.info(f"当前时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    logger.info(f"定时任务配置:")
    logger.info("  - 凌晨: 02:00 (数据清理)")
    logger.info("  - 早上: 08:00 (爬取舆情)")
    logger.info("  - 中午: 13:00 (爬取舆情)")
    logger.info("  - 晚上: 20:00 (爬取舆情)")
    logger.info(f"监测平台: {', '.join(PLATFORMS)}")
    logger.info(f"关键词数量: {len(KEYWORDS)}")
    logger.info(f"数据保留: 14天")
    logger.info("-" * 60)

    # 设置定时任务
    schedule.every().day.at("02:00").do(cleanup_data_task)  # 新增:每天凌晨2点清理数据
    schedule.every().day.at("08:00").do(morning_task)
    schedule.every().day.at("13:00").do(noon_task)
    schedule.every().day.at("20:00").do(evening_task)

    logger.info("⏰ 定时任务已设置，等待执行...")
    logger.info("提示：可以按 Ctrl+C 停止守护进程\n")

    # 如果想立即测试，可以取消下面这行的注释
    # logger.info("⚡ 立即执行一次测试爬取...")
    # run_crawl_task()

    # 持续运行
    try:
        while True:
            schedule.run_pending()
            time.sleep(60)  # 每分钟检查一次
    except KeyboardInterrupt:
        logger.info("\n👋 收到停止信号，守护进程正在退出...")
        logger.info("再见！")

if __name__ == "__main__":
    main()
