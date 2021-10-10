# Can't use alpine with prepackaged agate binary, because of bad ELF header.
FROM ubuntu:latest
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y git wget && rm -rf /var/lib/apt/lists/*
RUN wget https://github.com/mbrubeck/agate/releases/download/v3.1.0/agate.x86_64-unknown-linux-gnu.gz -O agate.gz && gunzip agate.gz
RUN mv agate /usr/bin && chmod uag+wrx /usr/bin/agate
CMD [ "agate", "--central-conf", "--certs", "/certificates", "--content", "/capsule", "--addr", "[::]:1965", "--addr", "0.0.0.0:1965" ]
