pragma Singleton
import QtQuick
import Fk

// 一些Qml代码可能常用到的封装函数 省得写一堆notify

QtObject {
  function enterNewPage(uri, name, prop) {
    const component = Qt.createComponent(uri, name);
    Mediator.notify(null, Command.PushPage, {
      component,
      prop,
    });
  }

  function changeRoomPage(data) {
    let c;
    if (!(data instanceof Object)) {
      c = Qt.createComponent("Fk.Pages.LunarLTK", "Room");
    } else {
      if (data.uri && data.name) {
        // TODO 还不可用，需要让Lua能添加import path
        c = Qt.createComponent(data.uri, data.name);
      } else {
        c = Qt.createComponent(Cpp.path + "/" + data.url);
      }
    }

    Mediator.notify(null, Command.ChangeRoomPage, c);
  }

  function quitPage() {
    Mediator.notify(null, Command.PopPage, null);
  }

  function showToast(s: string) {
    Mediator.notify(null, Command.ShowToast, s);
  }

  function setBusy(v: bool) {
    Mediator.notify(null, Command.SetBusyUI, v);
  }
}
