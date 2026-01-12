// SPDX-License-Identifier: GPL-3.0-or-later

pragma Singleton
import QtQuick

QtObject {
  // mock
  readonly property var backend: typeof Backend !== 'undefined' ? Backend : {
    callLuaFunction: (fn, params) => {
      console.log(`Lua.call: ${fn} ${params}`);
    },
    evalLuaExp: (exp) => {
      console.log(`Lua.evaluateuate: ${exp}`);
    },
    translate: (src) => {
      return src;
    },
  };

  function call(funcName, ...params) {
    return backend.callLuaFunction(funcName, [...params]);
  }

  function fn(func) {
    return (...params) => {
      let exp = `(${func})(`;
      exp += [...params].map(v => {
        return `json.decode '${JSON.stringify(v)}'`;
      }).join(', ');
      exp += ')';

      return evaluate(exp);
    }
  }

  function evaluate(lua) {
    return backend.evalLuaExp(`return ${lua}`);
  }

  function tr(src) {
    return backend.translate(src);
  }
}
