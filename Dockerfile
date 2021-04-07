FROM python:3-slim AS mosquitto-tls
LABEL maintainer ashleywm <ashley@ashleywm.co.uk>

# Set environment variables.
ENV TERM=xterm-color
ENV SHELL=/bin/bash

RUN \
	mkdir /mosquitto && \
	mkdir /mosquitto/log && \
	mkdir /mosquitto/conf && \
	mkdir /secrets && \
	apt update && \
	apt upgrade && \
	apt install \
		procps \
		bash \
		coreutils \
		nano \
		ca-certificates \
		certbot \
		mosquitto \
		mosquitto-clients -y && \
	rm -rf /var/cache/apt/* && \
	pip install --upgrade pip && \
	pip install pyRFC3339 configobj ConfigArgParse cloudflare

RUN \
	pip3 install --upgrade pip setuptools wheel && \
	pip3 install certbot-dns-cloudflare

COPY run.sh /run.sh
COPY certbot.sh /certbot.sh
COPY restart.sh /restart.sh
COPY croncert.sh /etc/periodic/weekly/croncert.sh
RUN \
	chmod +x /run.sh && \
	chmod +x /certbot.sh && \
	chmod +x /restart.sh && \
	chmod +x /etc/periodic/weekly/croncert.sh

EXPOSE 8083
EXPOSE 8883

# This will run any scripts found in /scripts/*.sh
# then start Mosquitto
CMD ["/bin/bash","-c","/run.sh"]
