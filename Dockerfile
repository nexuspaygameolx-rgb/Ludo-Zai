FROM node:20-alpine

WORKDIR /app
COPY backend_render/package*.json ./
RUN npm install --omit=dev
COPY backend_render/ ./

ENV NODE_ENV=production
ENV PORT=10000
EXPOSE 10000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:10000/health || exit 1

CMD ["npm", "start"]
