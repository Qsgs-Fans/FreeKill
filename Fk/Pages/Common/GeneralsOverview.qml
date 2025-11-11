// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Fk
import Fk.Components.Common
import Fk.Components.LunarLTK
import Fk.Widgets as W

W.PageBase {
  id: root
  property alias generals: gridView.model

  property bool loaded: false
  property int stat: 0 // 0=normal 1=banPkg 2=banChara

  Rectangle {
    id: listBg
    width: 260; height: parent.height
    color: "snow"
    radius: 6
  }

  ListView {
    id: modList // 大包
    width: 130; height: parent.height
    anchors.top: listBg.top; anchors.left: listBg.left
    clip: true
    model: ListModel {
      id: mods
    }

    Rectangle {
      anchors.fill: parent
      color: "#A48959"
      z: -1
    }

    highlight: Rectangle { color: "snow" }
    highlightMoveDuration: 500

    delegate: Item {
      width: modList.width
      height: 40

      Text {
        text: Lua.tr(name)
        color: modList.currentIndex === index ? "black" : "white"
        anchors.centerIn: parent
      }

      W.TapHandler {
        onTapped: {
          modList.currentIndex = index;
        }
      }
    }
  }

  ListView {
    id: pkgList // 小包
    width: 130; height: parent.height
    anchors.top: listBg.top; anchors.left: modList.right

    clip: true
    model: JSON.parse(mods.get(modList.currentIndex)?.pkgs ?? "[]")

    highlight: Rectangle { color: "#FFCC3F"; radius: 5; scale: 0.8 }
    highlightMoveDuration: 500

    delegate: Item {
      width: pkgList.width
      height: 40
      required property string modelData
      required property int index

      Text {
        text: Lua.tr(parent.modelData)
        color: !Config.curScheme.banPkg[parent.modelData] ? "black" : "grey"
        Behavior on color { ColorAnimation { duration: 200 } }
        anchors.centerIn: parent
      }

      Image {
        source: Cpp.path + "/image/button/skill/locked.png"
        opacity: !Config.curScheme.banPkg[parent.modelData] ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 200 } }
        anchors.centerIn: parent
        scale: 0.8
      }

      W.TapHandler {
        onTapped: {
          if (root.stat === 1) {
            const name = parent.modelData;
            let s = Config.curScheme;
            if (s.banPkg[name]) {
              delete s.banPkg[name];
              delete s.normalPkg[name];
            } else {
              delete s.normalPkg[name];
              s.banPkg[name] = [];
            }
            Config.curSchemeChanged();
          } else {
            pkgList.currentIndex = parent.index;
          }
        }
      }
    }

    onCurrentIndexChanged: { vanishAnim.start(); }
  }

  ToolBar {
    id: bar
    width: root.width - listBg.width - 16
    anchors.left: listBg.right
    anchors.leftMargin: 8
    y: 8

    background: Rectangle {
      color: root.stat === 0 ? "#5cb3cc" : "#869d9d"
      Behavior on color { ColorAnimation { duration: 200 } }
    }

    RowLayout {
      anchors.fill: parent
      Item { Layout.preferredWidth: 20 }

      Label {
        text: {
          switch (root.stat) {
            case 0: return Lua.tr("Generals Overview");
            case 1: return Lua.tr("$BanPkgHelp");
            case 2: return Lua.tr("$BanCharaHelp");
          }
        }
        elide: Label.ElideLeft
        verticalAlignment: Qt.AlignVCenter
        font.pixelSize: 28
      }

      Item { Layout.fillWidth: true }

      TextField {
        id: word
        clip: true
        leftPadding: 5
        rightPadding: 5
        focus: true
        onEditingFinished: {
          if (text !== "") {
            pkgList.currentIndex = 0;
            vanishAnim.start();
          }
        }
        ToolButton {
          text: "🔍"
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          font.pixelSize: 20
          enabled: word.text !== ""
          onClicked: {
            pkgList.currentIndex = 0;
            vanishAnim.start();
          }
        }
      }

      ToolButton {
        text: Lua.tr("Filter")
        font.pixelSize: 20
        onClicked: {
          lobby_dialog.sourceComponent = Qt.createComponent("GeneralFilter.qml");
          lobby_drawer.open();
        }
        onPressAndHold: {
          vanishAnim.start(); // 长按重置
        }
        ToolTip {
          x : parent.width / 2
          y : height
          visible: parent.hovered
          delay: 1500

          contentItem: Text{
            text: Lua.tr("FilterHelp")
            font.pixelSize: 20
            color: "white"
          }
        }
      }

      ToolButton {
        text: Lua.tr("Revert Selection")
        enabled: root.stat === 2
        font.pixelSize: 20
        onClicked: {
          generals.forEach((g) => {
            doBanGeneral(g);
          })
        }
      }

      ToolButton {
        id: banButton
        font.pixelSize: 20
        text: {
          if (root.stat === 2) return Lua.tr("OK");
          return Lua.tr("BanGeneral");
        }
        enabled: root.stat !== 1
        visible: root.parent instanceof StackView
        onClicked: {
          if (root.stat === 0) {
            root.stat = 2;
          } else {
            root.stat = 0;
          }
        }
      }

      ToolButton {
        id: banPkgButton
        font.pixelSize: 20
        text: {
          if (root.stat === 1) return Lua.tr("OK");
          return Lua.tr("BanPackage");
        }
        enabled: root.stat !== 2
        visible: root.parent instanceof StackView
        onClicked: {
          if (root.stat === 0) {
            root.stat = 1;
          } else {
            root.stat = 0;
          }
        }
      }

      ToolButton {
        text: Lua.tr("Quit")
        font.pixelSize: 20
        visible: root.parent instanceof StackView
        onClicked: {
          App.quitPage();
          Config.saveConf();
        }
      }
    }
  }

  GridView {
    id: gridView
    clip: true
    width: root.width - listBg.width - 16
    height: parent.height - bar.height - 24
    y: 16 + bar.height
    anchors.left: listBg.right
    anchors.leftMargin: 8 + (width % 100) / 2
    cellHeight: 140
    cellWidth: 100
    model: generals

    delegate: GeneralCardItem {
      autoBack: false
      name: modelData
      onClicked: {
        if (root.stat === 2) {
          doBanGeneral(modelData);
        } else {
          generalDetailLoader.item.general = modelData;
          generalDetailLoader.item.canSetAvatar = root.parent instanceof StackView;
          generalDetail.open();
        }
      }

      Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: {
          const s = Config.curScheme;
          const gdata = Lua.call("GetGeneralData", modelData);
          const pack = gdata.package;
          if (s.banPkg[pack]) {
            if (!s.banPkg[pack].includes(modelData)) return 0.5;
          } else {
            if (!!s.normalPkg[pack]?.includes(modelData)) return 0.5;
          }
          return 0;
        }
        Behavior on opacity {
          NumberAnimation {}
        }
      }

      GlowText {
        id: banText
        visible: {
          const s = Config.curScheme;
          const gdata = Lua.call("GetGeneralData", modelData);
          const pack = gdata.package;
          if (s.banPkg[pack]) {
            return s.banPkg[pack].includes(modelData);
          } else {
            return !!s.normalPkg[pack]?.includes(modelData);
          }
        }
        text: {
          if (!visible) return '';
          const s = Config.curScheme;
          const gdata = Lua.call("GetGeneralData", modelData);
          const pack = gdata.package;
          if (s.banPkg[pack]) {
            if (s.banPkg[pack].includes(modelData)) return Lua.tr('Enable');
          } else {
            if (!!s.normalPkg[pack]?.includes(modelData)) return Lua.tr('Prohibit');
          }
        }
        anchors.centerIn: parent
        font.family: Config.li2Name
        color: "#E4D5A0"
        font.pixelSize: 36
        font.weight: Font.Medium
        glow.color: "black"
        glow.spread: 0.3
        glow.radius: 5
      }
    }

    footer: Item {
      width: parent.width
      height: 40
      Label {
        text: "共" + (generals !== undefined ? generals.length : 0) + "个武将"
        font.pixelSize: 20
        anchors.horizontalCenter: parent.horizontalCenter
        horizontalAlignment: Text.AlignHCenter
        font.family: Config.libianName
        color: "lightgrey"
      }
    }
  }

  ParallelAnimation {
    id: vanishAnim
    property bool filtering: false
    property var filter
    PropertyAnimation {
      target: gridView
      property: "opacity"
      to: 0
      duration: 150
      easing.type: Easing.InOutQuad
    }
    PropertyAnimation {
      target: gridView
      property: "y"
      to: 36 + bar.height
      duration: 150
      easing.type: Easing.InOutQuad
    }
    onFinished: {
      if (filtering) {
        generals = Lua.call("FilterAllGenerals", filter);
        filtering = false;
      } else if (word.text !== "") {
        generals = Lua.call("SearchAllGenerals", word.text);
      } else {
        generals = Lua.call("SearchGenerals",
        pkgList.model[pkgList.currentIndex], word.text);
      }
      word.text = "";
      appearAnim.start();
    }
  }

  SequentialAnimation {
    id: appearAnim
    PauseAnimation { duration: 200 }
    ParallelAnimation {
      PropertyAnimation {
        target: gridView
        property: "opacity"
        to: 1
        duration: 150
        easing.type: Easing.InOutQuad
      }
      PropertyAnimation {
        target: gridView
        property: "y"
        from: 36 + bar.height
        to: 16 + bar.height
        duration: 150
        easing.type: Easing.InOutQuad
      }
    }
  }

  Popup {
    id: generalDetail
    width: Config.winWidth * 0.6
    height: Config.winHeight * 0.8
    anchors.centerIn: parent
    background: Rectangle {
      color: "#EEEEEEEE"
      radius: 5
      border.color: "#A6967A"
      border.width: 1
    }

    Loader {
      id: generalDetailLoader
      width: parent.width / Config.winScale
      height: parent.height / Config.winScale
      anchors.centerIn: parent
      scale: Config.winScale
      source: "GeneralDetailPage.qml"
    }
  }

  Popup {
    id: lobby_drawer
    width: Config.winWidth * 0.8
    height: Config.winHeight * 0.85
    anchors.centerIn: parent
    background: Rectangle {
      color: "#EEEEEEEE"
      radius: 5
      border.color: "#A6967A"
      border.width: 1
    }

    Loader {
      id: lobby_dialog
      anchors.centerIn: parent
      width: parent.width / Config.winScale
      height: parent.height / Config.winScale
      scale: Config.winScale
      clip: true
      onSourceChanged: {
        if (item === null)
          return;
        item.finished.connect((data) => {
          sourceComponent = undefined;
          lobby_drawer.close();
          if (data) {
            vanishAnim.filtering = true;
            vanishAnim.filter = data; // 筛选
            vanishAnim.start();
          } else {
            vanishAnim.start(); // 清空
          }
        });
      }
      onSourceComponentChanged: sourceChanged();
    }
  }

  function loadPackages() {
    if (loaded) return;
    const _mods = Lua.call("GetAllModNames");
    const modData = Lua.call("GetAllMods");
    const packs = Lua.call("GetAllGeneralPack");
    _mods.forEach(name => {
      const pkgs = modData[name].filter(p => packs.includes(p)
        && !Config.serverHiddenPacks.includes(p));
      if (pkgs.length > 0)
        mods.append({ name: name, pkgs: JSON.stringify(pkgs) });
    });
    loaded = true;
  }

  function doBanGeneral(name) {
    const s = Config.curScheme;
    const gdata = Lua.call("GetGeneralData", name);
    const pack = gdata.package;
    let arr;
    if (s.banPkg[pack]) {
      arr = s.banPkg[pack];
    } else {
      if (!s.normalPkg[pack]) {
        s.normalPkg[pack] = [];
      }
      arr = s.normalPkg[pack];
    }
    // TODO: 根据手动全禁/全白名单自动改为禁包
    const idx = arr.indexOf(name);
    if (idx !== -1) {
      arr.splice(idx, 1);
    } else {
      arr.push(name);
    }
    Config.curSchemeChanged();
  }

  Component.onCompleted: {
    loadPackages();
  }
}
