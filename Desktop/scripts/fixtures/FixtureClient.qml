import QtQuick
QtObject {
 property var dataset: ({})
 property bool authenticated: true
 property bool busy: false
 property string error: ""
 property var profile: dataset.profile||({})
 property var community: dataset.community||({})
 property var servers: dataset.servers||[]
 property var chat: dataset.chat||[]
 property var activity: dataset.activity||[]
 property var playtime: dataset.playtime||[]
 property var daily: dataset.daily||[]
 property var dailyWeek: dataset.dailyWeek||[]
 property string dailyDate: dataset.dailyDate||"2026-10-25"
 property var liveRooms: dataset.liveRooms||[]
 property var users: []
 property var logLines: []
 property var backups: []
 property var hostedStatus: ({})
 property var rconConfig: ({})
 property string commandResult: ""
 property bool uploading: false
 property real uploadProgress: 0
 signal changed()
 signal activityReceived(string player,string instance)
 signal operationFailed(string operation,string message)
 signal operationFinished(string operation,var result)
 function imageUrl(path){return path}
 function loadDailyWeek(date){}
 function loadDaily(date){dailyDate=date;changed()}
 function refresh(){}
 function reportGameStarted(name,version){}
 function clearError(){}
 function logout(){}
}
