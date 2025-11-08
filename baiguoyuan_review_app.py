"""
百果园舆情监测系统 - 人工审核界面
使用Streamlit开发的中文审核后台
"""

import streamlit as st
import pandas as pd
from datetime import datetime, timedelta
import json
import os
from pathlib import Path
import sqlite3
from openai import OpenAI
import subprocess
import threading

# 页面配置
st.set_page_config(
    page_title="百果园舆情监测系统",
    page_icon="🍎",
    layout="wide",
    initial_sidebar_state="expanded"
)

# 自定义CSS样式
st.markdown("""
<style>
    .main-header {
        font-size: 32px;
        font-weight: bold;
        color: #2E7D32;
        text-align: center;
        padding: 20px 0;
        border-bottom: 3px solid #4CAF50;
        margin-bottom: 30px;
    }
    .stat-card {
        background-color: #f0f2f6;
        padding: 15px;
        border-radius: 10px;
        border-left: 5px solid #4CAF50;
        margin: 10px 0;
    }
    .stat-number {
        font-size: 28px;
        font-weight: bold;
        color: #2E7D32;
    }
    .stat-label {
        font-size: 14px;
        color: #666;
    }
    .sentiment-positive {
        color: #4CAF50;
        font-weight: bold;
    }
    .sentiment-neutral {
        color: #FF9800;
        font-weight: bold;
    }
    .sentiment-negative {
        color: #f44336;
        font-weight: bold;
    }
    .info-card {
        background-color: white;
        padding: 20px;
        border-radius: 10px;
        border: 1px solid #e0e0e0;
        margin: 15px 0;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .platform-tag {
        display: inline-block;
        padding: 3px 8px;
        border-radius: 5px;
        font-size: 12px;
        font-weight: bold;
        margin-right: 5px;
    }
    .tag-xhs { background-color: #FF2442; color: white; }
    .tag-dy { background-color: #000000; color: white; }
    .tag-wb { background-color: #E6162D; color: white; }
    .tag-bili { background-color: #00A1D6; color: white; }
    .status-unprocessed {
        background-color: #FFF3E0;
        color: #F57C00;
        padding: 3px 10px;
        border-radius: 5px;
        font-weight: bold;
    }
    .status-processed {
        background-color: #E8F5E9;
        color: #388E3C;
        padding: 3px 10px;
        border-radius: 5px;
        font-weight: bold;
    }
</style>
""", unsafe_allow_html=True)

# 初始化数据库
def init_database():
    """初始化SQLite数据库"""
    db_path = Path("baiguoyuan_sentiment.db")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # 创建舆情信息表
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS sentiment_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            platform TEXT NOT NULL,
            keyword TEXT NOT NULL,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            url TEXT,
            author TEXT,
            publish_time TEXT,
            crawl_time TEXT NOT NULL,
            hot_score INTEGER DEFAULT 0,
            sentiment TEXT,
            sentiment_score REAL,
            category TEXT,
            status TEXT DEFAULT 'unprocessed',
            processed_time TEXT,
            notes TEXT
        )
    """)

    conn.commit()
    conn.close()

# DeepSeek AI分析
def analyze_sentiment_and_category(title, content):
    """使用DeepSeek进行情感分析和分类"""
    try:
        client = OpenAI(
            api_key="sk-aecac2abdacb49488c4fb1e7d1c62a94",
            base_url="https://api.deepseek.com"
        )

        prompt = f"""
请分析以下关于百果园的信息，返回JSON格式：

标题：{title}
内容：{content}

请返回：
1. sentiment: 情感（positive/neutral/negative）
2. sentiment_score: 情感分数（-1到1之间，负数表示负面）
3. category: 分类（价格问题/商品问题/服务问题/会员问题/安全问题/其他问题）

