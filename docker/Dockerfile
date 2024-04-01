FROM debian
USER root

COPY . /FreeKill

#update apt dependencies
RUN apt update -y && apt upgrade -y

#install compile tools
RUN apt install -y gcc g++ cmake
RUN apt install -y liblua5.4-dev libsqlite3-dev libreadline-dev libssl-dev libgit2-dev swig qt6-base-dev qt6-tools-dev-tools

#change workdir to FreeKill
WORKDIR /FreeKill

#compile source code
RUN mkdir build && cd build && cp -r /usr/include/lua5.4/* ../include && cmake .. -DFK_SERVER_ONLY=
RUN cd build && make

#build soft link
RUN ln -s build/FreeKill

EXPOSE 9527

ENTRYPOINT ["/FreeKill/FreeKill", "-s"]
