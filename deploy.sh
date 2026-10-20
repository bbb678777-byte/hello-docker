#!/usr/bin/env bash
# =============================================================
#  hello-docker 部署脚本（在服务器上执行）
#
#  用法：
#    bash deploy.sh            # 部署 origin/main 最新代码
#    bash deploy.sh v1.0.0     # 部署/回滚到指定标签（或分支、commit）
# =============================================================
#
# 整个流程包在 main 函数里，最后一行才调用：
# 因为 git reset 会改写本脚本自身，bash 是边读边执行的，
# 先把函数完整读进内存再执行，就不会因为脚本被修改而出错。

set -euo pipefail

APP_DIR="/www/wwwroot/hello-docker"
CONTAINER="hello-docker"
HEALTH_URL="http://127.0.0.1:3000/health"
MAX_RETRY=15

log()  { echo -e "\033[32m[deploy $(date '+%F %T')]\033[0m $*"; }
fail() { echo -e "\033[31m[deploy $(date '+%F %T')] ✗ $*\033[0m" >&2; }

main() {
  local target="${1:-origin/main}"

  cd "$APP_DIR"

  # 1. 选择 compose 命令：新版是 docker compose（插件），旧版是 docker-compose（独立程序）
  local compose
  if docker compose version >/dev/null 2>&1; then
    compose="docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    compose="docker-compose"
  else
    fail "没有找到 docker compose 或 docker-compose，请先安装"
    exit 1
  fi
  log "使用 compose 命令：$compose"

  # 2. 拉取远程最新代码和所有标签（--force 允许更新被移动过的标签）
  log "git fetch --all --tags"
  git fetch --all --tags --prune --force

  # 3. 强制让工作区和目标版本完全一致（会丢弃服务器上手动改过的代码，这是故意的）
  log "切换到目标版本：$target"
  git reset --hard "$target"
  log "当前提交：$(git log -1 --pretty='%h %s (%an, %ar)')"

  # 4. 重新构建镜像并启动容器（代码没变时会用缓存，很快）
  log "$compose up -d --build"
  $compose up -d --build

  # 5. 健康检查：每 2 秒请求一次 /health，最多 MAX_RETRY 次
  log "健康检查：$HEALTH_URL"
  local i
  for ((i = 1; i <= MAX_RETRY; i++)); do
    if resp=$(curl -fsS --max-time 3 "$HEALTH_URL" 2>/dev/null); then
      log "✓ 第 $i 次检查通过：$(echo "$resp" | tr -d '\n ')"
      # 6. 清理构建产生的悬空镜像（<none> 标签），释放磁盘
      docker image prune -f >/dev/null
      log "✓ 部署成功！"
      return 0
    fi
    echo "  第 $i/$MAX_RETRY 次检查未通过，2 秒后重试..."
    sleep 2
  done

  # 走到这里说明健康检查一直失败
  fail "健康检查失败，最近 50 行容器日志如下："
  docker logs --tail 50 "$CONTAINER" || true
  $compose ps || true
  exit 1
}

main "$@"
exit $?
