// SPDX-License-Identifier: GPL-3.0-or-later

pragma Singleton
import QtQuick

QtObject {
  readonly property var existsCache: ({})

  function convertUrlToPath(url) {
    return url.replace(Cpp.os === "Win" ? "file:///" : "file://", "");
  }

  function convertPathToUrl(path) {
    // 确保路径使用正斜杠
    path = path.replace(/\\/g, "/");
    if (Cpp.os === "Win") {
      if (!path.startsWith("file:///")) {
        return "file:///" + path;
      }
    } else {
      if (!path.startsWith("file://")) {
        return "file://" + path;
      }
    }
    return path;
}

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

  // 只有文件存在才会存到cache中
  function existsFile(path) {
    if (path in existsCache) {
      return existsCache[path];
    }
    const ret = Backend.exists(path);
    if (ret) existsCache[path] = ret;
    return ret;
  }

  function isDir(path) {
    return Backend.isDir(path);
  }

  // 解析文件路径（模拟 Image.source 的后缀匹配）：
  // - 目录：返回空串
  // - 带后缀：精确匹配，命中返回原路径，否则返回空串
  // - 不带后缀的非目录：先精确匹配，再依次尝试常见图片后缀
  function resolveFile(path) {
    if (!path) return "";

    if (isDir(path)) return "";

    const slash = Math.max(path.lastIndexOf("/"), path.lastIndexOf("\\"));
    const dot = path.lastIndexOf(".");
    if (dot > slash + 1) {
      return existsFile(path) ? path : "";
    }

    if (existsFile(path)) return path;

    const exts = [".png", ".jpg", ".jpeg", ".gif", ".bmp", ".svg", ".webp", ".avif", ".ico"];
    for (const ext of exts) {
      if (existsFile(path + ext)) return path + ext;
    }
    return "";
  }

  function downloadFileToAssets(url, path) {
    Backend.downloadFileToAssets(url, path)
  }
}

