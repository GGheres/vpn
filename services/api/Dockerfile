FROM elixir:1.16-alpine

# Базовые пакеты для сборки
RUN apk add --no-cache build-base git curl openssl bash

# Hex/Rebar
RUN mix local.hex --force && mix local.rebar --force

# Рабочая директория
WORKDIR /app

# Сначала только файлы зависимостей — кешируем deps между сборками
COPY mix.exs mix.lock ./
RUN mix deps.get

# Затем — остальной проект
COPY . .

# Компиляция (dev-окружение)
ENV MIX_ENV=dev
RUN mix compile

EXPOSE 4000
CMD ["mix", "run", "--no-halt"]