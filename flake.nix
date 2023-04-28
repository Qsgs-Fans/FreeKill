{
  description = "Sanguosha (a.k.a. Legend of Three Kingdoms, LTK) written in Qt and Lua.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
  };

  outputs = { self, nixpkgs }: {
    defaultPackage.x86_64-linux =
      with import nixpkgs { system = "x86_64-linux"; };
      stdenv.mkDerivation {
        name = "freekill";
        version = "0.1.6";
        src = self;

        buildInputs = with qt6; [
          qtbase
          qtdeclarative
          qt5compat
          qtmultimedia
          qttools
          sqlite
          swig
          openssl
          flex
          bison
          readline
          libgit2
          lua5_4
        ];
        nativeBuildInputs = [ cmake qt6.wrapQtAppsHook ];

        postPatch = ''
          substituteInPlace src/CMakeLists.txt --replace "LUA_LIB lua5.4" "LUA_LIB lua";
        '';
      };
  };
}
