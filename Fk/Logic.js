// SPDX-License-Identifier: GPL-3.0-or-later

/*
var generalsOverviewPage, cardsOverviewPage;
var clientPageCreated = false;
function createClientPages() {
  if (!clientPageCreated) {
    clientPageCreated = true;

    generalsOverviewPage = generalsOverview.createObject(mainWindow);
    cardsOverviewPage = cardsOverview.createObject(mainWindow);

    mainWindow.generalsOverviewPage = generalsOverviewPage;
    mainWindow.cardsOverviewPage = cardsOverviewPage;
  }
}
*/

var callbacks = {};

callbacks["ServerDetected"] = (j) => {
  const serverDialog = mainStack.currentItem.serverDialog;
  if (!serverDialog) {
    return;
  }
  const item = serverDialog.item;
  if (item) {
    // toast.show(qsTr("Detected Server %1").arg(j.slice(7)), 10000);
    item.addLANServer(j.slice(7))
  }
}

callbacks["GetServerDetail"] = (j) => {
  const [ver, icon, desc, capacity, count, addr] = JSON.parse(j);
  const serverDialog = mainStack.currentItem.serverDialog;
  if (!serverDialog) {
    return;
  }
  const item = serverDialog.item;
  if (item) {
    let [_addr, port] = addr.split(',');
    port = parseInt(port);
    item.updateServerDetail(_addr, port, [ver, icon, desc, capacity, count]);
  }
}

callbacks["ErrorMsg"] = (jsonData) => {
  let log;
  try {
    const a = JSON.parse(jsonData);
    log = qsTr(a[0]).arg(a[1]);
  } catch (e) {
    log = qsTr(jsonData);
  }

  console.log("ERROR: " + log);
  toast.show(log, 5000);
  mainWindow.busy = false;
}

callbacks["ErrorDlg"] = (jsonData) => {
  let log;
  try {
    const a = JSON.parse(jsonData);
    log = qsTr(a[0]).arg(a[1]);
  } catch (e) {
    log = qsTr(jsonData);
  }

  console.log("ERROR: " + log);
  Backend.showDialog("warning", log, jsonData);
  mainWindow.busy = false;
}

callbacks["UpdatePackage"] = (jsonData) => sheduled_download = jsonData;

callbacks["UpdateBusyText"] = (jsonData) => {
  mainWindow.busyText = jsonData;
}

callbacks["DownloadComplete"] = () => {
  mainWindow.busy = false;
  mainStack.currentItem.downloadComplete(); // should be pacman page
}

callbacks["SetDownloadingPackage"] = (name) => {
  const page = mainStack.currentItem;
  page.setDownloadingPackage(name);
}

callbacks["PackageDownloadError"] = (msg) => {
  const page = mainStack.currentItem;
  page.setDownloadError(msg);
}

callbacks["PackageTransferProgress"] = (data) => {
  const page = mainStack.currentItem;
  page.showTransferProgress(data);
}

callbacks["BackToStart"] = (jsonData) => {
  while (mainStack.depth > 1) {
    mainStack.pop();
  }

  tryUpdatePackage();
}

callbacks["SetServerSettings"] = (data) => {
  const [ motd, hiddenPacks, enableBots ] = data;
  config.serverMotd = motd;
  config.serverHiddenPacks = hiddenPacks;
  config.serverEnableBot = enableBots;
};

callbacks["EnterLobby"] = (jsonData) => {
  // depth == 1 means the lobby page is not present in mainStack
  // createClientPages();
  if (mainStack.depth === 1) {
    // we enter the lobby successfully, so save password now.
    config.lastLoginServer = config.serverAddr;
    // config.savedPassword[config.serverAddr] = {
    //   username: config.screenName,
    //   password: config.cipherText,
    //   key: config.aeskey,
    //   shorten_password: config.cipherText.slice(0, 8)
    // }
    mainStack.push(lobby);
  } else {
    mainStack.pop();
  }
  mainWindow.busy = false;
  ClientInstance.notifyServer("RefreshRoomList", "");
  config.saveConf();
}

callbacks["EnterRoom"] = (data) => {
  // jsonData: int capacity, int timeout
  config.roomCapacity = data[0];
  config.roomTimeout = data[1] - 1;
  const roomSettings = data[2];
  config.enableFreeAssign = roomSettings.enableFreeAssign;
  config.heg = roomSettings.gameMode.includes('heg_mode');
  mainStack.push(room);
  mainWindow.busy = false;
}

callbacks["UpdateRoomList"] = (data) => {
  const current = mainStack.currentItem;  // should be lobby
  if (mainStack.depth === 2) {
    current.roomModel.clear();
    const filtering = current.filtering;
    data.forEach(room => {
      const [roomId, roomName, gameMode, playerNum, capacity, hasPassword,
        outdated] = room;
      if (filtering) { // 筛选
        const f = config.preferredFilter;
        if ((f.name !== '' && !roomName.includes(f.name))
          || (f.id !== '' && !roomId.toString().includes(f.id))
          || (f.modes.length > 0 && !f.modes.includes(luatr(gameMode)))
          || (f.full !== 2 &&
            (f.full === 0 ? playerNum < capacity : playerNum >= capacity))
          || (f.hasPassword !== 2 &&
            (f.hasPassword === 0 ? !hasPassword : hasPassword))
          // || (capacityList.length > 0 && !capacityList.includes(capacity))
        ) return;
      }
      current.roomModel.append({
        roomId, roomName, gameMode, playerNum, capacity,
        hasPassword, outdated,
      });
    });
    current.filtering = false;
  }
}

callbacks["UpdatePlayerNum"] = (data) => {
  const current = mainStack.currentItem;  // should be lobby
  if (mainStack.depth === 2) {
    const l = data[0];
    const s = data[1];
    current.lobbyPlayerNum = l;
    current.serverPlayerNum = s;
  }
}

callbacks["Chat"] = (data) => {
  // jsonData: { string userName, string general, string time, string msg }
  const current = mainStack.currentItem;  // lobby or room
  const pid = data.sender;
  const userName = data.userName;
  const general = luatr(data.general);
  const time = data.time;
  const msg = data.msg;

  if (config.blockedUsers.indexOf(userName) !== -1) {
    return;
  }

  let text;
  if (general === "")
    text = `<font color="#3598E8">[${time}] ${userName}:</font> ${msg}`;
  else
    text = `<font color="#3598E8">[${time}] ${userName}` +
           `(${general}):</font> ${msg}`;
  current.addToChat(pid, data, text);
}

callbacks["ServerMessage"] = (jsonData) => {
  const current = mainStack.currentItem;  // lobby or room
  current.sendDanmaku('<font color="grey"><b>[Server] </b></font>' + jsonData);
}

callbacks["ShowToast"] = (j) => toast.show(j);

callbacks["AddTotalGameTime"] = (jsonData) => {
  config.totalTime++;
}
