import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import Fk.Components.Common

Item {
  id: root

  ListModel { id: generals }
  property int pastNDays: -1
  property list<string> generalFilter: []
  // 是否合并mode和role的查询结果
  property bool mergeMode: true
  property bool mergeRole: false

  function query() {
    const addr = ClientInstance.peerAddress();
    let query = `SELECT general, mode, role,
    COUNT(CASE result WHEN 1 THEN 1 END) AS win,
    COUNT(CASE result WHEN 2 THEN 1 END) AS lose,
    COUNT(CASE result WHEN 3 THEN 1 END) AS draw,
    COUNT() AS total,
    ROUND(COUNT(CASE result WHEN 1 THEN 1 END) * 1.0 / COUNT() * 100, 2) AS winRate
    FROM myGameData WHERE pid = ${Self.id} AND server_addr = '${addr}'`;

    if (generalFilter.length !== 0) {
      query += ' AND (';
      query += generalFilter.map(e => `general = '${e}'`).join(" OR ");
      query += ')';
    }

    if (!mergeMode || generalFilter.length > 0) {
      query += " GROUP BY";
      if (!mergeMode) {
        query += " mode,";
      }
      if (!mergeRole) {
        query += " role,";
      }
      if (generalFilter.length > 0) {
        query += " general,";
      }
      query = query.slice(0, -1);
    }
    query += " ORDER BY id;";

    model.clear();
    model.append({
      general: Lua.tr("General"),
      mode: Lua.tr("Game Mode"),
      role: Lua.tr("role"),
      win: Lua.tr("Game Win"),
      lose: Lua.tr("Game Lose"),
      draw: Lua.tr("Game Draw"),
      total: Lua.tr("Total"),
      winRate: Lua.tr("Win Rate"),
    });
    const result = Cpp.sqlquery(query);
    result.forEach(e => model.append(e));
  }

  Rectangle {
    id: queryResultList
    width: parent.width - operatePanel.width - 20
    height: parent.height - 20
    y: 10
    color: "#A0EFEFEF"
    radius: 8
    clip: true

    Text {
      text: ""
    }

    ListView {
      id: resultList
      clip: true
      anchors.fill: parent
      model: ListModel {
        id: model
      }
      delegate: RowLayout {
        width: resultList.width
        height: 36

        Text {
          Layout.preferredWidth: 120
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 18
          font.bold: index === 0
          text: {
            if (mergeMode) {
              return '-';
            }
            return Lua.tr(mode);
          }
        }
        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true
          property string g: general
          Avatar {
            id: avatar
            height: 32
            width: 32
            visible: generalFilter.length > 0 && index !== 0
            general: {
              if (generalFilter.length === 0) {
                return 'diaochan';
              }
              return parent.g;
            }
          }
          Text {
            anchors.left: avatar.right
            anchors.leftMargin: 4
            font.pixelSize: 20
            font.bold: index === 0
            horizontalAlignment: Text.AlignHCenter
            text: {
              if (generalFilter.length === 0) {
                return '-';
              }
              return Lua.tr(general);
            }
          }
        }
        Text {
          Layout.preferredWidth: 50
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 20
          font.bold: index === 0
          text: {
            if (mergeMode || mergeRole) {
              return '-';
            }
            return Lua.tr(role);
          }
        }
        Text {
          Layout.preferredWidth: 50
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 20
          font.bold: index === 0
          text: win
        }
        Text {
          Layout.preferredWidth: 50
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 20
          font.bold: index === 0
          text: lose
        }
        Text {
          Layout.preferredWidth: 50
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 20
          font.bold: index === 0
          text: draw
        }
        Text {
          Layout.preferredWidth: 50
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 20
          font.bold: index === 0
          text: total
        }
        Text {
          Layout.preferredWidth: 50
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 20
          font.bold: index === 0
          text: winRate
        }
      }
    }
  }

  Rectangle {
    id: operatePanel
    width: 310
    height: parent.height - 20
    y: 10
    anchors.right: parent.right
    anchors.rightMargin: 10
    color: "#88EEEEEE"
    radius: 8

    ColumnLayout {
      id: detailLayout
      width: parent.width
      height: parent.height

      Switch {
        text: Lua.tr("Merge Modes") // 检索时不区分游戏模式
        checked: root.mergeMode
        onCheckedChanged: {
          root.mergeMode = checked;
          root.query();
        }
      }

      Switch {
        text: Lua.tr("Merge Roles") // "检索时不区分身份"
        enabled: !root.mergeMode
        checked: root.mergeRole
        onCheckedChanged: {
          root.mergeRole = checked;
          root.query();
        }
      }

      GridView {
        model: generals
        cellWidth: parent.width / 2
        cellHeight: 26
        clip: true
        Layout.fillWidth: true
        Layout.fillHeight: true
        delegate: CheckBox {
          text: {
            const prefix = general.split("__")[0];
            let name = Lua.tr(general);
            if (prefix !== general) {
              name += (" (" + Lua.tr(prefix) + ")");
            }
            return name;
          }
          checked: root.generalFilter.includes(general)
          onCheckedChanged: {
            if (checked) {
              root.generalFilter.push(general);
            } else {
              root.generalFilter.splice(root.generalFilter.indexOf(general), 1);
            }
            root.query();
          }
        }
      }
    }
  }

  Component.onCompleted: {
    const addr = ClientInstance.peerAddress();
    Cpp.sqlquery(`SELECT general FROM myGameData WHERE pid = ${Self.id} AND
      server_addr = '${addr}' GROUP BY general ORDER BY id;`)
    .forEach(e => generals.append({ general: e.general }));
    query();
  }
}
