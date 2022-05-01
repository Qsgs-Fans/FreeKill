import QtQuick 2.15
import "../skin-bank.js" as SkinBank

/* Layout of general card:
 *      +--------+
 *kindom|wu  9999| <- hp
 *name -|s       |
 *      |q img   |
 *      |        |
 *      |        |
 *      +--------+
 * Inherit from CardItem to use common signal
 */

CardItem {
  property string kingdom
  property int hp
  name: ""
  // description: Sanguosha.getGeneralDescription(name)
  suit: ""
  number: 0
  footnote: ""
  card.source: SkinBank.GENERAL_DIR + name
  glow.color: "white" //Engine.kingdomColor[kingdom]

  Image {
    source: SkinBank.GENERALCARD_DIR + "border"
  }

  Image {
    source: SkinBank.GENERALCARD_DIR + kingdom
  }

  Row {
    x: 34
    y: 4
    spacing: 1
    Repeater {
      model: hp > 5 ? 1 : hp
      Image {
        source: SkinBank.GENERALCARD_DIR + kingdom + "-magatama"
      }
    }

    Text {
      visible: hp > 5
      text: "x" + hp
      color: "white"
      font.pixelSize: 14
      style: Text.Outline
      y: -6
    }
  }

  Text {
    width: 20
    height: 80
    x: 2
    y: lineCount > 6 ? 30 : 34
    text: Backend.translate(name)
    color: "white"
    font.family: "LiSu"
    font.pixelSize: 18
    lineHeight: Math.max(1.4 - lineCount / 10, 0.6)
    style: Text.Outline
    wrapMode: Text.WrapAnywhere
  }

  onNameChanged: {
    let data = JSON.parse(Backend.callLuaFunction("GetGeneralData", [name]));
    kingdom = data.kingdom;
    hp = data.hp;
  }
}
