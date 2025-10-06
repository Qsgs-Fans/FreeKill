import QtQuick

// 是对所有页面共同点的提取
// 即，所有页面都必须处理callback
//
// 之前的设计func(data)的函数里面涉及调页面的全局变量
// 需要去耦合，也就是改成func(page, data)

Item {
  id: root

  QtObject {
    id: priv
    property var callbacks: ({})
  }

  function addCallback(cmd, f) {
    priv.callbacks[cmd] = f;
  }

  function canHandleCommand(cmd) {
    return cmd in priv.callbacks;
  }

  function handleCommand(sender, cmd, data) {
    priv.callbacks[cmd](sender, data);
  }
}
