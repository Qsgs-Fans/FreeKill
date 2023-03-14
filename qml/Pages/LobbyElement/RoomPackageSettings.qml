import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
  id: root
  flickableDirection: Flickable.AutoFlickIfNeeded

  ColumnLayout {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.topMargin: 8
    anchors.leftMargin: 8

    // CheckBox {
    //   text: "禁用Lua拓展 (重启后生效)"
    // }

    Text {
      text: "General Packages"
    }

    Text {
      text: "Card Packages"
    }
  }
  
  Component.onCompleted: {
    ;
  }
}
