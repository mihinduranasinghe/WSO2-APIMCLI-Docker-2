FROM ubuntu:18.04

RUN apt update &&          \
    apt install -y git     \
                    curl   \
                    jq     \
                    nodejs \
                    npm    \
    && npm install -y -g newman@3 --unsafe-perm

# COPY apimcli /usr/local/bin/apimcli
COPY apimcli2_0_12/apimcli /usr/local/bin/apimcli
RUN chmod +x /usr/local/bin/apimcli

WORKDIR /usr/src/app
COPY . /usr/src/app

RUN chmod +x /usr/src/app/script.sh
RUN cd $GITHUB_WORKSPACE

ENTRYPOINT ["/usr/src/app/script.sh"]