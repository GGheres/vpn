
FROM hexpm/elixir:1.16.2-erlang-26.2.5-debian-bookworm-20240506
RUN apt-get update && apt-get install -y build-essential git curl && rm -rf /var/lib/apt/lists/*
RUN mix local.hex --force && mix local.rebar --force
WORKDIR /app
COPY . /app
RUN mix deps.get
RUN MIX_ENV=prod mix compile || mix compile
CMD ["mix", "run", "--no-halt"]
