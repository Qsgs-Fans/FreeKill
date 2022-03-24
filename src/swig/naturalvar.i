// ------------------------------------------------------
// type bindings
// ------------------------------------------------------

// LuaFunction(int) and lua function
%naturalvar LuaFunction;
%typemap(in) LuaFunction
%{
if (lua_isfunction(L, $input)) {
    lua_pushvalue(L, $input);
    $1 = luaL_ref(L, LUA_REGISTRYINDEX);
} else {
    $1 = 0;
}
%}

%typemap(out) LuaFunction
%{
lua_rawgeti(L, LUA_REGISTRYINDEX, $1);
SWIG_arg ++;
%}

// QString and lua string
%naturalvar QString;

%typemap(in, checkfn = "lua_isstring") QString
%{ $1 = lua_tostring(L, $input); %}

%typemap(out) QString
%{ lua_pushstring(L, $1.toUtf8()); SWIG_arg++; %}

// const QString &
%typemap(arginit) QString const &
  "QString $1_str;"

%typemap(in, checkfn = "lua_isstring") QString const &
%{
    $1_str = QString::fromUtf8(lua_tostring(L, $input));
    $1 = &$1_str;
%}

%typemap(out) QString const &
%{ lua_pushstring(L, $1.toUtf8()); SWIG_arg++; %}

