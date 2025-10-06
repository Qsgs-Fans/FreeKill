// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk

Item {
  property string source: ""
  property int currentFrame: 0
  property alias interval: timer.interval
  property int loadedFrameCount: 0
  property bool autoStart: false
  property bool loop: false
  property bool keepAtStop: false
  property alias running: timer.running

  signal loaded()
  signal started()
  signal finished()

  id: root
  width: childrenRect.width
  height: childrenRect.height

  property string folder: source
  property int fileModel

  Repeater {
    id: frames
    model: fileModel

    Image {
      source: root.source + "/" + index
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
    if (autoStart) {
      root.started();
      timer.start();
    }
  }

  Timer {
    id: timer
    interval: 50
    repeat: true
    onTriggered: {
      if (currentFrame >= fileModel) {
        if (!keepAtStop) {
          frames.itemAt(fileModel - 1).visible = false;
        }
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
      root.started();
      timer.start();
    } else {
      root.loaded.connect(() => {
        root.started();
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
