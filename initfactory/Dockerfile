FROM spacemeshos/post:latest

### Run as user root
USER root

### Install AWS CLI
# Prefer bundled Python libraries
RUN apk update && apk add \
    python3 \
    py3-docutils \
    py3-dateutil \
    py3-urllib3 \
    py3-rsa \
    py3-six \
    && \
    pip3 install --upgrade pip && \
    pip3 install awscli~=1.16.0

# Create unprivileged user
#RUN adduser -D spacemesh

# Install the wrapper
COPY --chown=spacemesh:spacemesh wrapper.py /bin/spacemesh-wrapper.py
RUN chmod 0755 /bin/spacemesh-wrapper.py

# Run as unprivileged user
USER spacemesh
WORKDIR /home/spacemesh

ENV SPACEMESH_INIT "/bin/spacemesh-init"

# Ensure data dir exists
RUN mkdir -p data

# Default entry point
#ENTRYPOINT /bin/sh
ENTRYPOINT /bin/spacemesh-wrapper.py

# vim:filetype=dockerfile ts=4 sw=4 et:
