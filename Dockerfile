# ---------- Stage 1: build the React frontend ----------
# Pinned Node 22 on Alpine: small image, specific major version
FROM node:22-alpine AS builder

# Working folder for the frontend inside the image
WORKDIR /app/frontend

# Copy only the dependency manifests first so Docker can cache the install layer.
# .npmrc carries legacy-peer-deps=true, which this project needs for npm to install.
COPY frontend/package.json frontend/package-lock.json frontend/.npmrc* ./

# Install exactly what package-lock.json specifies (reproducible, same as CI)
RUN npm ci

# Now copy the rest of the frontend source (node_modules is excluded by .dockerignore)
COPY frontend/ ./

# Build the production bundle (tsc type-check, then vite build) into /app/frontend/dist
RUN npm run build


# ---------- Stage 2: run the Express backend ----------
# Fresh image: none of the frontend build tooling ends up in the final image
FROM node:22-alpine AS runtime

# Production mode, and the port the server listens on (must match PORT in compose)
ENV NODE_ENV=production
ENV PORT=4000

# Backend lives in /app/backend so server.js finds ../frontend/dist at /app/frontend/dist
WORKDIR /app/backend

# Copy backend manifests first for layer caching
COPY --chown=node:node backend/package.json backend/package-lock.json ./

# Install production dependencies only (no jest, supertest, nodemon, eslint).
# Then remove npm, npx, corepack and yarn: the container only runs "node server.js",
# and the npm tool bundled in the base image carries its own vulnerable packages
# (pacote, sigstore, brace-expansion, ...) that Trivy flags. Less tooling = smaller attack surface.
RUN npm ci --omit=dev \
 && npm cache clean --force \
 && rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack \
           /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack \
           /opt/yarn* /usr/local/bin/yarn /usr/local/bin/yarnpkg

# Copy the backend source
COPY --chown=node:node backend/ ./

# Bring the built frontend from stage 1 to the path Express serves static files from
COPY --from=builder --chown=node:node /app/frontend/dist /app/frontend/dist

# Drop root: the official Node image already provides an unprivileged "node" user
USER node

# Document the port the app listens on
EXPOSE 4000

# Mark the container unhealthy if /health stops answering (wget ships with Alpine/BusyBox)
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -q --spider "http://localhost:${PORT}/health" || exit 1

# Start the API server
CMD ["node", "server.js"]