只返回JSON，不要其他内容。格式：
{{"sentiment": "...", "sentiment_score": 0.0, "category": "..."}}
"""

        response = client.chat.completions.create(
            model="deepseek-chat",
            messages=[
                {"role": "system", "content": "你是一个专业的舆情分析助手，专门分析百果园品牌相关的用户反馈。"},
                {"role": "user", "content": prompt}
            ],
            temperature=0.3
        )

        result = json.loads(response.choices[0].message.content)
        return result
    except Exception as e:
        print(f"AI分析错误: {e}")
        return {
            "sentiment": "neutral",
            "sentiment_score": 0,
            "category": "其他问题"
        }

# 添加测试数据
def add_sample_data():
    """添加测试数据（演示用）"""
    conn = sqlite3.connect("baiguoyuan_sentiment.db")
    cursor = conn.cursor()

    # 检查是否已有数据
    cursor.execute("SELECT COUNT(*) FROM sentiment_data")
    if cursor.fetchone()[0] > 0:
        conn.close()
        return

    sample_data = [
        {
            "platform": "xhs",
            "keyword": "百果园&贵",
            "title": "百果园真是水果刺客，太贵了买不起！",
            "content": "今天去百果园买了一个苹果18块钱，一个榴莲要98，真的是水果界的爱马仕，普通人根本吃不起。虽然水果确实新鲜，但这价格真的离谱。",
            "url": "https://xiaohongshu.com/discovery/item/xxxxx1",
            "author": "用户12345",
            "publish_time": "2025-11-06 10:23:00",
            "crawl_time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "hot_score": 12000,
            "sentiment": "negative",
            "sentiment_score": -0.85,
            "category": "价格问题",
            "status": "unprocessed"
        },
        {
            "platform": "dy",
            "keyword": "百果园&刺客",
            "title": "探店百果园，看看是不是真的是水果刺客！",
            "content": "今天带大家探店百果园，结账时被价格吓到了，一共才买了3样水果就花了150块。不过说实话，水果质量确实不错，就是价格对普通家庭来说确实有点贵。",
            "url": "https://douyin.com/video/xxxxx2",
            "author": "探店达人",
            "publish_time": "2025-11-06 09:15:00",
            "crawl_time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "hot_score": 56000,
            "sentiment": "neutral",
            "sentiment_score": -0.12,
            "category": "价格问题",
            "status": "unprocessed"
        },
        {
            "platform": "wb",
            "keyword": "百果园",
            "title": "百果园的会员卡不让退款，太坑了",
            "content": "充了500块钱会员卡，结果搬家了新地方没有百果园，想退卡不给退。客服态度还很差，说是规定不能退。这是霸王条款吧？",
            "url": "https://weibo.com/xxxxx3",
            "author": "维权用户",
            "publish_time": "2025-11-06 08:45:00",
            "crawl_time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "hot_score": 8900,
            "sentiment": "negative",
            "sentiment_score": -0.75,
            "category": "会员问题",
            "status": "unprocessed"
        },
        {
            "platform": "bili",
            "keyword": "百果园",
            "title": "百果园买的榴莲好甜！物有所值",
            "content": "昨天在百果园买了一个金枕榴莲，虽然价格是88一斤，但是真的超级甜，肉也很多。买水果就图个放心，贵点但品质确实有保障。",
            "url": "https://bilibili.com/video/xxxxx4",
            "author": "美食博主",
            "publish_time": "2025-11-06 11:30:00",
            "crawl_time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "hot_score": 3200,
            "sentiment": "positive",
            "sentiment_score": 0.88,
            "category": "商品问题",
            "status": "unprocessed"
        },
        {
            "platform": "xhs",
            "keyword": "百果园&吃不起",
            "title": "2万元吃不起百果园？这个梗火了",
            "content": "最近网上在传月薪2万都吃不起百果园的梗，说实话有点夸张了。但百果园确实比普通水果店贵不少，一个月去两三次还是可以的，天天吃确实吃不起。",
            "url": "https://xiaohongshu.com/discovery/item/xxxxx5",
            "author": "理性消费者",
            "publish_time": "2025-11-05 20:15:00",
            "crawl_time": (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d %H:%M:%S"),
            "hot_score": 45000,
            "sentiment": "neutral",
            "sentiment_score": -0.25,
            "category": "价格问题",
            "status": "processed"
        }
    ]

    for item in sample_data:
        cursor.execute("""
            INSERT INTO sentiment_data
            (platform, keyword, title, content, url, author, publish_time,
             crawl_time, hot_score, sentiment, sentiment_score, category, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            item["platform"], item["keyword"], item["title"], item["content"],
            item["url"], item["author"], item["publish_time"], item["crawl_time"],
            item["hot_score"], item["sentiment"], item["sentiment_score"],
            item["category"], item["status"]
        ))

    conn.commit()
    conn.close()

