function authTest() {
  var r = UrlFetchApp.fetch('https://www.googleapis.com/generate_204');
  Logger.log('Fetch OK, status ' + r.getResponseCode());
}