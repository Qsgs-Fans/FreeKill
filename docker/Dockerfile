FROM linuxcontainers/debian-slim:latest

# install dependencies
RUN apt update -y && apt upgrade -y && \
    apt install -y \
        gcc g++ cmake \
        liblua5.4-dev libsqlite3-dev libreadline-dev libssl-dev libgit2-dev swig qt6-base-dev qt6-tools-dev-tools \
        gosu && \
    apt clean -y && \
    rm -rf /var/lib/apt/lists/*

# prepare source code
COPY . /FreeKill

# compile and install
RUN mkdir -p /FreeKill/build && \
    cd /FreeKill/build && cp -r /usr/include/lua5.4/* ../include && cmake .. -DFK_SERVER_ONLY= && make && \
    cd /FreeKill && cmake --install build --config Release && \
    cp /FreeKill/docker/docker-entrypoint.sh / && chmod +x /docker-entrypoint.sh && \
    mkdir /data && \
    cd / && rm -rf /FreeKill

WORKDIR /data

EXPOSE 9527

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["FreeKill", "-s"]
