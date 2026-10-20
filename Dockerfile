# 基础镜像：官方 Node.js 20，alpine 版本体积小（约 50MB）
FROM node:20-alpine

# 设置容器内的工作目录，后面的命令都在 /app 下执行（目录不存在会自动创建）
WORKDIR /app

# 设置运行环境为生产模式
ENV NODE_ENV=production

# 先只复制 package.json：它很少变化，这一层会被缓存，以后装依赖时能跳过
COPY app/package.json ./

# 本项目零依赖，所以不需要 npm install；如果以后加了依赖，在这里写：RUN npm install --omit=dev

# 再复制程序代码：代码经常改，放在后面，改代码只会让这一层及之后的层重建
COPY app/ ./

# 声明容器监听 3000 端口（只是说明文档作用，真正映射端口在 docker-compose.yml 里）
EXPOSE 3000

# 健康检查：每 30 秒用 wget 请求一次 /health，超时 5 秒，启动后宽限 10 秒，连续失败 3 次标记为 unhealthy
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

# 以镜像自带的非 root 用户 node 运行，更安全
USER node

# 容器启动命令：用 exec 格式（数组），node 作为 1 号进程，能直接收到 SIGTERM 实现优雅退出
CMD ["node", "server.js"]
