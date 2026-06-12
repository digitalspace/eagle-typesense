FROM node:24-alpine

WORKDIR /app

# Upgrade base packages to fix CVE-2026-45447 in libcrypto3/libssl3
RUN apk upgrade --no-cache

COPY package.json ./
RUN npm install --production

COPY src/ ./src/

# Default: run the Change Stream listener.
# Override with ["node", "src/full-sync.js"] for the re-index CronJob.
CMD ["node", "src/index.js"]
