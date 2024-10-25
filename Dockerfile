ARG RUBY_VERSION=3.2.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LOG_LEVEL=":info" \
    DATABASE_URL="postgres://u92pf8v28hitm:pb9ee9c9eea0953701af4b36b635cf8257bb55c68535c1899339f44a371b532cc@c9pv5s2sq0i76o.cluster-czrs8kj4isg7.us-east-1.rds.amazonaws.com:5432/d7dgs3d97dpqn" \
    APP_URL="app.neetocal.com"

# Rails app lives here
WORKDIR /app

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips git libpq-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs=18.12.*

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && apt-get install -y yarn=1.22.*

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git pkg-config unzip && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install application gems
COPY Gemfile* ./
COPY .ruby-version ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile


# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile && rm -rf ./node_modules

# Final stage for app image
FROM base

# Copy built artifacts: gems, application
COPY --from=build /app /app
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"


# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["./bin/rails", "server"]
