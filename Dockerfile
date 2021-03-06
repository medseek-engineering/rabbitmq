FROM debian:jessie

MAINTAINER Eric Meisel <eric.meisel@influencehealth.com>

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -g 100005 -r rabbitmq && useradd -u 100005 -r -d /var/lib/rabbitmq -m -g rabbitmq rabbitmq

# grab gosu for easy step-down from root
# https://github.com/rabbitmq/rabbitmq-server/commit/53af45bf9a162dec849407d114041aad3d84feaf
ENV PYTHON_VERSION=3.5.1 GOSU_VERSION=1.7 RABBITMQ_VERSION=3.6.1 RABBITMQ_DEB_VERSION=3.6.1-1 RABBITMQ_LOGS=- RABBITMQ_SASL_LOGS=-
RUN set -x \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates wget \
	&& apt-get install -y build-essential libncursesw5-dev libreadline-dev libssl-dev libgdbm-dev libc6-dev libsqlite3-dev tk-dev \
	&& rm -rf /var/lib/apt/lists/* \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
	&& wget "http://www.rabbitmq.com/releases/rabbitmq-server/v$RABBITMQ_VERSION/rabbitmq-server_${RABBITMQ_DEB_VERSION}_all.deb" \
        && wget -O /usr/local/bin/rabbitmqadmin "https://raw.githubusercontent.com/rabbitmq/rabbitmq-management/rabbitmq_v3_6_1/bin/rabbitmqadmin" \
        && chmod +x /usr/local/bin/rabbitmqadmin \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true \
	&& wget "http://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz" \
	&& tar -xf "Python-$PYTHON_VERSION.tar.xz" \
        && cd "Python-$PYTHON_VERSION" \
	&& ./configure --prefix=/opt/python3 \
	&& make \
	&& make install \
        && cd .. \
	&& rm "Python-$PYTHON_VERSION.tar.xz" \
	&& rm -rf "Python-$PYTHON_VERSION" \
        && ln -s /opt/python3/bin/python3 /usr/bin/python \
	&& apt-get purge -y --auto-remove ca-certificates wget

# Add the officially endorsed Erlang debian repository:
# See:
#  - http://www.erlang.org/download.html
#  - https://www.erlang-solutions.com/downloads/download-erlang-otp
RUN apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 434975BD900CCBE4F7EE1B1ED208507CA14F4FCA
RUN echo 'deb http://packages.erlang-solutions.com/debian jessie contrib' > /etc/apt/sources.list.d/erlang.list

#Install erlang
RUN apt-get update && apt-get install -y --no-install-recommends \
		erlang-nox erlang-mnesia erlang-public-key erlang-crypto erlang-ssl erlang-asn1 erlang-inets erlang-os-mon erlang-xmerl erlang-eldap logrotate

# http://www.rabbitmq.com/install-debian.html
#Install Rabbit via Dpkg
RUN dpkg -i rabbitmq-server_${RABBITMQ_DEB_VERSION}_all.deb

# /usr/sbin/rabbitmq-server has some irritating behavior, and only exists to "su - rabbitmq /usr/lib/rabbitmq/bin/rabbitmq-server ..."
ENV PATH /usr/lib/rabbitmq/bin:$PATH

RUN echo '[{rabbit, [{loopback_users, []}]}].' > /etc/rabbitmq/rabbitmq.config

# set home so that any `--user` knows where to put the erlang cookie
ENV HOME /var/lib/rabbitmq

RUN mkdir -p /var/lib/rabbitmq /etc/rabbitmq \
	&& chown -R rabbitmq:rabbitmq /var/lib/rabbitmq /etc/rabbitmq \
	&& chmod 777 /var/lib/rabbitmq /etc/rabbitmq
VOLUME /var/lib/rabbitmq

# add a symlink to the .erlang.cookie in /root so we can "docker exec rabbitmqctl ..." without gosu
RUN ln -sf /var/lib/rabbitmq/.erlang.cookie /root/

RUN ln -sf /usr/lib/rabbitmq/lib/rabbitmq_server-$RABBITMQ_DEB_VERSION/plugins /plugins && rabbitmq-plugins enable --offline rabbitmq_management

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 4369 5671 5672 25672 15672
CMD ["rabbitmq-server"]
