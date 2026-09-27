FROM node:22-alpine
WORKDIR /app
COPY package.json ./
COPY src ./src
ENV NODE_ENV=production DB_PATH=/data/tunteuni.sqlite PORT=8787
VOLUME ["/data"]
EXPOSE 8787
USER node
CMD ["node", "--no-warnings=ExperimentalWarning", "src/server.js"]
