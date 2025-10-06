import QtQuick

import Fk

Image {
  id: root

  width: 64
  height: 64
  source: SkinBank.getGeneralExtraPic(general, "avatar/")
          ?? SkinBank.getGeneralPicture(general)
  // sourceSize.width: 250
  // sourceSize.height: 292
  sourceClipRect: useSmallPic ? undefined : Qt.rect(61, 20, 128, 128)
  clip: true

  property string general
  property string pkgName: {
    const splited = general.split('__')[0];
    if (splited == general) return "";
    return splited;
  }
  property bool useSmallPic: !!SkinBank.getGeneralExtraPic(general, "avatar/")
  property bool detailed: false

  Rectangle {
    visible: root.detailed && pkgName !== ""
    anchors.top: parent.top
    anchors.left: parent.left
    height: 16
    width: childrenRect.width + 4
    color: "#3C3229"
    opacity: 0.8

    Text {
      text: Lua.tr(pkgName)
      x: 2; y: 1
      font.family: Config.libianName
      font.pixelSize: 14
      color: "white"
      style: Text.Outline
      textFormat: Text.RichText
    }
  }

  Rectangle {
    visible: root.detailed
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    height: 16
    width: childrenRect.width + 4
    color: "snow"
    opacity: 0.8

    Text {
      text: Lua.tr(root.general)
      x: 2; y: 1
      font.family: Config.libianName
      font.pixelSize: 14
      color: "black"
      textFormat: Text.RichText
    }
  }

  Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.width: 1
  }
}
