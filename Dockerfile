FROM node:lts-trixie-slim AS base
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    build-essential \
    ca-certificates \
    curl \
    dnsutils \
    ffmpeg \
    file \
    git \
    iproute2 \
    iputils-ping \
    jq \
    less \
    netcat-openbsd \
    procps \
    rsync \
    unzip \
    vim \
    wget \
    zip \
  && rm -rf /var/lib/apt/lists/*
RUN corepack enable

FROM base AS deps
WORKDIR /app
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml .npmrc ./
COPY cli/package.json cli/
COPY server/package.json server/
COPY ui/package.json ui/
COPY packages/shared/package.json packages/shared/
COPY packages/db/package.json packages/db/
COPY packages/adapter-utils/package.json packages/adapter-utils/
COPY packages/adapters/claude-local/package.json packages/adapters/claude-local/
COPY packages/adapters/codex-local/package.json packages/adapters/codex-local/
COPY packages/adapters/cursor-local/package.json packages/adapters/cursor-local/
COPY packages/adapters/gemini-local/package.json packages/adapters/gemini-local/
COPY packages/adapters/openclaw-gateway/package.json packages/adapters/openclaw-gateway/
COPY packages/adapters/opencode-local/package.json packages/adapters/opencode-local/
COPY packages/adapters/pi-local/package.json packages/adapters/pi-local/
COPY packages/plugins/sdk/package.json packages/plugins/sdk/

RUN pnpm install

FROM base AS build
WORKDIR /app
COPY --from=deps /app /app
COPY . .
RUN pnpm --filter @paperclipai/ui build
RUN pnpm --filter @paperclipai/plugin-sdk build
RUN pnpm --filter @paperclipai/server build
RUN test -f server/dist/index.js || (echo "ERROR: server build output missing" && exit 1)

FROM base AS production
WORKDIR /app
COPY --chown=node:node --from=build /app /app
COPY --chown=node:node docker/paperclip-entrypoint.sh /app/docker/paperclip-entrypoint.sh
COPY --chown=node:node docker/nextcloud-sync-loop.sh /app/docker/nextcloud-sync-loop.sh
RUN apt-get update \
  && apt-get install -y --no-install-recommends chromium nextcloud-desktop-cmd \
  && rm -rf /var/lib/apt/lists/* \
  && npm install --global --omit=dev @anthropic-ai/claude-code@latest @openai/codex@latest opencode-ai \
  && mkdir -p /paperclip /nextcloud /nextcloud-state /chrome-data \
  && chmod +x /app/docker/paperclip-entrypoint.sh /app/docker/nextcloud-sync-loop.sh \
  && chown -R node:node /paperclip /nextcloud /nextcloud-state /chrome-data

ENV NODE_ENV=production \
  HOME=/paperclip \
  HOST=0.0.0.0 \
  PORT=3100 \
  SERVE_UI=true \
  PAPERCLIP_HOME=/paperclip \
  PAPERCLIP_INSTANCE_ID=default \
  PAPERCLIP_CONFIG=/paperclip/instances/default/config.json \
  PAPERCLIP_DEPLOYMENT_MODE=authenticated \
  PAPERCLIP_DEPLOYMENT_EXPOSURE=private \
  CHROME_BIN=/usr/bin/chromium \
  CHROME_USER_DATA_DIR=/chrome-data \
  NEXTCLOUD_SYNC_DIR=/nextcloud \
  NEXTCLOUD_STATE_DIR=/nextcloud-state \
  NEXTCLOUD_NETRC_FILE=/nextcloud-state/.netrc \
  NEXTCLOUD_SYNC_INTERVAL=300 \
  NEXTCLOUD_TRUST_SELF_SIGNED=0

VOLUME ["/paperclip", "/nextcloud", "/nextcloud-state", "/chrome-data"]
EXPOSE 3100

USER node
ENTRYPOINT ["/app/docker/paperclip-entrypoint.sh"]
CMD ["node", "--import", "./server/node_modules/tsx/dist/loader.mjs", "server/dist/index.js"]
