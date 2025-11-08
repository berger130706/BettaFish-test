# 安全说明

## 🔐 敏感信息保护

本项目包含以下敏感信息,已通过 `.gitignore` 排除提交:

### 不会提交到Git的文件

1. **环境变量文件**
   - `.env` - 包含API密钥、数据库密码等
   - `.venv/`, `venv/` - Python虚拟环境

2. **数据库文件**
   - `baiguoyuan_sentiment.db` - SQLite数据库
   - `backups/` - 数据库备份目录

3. **运行时文件**
   - `*.pid` - 进程ID文件
   - `*.log` - 日志文件
   - `logs/` - 日志目录

4. **临时文件**
   - `__pycache__/` - Python缓存
   - `*.pyc` - 编译后的Python文件

## 🔑 API密钥管理

### 正确配置方式

所有API密钥应该存储在 `.env` 文件中:

```bash
# DeepSeek API密钥
INSIGHT_ENGINE_API_KEY=sk-your-api-key-here
MEDIA_ENGINE_API_KEY=sk-your-api-key-here
QUERY_ENGINE_API_KEY=sk-your-api-key-here
REPORT_ENGINE_API_KEY=sk-your-api-key-here
MINDSPIDER_API_KEY=sk-your-api-key-here

# 数据库配置
DB_USER=your_db_user
DB_PASSWORD=your_db_password
```

### ❌ 不要这样做

- ❌ 不要在代码中硬编码API密钥
- ❌ 不要提交 `.env` 文件到Git
- ❌ 不要在文档中写入真实的API密钥
- ❌ 不要在公开的README中暴露密钥

### ✅ 应该这样做

- ✅ 使用环境变量读取密钥: `os.getenv("API_KEY")`
- ✅ 提供 `.env.example` 作为模板
- ✅ 在文档中使用占位符: `sk-your-api-key-here`
- ✅ 将 `.env` 添加到 `.gitignore`

## 🛡️ 如果API密钥泄露

### 立即行动

1. **撤销旧密钥**
   - 登录API提供商控制台
   - 删除或禁用泄露的密钥

2. **生成新密钥**
   - 创建新的API密钥
   - 更新本地 `.env` 文件

3. **清理Git历史**(如果密钥曾被提交)
   ```bash
   # 使用BFG Repo-Cleaner清理
   brew install bfg
   bfg --replace-text passwords.txt .git
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive
   git push --force
   ```

4. **更新服务器配置**
   ```bash
   # SSH登录服务器
   ssh root@101.201.214.42

   # 更新.env文件
   nano /root/BettaFish-test/.env

   # 重启服务
   systemctl restart baiguoyuan
   systemctl restart baiguoyuan-scheduler
   ```

## 📋 安全检查清单

部署前请确认:

- [ ] `.env` 文件在 `.gitignore` 中
- [ ] 代码中没有硬编码的密钥
- [ ] 数据库文件不会被提交
- [ ] 所有敏感配置使用环境变量
- [ ] 服务器密码已修改为强密码
- [ ] 阿里云安全组仅开放必要端口

## 🔒 服务器安全

### 默认配置

- 服务器IP: `101.201.214.42`
- SSH端口: `22`
- 默认密码: `qwer.123` ⚠️ **建议立即修改**

### 加固建议

1. **修改SSH密码**
   ```bash
   passwd
   ```

2. **配置防火墙**
   ```bash
   # 仅允许特定IP访问SSH
   ufw allow from YOUR_IP to any port 22
   ```

3. **定期备份**
   ```bash
   # 设置自动备份
   crontab -e
   # 添加:每天凌晨3点备份
   0 3 * * * cp /root/BettaFish-test/baiguoyuan_sentiment.db /root/backups/db_$(date +\%Y\%m\%d).db
   ```

## 📞 报告安全问题

如果发现安全问题,请联系:
- 邮箱: [项目维护者邮箱]
- 不要在公开issue中讨论安全漏洞

---

**最后更新**: 2025-11-08
**版本**: v1.0
