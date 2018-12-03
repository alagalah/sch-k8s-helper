#
# Copyright 2017 StreamSets Inc.
#
FROM ubuntu:bionic

LABEL Maintainer="Keith Burns <keith@streamsets.com>"
LABEL Name=sch-k8s-helper
LABEL Version=1.0.0

RUN apt-get update && apt-get install -y curl

# Package inst
COPY . /opt/sch-k8s-helper

CMD ["bash"]
