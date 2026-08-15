pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

ActionRow {
  id: root

  // 继承自button，已经有checked属性了
  property alias value: root.checked

  suffixComponent: Switch {
    checked: root.enabled ? root.checked : false
    onCheckedChanged: root.checked = root.enabled ? checked : false
  }

  onClicked: {
    root.checked = !root.checked;
  }

  onEnabledChanged: {
    root.checked = false;
  }
}

