# syntax = docker/dockerfile:1

# Указываем версию Ruby
ARG RUBY_VERSION=3.1.4
FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim as base

# Устанавливаем рабочую директорию
WORKDIR /rails



# Этап сборки
FROM base as build

# Устанавливаем зависимости для сборки гемов и ассетов
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    default-libmysqlclient-dev \
    git \
    libvips \
    pkg-config \
    nodejs \
    npm \
    && npm install -g yarn \
    && rm -rf /var/lib/apt/lists/*

# Копируем Gemfile и Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Устанавливаем гемы
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Копируем весь проект
COPY . .

# Предварительная компиляция bootsnap для ускорения запуска
RUN bundle exec bootsnap precompile app/ lib/

# Предварительная компиляция ассетов
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Финальный этап для production
FROM base

# Устанавливаем зависимости для production
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    default-mysql-client \
    libvips \
    && rm -rf /var/lib/apt/lists/*

# Копируем собранные артефакты: гемы и приложение
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Создаем пользователя rails для безопасности
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER rails:rails

# Подготовка базы данных при запуске
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Открываем порт 3000 и запускаем сервер
EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]