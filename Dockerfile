# build + prod in one go for a simple Node app on port 8080
FROM node:16 as build
WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY . .
EXPOSE 8080
CMD ["npm", "start"]