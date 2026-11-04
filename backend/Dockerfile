FROM node:20-alpine

WORKDIR /app

# Install dependencies first so this layer is cached when only code changes
COPY package*.json ./
RUN npm install --omit=dev

COPY index.js ./

# Run as the unprivileged user that ships with the node image
USER node

EXPOSE 5000
CMD ["node", "index.js"]