# 获取统计数据
def get_statistics(date_filter, status_filter):
    """获取统计数据"""
    conn = sqlite3.connect("baiguoyuan_sentiment.db")

    # 构建时间过滤条件
    date_condition = ""
    if date_filter == "今天":
        date_condition = f"AND crawl_time >= '{datetime.now().strftime('%Y-%m-%d')}'"
    elif date_filter == "昨天":
        yesterday = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
        date_condition = f"AND crawl_time >= '{yesterday}' AND crawl_time < '{datetime.now().strftime('%Y-%m-%d')}'"
    elif date_filter == "近7天":
        week_ago = (datetime.now() - timedelta(days=7)).strftime('%Y-%m-%d')
        date_condition = f"AND crawl_time >= '{week_ago}'"
    elif date_filter == "近30天":
        month_ago = (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d')
        date_condition = f"AND crawl_time >= '{month_ago}'"

    # 状态过滤
    status_condition = ""
    if status_filter != "全部":
        status_value = "unprocessed" if status_filter == "未处理" else "processed"
        status_condition = f"AND status = '{status_value}'"

    # 总监测数
    total_query = f"SELECT COUNT(*) FROM sentiment_data WHERE 1=1 {date_condition} {status_condition}"
    total_count = pd.read_sql_query(total_query, conn).iloc[0, 0]

    # 未处理数
    unprocessed_query = f"SELECT COUNT(*) FROM sentiment_data WHERE status='unprocessed' {date_condition}"
    unprocessed_count = pd.read_sql_query(unprocessed_query, conn).iloc[0, 0]

    # 负面信息数
    negative_query = f"SELECT COUNT(*) FROM sentiment_data WHERE sentiment='negative' {date_condition} {status_condition}"
    negative_count = pd.read_sql_query(negative_query, conn).iloc[0, 0]

    # 价格问题数
    price_query = f"SELECT COUNT(*) FROM sentiment_data WHERE category='价格问题' {date_condition} {status_condition}"
    price_count = pd.read_sql_query(price_query, conn).iloc[0, 0]

    conn.close()

    return {
        "total": total_count,
        "unprocessed": unprocessed_count,
        "negative": negative_count,
        "price": price_count
    }

# 获取列表数据
def get_items_list(platform_filter, category_filter, date_filter, status_filter, page=1, page_size=10):
    """获取舆情列表"""
    conn = sqlite3.connect("baiguoyuan_sentiment.db")

    # 构建查询条件
    conditions = []

    if platform_filter != "全部":
        platform_map = {"小红书": "xhs", "抖音": "dy", "微博": "wb", "B站": "bili"}
        conditions.append(f"platform = '{platform_map[platform_filter]}'")

    if category_filter != "全部":
        conditions.append(f"category = '{category_filter}'")

    if date_filter == "今天":
        conditions.append(f"crawl_time >= '{datetime.now().strftime('%Y-%m-%d')}'")
    elif date_filter == "昨天":
        yesterday = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
        today = datetime.now().strftime('%Y-%m-%d')
        conditions.append(f"crawl_time >= '{yesterday}' AND crawl_time < '{today}'")
    elif date_filter == "近7天":
        week_ago = (datetime.now() - timedelta(days=7)).strftime('%Y-%m-%d')
        conditions.append(f"crawl_time >= '{week_ago}'")
    elif date_filter == "近30天":
        month_ago = (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d')
        conditions.append(f"crawl_time >= '{month_ago}'")

    if status_filter != "全部":
        status_value = "unprocessed" if status_filter == "未处理" else "processed"
        conditions.append(f"status = '{status_value}'")

    where_clause = " AND ".join(conditions) if conditions else "1=1"

    query = f"""
        SELECT * FROM sentiment_data
        WHERE {where_clause}
        ORDER BY crawl_time DESC
        LIMIT {page_size} OFFSET {(page-1)*page_size}
    """

    df = pd.read_sql_query(query, conn)

    # 获取总数
    count_query = f"SELECT COUNT(*) FROM sentiment_data WHERE {where_clause}"
    total_count = pd.read_sql_query(count_query, conn).iloc[0, 0]

    conn.close()

    return df, total_count

# 标记为已处理
def mark_as_processed(item_id):
    """标记信息为已处理"""
    conn = sqlite3.connect("baiguoyuan_sentiment.db")
    cursor = conn.cursor()
    cursor.execute("""
        UPDATE sentiment_data
        SET status = 'processed', processed_time = ?
        WHERE id = ?
    """, (datetime.now().strftime("%Y-%m-%d %H:%M:%S"), item_id))
    conn.commit()
    conn.close()

# 手动触发爬虫
def trigger_crawl():
    """手动触发全网爬取任务"""
    try:
        # 检查MindSpider目录是否存在
        mindspider_dir = Path(__file__).parent / "MindSpider"
        if not mindspider_dir.exists():
            return False, "MindSpider目录不存在"

        # 平台列表
        platforms = ["xhs", "dy", "wb", "bili"]

        # 在后台运行爬取任务
        def run_background_crawl():
            os.chdir(mindspider_dir)
            for platform in platforms:
                try:
                    cmd = [
                        "python", "main.py",
                        "--deep-sentiment",
                        "--platforms", platform,
                        "--max-keywords", "10",
                        "--max-notes", "20"
                    ]
                    subprocess.run(cmd, timeout=600, capture_output=True)
                except Exception as e:
                    print(f"平台 {platform} 爬取失败: {e}")

        # 启动后台线程
        thread = threading.Thread(target=run_background_crawl, daemon=True)
        thread.start()

        return True, "爬取任务已在后台启动"
    except Exception as e:
        return False, f"启动失败: {str(e)}"

# 主界面
def main():
    # 初始化数据库
    init_database()
    add_sample_data()

    # 标题
    st.markdown('<div class="main-header">🍎 百果园舆情监测系统 - 人工审核后台</div>', unsafe_allow_html=True)

    # 顶部刷新按钮
    col_refresh1, col_refresh2, col_refresh3 = st.columns([2, 1, 2])
    with col_refresh2:
        if st.button("🔄 手动刷新全网数据", use_container_width=True, type="primary"):
            with st.spinner("正在启动全网爬取..."):
                success, message = trigger_crawl()
                if success:
                    st.success("✅ 已完成全网搜索！爬取任务已启动，数据将在几分钟内更新")
                    st.balloons()
                else:
                    st.error(f"❌ {message}")

    st.markdown("---")

    # 侧边栏筛选条件
    st.sidebar.header("🔍 筛选条件")

    platform_filter = st.sidebar.selectbox(
        "平台",
        ["全部", "小红书", "抖音", "微博", "B站"],
        index=0
    )

    category_filter = st.sidebar.selectbox(
        "分类",
        ["全部", "价格问题", "商品问题", "服务问题", "会员问题", "安全问题", "其他问题"],
        index=0
    )

    date_filter = st.sidebar.selectbox(
        "日期",
        ["全部", "今天", "昨天", "近7天", "近30天"],
        index=1
    )

    status_filter = st.sidebar.selectbox(
        "状态",
        ["未处理", "已处理", "全部"],
        index=0
    )

    if st.sidebar.button("🔄 刷新数据", use_container_width=True):
        st.rerun()

    # 统计概览
    st.subheader("📊 统计概览")
    stats = get_statistics(date_filter, status_filter)

    col1, col2, col3, col4 = st.columns(4)

    with col1:
        st.markdown(f"""
        <div class="stat-card">
            <div class="stat-number">{stats['total']}</div>
            <div class="stat-label">今日监测</div>
        </div>
        """, unsafe_allow_html=True)

    with col2:
        st.markdown(f"""
        <div class="stat-card">
            <div class="stat-number" style="color: #FF9800;">{stats['unprocessed']}</div>
            <div class="stat-label">未处理</div>
        </div>
        """, unsafe_allow_html=True)

    with col3:
        st.markdown(f"""
        <div class="stat-card">
            <div class="stat-number" style="color: #f44336;">{stats['negative']}</div>
            <div class="stat-label">负面信息</div>
        </div>
        """, unsafe_allow_html=True)

    with col4:
        st.markdown(f"""
        <div class="stat-card">
            <div class="stat-number" style="color: #2E7D32;">{stats['price']}</div>
            <div class="stat-label">价格问题</div>
        </div>
        """, unsafe_allow_html=True)

    st.markdown("---")

    # 信息列表
    st.subheader("📋 舆情信息列表")

    # 获取数据
    df, total_count = get_items_list(platform_filter, category_filter, date_filter, status_filter)

    if len(df) == 0:
        st.info("暂无符合条件的数据")
        return

    # 显示每条信息
    for idx, row in df.iterrows():
        # 平台图标映射
        platform_map = {
            "xhs": ("📱", "小红书", "tag-xhs"),
            "dy": ("📹", "抖音", "tag-dy"),
            "wb": ("🐦", "微博", "tag-wb"),
            "bili": ("📺", "B站", "tag-bili")
        }

        icon, platform_name, platform_class = platform_map.get(row['platform'], ("❓", "未知", "tag-xhs"))

        # 情感显示
        sentiment_map = {
            "positive": ("😊", "正面", "sentiment-positive"),
            "neutral": ("😐", "中性", "sentiment-neutral"),
            "negative": ("😡", "负面", "sentiment-negative")
        }
        sentiment_icon, sentiment_text, sentiment_class = sentiment_map.get(
            row['sentiment'], ("😐", "未知", "sentiment-neutral")
        )

        # 状态显示
        status_display = "未处理" if row['status'] == "unprocessed" else "已处理"
        status_class = "status-unprocessed" if row['status'] == "unprocessed" else "status-processed"

        st.markdown(f"""
        <div class="info-card">
            <div style="margin-bottom: 10px;">
                <span class="platform-tag {platform_class}">{icon} {platform_name}</span>
                <span style="color: #666; font-size: 14px;">⏰ {row['publish_time']}</span>
                <span style="color: #666; font-size: 14px; margin-left: 10px;">🔥 热度：{row['hot_score']:,}</span>
                <span class="{status_class}" style="float: right;">{status_display}</span>
            </div>
            <div style="margin-bottom: 8px;">
                <span style="background-color: #E3F2FD; color: #1976D2; padding: 2px 8px; border-radius: 3px; font-size: 12px;">
                    关键词：{row['keyword']}
                </span>
            </div>
            <div style="font-size: 16px; font-weight: bold; margin-bottom: 8px; color: #333;">
                {row['title']}
            </div>
            <div style="font-size: 14px; color: #666; margin-bottom: 10px; line-height: 1.6;">
                {row['content'][:200]}{'...' if len(row['content']) > 200 else ''}
            </div>
            <div style="margin-bottom: 10px;">
                <span class="{sentiment_class}">{sentiment_icon} {sentiment_text} ({row['sentiment_score']:.2f})</span>
                <span style="margin-left: 15px; color: #666;">| 分类：💰 {row['category']}</span>
            </div>
            <div style="font-size: 12px; color: #999;">
                🔗 <a href="{row['url']}" target="_blank">{row['url']}</a>
            </div>
        </div>
        """, unsafe_allow_html=True)

        # 操作按钮
        col1, col2, col3 = st.columns([1, 1, 3])

        with col1:
            # 复制内容按钮
            copy_text = f"【{platform_name}】{row['title']}\n\n{row['content']}\n\n链接：{row['url']}"
            if st.button(f"📋 复制内容", key=f"copy_{row['id']}", use_container_width=True):
                st.code(copy_text, language=None)
                st.success("✅ 内容已显示，请手动复制")

        with col2:
            # 标记已处理按钮
            if row['status'] == 'unprocessed':
                if st.button(f"✅ 标记已处理", key=f"mark_{row['id']}", use_container_width=True):
                    mark_as_processed(row['id'])
                    st.success("已标记为已处理！")
                    st.rerun()
            else:
                st.button(f"✓ 已处理", key=f"marked_{row['id']}", disabled=True, use_container_width=True)

        st.markdown("---")

    # 分页
    st.markdown(f"<div style='text-align: center; color: #666;'>共 {total_count} 条数据</div>", unsafe_allow_html=True)

if __name__ == "__main__":
    main()
