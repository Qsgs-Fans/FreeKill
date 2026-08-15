import QtQuick

import Fk
import Fk.Widgets as W
import LunarLtk

Rectangle {
  id: root

  required property PhotoModel dataModel

  color: "#CC2E2C27"
  radius: 6
  border.color: "#A6967A"
  border.width: 1
  width: 44
  height: 112

  visible: {
    if (root.dataModel.playerid === Cpp.self.id) return false;
    if (root.dataModel.handcards.length === 0) return false; // 优先绑定再判buddy，否则不会更新
    if (!Lua.selfPlayer.isBuddy(root.dataModel.luaPlayer) &&
    !Ltk.hasVisibleCard(Cpp.self.id, root.dataModel.playerid)) return false;
    return true;
  }

  Text {
    x: 2; y: 2
    width: 42
    text: {
      if (!parent.visible) return "";
      const ids = root.dataModel.handcards;
      const txt = [];
      for (const cid of ids) {
        if (txt.length >= 4) {
          txt.push("...");
          break;
        }
        if (!Lua.selfPlayer.cardVisible(cid)) continue;
        const data = Ltk.getCardData(cid, true);
        let a = Lua.tr(data.name);
         if (a.length >= 2) {
           a = a.slice(0, 2);
         }
         txt.push(a);
       }

       if (txt.length < 5) {
         const unknownCards = ids.length - txt.length;
         for (let i = 0; i < unknownCards; i++) {
           if (txt.length >= 4) {
             txt.push("...");
             break;
           } else {
             txt.push("?");
           }
         }
       }

       return txt.join("<br>");
     }
     color: "#E4D5A0"
     font.family: Config.libianName
     font.pixelSize: 18
     textFormat: Text.RichText
     horizontalAlignment: Text.AlignHCenter
   }

   W.TapHandler {
     onTapped: {
       const params = { name: "hand_card" };
       let data = root.dataModel.handcards;
       data = data.filter((e) => Lua.selfPlayer.cardVisible(e));

       params.ids = data;

       // Just for using room's right drawer
       roomScene.showInfoPopup(Qt.createComponent("LunarLtk.Pages.InfoPopups", "ViewPile"), params);
     }
   }
 }
