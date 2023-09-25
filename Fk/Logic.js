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
let sheduled_download = "";

callbacks["ServerDetected"] = (j) => {
  const serverDialog = mainStack.currentItem.serverDialog;
  if (!serverDialog) {
    return;
  }
  const item = serverDialog.item;
  if (item) {
    toast.show(qsTr("Detected Server %1").arg(j.slice(7)), 10000);
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
    item.updateServerDetail(addr, [ver, icon, desc, capacity, count]);
  }
}

callbacks["NetworkDelayTest"] = (jsonData) => {
  // jsonData: RSA pub key
  let cipherText;
  let aeskey;
  if (config.savedPassword[config.serverAddr] !== undefined
    && config.savedPassword[config.serverAddr].shorten_password === config.password) {
    cipherText = config.savedPassword[config.serverAddr].password;
    aeskey = config.savedPassword[config.serverAddr].key;
    config.aeskey = aeskey ?? "";
    Backend.setAESKey(aeskey);
    if (Debugging)
      console.log("use remembered password", config.password);
  } else {
    cipherText = Backend.pubEncrypt(jsonData, config.password);
    config.aeskey = Backend.getAESKey();
  }
  config.cipherText = cipherText;
  Backend.replyDelayTest(config.screenName, cipherText);
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
  if (sheduled_download !== "") {
    mainWindow.busy = true;
    Pacman.loadSummary(sheduled_download, true);
    sheduled_download = "";
  }
}

callbacks["UpdatePackage"] = (jsonData) => sheduled_download = jsonData;

callbacks["UpdateBusyText"] = (jsonData) => {
  mainWindow.busyText = jsonData;
}

callbacks["DownloadComplete"] = () => {
  mainWindow.busy = false;
  mainStack.currentItem.downloadComplete(); // should be pacman page
}

callbacks["BackToStart"] = (jsonData) => {
  while (mainStack.depth > 1) {
    mainStack.pop();
  }
}

callbacks["SetServerSettings"] = (j) => {
  const data = JSON.parse(j);
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
    config.savedPassword[config.serverAddr] = {
      username: config.screenName,
      password: config.cipherText,
      key: config.aeskey,
      shorten_password: config.cipherText.slice(0, 8)
    }
    mainStack.push(lobby);
  } else {
    mainStack.pop();
  }
  mainWindow.busy = false;
  ClientInstance.notifyServer("RefreshRoomList", "");
  config.saveConf();
}

callbacks["EnterRoom"] = (jsonData) => {
  // jsonData: int capacity, int timeout
  const data = JSON.parse(jsonData);
  config.roomCapacity = data[0];
  config.roomTimeout = data[1] - 1;
  const roomSettings = data[2];
  config.enableFreeAssign = roomSettings.enableFreeAssign;
  config.heg = roomSettings.gameMode.includes('heg_mode');
  mainStack.push(room);
  mainWindow.busy = false;
}

callbacks["UpdateRoomList"] = (jsonData) => {
  const current = mainStack.currentItem;  // should be lobby
  if (mainStack.depth === 2) {
    current.roomModel.clear();
    JSON.parse(jsonData).forEach(function (room) {
      current.roomModel.append({
        roomId: room[0],
        roomName: room[1],
        gameMode: room[2],
        playerNum: room[3],
        capacity: room[4],
        hasPassword: room[5] ? true : false,
      });
    });
  }
}

callbacks["UpdatePlayerNum"] = (j) => {
  const current = mainStack.currentItem;  // should be lobby
  if (mainStack.depth === 2) {
    const data = JSON.parse(j);
    const l = data[0];
    const s = data[1];
    current.lobbyPlayerNum = l;
    current.serverPlayerNum = s;
  }
}

callbacks["Chat"] = (jsonData) => {
  // jsonData: { string userName, string general, string time, string msg }
  const current = mainStack.currentItem;  // lobby or room
  const data = JSON.parse(jsonData);
  const pid = data.sender;
  const userName = data.userName;
  const general = Backend.translate(data.general);
  const time = data.time;
  const msg = data.msg;

  if (config.blockedUsers.indexOf(userName) !== -1) {
    return;
  }

  if (general === "")
    current.addToChat(pid, data, `<font color="#3598E8">[${time}] ${userName}:</font> ${msg}`);
  else
    current.addToChat(pid, data, `<font color="#3598E8">[${time}] ${userName}(${general}):</font> ${msg}`);
}

callbacks["ServerMessage"] = (jsonData) => {
  const current = mainStack.currentItem;  // lobby or room
  current.sendDanmaku('<font color="gold"><b>[Server] </b></font>' + jsonData);
}

callbacks["ShowToast"] = (j) => toast.show(j);
callbacks["InstallKey"] = (j) => Backend.installAESKey();
