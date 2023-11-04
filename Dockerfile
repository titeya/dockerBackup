FROM ubuntu:22.04
LABEL MAINTAINER="Titeya <contact@titeya.com>"

ARG DEBIAN_FRONTEND=noninteractive

RUN apt update && apt upgrade -y && \
    apt install -y gnupg2 gnupg gnupg1 curl tzdata cron wget mysql-client

RUN echo Europe/Paris | tee /etc/timezone && dpkg-reconfigure --frontend noninteractive tzdata

RUN echo "deb https://apt.postgresql.org/pub/repos/apt jammy-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list && \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc|gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg

RUN curl -fsSL https://www.mongodb.org/static/pgp/server-6.0.asc|gpg --dearmor -o /etc/apt/trusted.gpg.d/mongodb-6.gpg

RUN echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list
RUN apt update && apt install -y mongodb-org-shell mongodb-org-tools  postgresql-client-16 postgresql-client-common libpq-dev

RUN mkdir /backup


ENV CRON_TIME="0 0 * * *"

ADD run.sh /run.sh
VOLUME ["/backup"]
CMD ["/run.sh"]
