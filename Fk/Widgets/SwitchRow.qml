import QtQuick
import QtQuick.Controls

ActionRow {
  id: root

  // 继承自button，已经有checked属性了

  suffixComponent: Switch {
    checked: root.checked
    onCheckedChanged: root.checked = checked
  }

  onClicked: {
    checked = !checked;
  }
}

