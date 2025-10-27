import QtQuick
import QtQuick.Controls

import Fk

ActionRow {
  id: root

  property var model
  property string value
  // property var currentIndex

  onValueChanged: {
    setCurrentIndex(model.indexOf(value));
  }

  suffixComponent: ComboBox {
    id: combo
    model: root.model
    editable: false
    displayText: Lua.tr(currentText)

    background: Rectangle {
      color: "transparent"
      implicitHeight: root.height - 16
      implicitWidth: 120
    }

    popup: Popup {
      y: combo.height - 1
      width: combo.width
      height: Math.min(contentItem.implicitHeight, combo.Window.height - topMargin - bottomMargin)
      padding: 1

      contentItem: ListView {
        clip: true
        implicitHeight: contentHeight
        model: combo.popup.visible ? combo.delegateModel : null
        currentIndex: combo.highlightedIndex

        delegate: ItemDelegate {
          width: combo.width
          text: Lua.tr(modelData)
        }

        ScrollIndicator.vertical: ScrollIndicator { }
      }

      background: Rectangle {
        border.color: "#21be2b"
        radius: 2
      }
    }

    onCurrentIndexChanged: {
      root.value = model[currentIndex];
    }
  }

  function setCurrentIndex(idx) {
    if (suffixLoader.item) {
      suffixLoader.item.currentIndex = idx;
    }
  }

  onClicked: {
    const cbox = root.suffixLoader.item;
    cbox.popup.open()
  }
}
