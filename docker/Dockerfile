FROM ubuntu

USER root

RUN apt update -y && apt upgrade -y

RUN apt install git -y

RUN git clone https://gitee.com/notify-ctrl/FreeKill

RUN apt install -y gcc g++ cmake || true

RUN apt install -y liblua5.4-dev libsqlite3-dev libreadline-dev libssl-dev libgit2-dev swig qt6-base-dev qt6-tools-dev-tools

RUN cd FreeKill && mkdir build && cd build && cp -r /usr/include/lua5.4/* ../include && cmake .. -DFK_SERVER_ONLY=

RUN cd FreeKill/build && make

RUN cd / && ln -s FreeKill/server && ln -s FreeKill/packages

EXPOSE 9527

CMD ["/FreeKill/build/FreeKill", "-s"]

#building process:
#open powershell and cd to this folder
#using below cmd to build:(should replace af747025114 with your personal docker hub repository name)
# docker build -t af747025114/freekill-server:0.1 .
#pushing to remote docker hub repository(optional)
# docker push af747025114/freekill-server:0.1

##run docker with below cmd: 
#docker run -p 9527:9527 -it af747025114/freekill-server:0.1 /FreeKill/build/FreeKill -s
#or
#docker run -p 9527:9527 -it af747025114/freekill-server:0.1