FROM alpine

### Install AWS CLI

# Prefer bundled Python libraries
RUN apk update && \
    apk add \
        python3 \
        py3-docutils \
        py3-dateutil \
        py3-urllib3 \
        py3-rsa \
        py3-six && \
    pip3 install --upgrade pip &&\
    pip3 install awscli~=1.16.0


### Default environment
ENV SPACEMESH_MAX_TRIES "5"

ENV SPACEMESH_FILESIZE  "1048576"
ENV SPACEMESH_SPACE     "1048576"

ENV SPACEMESH_DATADIR   "./data"

ENV SPACEMESH_S3_BUCKET "initdata-testnet-us-east-1.spacemesh.io"
ENV SPACEMESH_S3_PREFIX ""

ENV SPACEMESH_DYNAMODB_TABLE  "initdata-testnet-us-east-1.spacemesh.io"
ENV SPACEMESH_DYNAMODB_REGION "us-east-1"

### Create an unprivileged user (FIXME: Move to main Dockerfile)
RUN adduser -D spacemesh

COPY --chown=root:root miner-init.py /bin/spacemesh-miner-init.py
RUN chmod 0755 /bin/spacemesh-miner-init.py

### Default command
#USER spacemesh
#WORKDIR /home/spacemesh
USER root
WORKDIR /root
CMD ["/bin/spacemesh-miner-init.py"]
