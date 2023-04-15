// SPDX-License-Identifier: GPL-3.0-or-later

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

var callbacks = {};
let sheduled_download = "";

callbacks["NetworkDelayTest"] = function(jsonData) {
  // jsonData: RSA pub key
  let cipherText;
  let aeskey;
  if (config.savedPassword[config.serverAddr] !== undefined
    && config.savedPassword[config.serverAddr].shorten_password === config.password) {
    cipherText = config.savedPassword[config.serverAddr].password;
    aeskey = config.savedPassword[config.serverAddr].key;
    config.aeskey = aeskey;
    Backend.setAESKey(aeskey);
    if (Debugging)
      console.log("use remembered password", config.password);
  } else {
    cipherText = Backend.pubEncrypt(jsonData, config.password);
    config.aeskey = Backend.getAESKey();
  }
  config.cipherText = cipherText;
  Backend.replyDelayTest(config.screenName, cipherText);
  Backend.installAESKey();
}

callbacks["ErrorMsg"] = function(jsonData) {
  console.log("ERROR: " + jsonData);
  toast.show(qsTr(jsonData), 5000);
  mainWindow.busy = false;
  if (sheduled_download !== "") {
    mainWindow.busy = true;
    Pacman.loadSummary(sheduled_download, true);
    sheduled_download = "";
  }
}

callbacks["UpdatePackage"] = (jsonData) => sheduled_download = jsonData;

callbacks["UpdateBusyText"] = function(jsonData) {
  mainWindow.busyText = jsonData;
}

callbacks["DownloadComplete"] = function() {
  mainWindow.busy = false;
  mainStack.currentItem.downloadComplete(); // should be pacman page
}

callbacks["BackToStart"] = function(jsonData) {
  while (mainStack.depth > 1) {
    mainStack.pop();
  }
}

callbacks["EnterLobby"] = function(jsonData) {
  // depth == 1 means the lobby page is not present in mainStack
  createClientPages();
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
}

callbacks["EnterRoom"] = function(jsonData) {
  // jsonData: int capacity, int timeout
  let data = JSON.parse(jsonData);
  config.roomCapacity = data[0];
  config.roomTimeout = data[1] - 1;
  let roomSettings = data[2];
  config.enableFreeAssign = roomSettings.enableFreeAssign;
  mainStack.push(room);
  mainWindow.busy = false;
}

callbacks["UpdateRoomList"] = function(jsonData) {
  let current = mainStack.currentItem;  // should be lobby
  current.roomModel.clear();
  JSON.parse(jsonData).forEach(function(room) {
    current.roomModel.append({
    roomId: room[0],
    roomName: room[1],
    gameMode: room[2],
    playerNum: room[3],
    capacity: room[4],
    });
  });
}

callbacks["UpdatePlayerNum"] = (j) => {
  let current = mainStack.currentItem;  // should be lobby
  let data = JSON.parse(j);
  let l = data[0];
  let s = data[1];
  current.lobbyPlayerNum = l;
  current.serverPlayerNum = s;
}

callbacks["Chat"] = function(jsonData) {
  // jsonData: { string userName, string general, string time, string msg }
  let current = mainStack.currentItem;  // lobby(TODO) or room
  let data = JSON.parse(jsonData);
  let pid = data.sender;
  let userName = data.userName;
  let general = Backend.translate(data.general);
  let time = data.time;
  let msg = data.msg;

  if (general === "")
    current.addToChat(pid, data, `[${time}] ${userName}: ${msg}`);
  else
    current.addToChat(pid, data, `[${time}] ${userName}(${general}): ${msg}`);
}
