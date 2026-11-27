ARG ELIXIR_IMAGE=elixir:1.20.5-otp-29-slim
ARG RUNNER_IMAGE=debian:trixie-slim

# ---- build stage -----------------------------------------------------------
FROM ${ELIXIR_IMAGE} AS build

ENV MIX_ENV=prod \
    LANG=C.UTF-8

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

RUN mkdir config
COPY config/config.exs config/prod.exs config/runtime.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

# Colocated hooks are generated during compilation, so compile before bundling
# the JavaScript.
RUN mix compile
RUN mix assets.deploy
RUN mix release

# ---- runtime stage ---------------------------------------------------------
FROM ${RUNNER_IMAGE} AS app

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    MIX_ENV=prod \
    PHX_SERVER=true \
    PORT=4000 \
    HOME=/app

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    libstdc++6 \
    openssl \
    libncurses6 \
    locales \
    ca-certificates \
    curl \
    tini \
  && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN useradd --create-home --shell /usr/sbin/nologin app

COPY --from=build --chown=app:app /app/_build/prod/rel/certfy ./

USER app

EXPOSE 4000

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bin/certfy", "start"]
