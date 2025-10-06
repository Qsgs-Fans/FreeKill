// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk

Item {
  id: root
  height: 15
  property string skillname: "zhiheng"
  property string skilltype: "limit" // limit, wake, ...
  property int usedtimes: -1 // -1 will not be shown
  // visible: false

  Image {
    id: bg
    source: SkinBank.limitSkillDir + skilltype
    height: 47 * 0.45
    width: 87 * 0.45
  }

  Text {
    anchors.centerIn: bg
    color: "#F0E5DA"
    font.pixelSize: 15
    font.family: Config.li2Name
    style: Text.Outline
    styleColor: "#3D2D1C"
    text: Lua.tr(skillname);
  }

  Text {
    id: x
    opacity: (skilltype === "limit" || skilltype === "quest") ? 1 : 0
    text: "X"
    font.family: Config.libianName
    font.pixelSize: 28
    color: "red"
    x: 26
  }

  onSkillnameChanged: {
    let data = Lua.call("GetSkillData", skillname);
    if (data.frequency || data.switchSkillName) {
      skilltype = data.switchSkillName ? 'switch' : data.frequency;
      visible = true;
    } else {
      visible = false;
    }
  }

  onUsedtimesChanged: {
    x.visible = false;
    visible = false;
    if (usedtimes > -1) {
      visible = true;
    }
    if (skilltype === "wake") {
      visible = (usedtimes > 0);
    } else if (skilltype === "limit") {
      if (usedtimes >= 1) {
        x.visible = true;
        bg.source = SkinBank.limitSkillDir + "limit-used";
      } else {
        x.visible = false;
        bg.source = SkinBank.limitSkillDir + "limit";
      }
    } else if (skilltype === 'switch') {
      bg.source = SkinBank.limitSkillDir +
        (usedtimes < 1 ? 'switch' : 'switch-yin');
    } else if (skilltype === 'quest') {
      if (usedtimes > 1) {
        x.visible = true;
        bg.source = SkinBank.limitSkillDir + "limit-used";
      }
    }
  }
}
