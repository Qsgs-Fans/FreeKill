import QtQuick
import QtQuick.Controls

ActionRow {
  id: root

  property int from
  property int to
  property int value

  suffixComponent: Slider {
    from: root.from
    to: root.to
    value: root.value

    onValueChanged: root.value = value
  }
}