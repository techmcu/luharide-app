FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev || npm install --omit=dev
COPY . .
ENV NODE_ENV=production
EXPOSE 3000 3001 3002 3003 3004
# Default remains monolith; compose overrides command per service
CMD ["node", "server.js"]
