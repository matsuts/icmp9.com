#!/bin/sh

# 定义颜色 (使用 \033 或 \133 均可，printf 兼容性更好)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 定义一个打印函数，方便调用且保证兼容
# 用法: info "内容"
info() {
    printf "${GREEN}%s${NC}\n" "$1"
}
warn() {
    printf "${YELLOW}%s${NC}\n" "$1"
}
error() {
    printf "${RED}%s${NC}\n" "$1"
}

printf "${GREEN}=============================================${NC}\n"
printf "${GREEN}        ICMP9聚合落地节点部署脚本                ${NC}\n"
printf "${GREEN}     (支持 Debian / Ubuntu / Alpine)          ${NC}\n"
printf "${GREEN}=============================================${NC}\n"

# 1. 环境检测与 Docker 安装
if ! command -v docker >/dev/null 2>&1; then
    warn "⚠️ 未检测到 Docker，正在识别系统并安装..."
    if [ -f /etc/alpine-release ]; then
        apk update
        apk add docker docker-cli-compose
        addgroup root docker >/dev/null 2>&1
        rc-service docker start
        rc-update add docker default
    else
        apt-get update
        apt-get install -y curl
        curl -fsSL https://get.docker.com | sh
        systemctl enable --now docker
    fi
fi

# 检查 Docker Compose
if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
    warn "⚠️ 未检测到 Docker Compose，正在安装..."
    if [ -f /etc/alpine-release ]; then
        apk add docker-cli-compose
    else
        apt-get update
        apt-get install -y docker-compose-plugin
    fi
fi

# 2. 创建工作目录
WORK_DIR="icmp9"
[ ! -d "$WORK_DIR" ] && mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || exit

# 3. 收集用户输入
printf "\n${YELLOW}>>> 请输入配置参数 <<<${NC}\n"

while [ -z "$API_KEY" ]; do
    printf "1. 请输入 ICMP9_API_KEY (必填): "
    read -r API_KEY
done

while [ -z "$SERVER_HOST" ]; do
    printf "2. 请输入 Tunnel 域名 (SERVER_HOST) (必填): "
    read -r SERVER_HOST
done

while [ -z "$TOKEN" ]; do
    printf "3. 请输入 Tunnel Token (必填): "
    read -r TOKEN
done

printf "4. 是否仅 IPv6 (True/False) [默认: False]: "
read -r IPV6_INPUT
[ -z "$IPV6_INPUT" ] && IPV6_ONLY="False" || IPV6_ONLY=$IPV6_INPUT

printf "5. 请输入 CDN 优选 IP 或域名 [默认: icook.tw]: "
read -r CDN_INPUT
[ -z "$CDN_INPUT" ] && CDN_DOMAIN="icook.tw" || CDN_DOMAIN=$CDN_INPUT

printf "6. 请输入起始端口 [默认: 39001]: "
read -r PORT_INPUT
[ -z "$PORT_INPUT" ] && START_PORT="39001" || START_PORT=$PORT_INPUT

# 4. 生成 docker-compose.yml
info "⏳ 正在生成 docker-compose.yml..."

cat > docker-compose.yml <<EOF
services:
  icmp9:
    image: nap0o/icmp9:latest
    container_name: icmp9
    restart: always
    network_mode: "host"
    environment:
      - ICMP9_API_KEY=${API_KEY}
      - ICMP9_SERVER_HOST=${SERVER_HOST}
      - ICMP9_CLOUDFLARED_TOKEN=${TOKEN}
      - ICMP9_IPV6_ONLY=${IPV6_ONLY}
      - ICMP9_CDN_DOMAIN=${CDN_DOMAIN}
      - ICMP9_START_PORT=${START_PORT}
    volumes:
      - ./data/subscribe:/root/subscribe
EOF

# 5. 启动服务
DOCKER_COMPOSE_CMD="docker compose"
if ! docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker-compose"
fi

printf "\n是否立即启动容器？(y/n) [默认: y]: "
read -r START_NOW
[ -z "$START_NOW" ] && START_NOW="y"

if [ "$START_NOW" = "y" ] || [ "$START_NOW" = "Y" ]; then
    info "🚀 正在启动容器..."
    $DOCKER_COMPOSE_CMD up -d
    if [ $? -eq 0 ]; then
        printf "\n${GREEN}✅ ICMP9 部署成功！${NC}\n\n\n"
        printf "✈️ 节点订阅地址: ${YELLOW}https://${SERVER_HOST}/${API_KEY}${NC}\n\n\n"
    else
        error "❌ 启动失败。"
    fi
else
    warn "已取消启动。"
fi