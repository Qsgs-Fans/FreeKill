import QtQuick

Item {
  id: root
  anchors.fill: parent
  property var extra_data: ({})
  signal finish()

  // TODO: complete this ......
  Text {
    anchors.fill: parent
    text: JSON.stringify(extra_data)
  }
}
