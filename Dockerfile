ARG ELIXIR_VERSION=1.13.4
ARG OTP_VERSION=24.0.1
ARG DEBIAN_VERSION=bullseye-20210902-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"
ENV EXS_DRY_RUN="true"
ENV MIX_INSTALL_DIR="/app/.mix"

# install mix dependencies
COPY run.exs ./
RUN elixir ./run.exs

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR "/app"

# set runner ENV
ENV MIX_ENV="prod"
ENV MIX_INSTALL_DIR="/app/.mix"
ENV SHELL=/bin/bash
ENV ERL_AFLAGS "-proto_dist inet6_tcp"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/.mix/ ./.mix
COPY --from=builder --chown=nobody:root /app/run.exs ./

RUN mix local.hex --force && \
    mix local.rebar --force

CMD ["elixir", "/app/run.exs"]

