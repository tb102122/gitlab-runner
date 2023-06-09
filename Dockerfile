FROM python:3.11-alpine AS builder

ARG AWSCLI_VERSION=2.11.26

RUN apk add --no-cache \
    curl \
    make \
    gzip \
    cmake \
    gcc \
    g++ \
    libc-dev \
    libffi-dev \
    openssl-dev \
    && curl https://awscli.amazonaws.com/awscli-{AWSCLI_VERSION}.tar.gz | tar -xz \
    && cd awscli-{AWSCLI_VERSION} \
    && ./configure --prefix=/opt/aws-cli/ --with-download-deps \
    && make \
    && make install

# reduce image size: remove autocomplete and examples
RUN rm -rf /opt/aws-cli/v2/current/dist/aws_completer /opt/aws-cli/v2/current/dist/awscli/data/ac.index /opt/aws-cli/v2/current/dist/awscli/examples \
    && find /opt/aws-cli/v2/current/dist/awscli/botocore/data -name examples-1.json -delete

# build the final image
FROM registry.gitlab.com/gitlab-org/terraform-images/stable:latest
# COPY --from=builder /usr/local/aws-cli/ /usr/local/aws-cli/ 
# COPY --from=builder /aws-cli-bin/ /usr/local/bin/
COPY --from=builder /opt/aws-cli/ /opt/aws-cli/
RUN apk --no-cache add docker openrc sqlite-libs libffi groff \ 
    && apk --no-cache del binutils curl
RUN rm -rf /var/cache/apk/* \
    && rc-update add docker boot
