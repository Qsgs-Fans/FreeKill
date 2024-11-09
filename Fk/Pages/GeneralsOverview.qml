// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Fk
import Fk.RoomElement
// import "RoomLogic.js" as RoomLogic

Item {
  id: root
  objectName: "GeneralsOverview"

  property bool loaded: false
  property int stat: 0 // 0=normal 1=banPkg 2=banChara

  Rectangle {
    id: listBg
    width: 260; height: parent.height
    color: "snow"
    radius: 6
  }

  ListView {
    id: modList
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
        text: luatr(name)
        color: modList.currentIndex === index ? "black" : "white"
        anchors.centerIn: parent
      }

      TapHandler {
        onTapped: {
          modList.currentIndex = index;
        }
      }
    }
  }

  ListView {
    id: pkgList
    width: 130; height: parent.height
    anchors.top: listBg.top; anchors.left: modList.right

    clip: true
    model: JSON.parse(mods.get(modList.currentIndex)?.pkgs ?? "[]")

    highlight: Rectangle { color: "#FFCC3F"; radius: 5; scale: 0.8 }
    highlightMoveDuration: 500

    delegate: Item {
      width: pkgList.width
      height: 40

      Text {
        text: luatr(modelData)
        color: !config.curScheme.banPkg[modelData] ? "black" : "grey"
        Behavior on color { ColorAnimation { duration: 200 } }
        anchors.centerIn: parent
      }

      Image {
        source: AppPath + "/image/button/skill/locked.png"
        opacity: !config.curScheme.banPkg[modelData] ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 200 } }
        anchors.centerIn: parent
        scale: 0.8
      }

      TapHandler {
        onTapped: {
          if (stat === 1) {
            const name = modelData;
            let s = config.curScheme;
            if (s.banPkg[name]) {
              delete s.banPkg[name];
              delete s.normalPkg[name];
            } else {
              delete s.normalPkg[name];
              s.banPkg[name] = [];
            }
            config.curSchemeChanged();
          } else {
            pkgList.currentIndex = index;
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
      color: stat === 0 ? "#5cb3cc" : "#869d9d"
      Behavior on color { ColorAnimation { duration: 200 } }
    }

    RowLayout {
      anchors.fill: parent
      Item { Layout.preferredWidth: 20 }

      Label {
        text: {
          switch (stat) {
            case 0: return luatr("Generals Overview");
            case 1: return luatr("$BanPkgHelp");
            case 2: return luatr("$BanCharaHelp");
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
      }

      ToolButton {
        text: luatr("Search")
        font.pixelSize: 20
        enabled: word.text !== ""
        onClicked: {
          pkgList.currentIndex = 0;
          vanishAnim.start();
        }
      }

      ToolButton {
        id: banButton
        font.pixelSize: 20
        text: {
          if (stat === 2) return luatr("OK");
          return luatr("BanGeneral");
        }
        enabled: stat !== 1
        visible: mainStack.currentItem.objectName === "GeneralsOverview"
        onClicked: {
          if (stat === 0) {
            stat = 2;
          } else {
            stat = 0;
          }
        }
      }

      ToolButton {
        id: banPkgButton
        font.pixelSize: 20
        text: {
          if (stat === 1) return luatr("OK");
          return luatr("BanPackage");
        }
        enabled: stat !== 2
        visible: mainStack.currentItem.objectName === "GeneralsOverview"
        onClicked: {
          if (stat === 0) {
            stat = 1;
          } else {
            stat = 0;
          }
        }
      }

      ToolButton {
        text: luatr("Quit")
        font.pixelSize: 20
        visible: mainStack.currentItem.objectName === "GeneralsOverview"
        onClicked: {
          mainStack.pop();
          config.saveConf();
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

    delegate: GeneralCardItem {
      autoBack: false
      name: modelData
      onClicked: {
        if (stat === 2) {
          const s = config.curScheme;
          const gdata = lcall("GetGeneralData", modelData);
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
          const idx = arr.indexOf(modelData);
          if (idx !== -1) {
            arr.splice(idx, 1);
          } else {
            arr.push(modelData);
          }
          config.curSchemeChanged();
        } else {
          generalText.clear();
          generalText.clearSavedText();
          generalDetail.general = modelData;
          generalDetail.updateGeneral();
          generalDetail.open();
        }
      }

      Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: {
          const s = config.curScheme;
          const gdata = lcall("GetGeneralData", modelData);
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
          const s = config.curScheme;
          const gdata = lcall("GetGeneralData", modelData);
          const pack = gdata.package;
          if (s.banPkg[pack]) {
            return s.banPkg[pack].includes(modelData);
          } else {
            return !!s.normalPkg[pack]?.includes(modelData);
          }
        }
        text: {
          if (!visible) return '';
          const s = config.curScheme;
          const gdata = lcall("GetGeneralData", modelData);
          const pack = gdata.package;
          if (s.banPkg[pack]) {
            if (s.banPkg[pack].includes(modelData)) return luatr('Enable');
          } else {
            if (!!s.normalPkg[pack]?.includes(modelData)) return luatr('Prohibit');
          }
        }
        anchors.centerIn: parent
        font.family: fontLi2.name
        color: "#E4D5A0"
        font.pixelSize: 36
        font.weight: Font.Medium
        glow.color: "black"
        glow.spread: 0.3
        glow.radius: 5
      }
    }
  }

  ParallelAnimation {
    id: vanishAnim
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
      if (word.text !== "") {
        gridView.model = lcall("SearchAllGenerals", word.text);
      } else {
        gridView.model = lcall("SearchGenerals",
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

  Component {
    id: skillAudioBtn
    Button {
      Layout.fillWidth: true
      contentItem: ColumnLayout {
        Text {
          Layout.fillWidth: true
          text: {
            if (name.endsWith("_win_audio")) {
              return luatr("Win audio");
            }
            return luatr(name) + (idx ? " (" + idx.toString() + ")"
              : "");
          }
          font.bold: true
          font.pixelSize: 14
        }
        Text {
          Layout.fillWidth: true
          text: {
            const orig = '$' + name + (specific ? '_' + detailGeneralCard.name : "")
              + (idx ? idx.toString() : "");
            const orig_trans = luatr(orig);

            if (orig_trans !== orig) {
              return orig_trans;
            }

            return "";
          }
          wrapMode: Text.WordWrap
        }
      }

      onClicked: {
        const skill = name;
        const general = specific ? detailGeneralCard.name : null;
        let extension;
        let path;
        let dat;

        // try main general
        if (general) {
          dat = lcall("GetGeneralData", general);
          extension = dat.extension;
          path = "./packages/" + extension + "/audio/skill/" + skill + "_" + general;
          if (Backend.exists(path + ".mp3") || Backend.exists(path + "1.mp3")) {
            Backend.playSound(path, idx);
            return;
          }
        }

        // finally normal skill
        dat = lcall("GetSkillData", skill);
        extension = dat.extension;
        path = "./packages/" + extension + "/audio/skill/" + skill;
        Backend.playSound(path, idx);
      }

      onPressAndHold: {
        Backend.copyToClipboard('$' + name + (specific ? '_' + detailGeneralCard.name : "")
              + (idx ? idx.toString() : "") + ':');
        toast.show(luatr("Audio Code Copy Success"));
      }

      ToolButton {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        visible: parent.hovered
        text: "⋮"
        onClicked: {
          if (skillAudioMenu.visible){
            skillAudioMenu.close();
          } else {
            skillAudioMenu.open();
          }
        }
        Menu {
          id: skillAudioMenu
          MenuItem {
            text: luatr("Copy Audio Code")
            onTriggered: {
              Backend.copyToClipboard('$' + name + (specific ? '_' + detailGeneralCard.name : "")
              + (idx ? idx.toString() : "") + ':');
              toast.show(luatr("Audio Code Copy Success"));
            }
          }
          MenuItem {
            text: luatr("Copy Audio Text")
            onTriggered: {
              Backend.copyToClipboard(luatr('$' + name + (specific ? '_' + detailGeneralCard.name : "")
              + (idx ? idx.toString() : "")));
              toast.show(luatr("Audio Text Copy Success"));
            }
          }
        }
      }
    }
  }

  Popup {
    id: generalDetail
    width: realMainWin.width * 0.6
    height: realMainWin.height * 0.8
    anchors.centerIn: parent
    background: Rectangle {
      color: "#EEEEEEEE"
      radius: 5
      border.color: "#A6967A"
      border.width: 1
    }

    property string general: "caocao"

    function addSpecialSkillAudio(skill) {
      const gdata = lcall("GetGeneralData", general);
      const extension = gdata.extension;
      let ret = false;
      for (let i = 0; i < 999; i++) {
        const fname = AppPath + "/packages/" + extension + "/audio/skill/" +
          skill + "_" + general + (i !== 0 ? i.toString() : "") + ".mp3";

        if (Backend.exists(fname)) {
          ret = true;
          audioModel.append({ name: skill, idx: i, specific: true });
        } else {
          if (i > 0) break;
        }
      }
      return ret;
    }

    function addSkillAudio(skill) {
      if (addSpecialSkillAudio(skill)) return;
      const skilldata = lcall("GetSkillData", skill);
      if (!skilldata) return;
      const extension = skilldata.extension;
      for (let i = 0; i < 999; i++) {
        const fname = AppPath + "/packages/" + extension + "/audio/skill/" +
          skill + (i !== 0 ? i.toString() : "") + ".mp3";

        if (Backend.exists(fname)) {
          audioModel.append({ name: skill, idx: i, specific: false});
        } else {
          if (i > 0) break;
        }
      }
    }

    function findDeathAudio(general) {
      const extension = lcall("GetGeneralData", general).extension;
      const fname = AppPath + "/packages/" + extension + "/audio/death/"
        + general + ".mp3";
      if (Backend.exists(fname)) {
        audioDeath.visible = true;
      } else {
        audioDeath.visible = false;
      }
    }

    function updateGeneral() {
      detailGeneralCard.name = general;
      detailFlickable.contentY = 0; // 重置滚动条
      const data = lcall("GetGeneralDetail", general);
      generalText.clear();
      generalText.clearSavedText();
      audioModel.clear();

      if (data.companions.length > 0){
        let ret = "<font color=\"slategrey\"><b>" + luatr("Companions")
          + "</b>: ";
        data.companions.forEach(t => {
          ret += luatr(t) + ' '
        });
        generalText.append(ret)
      }

      data.skill.forEach(t => {
        if (!t.name.startsWith('#')) {
          generalText.append((t.is_related_skill ? "<font color=\"purple\"><b>" : "<b>") + luatr(t.name) +
            "</b>: " + t.description + (t.is_related_skill ? "</font>" : ""));

          addSkillAudio(t.name);
        }
      });
      findDeathAudio(general);

      addSkillAudio(general + "_win_audio");
    }

    Item {
      anchors.centerIn: parent
      width: parent.width / mainWindow.scale
      height: parent.height / mainWindow.scale
      scale: mainWindow.scale

      Item {
        id: generalInfo
        x: 5
        y: 10
        width: 150
        ColumnLayout {
          width: parent.width
          GeneralCardItem {
            id: detailGeneralCard
            name: "caocao"
            scale: 1.5; transformOrigin: Item.TopLeft
          }

          Item { Layout.preferredHeight: 130 * 0.5 }

          Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            textFormat: TextEdit.RichText
            font.pixelSize: 16
            lineHeight: 21
            lineHeightMode: Text.FixedHeight
            function trans(str) {
              const ret = luatr(str);
              if (ret === str) {
                return luatr("Official");
              }
              return ret;
            }
            text: {
              const general = generalDetail.general;
              const gdata = lcall("GetGeneralData", general);
              let ret = [
                luatr(gdata.package),
                luatr("Title") + trans("#" + general),
                luatr("Designer") + trans("designer:" + general),
                luatr("Voice Actor") + trans("cv:" + general),
                luatr("Illustrator") + trans("illustrator:" + general),
              ].join("<br>");
              if (gdata.hidden) {
                ret += "<br><font color=\"grey\">" + luatr("Hidden General") + "</font>";
              }
              return ret;
            }
          }

          Timer {
            id: opTimer
            interval: 4000
          }

          Button {
            text: luatr("Set as Avatar")
            visible: mainStack.currentItem.objectName === "GeneralsOverview"
            enabled: detailGeneralCard.name !== "" && !opTimer.running
              && Self.avatar !== detailGeneralCard.name
            onClicked: {
              mainWindow.busy = true;
              opTimer.start();
              ClientInstance.notifyServer(
                "UpdateAvatar",
                JSON.stringify([detailGeneralCard.name])
              );
            }
          }
        }
      }

      Flickable {
        id: detailFlickable
        flickableDirection: Flickable.VerticalFlick
        contentHeight: detailLayout.height
        width: parent.width - 40 - generalInfo.width
        height: parent.height - 40
        clip: true
        anchors.left: generalInfo.right
        anchors.leftMargin: 20
        y: 20

        ColumnLayout {
          id: detailLayout
          width: parent.width

          TextEdit {
            id: generalText

            property var savedtext: []
            function clearSavedText() {
              savedtext = [];
            }
            Layout.fillWidth: true
            readOnly: true
            selectByKeyboard: true
            selectByMouse: false
            wrapMode: TextEdit.WordWrap
            textFormat: TextEdit.RichText
            font.pixelSize: 18
            onLinkActivated: (link) => {
              if (link === "back") {
                text = savedtext.pop();
              } else {
                savedtext.push(text);
                text = '<a href="back">点击返回</a><br>' + luatr(link);
              }
            }
          }

          GridLayout {
            Layout.fillWidth: true
            columns: 2
            Repeater {
              model: ListModel {
                id: audioModel
              }
              delegate: skillAudioBtn
            }
          }

          Button {
            id: audioDeath
            Layout.fillWidth: true
            contentItem: ColumnLayout {
              Text {
                Layout.fillWidth: true
                text: luatr("Death audio")
                font.bold: true
                font.pixelSize: 14
              }
              Text {
                Layout.fillWidth: true
                text: {
                  const orig = "~" + generalDetail.general;
                  const tr = luatr(orig);
                  if (tr === orig) {
                    return "";
                  }
                  return tr;
                }
                wrapMode: Text.WordWrap
              }
            }

            onClicked: {
              const general = generalDetail.general
              const extension = lcall("GetGeneralData", general).extension;
              Backend.playSound("./packages/" + extension + "/audio/death/"
                + general);
            }

            onPressAndHold: {
              Backend.copyToClipboard("$~" + generalDetail.general);
              toast.show(luatr("Audio Code Copy Success"));
            }

            ToolButton {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              Layout.preferredWidth: 32
              Layout.preferredHeight: 32
              visible: parent.hovered
              text: "⋮"
              onClicked: {
                if (deathAudioMenu.visible){
                  deathAudioMenu.close();
                } else {
                  deathAudioMenu.open();
                }
              }
              Menu {
                id: deathAudioMenu
                MenuItem {
                  text: luatr("Copy Audio Code")
                  onTriggered: {
                    Backend.copyToClipboard("$~" + generalDetail.general);
                    toast.show(luatr("Audio Code Copy Success"));
                  }
                }
                MenuItem {
                  text: luatr("Copy Audio Text")
                  onTriggered: {
                    Backend.copyToClipboard(luatr("~" + generalDetail.general));
                    toast.show(luatr("Audio Text Copy Success"));
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  function loadPackages() {
    if (loaded) return;
    const _mods = lcall("GetAllModNames");
    const modData = lcall("GetAllMods");
    const packs = lcall("GetAllGeneralPack");
    _mods.forEach(name => {
      const pkgs = modData[name].filter(p => packs.includes(p)
        && !config.serverHiddenPacks.includes(p));
      if (pkgs.length > 0)
        mods.append({ name: name, pkgs: JSON.stringify(pkgs) });
    });
    loaded = true;
  }
}
