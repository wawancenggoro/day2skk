# Custom image: pgvector + Timescale's pg_textsearch (BM25 full-text search).
#
# Why a custom image: pg_textsearch has no prebuilt image and must be compiled
# from source (https://github.com/timescale/pg_textsearch). It supports
# PostgreSQL 17/18, so we base on pgvector's pg17 image (Postgres 17 with the
# `vector` extension already built in) and add pg_textsearch on top.
#
# Build and push to a registry your Cloudeka (Deka) cluster can pull from, e.g.:
#   docker build -t <registry>/pgvector-textsearch:pg17 .
#   docker push  <registry>/pgvector-textsearch:pg17
# then set that image name in 04-deployment.yaml.
FROM pgvector/pgvector:pg17

# Compile pg_textsearch, then remove the build toolchain to keep the image small.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        git \
        ca-certificates \
        postgresql-server-dev-17; \
    cd /tmp; \
    git clone --depth 1 https://github.com/timescale/pg_textsearch; \
    cd pg_textsearch; \
    make; \
    make install; \
    cd /; \
    rm -rf /tmp/pg_textsearch; \
    apt-get purge -y --auto-remove build-essential git postgresql-server-dev-17; \
    rm -rf /var/lib/apt/lists/*
