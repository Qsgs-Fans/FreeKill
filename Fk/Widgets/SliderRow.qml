import QtQuick
import QtQuick.Controls

ActionRow {
  id: root

  property real from
  property real to
  property real value

  suffixComponent: Slider {
    from: root.from
    to: root.to
    value: root.value

    onValueChanged: root.value = value
  }
}
