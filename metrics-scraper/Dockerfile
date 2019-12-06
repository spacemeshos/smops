FROM alpine:3.10.2

# Upgrade and install required packages
RUN apk upgrade && \
    apk add python3 py3-yaml py3-asn1-modules py3-six py3-dateutil py3-docutils py3-urllib3 py3-requests py3-requests-oauthlib py3-rsa py3-websocket-client ca-certificates && \
    pip3 install --upgrade pip && \
    pip3 install botocore~=1.12.244 kubernetes~=10.0.0

# Clean up some caches
RUN rm -vrf /root/.cache/ /var/cache/apk/*

# Run as an unprivileged user in their home
RUN adduser -D scraper
USER scraper
WORKDIR /home/scraper

# Copy and use the script as the default command
CMD /usr/local/bin/scraper
COPY scraper.py /usr/local/bin/scraper
