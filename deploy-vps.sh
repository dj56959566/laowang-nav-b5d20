#!/bin/bash

# VPS 一键部署脚本
# 用途：快速设置导航站自动同步

set -e  # 遇到错误立即退出

echo "======================================"
echo "导航站自动同步一键部署脚本"
echo "======================================"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置变量（请根据实际情况修改）
PROJECT_DIR="/opt/laowang-nav"
LOG_FILE="/var/log/nav-sync.log"
CRON_SCHEDULE="0 */6 * * *"  # 每6小时

# 检查是否为 root 或有 sudo 权限
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}注意：部分操作可能需要 sudo 权限${NC}"
fi

# 步骤 1: 检查项目目录
echo -e "${GREEN}[1/5] 检查项目目录...${NC}"
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}错误: 项目目录不存在: $PROJECT_DIR${NC}"
    echo "请先将项目文件上传到 VPS 或克隆 Git 仓库"
    exit 1
fi
cd "$PROJECT_DIR"
echo "✓ 项目目录: $PROJECT_DIR"

# 步骤 2: 检查 Node.js 和 npm
echo -e "${GREEN}[2/5] 检查 Node.js 环境...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${RED}错误: Node.js 未安装${NC}"
    exit 1
fi
if ! command -v npm &> /dev/null; then
    echo -e "${RED}错误: npm 未安装${NC}"
    exit 1
fi
echo "✓ Node.js 版本: $(node -v)"
echo "✓ npm 版本: $(npm -v)"

# 步骤 3: 安装依赖
echo -e "${GREEN}[3/5] 安装项目依赖...${NC}"
npm install --production
echo "✓ 依赖安装完成"

# 步骤 4: 测试同步脚本
echo -e "${GREEN}[4/5] 测试同步脚本...${NC}"
if npm run sync; then
    echo "✓ 同步测试成功"
else
    echo -e "${RED}错误: 同步脚本执行失败${NC}"
    exit 1
fi

# 步骤 5: 设置 crontab
echo -e "${GREEN}[5/5] 配置定时任务...${NC}"

# 获取 npm 的绝对路径
NPM_PATH=$(which npm)

# 创建 crontab 条目
CRON_ENTRY="$CRON_SCHEDULE cd $PROJECT_DIR && $NPM_PATH run sync >> $LOG_FILE 2>&1"

# 检查是否已存在相同的定时任务
if crontab -l 2>/dev/null | grep -q "npm run sync"; then
    echo -e "${YELLOW}检测到已存在的同步任务，是否替换？(y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        # 删除旧的任务
        crontab -l 2>/dev/null | grep -v "npm run sync" | crontab -
        # 添加新任务
        (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
        echo "✓ 定时任务已更新"
    else
        echo "保持现有定时任务"
    fi
else
    # 添加新任务
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
    echo "✓ 定时任务已添加"
fi

# 显示当前 crontab
echo ""
echo "当前的定时任务："
crontab -l | grep "npm run sync"

# 创建日志文件
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

echo ""
echo -e "${GREEN}======================================"
echo "部署完成！"
echo "======================================${NC}"
echo ""
echo "配置信息："
echo "  - 项目目录: $PROJECT_DIR"
echo "  - 同步频率: 每6小时"
echo "  - 日志文件: $LOG_FILE"
echo ""
echo "接下来的步骤："
echo "  1. 修改 docker-compose.yml 添加 volume 挂载"
echo "  2. 重启 Docker 容器"
echo "  3. 访问 https://nav.199060.xyz 验证"
echo ""
echo "查看日志："
echo "  tail -f $LOG_FILE"
echo ""
echo -e "${GREEN}🎉 自动同步已启用！${NC}"
