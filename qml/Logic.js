var callbacks = {};

callbacks["NetworkDelayTest"] = function(jsonData) {
  ClientInstance.notifyServer("Setup", JSON.stringify([
    config.screenName,
    config.password
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
  if (mainStack.depth === 1) {
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
  config.roomTimeout = data[1];
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
