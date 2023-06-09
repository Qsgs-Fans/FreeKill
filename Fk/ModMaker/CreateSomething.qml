import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
  id: root
  anchors.fill: parent
  anchors.margins: 16
  signal finished()
  signal accepted(string result)

  property string head
  property string hint

  Text {
    text: qsTr(head)
    font.pixelSize: 20
    font.bold: true
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
  }

  Text {
    text: qsTr(hint)
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
  }

  Text {
    text: qsTr("validator_hint")
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
  }

  TextField {
    id: edit
    font.pixelSize: 18
    Layout.fillWidth: true
    validator: RegularExpressionValidator { regularExpression: /[0-9A-Za-z_]+/ }
  }

  Button {
    text: "OK"
    enabled: edit.text.length >= 4
    onClicked: {
      accepted(edit.text);
      finished();
    }
  }
}
