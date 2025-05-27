FROM python:3.11.11-alpine3.19 AS builder
# pin version due to https://github.com/aws/aws-cli/issues/8698
# build AWS CLI
ARG AWSCLI_VERSION=2.27.22

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

# build layer with Docker and Terraform and kubectl
FROM registry.gitlab.com/noemix/shared-resources/terraform-images/stable:latest
COPY --from=builder /opt/aws-cli/ /opt/aws-cli/
COPY --from=builder --chown=0:0 /usr/local/lib/ /usr/local/lib/
ENV PATH="/opt/aws-cli/bin:${PATH}"
RUN apk update && apk --no-cache add curl bash groff docker openrc sqlite-libs libffi \
    && KUBECTL_VERSION="v1.33.1" \
    && curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256" \
    && echo "$(cat kubectl.sha256)  kubectl" | sha256sum -c - \
    && install -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl kubectl.sha256 \
    && apk del curl \
    && rc-update add docker boot \
    && rm -rf /var/cache/apk/*

