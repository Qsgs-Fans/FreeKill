pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Fk
import Fk.Widgets as W

import LunarLtk
import LunarLtk.Components

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
  readonly property int audioTextMarginH: 12  // 音频按钮文本水平间距
  readonly property int audioTextMarginV: 5   // 音频按钮文本垂直间距

  signal changeGeneralDetailInside(string to_general)

  onGeneralChanged: {
    root.updateGeneral();
    isFavor = Config.favoriteGenerals.includes(general);
    detailSwipeView.currentItem?.item?.update()
  }

  function updateGeneral() {
    detailGeneralCard.dataModel = Ltk.createGeneralCardModel(general);
  }

  function getSameNameGenerals(general) {
    if (general === undefined) return [];
    const g = Ltk.getGeneral(general);
    if (!g) return [];
    // 不用Lua.fk.same_generals是为了避免拷贝，这玩意挺大
    const sameGenerals = Lua.ev(`Fk.same_generals['${g.trueName}']`);
    if (sameGenerals) {
      sameGenerals.splice(sameGenerals.indexOf(general), 1);
      return sameGenerals;
    }
    return []
  }

  Component {
    id: skillAudioBtn
    W.ButtonContent {
      id: skillAudioItem
      Layout.preferredHeight: skillAudioName.height + skillAudio.height + 2 * audioTextMarginV
      plainButton: false
      required property string name
      required property int idx
      required property bool specific

      Layout.fillWidth: true
      contentItem: Column {
        anchors.fill: parent
        anchors.leftMargin: audioTextMarginH
        anchors.rightMargin: audioTextMarginH
        anchors.topMargin: audioTextMarginV
        anchors.bottomMargin: audioTextMarginV
        Text {
          id: skillAudioName
          width: parent.width
          text: {
            return Lua.tr(skillAudioItem.name) + (skillAudioItem.idx ? " (" + skillAudioItem.idx.toString() + ")"
              : "");
          }
          font.bold: true
          font.pixelSize: 14
        }
        Text {
          id: skillAudio
          width: parent.width
          text: {
            const orig = '$' + skillAudioItem.name + (skillAudioItem.specific ? '_' + detailGeneralCard.dataModel.name : "")
              + (skillAudioItem.idx ? skillAudioItem.idx.toString() : "");
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
        const skill = skillAudioItem.name;
        const general = skillAudioItem.specific ? detailGeneralCard.dataModel.name : null;
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
            Backend.playSound(path, skillAudioItem.idx);
            return;
          }
        }

        // finally normal skill
        dat = Ltk.getSkillData(skill);
        extension = dat.extension;
        path = SkinBank.getAudio(skill, extension, "skill");
        Backend.playSound(path, skillAudioItem.idx);
      }

      onPressAndHold: {
        Backend.copyToClipboard('$' + skillAudioItem.name + ':' + (skillAudioItem.idx ? skillAudioItem.idx.toString() : "")
          + (skillAudioItem.specific ? ':' + detailGeneralCard.dataModel.name : ""));
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
              Backend.copyToClipboard('$' + skillAudioItem.name + ':' + (skillAudioItem.idx ? skillAudioItem.idx.toString() : "")
                + (skillAudioItem.specific ? ':' + detailGeneralCard.dataModel.name : ""));
              App.showToast(Lua.tr("Audio Code Copy Success"));
            }
          }
          MenuItem {
            text: Lua.tr("Copy Audio Text")
            onTriggered: {
              Backend.copyToClipboard(Lua.tr('$' + skillAudioItem.name + (skillAudioItem.specific ? '_' + detailGeneralCard.dataModel.name : "")
              + (skillAudioItem.idx ? skillAudioItem.idx.toString() : "")));
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
      dataModel: Ltk.createGeneralCardModel("caocao")
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

    W.ButtonContent {
      Layout.preferredWidth: 130
      Layout.preferredHeight: 25
      plainButton: false
      text: Lua.tr("Set as Avatar")
      visible: root.canSetAvatar
      enabled: detailGeneralCard.dataModel.name !== "" && !opTimer.running
      && Cpp.self.avatar !== detailGeneralCard.dataModel.name
      onClicked: {
        App.setBusy(true);
        opTimer.start();
        ClientInstance.notifyServer(
          "UpdateAvatar",
          detailGeneralCard.dataModel.name
        );
      }
    }

    W.ButtonContent {
      Layout.preferredWidth: 130
      Layout.preferredHeight: 25
      plainButton: false
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

    W.ButtonContent {
      Layout.preferredWidth: 130
      Layout.preferredHeight: 25
      plainButton: false
      text: Lua.tr("Check Skins")
      visible: Ltk.getSkinNamesByGeneral(root.general).length > 0

      onClicked: {
        detailSwipeView.drawer.currentIndex = 5
      }
    }
  }

  // TODO: 下面都是小页面的Component，UI重构合并后再拆分到单独qml文件
  Component {
    id: skillTextComponent

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

      function update() {
        const general = root.general;
        const data = Ltk.getGeneralDetail(general);
        generalText.clear();
        generalText.clearSavedText();

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
          if (!t.name.startsWith('#')) {
            generalText.append((`${skillnamecss}<font ${t.is_related_skill ? 'color="purple"' : ''} class='skill-name'><b>`) + Lua.tr(t.name) +
            "</b></font> " + `${t.is_related_skill ? '<font color="purple">' : ''}${t.description}${t.is_related_skill ? '</font>' : ''}`);
          }
        }

        if (data.endnote !== "") {
          generalText.append("<font color=\"lightslategrey\">" + Lua.tr(data.endnote) + "</font>");
        }
      }

      Component.onCompleted: update();
    }
  }

  Component {
    id: skillAudioComponent

    Flickable {
      clip: true
      contentHeight: audioLayout.height
      ColumnLayout {
        id: audioLayout
        width: parent.width - 4
        y: 3
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

        W.ButtonContent {
          id: audioWin
          Layout.fillWidth: true
          Layout.preferredHeight: winName.height + winAudio.height + 2 * audioTextMarginV
          plainButton: false
          contentItem: Column {
            anchors.fill: parent
            anchors.leftMargin: audioTextMarginH
            anchors.rightMargin: audioTextMarginH
            anchors.topMargin: audioTextMarginV
            anchors.bottomMargin: audioTextMarginV
            Text {
              id: winName
              // Layout.fillWidth: true
              text: Lua.tr("Win audio")
              font.bold: true
              font.pixelSize: 14
            }
            Text {
              id: winAudio
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

        W.ButtonContent {
          id: audioDeath
          Layout.preferredHeight: deathName.height + deathAudio.height + 2 * audioTextMarginV
          Layout.fillWidth: true
          plainButton: false
          contentItem: Column {
            anchors.fill: parent
            anchors.leftMargin: audioTextMarginH
            anchors.rightMargin: audioTextMarginH
            anchors.topMargin: audioTextMarginV
            anchors.bottomMargin: audioTextMarginV
            Text {
              id: deathName
              Layout.fillWidth: true
              text: Lua.tr("Death audio")
              font.bold: true
              font.pixelSize: 14
            }
            Text {
              id: deathAudio
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


      function update() {
        const data = Ltk.getGeneralDetail(general);
        audioModel.clear();

        for (const t of data.skill) {
          if (!t.name.startsWith('#')) {
            Qt.callLater(() => addSkillAudio(t.name));
          }
        }

        Qt.callLater(() => {
          findWinAudio(general);
          findDeathAudio(general);
        });
      }

      Component.onCompleted: update();
    }
  }

  Component {
    id: statisticsComponent

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

      function update() {
        otherText.clear();
        const descLen = Lua.fn(`function(general)
          local allDesc = table.map(Fk.generals[general]:getSkillNameList(true, true), function(s)
            return Fk:translate(s) + Fk:translate(":" .. s)
          end)
          local ret = 0
          for _, s in ipairs(allDesc) do
            ret = ret + s:len()
          end
          return ret
        end`)(general);
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
        otherText.append(`<font color="lightslategrey">技能描述全字符数：</font><b>${descLen} ~ ${descLenComment}</b><br>`);

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
      }

      Component.onCompleted: update();
    }
  }

  // 这个页面加载的速度非常慢！
  Component {
    id: sameGeneralsComponent

    GridView {
      clip: true
      id: otherSameLayout
      cellWidth: 70
      cellHeight: 70
      model: root.getSameNameGenerals(root.general)
      delegate: CompactGeneralCardItem {
        required property var modelData
        id: sameNameGeneralCard
        dataModel: Ltk.createGeneralCardModel(modelData)
        scale: 1; transformOrigin: Item.TopLeft

        onClicked: {
          drawerBar.currentIndex = 0;
          root.changeGeneralDetailInside(modelData)
        }
      }
    }
  }

  // 这个页面加载的速度很慢！
  Component {
    id: sourceCodeComponent

    Flickable {
      clip: true
      contentHeight: srcList.height
      ColumnLayout {
        id: srcList
        width: parent.width - 4
        x: 2
        y: 3
        spacing: 0
        property string generalSourceCode

        W.ButtonContent {
          Layout.fillWidth: true
          Layout.preferredHeight: 27
          plainButton: false
          text: {
            const skill = root.general;
            const skillTr = "武将定义";
            if (generalSrcArea.text === "") {
              return skillTr + " (点击查看源码)";
            } else {
              return skillTr + " (点击折叠)";
            }
          }

          onClicked: {
            if (generalSrcArea.text !== "") {
              generalSrcArea.text = "";
            } else {
              if (!parent.generalSourceCode) parent.updateGeneralSourceCode();
              generalSrcArea.text = parent.generalSourceCode;
            }
          }
        }

        TextEdit {
          id: generalSrcArea
          font.pixelSize: 12
          Layout.fillWidth: true
          font.family: "Consolas"
          readOnly: true
          wrapMode: Text.WrapAnywhere
          selectByKeyboard: true
          selectByMouse: false
          textFormat: Text.PlainText

          Component.onCompleted: {
            // 就目前而言只有使用Kde桌面的Linux用户才能体验到语法高亮功能！
            // 不过那个语法高亮库只依赖Qt库，理论上可以编译到游戏中，但是应该会很麻烦
            const component = Qt.createComponent("org.kde.syntaxhighlighting", "SyntaxHighlighter");
            if (component.status !== Component.Ready) {
              console.warn("SyntaxHighlighter is not installed, syntax highlight feature disabled.");
              return;
            }

            const highlighter = component.createObject(generalSrcArea, {
              textEdit: generalSrcArea,
              definition: "Lua",
            });
          }
        }

        function updateGeneralSourceCode() {
          const general = root.general;
          let ret = "--------------------------------------------\n" +
          `--- 武将名：${Lua.tr(general)}\n` +
          "--- 源码：";

          const dat = Ltk.getGeneralData(general);
          let path = `/packages/${dat.extension}/pkg/${dat.package}/init.lua`;
          const whole_path = `${Cpp.path}` + path;

          if (!Fs.exists(whole_path)) {
            ret += "(不可用)\n" + "--------------------------------------------\n\n";
            generalSourceCode = ret;
            return;
          }
          path = "." + path;
          const readFile = Lua.fn(`function(path)
            local f = io.open(path)
            if not f then return "" end
            local ret = f:read("a")
            f:close()
            return ret
          end`);
          const fileContent = readFile(path) || "";

          function extractGeneralSnippet(content, name) {
            if (!content) return { snippet: content, startLine: -1, endLine: -1 };
            const lines = content.split(/\r?\n/);
            // find start line: General( or General:new(
            let startLine = -1;
            for (let i = 0; i < lines.length; i++) {
              const line = lines[i];
              const m = line.match(/General(?::new)?\s*\(/);
              if (!m) continue;
              // gather text from this '(' to its matching ')'
              let parenCount = 0;
              let foundClose = false;
              let j = i;
              let seg = "";
              for (; j < lines.length; j++) {
                const fragment = (j === i) ? lines[j].slice(lines[j].indexOf('(')) : lines[j];
                seg += (j === i ? lines[j].slice(lines[j].indexOf('(')) : '\n' + lines[j]);
                for (let k = 0; k < fragment.length; k++) {
                  const ch = fragment[k];
                  if (ch === '(') parenCount++;
                  else if (ch === ')') {
                    parenCount--;
                    if (parenCount === 0) { foundClose = true; break; }
                  }
                }
                if (foundClose) break;
              }
              const argsSegment = seg;
              // check second argument contains root.general
              const escName = name.replace(/[\\^$*+?.()|[\]{}]/g, '\\$&');
              const reSecond = new RegExp(`,\\s*(root\\.general|["']${escName}["'])`);
              if (reSecond.test(argsSegment)) {
                startLine = i;
                break;
              }
            }

            if (startLine === -1) return { snippet: content, startLine: -1, endLine: -1 };

            // compute char index for startLine
            let charIdx = 0;
            for (let t = 0; t < startLine; t++) {
              charIdx += lines[t].length + 1; // +1 for newline
            }

            // find next General definition after startLine or a top-level return, and cut before it
            let nextStartLine = -1;
            const startRegex = /General(?::new)?\s*\(/;
            const returnRegex = /^\s*return\b/;
            for (let i2 = startLine + 1; i2 < lines.length; i2++) {
              if (startRegex.test(lines[i2]) || returnRegex.test(lines[i2])) {
                nextStartLine = i2;
                break;
              }
            }
            if (nextStartLine === -1) {
              // no next general or return, return rest of file from start
              return { snippet: content.slice(charIdx), startLine: startLine + 1, endLine: lines.length };
            }
            let charIdxEnd = 0;
            for (let t = 0; t < nextStartLine; t++) {
              charIdxEnd += lines[t].length + 1;
            }
            return { snippet: content.slice(charIdx, charIdxEnd), startLine: startLine + 1, endLine: nextStartLine };
          }

          const snippetObj = extractGeneralSnippet(fileContent, general);
          const lineInfo = snippetObj.startLine > 0 ? `:${snippetObj.startLine}-${snippetObj.endLine}\n` : "";
          generalSourceCode = ret + `${path}` + lineInfo + `\n` + "--------------------------------------------\n\n" + snippetObj.snippet + "\n";
        }

        Repeater {
          model: root.general ? Lua.evaluate(`Fk.generals["${root.general}"]:getSkillNameList(true, true)`) : []

          ColumnLayout {
            Layout.fillWidth: true
            required property string modelData
            property string sourceCode

            W.ButtonContent {
              Layout.fillWidth: true
              Layout.preferredHeight: 27
              plainButton: false
              text: {
                const skill = parent.modelData;
                const skillTr = Lua.tr(skill);
                if (!enabled) {
                  return skillTr + " (源码不可用)";
                } else {
                  if (srcArea.text === "") {
                    return skillTr + " (点击查看源码)";
                  } else {
                    return skillTr + " (点击折叠)";
                  }
                }
              }

              enabled: {
                const skill = parent.modelData;
                return !!Lua.evaluate(`Fk.skill_skels["${skill}"].file_path`);
              }

              onClicked: {
                if (srcArea.text !== "") {
                  srcArea.text = "";
                } else {
                  if (!parent.sourceCode) parent.update();
                  srcArea.text = parent.sourceCode;
                }
              }
            }

            TextEdit {
              id: srcArea
              font.pixelSize: 12
              Layout.fillWidth: true
              font.family: "Consolas"
              readOnly: true
              wrapMode: Text.WrapAnywhere
              selectByKeyboard: true
              selectByMouse: false
              textFormat: Text.PlainText

              Component.onCompleted: {
                // 就目前而言只有使用Kde桌面的Linux用户才能体验到语法高亮功能！
                // 不过那个语法高亮库只依赖Qt库，理论上可以编译到游戏中，但是应该会很麻烦
                const component = Qt.createComponent("org.kde.syntaxhighlighting", "SyntaxHighlighter");
                if (component.status !== Component.Ready) {
                  console.warn("SyntaxHighlighter is not installed, syntax highlight feature disabled.");
                  return;
                }

                const highlighter = component.createObject(srcArea, {
                  textEdit: srcArea,
                  definition: "Lua",
                });
              }
            }

            function update() {
              const skill = modelData;
              let ret = "--------------------------------------------\n" +
              `--- 技能名：${Lua.tr(skill)}\n` +
              "--- 源码：";

              const path = Lua.evaluate(`Fk.skill_skels["${skill}"].file_path`);
              if (!path) {
                ret += "(不可用)\n" + "--------------------------------------------\n\n";
                sourceCode = ret;
                return;
              }
              const readFile = Lua.fn(`function(path)
                local f = io.open(path)
                local ret = f:read("a")
                return ret
              end`);
              sourceCode = ret +
              `${path}\n` + "--------------------------------------------\n\n"
              + readFile(path) + "\n";
            }
          }
        }
      }
      function update() {
        generalSrcArea.text = "";
        srcList.generalSourceCode = "";
      }
    }
  }

  Component {
    id: chechSkinsComponent
    GeneralSkinOverview {
      id: generalSkinOverview
      general: root.general
    }
  }

  ColumnLayout {
    width: parent.width - 40 - generalInfo.width
    height: parent.height - 10
    anchors.left: generalInfo.right
    anchors.leftMargin: 20
    y: 10

    SwipeView {
      id: detailSwipeView
      Layout.fillWidth: true
      Layout.fillHeight: true
      interactive: false
      currentIndex: drawerBar.currentIndex
      clip: true

      property alias drawer: drawerBar

      // 出于性能考虑，改为Loader延迟加载
      Loader {
        active: SwipeView.isCurrentItem
        sourceComponent: skillTextComponent
      }

      Loader {
        active: SwipeView.isCurrentItem
        sourceComponent: skillAudioComponent
      }

      Loader {
        active: SwipeView.isCurrentItem
        sourceComponent: statisticsComponent
      }

      Loader {
        active: SwipeView.isCurrentItem
        sourceComponent: sameGeneralsComponent
      }

      Loader {
        active: SwipeView.isCurrentItem
        sourceComponent: sourceCodeComponent
      }

      Loader {
        active: SwipeView.isCurrentItem
        sourceComponent: chechSkinsComponent
      }
    }

    W.ViewSwitcher {
      id: drawerBar
      Layout.alignment: Qt.AlignHCenter
      model: [
        Lua.tr("skill"),
        Lua.tr("Audio Text"),
        Lua.tr("General Statistics Overview"),
        Lua.tr("Other Same Name Generals"),
        Lua.tr("Skill Source Code"),
      ]
    }
  }
}
