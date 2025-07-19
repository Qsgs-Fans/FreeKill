为了rpc化lua服务端，特地把QRandomGenerator单开一个lua模块

```sh
$ make
$ sudo make install
```

如果你实在没有sudo的话，可以在启动新月杀的时候指定`LUA_CPATH`环境变量：

```sh
$ LUA_CPATH=';;/path/to/src/swig/qrandom' ./FreeKill --rpc -s
```

这会给lua的`package.cpath`变量加入qrandom编译目录，好让他正常require到so文件。
