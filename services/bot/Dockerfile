FROM elixir:1.16-alpine

RUN apk add --no-cache build-base git curl openssl bash
RUN mix local.hex --force && mix local.rebar --force

WORKDIR /app

# Кешируем deps
COPY mix.exs mix.lock ./
RUN mix deps.get

# Копируем исходники и компилим (dev)
COPY . .
ENV MIX_ENV=dev
RUN mix deps.get
RUN mix compile

CMD ["mix", "run", "--no-halt"]
