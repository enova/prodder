ARG RUBY_VERSION=3.3

FROM ruby:${RUBY_VERSION}

WORKDIR /app

RUN apt update && \
  apt install -y git postgresql-client && \
  apt clean && \
  rm -rf /var/lib/apt/lists/*

ENV BUNDLER_VERSION 2.4.22

RUN gem install bundler -v $BUNDLER_VERSION

COPY Gemfile ./

RUN bundle install -j $(nproc)

COPY . .

ENTRYPOINT ["entrypoints/entry.sh"]
CMD ["bin/prodder"]
