import QtQuick
import Fk

Image {
  property string general

  width: 64
  height: 64
  source: SkinBank.getGeneralExtraPic(general, "avatar/")
          ?? SkinBank.getGeneralPicture(general)
  // sourceSize.width: 250
  // sourceSize.height: 292
  property bool useSmallPic: !!SkinBank.getGeneralExtraPic(general, "avatar/")
  sourceClipRect: useSmallPic ? undefined : Qt.rect(61, 0, 128, 128)

  Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.width: 1
  }
}
