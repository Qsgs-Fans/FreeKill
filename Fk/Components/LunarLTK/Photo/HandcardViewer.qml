import QtQuick

import Fk
import Fk.Widgets as W
import Fk.Components.LunarLTK

Rectangle {
  id: root

  color: "#CC2E2C27"
  radius: 6
  border.color: "#A6967A"
  border.width: 1
  width: 44
  height: 112

  property int playerid
  property int handcards

  Text {
    x: 2; y: 2
    width: 42
    text: {
      if (!parent.visible) return "";
      const unused = root.handcards; // 绑定
      const ids = Ltk.getPlayerHandcards(root.playerid);
      const txt = [];
      for (const cid of ids) {
        if (txt.length >= 4) {
          // txt.push("&nbsp;&nbsp;&nbsp;...");
          txt.push("...");
          break;
        }
        if (!Ltk.cardVisibility(cid)) continue;
        const data = Ltk.getCardData(cid, true);
        let a = Lua.tr(data.name);
        /* if (a.length === 1) {
           a = "&nbsp;&nbsp;" + a;
         } else  */
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
       let data = Ltk.getPlayerHandcards(root.playerid);
       data = data.filter((e) => Ltk.cardVisibility(e));

       params.ids = data;

       // Just for using room's right drawer
       roomScene.startCheat("ViewPile", params);
     }
   }
 }
