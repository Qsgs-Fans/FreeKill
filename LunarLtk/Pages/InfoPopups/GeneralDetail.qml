// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import LunarLtk
import LunarLtk.Components

Flickable {
  id: root
  anchors.fill: parent

  property list<string> generals

  signal finish()

  contentHeight: details.height
  ScrollBar.vertical: ScrollBar {}

  ColumnLayout {
    id: details
    width: parent.width - 40
    x: 20

    Flickable {
      width: parent.width
      height: parent.height
      contentHeight: skillDesc.height
      ScrollBar.vertical: ScrollBar {}
      DescriptionText {
        id: skillDesc
        color: "#E4D5A0"
        width: parent.width
        text: root.getGeneralDescText();
      }
    }
  }

  function getGeneralDescText() {
    let desc = "";
    generals.forEach((g) => {
      const data = Ltk.getGeneralDetail(g);
      desc += Lua.tr(data.kingdom) + " " + Lua.tr(g) + " " + (data.hp === data.maxHp
        ? ((g.startsWith('hs__') || g.startsWith('ld__') || g.includes('heg__'))
          ? ((data.mainMaxHp != 0 || data.deputyMaxHp != 0)
            ? ((data.hp + data.mainMaxHp) / 2 + '/' + (data.hp + data.deputyMaxHp) / 2)
            : data.hp / 2)
          : data.hp)
        : data.hp + "/" + data.maxHp) + "<br/>";
      if (data.headnote !== "") desc += "<font color=\"lightslategrey\">" + Lua.tr(data.headnote) + "</font><br/>";
      if (data.companions.length > 0){
        let ret = '';
        ret +="<font color=\"slategrey\"><b>" + Lua.tr("Companions") + "</b>: ";
        data.companions.forEach(t => {
          ret += Lua.tr(t) + ' '
        });
        ret += "</font><br/>";
        desc += ret
      }
      data.skill.forEach(t => {
        desc += (t.is_related_skill ? "<font color=\"purple\"><b>" : "<b>") + Lua.tr(t.name) +
          "</b>: " + t.description + (t.is_related_skill ? "</font>" : "") + "<br/>";
      });
      if (data.endnote !== "") desc += "<font color=\"lightslategrey\">" + Lua.tr(data.endnote) + "</font><br/>";
      desc += "<br/>";
    });
    return desc;
  }
}
