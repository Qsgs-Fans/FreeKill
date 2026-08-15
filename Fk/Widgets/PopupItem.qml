import QtQuick
import QtQuick.Controls
import Fk

// 由于Loader太烂，改为基于Qt.createComponent流程展示动态对象。

Popup {
  id: root

  property Item item

  clip: true
  padding: 4 * Config.winScale

  background: Rectangle {
    color: "#FAFAFB"
    radius: 5
    border.color: "#E7E7E8"
    border.width: 1
  }

  contentItem: Item {
    Item {
      id: container

      width: parent.width / Config.winScale
      height: parent.height / Config.winScale
      scale: Config.winScale
      transformOrigin: Item.TopLeft
      clip: true
    }
  }

  onClosed: {
    item.destroy();
    item = null;
  }

  // 辣鸡Qt这么一个破函数还跳票到6.14发布明明说了6.11就发我等了两年啊两年！
  function setSourceComponent(component, prop) {
    if (item) {
      item.destroy();
      item = null;
    }

    item = component.createObject(container, prop);
    item.finish?.connect(close);
  }
}
