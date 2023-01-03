import QtQuick
import "../skin-bank.js" as SkinBank

Item {
  property string source: ""
  property int currentFrame: 0
  property alias interval: timer.interval
  property int loadedFrameCount: 0
  property bool autoStart: false
  property bool loop: false

  signal loaded()
  signal started()
  signal finished()

  id: root
  width: childrenRect.width
  height: childrenRect.height

  property string folder: SkinBank.PIXANIM_DIR + source
  property int fileModel

  Repeater {
    id: frames
    model: fileModel

    Image {
      source: SkinBank.PIXANIM_DIR + root.source + "/" + index
      visible: false
      onStatusChanged: {
        if (status == Image.Ready) {
          loadedFrameCount++;
          if (loadedFrameCount == fileModel)
            root.loaded();
        }
      }
    }
  }

  onLoaded: {
    if (autoStart)
      timer.start();
  }

  Timer {
    id: timer
    interval: 50
    repeat: true
    onTriggered: {
      if (currentFrame >= fileModel) {
        frames.itemAt(fileModel - 1).visible = false;
        if (loop) {
          currentFrame = 0;
        } else {
          timer.stop();
          root.finished();
          return;
        }
      }

      if (currentFrame > 0)
        frames.itemAt(currentFrame - 1).visible = false;
      frames.itemAt(currentFrame).visible = true;

      currentFrame++;
    }
  }

  function start()
  {
    if (loadedFrameCount == fileModel) {
      timer.start();
    } else {
      root.loaded.connect(function(){
        timer.start();
      });
    }
  }

  function stop()
  {
    timer.stop();
  }

  Component.onCompleted: {
    fileModel = Backend.ls(folder).length;
  }
}
