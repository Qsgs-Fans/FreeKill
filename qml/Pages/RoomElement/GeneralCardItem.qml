import QtQuick
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
  property int maxHp
  property string pkgName: ""
  name: ""
  // description: Sanguosha.getGeneralDescription(name)
  suit: ""
  number: 0
  footnote: ""
  card.source: SkinBank.getGeneralPicture(name)
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
      model: (hp > 5 || hp !== maxHp) ? 1 : hp
      Image {
        source: SkinBank.GENERALCARD_DIR + kingdom + "-magatama"
      }
    }

    Text {
      visible: hp > 5 || hp !== maxHp
      text: hp === maxHp ? ("x" + hp) : (" " + hp + "/" + maxHp)
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
    visible: Backend.translate(name).length <= 6
    color: "white"
    font.family: fontLibian.name
    font.pixelSize: 18
    lineHeight: Math.max(1.4 - lineCount / 10, 0.6)
    style: Text.Outline
    wrapMode: Text.WrapAnywhere
  }

  Text {
    x: 0
    y: 12
    rotation: 90
    transformOrigin: Item.BottomLeft
    text: Backend.translate(name)
    visible: Backend.translate(name).length > 6
    color: "white"
    font.family: fontLibian.name
    font.pixelSize: 18
    style: Text.Outline
  }

  Rectangle {
    visible: pkgName !== ""
    height: 16
    width: childrenRect.width + 4
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 4
    anchors.right: parent.right
    anchors.rightMargin: 4

    color: "#3C3229"
    opacity: 0.8
    radius: 4
    border.color: "white"
    border.width: 1
    Text {
      text: Backend.translate(pkgName)
      x: 2; y: 1
      font.family: fontLibian.name
      font.pixelSize: 14
      color: "white"
      style: Text.Outline
      textFormat: Text.RichText
    }
  }

  onNameChanged: {
    let data = JSON.parse(Backend.callLuaFunction("GetGeneralData", [name]));
    kingdom = data.kingdom;
    hp = data.hp;
    maxHp = data.maxHp;

    let splited = name.split("__");
    if (splited.length > 1) {
      pkgName = splited[0];
    } else {
      pkgName = "";
    }
  }
}
