FROM node:18-alpine
# Create app directory
WORKDIR /app
# Install git
RUN apk add --no-cache git
# Install app dependencies
COPY package.json ./
COPY package-lock.json ./
RUN npm install --production
# Bundle app source
COPY . .
# Permissions workaround
RUN chown -R node:node /app
# Switch to non-root user
USER node
# Export command
CMD [ "node", "index.mjs" ]
