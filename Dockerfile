# =============================================================================
# Multi-stage build for the CFD workbench with a pinned OpenFOAM v2606 runtime
# =============================================================================

# Build frontend assets
FROM node:20-alpine AS frontend-builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --no-audit --prefer-offline
COPY . .
RUN npm run build

# Runtime includes the exact OpenFOAM version required by the simulation backend.
FROM ubuntu:24.04 AS runtime
ENV DEBIAN_FRONTEND=noninteractive

USER root

# Install Node.js 20 and the official OpenCFD OpenFOAM v2606 binaries.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      bash ca-certificates curl gnupg passwd \
    && curl -fsSL https://dl.openfoam.com/add-debian-repo.sh | bash \
    && apt-get update \
    && apt-get install -y --no-install-recommends openfoam2606-default \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" \
      > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs curl \
    && bash -lc 'source /usr/lib/openfoam/openfoam2606/etc/bashrc && for bin in blockMesh snappyHexMesh checkMesh simpleFoam chtMultiRegionSimpleFoam foamToVTK; do command -v "$bin" >/dev/null || { echo "Missing OpenFOAM v2606 binary: $bin" >&2; exit 1; }; done' \
    && node --version | grep -E '^v20\.' \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create secure unprivileged runtime user and writable simulation scratch directory.
RUN groupadd -g 10001 cfduser \
    && useradd -u 10001 -g cfduser -s /bin/bash -m cfduser \
    && mkdir -p /tmp/of_cases \
    && chown -R cfduser:cfduser /tmp/of_cases \
    && chmod 700 /tmp/of_cases

WORKDIR /app

# Install production-only Node dependencies and copy the built application.
COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force
COPY --chown=cfduser:cfduser backend/ ./backend/
COPY --from=frontend-builder --chown=cfduser:cfduser /app/dist /app/dist
COPY --chown=cfduser:cfduser public/ ./public/

USER cfduser

ENV NODE_ENV=production \
    PORT=3000 \
    OPENFOAM_EXEC_MODE=local \
    OPENFOAM_BASHRC=/usr/lib/openfoam/openfoam2606/etc/bashrc \
    CASE_TIMEOUT_MS=600000

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:3000/readyz || exit 1

CMD ["node", "dist/server.cjs"]
