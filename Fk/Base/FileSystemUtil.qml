// SPDX-License-Identifier: GPL-3.0-or-later

pragma Singleton
import QtQuick

QtObject {
  readonly property var existsCache: ({})

  // exists是一次stat操作，属于相当耗时的系统调用
  // 这里简单加一层cache，显然这个cache不会清理，懒得管了
  function exists(path) {
    if (path in existsCache) {
      return existsCache[path];
    }
    const ret = Backend.exists(path);
    existsCache[path] = ret;
    return ret;
  }
}

