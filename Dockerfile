FROM alpine:latest

LABEL Alec Pervushin <alec.for.public@gmail.com>

ENV RUBY_INSTALL_VERSION "0.7.0"
ENV RUBY_INSTALL_URL "https://github.com/postmodern/ruby-install/archive/v${RUBY_INSTALL_VERSION}.tar.gz"
ENV CHRUBY_VERSION '0.3.9'
ENV CHRUBY_URL "https://github.com/postmodern/chruby/archive/v${CHRUBY_VERSION}.tar.gz"

RUN apk update && \
  apk upgrade && \
  apk add --no-cache gnupg curl bash procps musl zlib openssl \
  patch make gcc g++ gnupg musl-dev linux-headers zlib-dev openssl-dev \
  postgresql-dev tzdata ruby readline-dev git nodejs yarn

SHELL ["/bin/bash", "-lc"]

WORKDIR /tmp

RUN curl -L -o ruby-install.tar.gz ${RUBY_INSTALL_URL} && \
  tar -xzvf ruby-install.tar.gz && \
  cd ruby-install-${RUBY_INSTALL_VERSION}/ && make install

ADD .docker/current.tgz* /opt/

COPY .docker/install-railsexpress* /tmp/
COPY dev.to/.ruby-version* /root/
COPY dev.to/Gemfile* /tmp/

RUN echo 'export RUBY_VERSION=$([ -z "$RUBY_VERSION" ] && cat ~/.ruby-version || "$RUBY_VERSION")' >> /etc/profile

ENV THREAD_PATCH "https://bugs.ruby-lang.org/attachments/download/7081/0001-thread_pthread.c-make-get_main_stack-portable-on-lin.patch"

RUN ./install-railsexpress railsexpress $RUBY_VERSION \
  -p ${THREAD_PATCH} --jobs=2 --cleanup --no-reinstall

RUN curl -L -o chruby.tar.gz ${CHRUBY_URL} && \
  tar -xzvf chruby.tar.gz && \
  cd chruby-${CHRUBY_VERSION}/ && make install && \
  echo "source /usr/local/share/chruby/chruby.sh" >> /etc/profile && \
  echo 'chruby $RUBY_VERSION' >> /etc/profile

RUN gem install bundler rb-readline && bundle check || bundle install

RUN apk del gnupg musl-dev linux-headers ruby && \
  rm -rf /tmp/* /var/cache/apk/*

COPY docker-entrypoint.sh* /