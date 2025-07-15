import QtQuick
import QtQuick.Controls

ActionRow {
  id: root

  property bool editable: false
  property int from
  property int to
  property int value

  suffixComponent: SpinBox {
    editable: root.editable
    from: root.from
    to: root.to
    value: root.value

    onValueChanged: root.value = value

    background: Rectangle {
      color: "transparent"
      implicitHeight: root.height - 16
      implicitWidth: 120
    }

    /* Connections {
      target: root
      function onFromChanged() {
        from = root.from;
      }
      function onToChanged() {
        to = root.to;
      }
    } */
  }

  onClicked: {
    if (!root.editable) return;
  }
}


