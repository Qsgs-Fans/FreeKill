import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Fk
import Fk.Widgets as W
import Fk.Components.LunarLTK

// 神秘bug 在import Fk之前引进这个会把Config单例爆破
import QtQuick.Controls.FluentWinUI3 as Win

Item {
  id: root

  property string general: ""
  property bool canSetAvatar
  property bool isFavor: {
    const g = root.general;
    const fav = Config.favoriteGenerals;
    return fav.includes(g);
  }

  signal changeGeneralDetailInside(string to_general)

  onGeneralChanged: {
    generalText.clear();
    generalText.clearSavedText();
    root.updateGeneral();
    isFavor = Config.favoriteGenerals.includes(general);
  }

  function addSpecialSkillAudio(skill) {
    const gdata = Ltk.getGeneralData(general);
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
    const skilldata = Ltk.getSkillData(skill);
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
    const extension = Ltk.getGeneralData(general).extension;
    const fname = SkinBank.getAudioRealPath(general, extension, "win");
    audioWin.visible = !!fname;
  }

  function findDeathAudio(general) {
    const extension = Ltk.getGeneralData(general).extension;
    const fname = SkinBank.getAudioRealPath(general, extension, "death");
    audioDeath.visible = !!fname;
  }

  function updateGeneral() {
    detailGeneralCard.name = general;
    //detailFlickable.contentY = 0; // 重置滚动条
    const data = Ltk.getGeneralDetail(general);
    generalText.clear();
    generalText.clearSavedText();
    audioModel.clear();

    if (data.headnote !== "") generalText.append("<font color=\"lightslategrey\">" + Lua.tr(data.headnote) + "</font>");

    if (data.companions.length > 0){
      let ret = "<font color=\"slategrey\"><b>" + Lua.tr("Companions") + "</b>: ";
      ret += data.companions.map(Lua.tr).join(" ");
      generalText.append(ret);
    }

    const skillnamecss = `
    <style>
    .skill-name {
      font-size: 19px;
      font-weight: bold;
    }
    </style>
    `;

    for (const t of data.skill) {
      Qt.callLater(() => {
        if (!t.name.startsWith('#')) {
          generalText.append((`${skillnamecss}<font ${t.is_related_skill ? 'color="purple"' : ''} class='skill-name'><b>`) + Lua.tr(t.name) +
          "</b></font> " + `${t.is_related_skill ? '<font color="purple">' : ''}${t.description}${t.is_related_skill ? '</font>' : ''}`);

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

    otherText.clear();
    Qt.callLater(() => {
      const descLen = generalText.length;
      let descLenComment;
      if (descLen < 60) {
        descLenComment = "<font color='darkgreen'>惜墨如金 (非常短)</font>"
      } else if (descLen < 80) {
        descLenComment = "<font color='mediumseagreen'>短小精悍 (短)</font>"
      } else if (descLen < 115) {
        descLenComment = "<font color='lightseagreen'>简明扼要 (较短)</font>"
      } else if (descLen < 160) {
        descLenComment = "<font color='steelblue'>恰到好处 (适中)</font>"
      } else if (descLen < 210) {
        descLenComment = "<font color='blueviolet'>下笔成文 (较长)</font>"
      } else if (descLen < 280) {
        descLenComment = "<font color='orangered'>洋洋洒洒 (长)</font>"
      } else if (descLen <= 450) {
        descLenComment = "<font color='crimson'>鸿篇巨制 (非常长)</font>"
      } else {
        descLenComment = "<font color='darkred'>罄竹难书 (难评)</font>"
      }
      otherText.append(`<font color="lightslategrey">技能描述全字符数：</font><b>${generalText.length} ~ ${descLenComment}</b><br>`);

      // 写sql是吧，我觉得这样不太好
      const addr = ClientInstance.peerAddress();
      let query = `SELECT general, mode, role,
      COUNT(CASE result WHEN 1 THEN 1 END) AS win,
      COUNT(CASE result WHEN 2 THEN 1 END) AS lose,
      COUNT(CASE result WHEN 3 THEN 1 END) AS draw,
      COUNT() AS total
      FROM myGameData WHERE pid = ${Self.id} AND server_addr = '${addr}' AND general = '${general}'
      GROUP BY mode;`
      const result = Cpp.sqlquery(query);

      let allTotal = 0, allWin = 0;
      let winRateTxt = "";
      for (const dat of result) {
        let { mode, total, win } = dat;
        total = parseInt(total);
        win = parseInt(win);
        if (total > 0 && Lua.tr(mode) !== mode) {
          allTotal += total;
          allWin += win;
          winRateTxt += `<tr><td>${Lua.tr(mode)}</td><td>${total}</td><td>${win}</td><td>${(win/total*100).toFixed(2)}%</td></tr>`
        }
      }
      if (winRateTxt === '') {
        winRateTxt = '没有出战记录<br>';
      } else {
        const css = `<style>
        table {
          border-collapse: collapse;
          border: 2px solid rgb(140 140 140);
        }

        th, td {
          padding: 2px 12px;
          text-align: center;
        }
        </style>`;

        winRateTxt = `总出战${allTotal}场 胜利${allWin}场 胜率${(allWin/allTotal*100).toFixed(2)}%`
        + `${css}<table border="1"><tr><th>游戏模式</th><th>出战次数</th><th>胜利次数</th><th>胜率</th></tr>`
        + winRateTxt
        + '</table>';
      }

      otherText.append(winRateTxt);
    });
  }

  function getSameNameGenerals(general) {
    if (general === undefined) return [];
    let generals = Lua.evaluate(`(function(general)
      local trueName = (Fk.generals[general] or {}).trueName
      local generals = {}
      if trueName then
        for i, g in pairs(Fk.generals) do
          if g.trueName == trueName and i ~= general then
            table.insert(generals, i)
          end
        end
      end
      return generals
    end)("${general}")`)
    return generals
  }

  Component {
    id: skillAudioBtn
    Win.Button {
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
          dat = Ltk.getGeneralData(general);
          extension = dat.extension;
          path = SkinBank.getAudio(skill + "_" + general, extension, "skill");
          //path = "./packages/" + extension + "/audio/skill/" + skill + "_" + general;
          if (path !== undefined) {
            Backend.playSound(path, idx);
            return;
          }
        }

        // finally normal skill
        dat = Ltk.getSkillData(skill);
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
        const gdata = Ltk.getGeneralData(general);
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

    Win.Button {
      Layout.preferredWidth: 130
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

    Win.Button {
      Layout.preferredWidth: 130
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

  ColumnLayout {
    width: parent.width - 40 - generalInfo.width
    height: parent.height - 10
    anchors.left: generalInfo.right
    anchors.leftMargin: 20
    y: 10

    SwipeView {
      Layout.fillWidth: true
      Layout.fillHeight: true
      interactive: false
      currentIndex: drawerBar.currentIndex
      clip: true

      Flickable {
        clip: true
        contentHeight: generalText.height
        TextEdit {
          id: generalText
          width: parent.width - 4
          x: 2

          property var savedtext: []
          function clearSavedText() {
            savedtext = [];
          }
          // Layout.fillWidth: true
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
      }

      Flickable {
        clip: true
        contentHeight: audioLayout.height
        ColumnLayout {
          id: audioLayout
          width: parent.width - 4
          x: 2

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

          Win.Button {
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
              const extension = Ltk.getGeneralData(general).extension;
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

          Win.Button {
            id: audioDeath
            Layout.fillWidth: true
            contentItem: Column {
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
              const extension = Ltk.getGeneralData(general).extension;
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

      Flickable {
        clip: true
        contentHeight: otherText.height
        TextEdit {
          id: otherText
          width: parent.width - 4
          x: 2

          readOnly: true
          selectByKeyboard: true
          selectByMouse: false
          wrapMode: TextEdit.WordWrap
          textFormat: TextEdit.RichText
          font.pixelSize: 18
        }
      }

      Flickable {
        clip: true
        contentHeight: otherSameLayout.height
        GridLayout {
          id: otherSameLayout
          columns: 5
          columnSpacing: 5
          rowSpacing: 5
          Repeater {
            model: root.getSameNameGenerals(root.general)
            delegate: GeneralCardItem {
              id: sameNameGeneralCard
              name: modelData
              scale: 1; transformOrigin: Item.TopLeft

              onClicked: {
                drawerBar.currentIndex = 0;
                root.changeGeneralDetailInside(modelData)
              }
            }
          }
        }
      }
    }

    W.ViewSwitcher {
      id: drawerBar
      Layout.alignment: Qt.AlignHCenter
      model: [
        Lua.tr("Skill Description"),
        Lua.tr("Audio Text"),
        Lua.tr("Statistics Overview"),
        Lua.tr("Other Same Name Generals"),
      ]
    }
  }
}
