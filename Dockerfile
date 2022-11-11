ARG ALPINE_VERSION=3.16
FROM python:3.11.0-alpine${ALPINE_VERSION} as builder

ARG AWS_CLI_VERSION=2.8.11
RUN apk update
RUN apk add --no-cache git unzip groff build-base libffi-dev
RUN git clone --single-branch --depth 1 -b ${AWS_CLI_VERSION} https://github.com/aws/aws-cli.git

WORKDIR aws-cli
RUN sed -i'' 's/PyInstaller.*/PyInstaller==5.6/g' requirements-build.txt
RUN pip install --upgrade pip, cmake
RUN python -m venv venv
RUN . venv/bin/activate
RUN scripts/installers/make-exe
RUN unzip -q dist/awscli-exe.zip
RUN aws/install --bin-dir /aws-cli-bin
RUN /aws-cli-bin/aws --version

# reduce image size: remove autocomplete and examples
RUN rm -rf /usr/local/aws-cli/v2/current/dist/aws_completer /usr/local/aws-cli/v2/current/dist/awscli/data/ac.index /usr/local/aws-cli/v2/current/dist/awscli/examples
RUN find /usr/local/aws-cli/v2/current/dist/awscli/botocore/data -name examples-1.json -delete

# build the final image
FROM registry.gitlab.com/gitlab-org/terraform-images/stable:latest
COPY --from=builder /usr/local/aws-cli/ /usr/local/aws-cli/
COPY --from=builder /aws-cli-bin/ /usr/local/bin/
RUN apk --no-cache add docker openrc sqlite-libs libffi
RUN apk --no-cache del \
    binutils \
    curl
RUN rm -rf /var/cache/apk/*
RUN rc-update add docker boot