// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import Fk.Widgets as W
import Fk.Components.Common

import LunarLtk

W.PageBase {
  id: root
  objectName: "SkinSetting"
  property var skins: getSkins()
  property var unsolvedSkins: []
  property var currentDownloadArr: []
  property bool pause: false

  property var downloadPool: []
  property int poolIdx: 0
  property int activeCount: 0
  property int maxConcurrent: 5
  property var skinResults: []

  signal downloaded(bool ok, string path)
  signal allFinished()

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 30
    spacing: 20
    RowLayout {
      Layout.alignment: Qt.AlignTop
      Text {
        id: skinCount
        text: Lua.tr("Skins Count: ")
        font.bold: true
        color: '#979797'
        font.pixelSize: 30
      }
      Text {
        text: {
          return `${root.skins.length - root.unsolvedSkins.length} / ${root.skins.length}`
        }
        font.bold: true
        color: '#979797'
        font.pixelSize: 30
      }
      Text {
        Layout.leftMargin: 50
        text: Lua.tr("Download Threads: ") + String(root.maxConcurrent)
        font.bold: true
        color: '#585858'
        font.pixelSize: 22
      }
    }
    Rectangle {
      Layout.fillHeight: true
      Layout.fillWidth: true
      color: "transparent"
      border.width: 2
      border.color: '#535353'
      radius: 5

      LogEdit {
        id: log
        anchors.fill: parent
        anchors.margins: 20
      }
    }
  }

  Button {
    anchors {
      top: parent.top
      topMargin: 30
      right: parent.right
      rightMargin: 30
    }
    text: Lua.tr(currentDownloadArr.length > 0 ? (root.pause ? "Continue Download" : "Pause Download") : "Start Download")
    enabled: root.unsolvedSkins.length > 0
    onClicked: {
      if (currentDownloadArr.length === 0) {
        root.startDownloadArray()
      } else if (root.pause) {
        root.pause = false;
        root.addLog(Lua.tr("Continue Skin Downloading"))
        root.pumpDownload();
        if (root.activeCount === 0 && root.poolIdx >= root.downloadPool.length) {
          root.allFinished();
        }
      } else root.pause = true;
    }
  }

  Connections {
    target: Backend
    function onAssetsDownloadFinished(ok, path, error) {
      const doneIdx = downloadPool.findIndex(f => f.dest === path);
      const idx = doneIdx >= 0 ? doneIdx + 1 : poolIdx + 1;
      if (ok) {
        const spl = path.split("/")
        root.addLog(`<font color='green'><b>${Lua.tr("Download Success")}[${idx}/${downloadPool.length}]</b></font>: ${Lua.tr(spl[spl.length - 1] ?? path)}  ${spl}`)
      } else {
        root.addLog(`<font color='red'><b>${Lua.tr("Download Fail")}[${idx}/${downloadPool.length}]</b>: ${error}`)
      }
      downloaded(ok, path)
    }
  }

  onDownloaded: (ok, path) => {
    activeCount--;
    const doneIdx = downloadPool.findIndex(f => f.dest === path);
    if (doneIdx >= 0 && !ok) {
      skinResults[downloadPool[doneIdx].skinIdx] = false;
    }
    if (pause) {
      addLog(Lua.tr("Skin Downloading Paused"));
      // 暂停期间所有在飞下载都已收尾且池已排空时，也要正常收尾
      if (activeCount === 0 && poolIdx >= downloadPool.length) {
        allFinished()
      }
      return;
    }
    pumpDownload();
    if (activeCount === 0 && poolIdx >= downloadPool.length) {
      allFinished()
    }
  }

  onAllFinished: {
    const failed = skinResults.filter(r => !r).length;
    addLog(Lua.tr("All skins downloaded: success: %1; fail: %2; total: %3").arg(currentDownloadArr.length - failed).arg(failed).arg(currentDownloadArr.length));
    currentDownloadArr = [];
    pause = false;
    unsolvedSkins = getUnsolvedSkins(skins);
  }

  function startDownloadArray() {
    addLog(Lua.tr("Start Downloading Skins"));
    currentDownloadArr = [...unsolvedSkins];
    skinResults = currentDownloadArr.map(() => true);
    poolIdx = 0;
    activeCount = 0;

    downloadPool = generateFiles();
    for (let i = 0; i < Math.min(maxConcurrent, downloadPool.length); i++) {
      pumpDownload();
    }
  }

  function downloadFile(file) {
    root.addLog(`${Lua.tr("Downloading: ")}${file.path + file.fileName}`);
    Fs.downloadFileToAssets(file.path + file.fileName, file.dest);
  }

  function generateFiles() {
    const files = [];
    for (let i = 0; i < currentDownloadArr.length; i++) {
      const skin = currentDownloadArr[i];
      const hash = Ltk.urlToBase62(skin.path)
      if (skin.is_skel) {
        skin.files.forEach(f => files.push({
          path: skin.path,
          fileName: f,
          dest: `lunarltk/skel/${hash}/${f}`,
          skinIdx: i
        }))
      } else {
        files.push({
          path: skin.path,
          fileName: skin.name,
          dest: `lunarltk/skins/${hash}/${skin.name}`,
          skinIdx: i
        })
      }
    }
    return files
  }

  function pumpDownload() {
    if (poolIdx >= downloadPool.length) return;
    const file = downloadPool[poolIdx];
    poolIdx++;
    activeCount++;
    downloadFile(file);
  }

  function getSkins() {
    return Lua.evaluate(`(function()
      local skins = {}
      local full_paths = {}
      for g, v in pairs(Fk.skin_packages) do
        for skin, skin_data in pairs(v) do
          if not table.contains(full_paths, skin_data.path + skin_data.name) then
            table.insert(full_paths, skin_data.path + skin_data.name)
            table.insert(skins, skin_data)
          end
        end
      end
      return skins
    end)()`) ?? []
  }

  function getUnsolvedSkins(_skins) {
    return root.skins.filter(s => {
      const hash = Ltk.urlToBase62(s.path)
      if (!s.path.startsWith("http://") && !s.path.startsWith("https://")) return false;
      if (s.is_skel) {
        for (const f of s.files) {
          if (!Fs.resolveFile(`${Cpp.path}/assets/lunarltk/skel/${hash}/${f}`)) return false;
        }
        return false
      } else {
        return !Fs.resolveFile(`${Cpp.path}/assets/lunarltk/skins/${hash}/${s.name}`)
      }
    })
  }

  function addLog(msg) {
    log.append({
      logText: msg
    })
  }

  Component.onCompleted: {
    unsolvedSkins = getUnsolvedSkins(skins);
    log.append({
      logText: Lua.tr("Total skins %1, %2 skins waiting for downloading").arg(skins.length).arg(root.unsolvedSkins.length)
    })
  }
}
