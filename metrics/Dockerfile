FROM alpine:3.10.2

RUN apk upgrade && \
    apk add python3 py3-yaml py3-asn1-modules py3-six py3-dateutil py3-docutils py3-urllib3 py3-requests py3-requests-oauthlib py3-rsa py3-websocket-client ca-certificates && \
    pip3 install --upgrade pip && \
    pip3 install botocore~=1.12.244 kubernetes~=10.0.0

RUN rm -vrf /root/.cache/ /var/cache/apk/*

RUN adduser -D scraper

USER scraper
WORKDIR /home/scraper
CMD /usr/local/bin/scraper

COPY scraper.py /usr/local/bin/scraper

# Development env only
#COPY aws-iam-authenticator /usr/bin/
#RUN mkdir .kube .aws
#COPY --chown=scraper kube_config .kube/config
#COPY --chown=scraper aws_config .aws/config
#RUN chmod 0700 .kube .aws && chmod 0600 .kube/config .aws/config
