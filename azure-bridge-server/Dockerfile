FROM node:24-alpine

WORKDIR /app
COPY package*.json ./
COPY server.js .
RUN npm install --production

EXPOSE 80
ENV PORT=80

CMD ["node", "server.js"]
