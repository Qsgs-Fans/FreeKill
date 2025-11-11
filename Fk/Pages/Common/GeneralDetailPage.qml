import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Fk
import Fk.Widgets as W
import Fk.Components.LunarLTK

Item {
  id: root

  property string general: "caocao"
  property bool canSetAvatar
  property bool isFavor: {
    const g = root.general;
    const fav = Config.favoriteGenerals;
    return fav.includes(g);
  }

  onGeneralChanged: {
    generalText.clear();
    generalText.clearSavedText();
    root.updateGeneral();
    isFavor = Config.favoriteGenerals.includes(general);
  }

  function addSpecialSkillAudio(skill) {
    const gdata = Lua.call("GetGeneralData", general);
    const extension = gdata.extension;
    let ret = false;
    for (let i = 0; i < 999; i++) {
      const fname = SkinBank.getAudioRealPath(skill + "_" + general+(i !== 0 ? i.toString() : ""), extension, "skill");

      if (fname) {
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
    const skilldata = Lua.call("GetSkillData", skill);
    if (!skilldata) return;
    const extension = skilldata.extension;
    for (let i = 0; i < 999; i++) {
      const fname = SkinBank.getAudioRealPath(skill +(i !== 0 ? i.toString() : ""), extension, "skill");

      if (fname) {
        audioModel.append({ name: skill, idx: i, specific: false});
      } else {
        if (i > 0) break;
      }
    }
  }

  function findWinAudio(general) {
    const extension = Lua.call("GetGeneralData", general).extension;
    const fname = SkinBank.getAudioRealPath(general, extension, "win");
    audioWin.visible = !!fname;
  }

  function findDeathAudio(general) {
    const extension = Lua.call("GetGeneralData", general).extension;
    const fname = SkinBank.getAudioRealPath(general, extension, "death");
    audioDeath.visible = !!fname;
  }

  function updateGeneral() {
    detailGeneralCard.name = general;
    detailFlickable.contentY = 0; // 重置滚动条
    const data = Lua.call("GetGeneralDetail", general);
    generalText.clear();
    generalText.clearSavedText();
    audioModel.clear();

    if (data.headnote !== "") generalText.append("<font color=\"lightslategrey\">" + Lua.tr(data.headnote) + "</font>");

    if (data.companions.length > 0){
      let ret = "<font color=\"slategrey\"><b>" + Lua.tr("Companions") + "</b>: ";
      ret += data.companions.map(Lua.tr).join(" ");
      generalText.append(ret);
    }

    for (const t of data.skill) {
      Qt.callLater(() => {
        if (!t.name.startsWith('#')) {
          generalText.append((t.is_related_skill ? "<font color=\"purple\"><b>" : "<b>") + Lua.tr(t.name) +
          "</b>: " + t.description + (t.is_related_skill ? "</font>" : ""));

          addSkillAudio(t.name);
        }
      });
    }

    Qt.callLater(() => {
      findWinAudio(general);
      findDeathAudio(general);
    });

    Qt.callLater(() => {
      if (data.endnote !== "") {
        generalText.append("<font color=\"lightslategrey\">" + Lua.tr(data.endnote) + "</font>");
      }
    });
  }

  Component {
    id: skillAudioBtn
    Button {
      Layout.fillWidth: true
      contentItem: Column {
        Text {
          width: parent.width
          text: {
            return Lua.tr(name) + (idx ? " (" + idx.toString() + ")"
              : "");
          }
          font.bold: true
          font.pixelSize: 14
        }
        Text {
          width: parent.width
          text: {
            const orig = '$' + name + (specific ? '_' + detailGeneralCard.name : "")
              + (idx ? idx.toString() : "");
            const orig_trans = Lua.tr(orig);

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
          dat = Lua.call("GetGeneralData", general);
          extension = dat.extension;
          path = SkinBank.getAudio(skill + "_" + general, extension, "skill");
          //path = "./packages/" + extension + "/audio/skill/" + skill + "_" + general;
          if (path !== undefined) {
            Backend.playSound(path, idx);
            return;
          }
        }

        // finally normal skill
        dat = Lua.call("GetSkillData", skill);
        extension = dat.extension;
        path = SkinBank.getAudio(skill, extension, "skill");
        Backend.playSound(path, idx);
      }

      onPressAndHold: {
        Backend.copyToClipboard('$' + name + ':' + (idx ? idx.toString() : "")
          + (specific ? ':' + detailGeneralCard.name : ""));
        App.showToast(Lua.tr("Audio Code Copy Success"));
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
            text: Lua.tr("Copy Audio Code")
            onTriggered: {
              Backend.copyToClipboard('$' + name + ':' + (idx ? idx.toString() : "")
                + (specific ? ':' + detailGeneralCard.name : ""));
              App.showToast(Lua.tr("Audio Code Copy Success"));
            }
          }
          MenuItem {
            text: Lua.tr("Copy Audio Text")
            onTriggered: {
              Backend.copyToClipboard(Lua.tr('$' + name + (specific ? '_' + detailGeneralCard.name : "")
              + (idx ? idx.toString() : "")));
              App.showToast(Lua.tr("Audio Text Copy Success"));
            }
          }
        }
      }
    }
  }

  ColumnLayout {
    id: generalInfo
    x: 5
    y: 10
    width: 150
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
        const ret = Lua.tr(str);
        if (ret === str) {
          return Lua.tr("Official");
        }
        return ret;
      }
      text: {
        const general = root.general;
        const gdata = Lua.call("GetGeneralData", general);
        let ret = [
          Lua.tr(gdata.package),
          Lua.tr("Title") + ": " + trans("#" + general),
          Lua.tr("Designer") + ": " + trans("designer:" + general),
          Lua.tr("Voice Actor") + ": " + trans("cv:" + general),
          Lua.tr("Illustrator") + ": " + trans("illustrator:" + general),
        ].join("<br>");
        if (gdata.hidden) {
          ret += "<br><font color=\"grey\">" + Lua.tr("Hidden General") + "</font>";
        }
        return ret;
      }
    }

    Timer {
      id: opTimer
      interval: 4000
    }

    W.ButtonContent {
      text: Lua.tr("Set as Avatar")
      visible: root.canSetAvatar
      enabled: detailGeneralCard.name !== "" && !opTimer.running
      && Self.avatar !== detailGeneralCard.name
      onClicked: {
        App.setBusy(true);
        opTimer.start();
        ClientInstance.notifyServer(
          "UpdateAvatar",
          detailGeneralCard.name
        );
      }
    }

    W.ButtonContent {
      text: root.isFavor ? Lua.tr("Remove from Favorite") : Lua.tr("Set as Favorite")
      onClicked: {
        const g = root.general;
        const fav = Config.favoriteGenerals;
        root.isFavor = fav.includes(g);
        if (root.isFavor) {
          fav.splice(fav.indexOf(g), 1);
        } else {
          fav.push(g);
        }
        root.isFavor = fav.includes(g);
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
            text = '<a href="back">' + Lua.tr("Click to back") + '</a><br>' + Lua.tr(link);
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
        id: audioWin
        Layout.fillWidth: true
        contentItem: Column {
          Text {
            // Layout.fillWidth: true
            text: Lua.tr("Win audio")
            font.bold: true
            font.pixelSize: 14
          }
          Text {
            // Layout.fillWidth: true
            text: {
              const orig = "!" + root.general;
              const tr = Lua.tr(orig);
              if (tr === orig) {
                return "";
              }
              return tr;
            }
            wrapMode: Text.WordWrap
          }
        }

        onClicked: {
          const general = root.general
          const extension = Lua.call("GetGeneralData", general).extension;
          const path = SkinBank.getAudio(general, extension, "win");
          if (path !== undefined) {
            Backend.playSound(path);
          }
        }

        onPressAndHold: {
          Backend.copyToClipboard("$!" + root.general);
          App.showToast(Lua.tr("Audio Code Copy Success"));
        }

        ToolButton {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          Layout.preferredWidth: 32
          Layout.preferredHeight: 32
          visible: parent.hovered
          text: "⋮"
          onClicked: {
            if (winAudioMenu.visible){
              winAudioMenu.close();
            } else {
              winAudioMenu.open();
            }
          }
          Menu {
            id: winAudioMenu
            MenuItem {
              text: Lua.tr("Copy Audio Code")
              onTriggered: {
                Backend.copyToClipboard("$~" + root.general);
                App.showToast(Lua.tr("Audio Code Copy Success"));
              }
            }
            MenuItem {
              text: Lua.tr("Copy Audio Text")
              onTriggered: {
                Backend.copyToClipboard(Lua.tr("~" + root.general));
                App.showToast(Lua.tr("Audio Text Copy Success"));
              }
            }
          }
        }
      }

      Button {
        id: audioDeath
        Layout.fillWidth: true
        contentItem: ColumnLayout {
          Text {
            Layout.fillWidth: true
            text: Lua.tr("Death audio")
            font.bold: true
            font.pixelSize: 14
          }
          Text {
            Layout.fillWidth: true
            text: {
              const orig = "~" + root.general;
              const tr = Lua.tr(orig);
              if (tr === orig) {
                return "";
              }
              return tr;
            }
            wrapMode: Text.WordWrap
          }
        }

        onClicked: {
          const general = root.general
          const extension = Lua.call("GetGeneralData", general).extension;
          const path = SkinBank.getAudio(general, extension, "death");
          if (path !== undefined) {
            Backend.playSound(path);
          }
        }

        onPressAndHold: {
          Backend.copyToClipboard("$~" + root.general);
          App.showToast(Lua.tr("Audio Code Copy Success"));
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
              text: Lua.tr("Copy Audio Code")
              onTriggered: {
                Backend.copyToClipboard("$~" + root.general);
                App.showToast(Lua.tr("Audio Code Copy Success"));
              }
            }
            MenuItem {
              text: Lua.tr("Copy Audio Text")
              onTriggered: {
                Backend.copyToClipboard(Lua.tr("~" + root.general));
                App.showToast(Lua.tr("Audio Text Copy Success"));
              }
            }
          }
        }
      }
    }
  }
}
