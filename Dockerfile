ARG ALPINE_VERSION=3.18
FROM python:3.11.4-alpine${ALPINE_VERSION} as builder

ARG AWS_CLI_VERSION=2.11.26
RUN apk update \
    && apk add --no-cache git unzip groff build-base libffi-dev \ 
    && git clone --single-branch --depth 1 -b ${AWS_CLI_VERSION} https://github.com/aws/aws-cli.git

WORKDIR aws-cli
RUN sed -i'' 's/PyInstaller.*/PyInstaller==5.8/g' requirements-build.txt \
    && pip install --upgrade pip cmake \
    && python -m venv venv \
    && . venv/bin/activate \
    && scripts/installers/make-exe \
    && unzip -q dist/awscli-exe.zip \ 
    && aws/install --bin-dir /aws-cli-bin \
    && /aws-cli-bin/aws --version

# reduce image size: remove autocomplete and examples
RUN rm -rf /usr/local/aws-cli/v2/current/dist/aws_completer /usr/local/aws-cli/v2/current/dist/awscli/data/ac.index /usr/local/aws-cli/v2/current/dist/awscli/examples \
    && find /usr/local/aws-cli/v2/current/dist/awscli/botocore/data -name examples-1.json -delete

# build the final image
FROM registry.gitlab.com/gitlab-org/terraform-images/stable:latest
COPY --from=builder /usr/local/aws-cli/ /usr/local/aws-cli/ 
COPY --from=builder /aws-cli-bin/ /usr/local/bin/
RUN apk --no-cache add docker openrc sqlite-libs libffi \ 
    && apk --no-cache del binutils curl
RUN rm -rf /var/cache/apk/* \
    && rc-update add docker boot