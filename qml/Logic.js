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

callbacks["NetworkDelayTest"] = function(jsonData) {
  // jsonData: RSA pub key
  let cipherText
  if (config.savedPassword[config.serverAddr] !== undefined
    && config.savedPassword[config.serverAddr].shorten_password === config.password) {
    cipherText = config.savedPassword[config.serverAddr].password;
    if (Debugging)
      console.log("use remembered password", config.password);
  } else {
    cipherText = Backend.pubEncrypt(jsonData, config.password);
  }
  config.cipherText = cipherText;
  ClientInstance.notifyServer("Setup", JSON.stringify([
    config.screenName, cipherText
  ]));
}

callbacks["ErrorMsg"] = function(jsonData) {
  console.log("ERROR: " + jsonData);
  toast.show(jsonData, 5000);
  mainWindow.busy = false;
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
