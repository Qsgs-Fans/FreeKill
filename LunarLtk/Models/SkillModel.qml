import QtQuick
import Fk
import LunarLtk

QtObject {
  id: root

  property string name: "仁德"
  property string origName: "rende"

  property bool isActive: false
  property string frequency

  property string extension

  property bool isPrelight: false // 预亮按钮
  property bool prelighted: false // 已预亮
  property bool nullified: false // 被失效了？失效的话一般会显示锁

  property int times: -1

  property bool enabled
  property bool selected

  onEnabledChanged: {
    if (!enabled) selected = false;
  }
}
