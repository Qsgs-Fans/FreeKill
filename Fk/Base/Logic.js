// 服了。。
function translateErrorMsg(data) {
  let log;
  try {
    const a = JSON.parse(data);
    log = qsTr(a[0]).arg(a[1]);
  } catch (e) {
    log = qsTr(data);
  }
  return log;
}
