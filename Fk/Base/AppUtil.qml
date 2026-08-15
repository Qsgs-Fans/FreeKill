pragma Singleton
import QtQuick
import Fk

// 一些Qml代码可能常用到的封装函数 省得写一堆notify

QtObject {
  function enterNewPage(component, prop) {
    Mediator.notify(null, Command.PushPage, {
      component,
      prop,
    });
  }

  function changeRoomPage(data) {
    let c;
    if (!(data instanceof Object)) {
      c = Qt.createComponent("LunarLtk.Pages", "Room");
    } else {
      c = Lua.createComponent(data);
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
