FROM python:3.11-alpine AS builder

# build AWS CLI
ARG AWSCLI_VERSION=2.15.54
RUN python -m pip install --upgrade pip
RUN apk update && apk add --no-cache \
    curl \
    make \
    cmake \
    gcc \
    g++ \
    libc-dev \
    libffi-dev \
    openssl-dev \
    && curl -L https://awscli.amazonaws.com/awscli-${AWSCLI_VERSION}.tar.gz | tar -xz \
    && cd awscli-${AWSCLI_VERSION} \
    && ./configure --prefix=/opt/aws-cli/ --with-download-deps \
    && make \
    && make install

# reduce image size: remove autocomplete and examples
RUN rm -rf \
    /opt/aws-cli/aws_completer \
    /opt/aws-cli/awscli/data/ac.index \
    /opt/aws-cli/awscli/examples
RUN find /opt/aws-cli/lib/aws-cli -name completions-1*.json -delete
RUN find /opt/aws-cli/lib/aws-cli -name examples-1.json -delete

#build layer with Docker and Terraform
FROM registry.gitlab.com/gitlab-org/terraform-images/stable:latest
COPY --from=builder /opt/aws-cli/ /opt/aws-cli/
COPY --from=builder --chown=0:0 /usr/local/lib/ /usr/local/lib/
ENV PATH="/opt/aws-cli/bin:${PATH}"
RUN apk update && apk --no-cache add groff docker openrc sqlite-libs libffi \
    && apk --no-cache del binutils curl \
    && apk upgrade libexpat \
    && rc-update add docker boot \
    && apk clean cache
