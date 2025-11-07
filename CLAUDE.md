# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BettaFish (微舆) is a multi-agent public opinion analysis system that analyzes social media and user comments across 30+ platforms. The system uses specialized AI agents that collaborate through a "forum" mechanism to identify trends, perform sentiment analysis, and generate comprehensive reports.

## Core Architecture

### Multi-Agent System

The system consists of 4 main agent engines that work in parallel:

1. **InsightEngine** (`InsightEngine/agent.py`) - Private database mining agent
   - Queries internal MySQL/PostgreSQL databases for historical sentiment data
   - Recommended LLM: Kimi (Moonshot API)
   - 783 lines of core logic

2. **MediaEngine** (`MediaEngine/agent.py`) - Multimodal content analysis agent
   - Analyzes images, videos, and structured data from search results
   - Recommended LLM: Gemini 2.5 Pro
   - 441 lines of core logic

3. **QueryEngine** (`QueryEngine/agent.py`) - Web search agent
   - Performs broad web and news searches using Tavily and Bocha APIs
   - Recommended LLM: DeepSeek Reasoner
   - 473 lines of core logic

4. **ReportEngine** (`ReportEngine/agent.py`) - Report generation agent
   - Synthesizes all findings into HTML reports using Markdown templates
   - Recommended LLM: Gemini 2.5 Pro
   - 495 lines of core logic

### Agent Collaboration Pattern

- **ForumEngine** (`ForumEngine/monitor.py` and `llm_host.py`) coordinates multi-agent discussion
- Each agent outputs findings to log files monitored by the forum system
- A moderator LLM generates summaries every 5 agent statements
- Agents read forum summaries and adjust research direction accordingly

### Common Agent Structure

All agents follow a consistent pattern:
```
<AgentName>/
├── agent.py              # Main orchestration logic
├── llms/base.py          # OpenAI-compatible LLM client
├── nodes/                # Processing nodes (search, reflection, summary, formatting)
├── tools/                # Agent-specific tools (search APIs, database queries)
├── state/state.py        # Agent state management
├── prompts/prompts.py    # System prompts and templates
└── utils/config.py       # Configuration
```

## Configuration

All configuration is managed via Pydantic Settings in `/config.py`:

- Configuration is loaded from `.env` file (see `.env.example` template)
- 94+ configuration fields covering databases, LLM APIs, search APIs, and limits
- Environment variables are case-insensitive
- `.env` should be placed in the project root directory

**Key configuration categories:**
- Database: `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_DIALECT` (mysql/postgresql)
- LLM APIs: Each agent has its own `<AGENT>_API_KEY`, `<AGENT>_BASE_URL`, `<AGENT>_MODEL_NAME`
- Search APIs: `TAVILY_API_KEY`, `BOCHA_WEB_SEARCH_API_KEY`

## Development Commands

### Environment Setup

Using Conda:
```bash
conda create -n your_env_name python=3.11
conda activate your_env_name
pip install -r requirements.txt
playwright install chromium
```

Using uv (faster):
```bash
uv venv --python 3.11
source .venv/bin/activate  # Linux/macOS
.venv\Scripts\activate     # Windows
uv pip install -r requirements.txt
playwright install chromium
```

### Running the System

**Full system (Flask orchestrator + 3 Streamlit agents):**
```bash
python app.py
# Access at http://localhost:5000
# Agent dashboards run on ports 8501-8503
```

**Individual agents (for testing):**
```bash
streamlit run SingleEngineApp/query_engine_streamlit_app.py --server.port 8503
streamlit run SingleEngineApp/media_engine_streamlit_app.py --server.port 8502
streamlit run SingleEngineApp/insight_engine_streamlit_app.py --server.port 8501
```

### MindSpider Crawler System

Separate crawler for gathering social media data (see `MindSpider/README.md`):

```bash
cd MindSpider

# Initialize database
python main.py --setup

# Check status
python main.py --status

# Extract daily topics from news sources
python main.py --broad-topic

# Run deep crawling on specific platforms (requires login first)
python main.py --deep-sentiment --platforms xhs dy wb --test

# Complete workflow
python main.py --complete --test
```

**First-time platform login (critical):**
```bash
# Each platform requires QR code login on first use
python main.py --deep-sentiment --platforms xhs --test  # Scan with Xiaohongshu app
python main.py --deep-sentiment --platforms dy --test   # Scan with Douyin app
# Repeat for: ks (Kuaishou), bili (Bilibili), wb (Weibo), tieba, zhihu
```

### Docker Deployment

```bash
docker-compose up -d
# Services:
# - bettafish: Main application (ports 5000, 8501-8503)
# - db: PostgreSQL 15 database (port 5432)
```

## Key Implementation Patterns

### LLM Integration

All agents use OpenAI-compatible API clients:
```python
from openai import OpenAI

client = OpenAI(
    api_key=config.INSIGHT_ENGINE_API_KEY,
    base_url=config.INSIGHT_ENGINE_BASE_URL
)

response = client.chat.completions.create(
    model=config.INSIGHT_ENGINE_MODEL_NAME,
    messages=[{'role': 'user', 'content': 'query'}]
)
```

### Database Queries

InsightEngine provides database search tools in `InsightEngine/tools/search.py`:
- `search_topic_globally()` - Search posts by keywords (limit: 200)
- `get_comments_by_content_ids()` - Fetch comments for posts (limit: 500)
- Uses `keyword_optimizer.py` with Qwen3 to generate SQL-safe keywords

### Sentiment Analysis

5 sentiment analysis models available in `SentimentAnalysisModel/`:
1. **WeiboMultilingualSentiment** - 22-language support (recommended)
2. WeiboSentiment_Finetuned - BERT/GPT-2 variants
3. WeiboSentiment_SmallQwen - Lightweight Qwen3 fine-tuning
4. WeiboSentiment_MachineLearning - SVM/XGBoost models
5. BertTopicDetection_Finetuned - Topic extraction

Access via `InsightEngine/tools/sentiment_analyzer.py`

### Report Generation

ReportEngine uses Markdown templates in `ReportEngine/report_template/`:
- Templates for social events, brand reputation monitoring, custom analyses
- Agent automatically selects appropriate template based on query
- Multi-turn HTML generation with Plotly visualizations

## Working with Agents

### Modifying Agent Behavior

Each agent has configurable parameters in `<Agent>/utils/config.py`:
```python
# Example: QueryEngine/utils/config.py
class Config:
    max_reflections = 2           # Deep analysis iterations
    max_search_results = 15       # Results per search
    max_content_length = 8000     # Content truncation limit
```

### Adding Custom Tools

To add business database tools to InsightEngine:
1. Create `InsightEngine/tools/custom_db_tool.py`
2. Initialize in `InsightEngine/agent.py`
3. Register in agent's tool list
4. Update system prompts to instruct LLM when to use the tool

### Forum Collaboration

ForumEngine monitors specific log files:
- `FirstSummaryNode` outputs (initial analysis)
- `ReflectionSummaryNode` outputs (deep analysis)
- Moderator triggers every 5 statements
- Agents read forum via `utils/forum_reader.py`

## Important Notes

- **Encoding**: System explicitly configured for UTF-8 (`PYTHONIOENCODING=utf-8`)
- **Async Operations**: Extensive use of `asyncio`, `aiohttp`, `asyncpg` for crawler performance
- **State Management**: Each agent maintains state via `state/state.py` (typed dictionaries)
- **Error Handling**: Use `utils/retry_helper.py` for network request retries
- **Logging**: Loguru configured in each module, outputs to `logs/` directory
- **Reports**: Generated HTML saved to `final_reports/`

## Common Troubleshooting

**Streamlit agents don't stop properly:**
```bash
# Find and kill orphaned processes
# Windows: netstat -ano | findstr "8501"
# Linux/macOS: lsof -i :8501
kill -9 <PID>
```

**Database connection fails:**
- Verify `.env` has correct `DB_*` values
- Check database is running: `python main.py --status` (for MindSpider)
- Ensure charset is `utf8mb4` for emoji support

**LLM API errors:**
- Confirm API keys are valid in `.env`
- Check BASE_URL format includes `/v1` suffix for OpenAI-compatible endpoints
- Verify model names match provider's naming (e.g., `kimi-k2-0711-preview`, `gemini-2.5-pro`)

**Crawler login issues:**
- Set `HEADLESS = False` in `DeepSentimentCrawling/MediaCrawler/config/base_config.py`
- Delete `DeepSentimentCrawling/MediaCrawler/browser_data/` to force re-login
- Use `--test` flag for small-scale verification

## File Locations

- **Main app**: `app.py` (Flask orchestrator, 1042 lines)
- **Global config**: `config.py` (Pydantic Settings, 97 lines)
- **Templates**: `templates/index.html` (web UI)
- **Static assets**: `static/` (images, CSS, JS)
- **Logs**: `logs/`
- **Final reports**: `final_reports/`
- **Agent state**: `*_streamlit_reports/` (Streamlit session state)
- **Database schema**: `MindSpider/schema/mindspider_tables.sql`
