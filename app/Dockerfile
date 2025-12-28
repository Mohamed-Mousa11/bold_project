# Minimal Node.js runtime
FROM node:20-alpine

WORKDIR /usr/src/app

# Install dependencies first to leverage Docker layer caching
COPY package.json ./
RUN npm install --only=production

# Copy application code
COPY src ./src
COPY scripts ./scripts

ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

CMD ["npm", "start"]
