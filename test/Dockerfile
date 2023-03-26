FROM node:18-alpine
# Switch to non-root user
USER node
# Create app directory
WORKDIR /app
# Install app dependencies
COPY package.json ./
COPY package-lock.json ./
RUN npm install --production
# Bundle app source
COPY . .
# Export command
CMD [ "node", "index.mjs" ]
