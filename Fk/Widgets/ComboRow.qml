import QtQuick
import QtQuick.Controls

ActionRow {
  id: root

  property var model
  property var currentValue
  // property var currentIndex
  property string textRole

  suffixComponent: ComboBox {
    model: root.model
    editable: false
    textRole: root.textRole

    background: Rectangle {
      color: "transparent"
      implicitHeight: root.height - 16
      implicitWidth: 120
    }

    onCurrentIndexChanged: root.currentValue = model.get(currentIndex);
  }

  function setCurrentIndex(idx) {
    suffixLoader.item.currentIndex = idx;
  }

  onClicked: {
    const cbox = root.suffixLoader.item;
    cbox.popup.open()
  }
}


