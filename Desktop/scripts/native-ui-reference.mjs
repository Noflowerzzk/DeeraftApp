// Read rendered reference DOM and capture design prototypes in a workspace-local Edge profile.
import { spawn } from 'node:child_process';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';

const mode='strict-native';
const workspace=resolve(import.meta.dirname,'..');
const output=join(workspace,'.cache','strict-ui','reference');
const profile=join(workspace,'.cache','design-edge-'+mode+'-'+Date.now());
await mkdir(output,{recursive:true});
await mkdir(profile,{recursive:true});
const edge='C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const browser=spawn(edge,['--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check',`--user-data-dir=${profile}`,'--remote-debugging-port=0','about:blank'],{windowsHide:true,stdio:'ignore'});
let port;
for(let i=0;i<100;i++){
  try{port=(await readFile(join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0];break;}catch{}
  await new Promise(r=>setTimeout(r,150));
}
if(!port)throw new Error('Edge DevTools did not start');
const tabs=await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
const socket=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);
await new Promise((r,j)=>{socket.addEventListener('open',r,{once:true});socket.addEventListener('error',j,{once:true});});
let sequence=0;
const calls=new Map();
const runtimeErrors=[];
socket.addEventListener('message',event=>{const result=JSON.parse(event.data);if(result.method==='Runtime.exceptionThrown')runtimeErrors.push(result.params.exceptionDetails);const pending=calls.get(result.id);if(pending){calls.delete(result.id);result.error?pending.reject(new Error(JSON.stringify(result.error))):pending.resolve(result.result);}});
function command(method,params={}){return new Promise((resolve,reject)=>{const id=++sequence;calls.set(id,{resolve,reject});socket.send(JSON.stringify({id,method,params}));});}
async function evaluate(expression){const r=await command('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});if(r.exceptionDetails)throw new Error(JSON.stringify(r.exceptionDetails));return r.result.value;}
const pause=ms=>new Promise(r=>setTimeout(r,ms));
await command('Page.enable');
await command('Runtime.enable');
await command('Page.enable');
try {
 await command('Emulation.setDeviceMetricsOverride',{width:1440,height:960,deviceScaleFactor:1,mobile:false});
 await command('Page.navigate',{url:pathToFileURL(join(workspace,'design','m3-expressive','index.html')).href});
 await pause(1800);
 await evaluate(`(async()=>{await document.fonts.ready;let s=document.createElement('style');s.textContent='.window-bar{display:none!important}.app-layout{height:100dvh!important}';document.head.append(s)})()`);
 const fixture=await evaluate(`(()=>{const a=window.designApp;const asset=p=>new URL(p,location.href).href;return {
 instances:a.instances.map(r=>({id:r.id,name:r.name,version:r.version,loader:r.loader==='Vanilla'?'':r.loader+' '+r.loaderVersion,icon:'grass',glyph:r.icon,tile:r.tile,tileInk:r.tileInk,source:r.source==='local'?'native':r.source,sourceName:r.source==='local'?'DeeraftApp':r.source,group:r.group,seconds:Number(r.hours)*3600,maxMemory:4096,external:false,valid:true,running:false,lastPlayed:r.lastPlayed})),
 profile:{username:document.querySelector('.profile-header h2').textContent,bio:'Deeraft',role:'admin',avatar_url:asset('assets/avatar-2.svg')},
 community:{mc:{motd:document.querySelector('.server-hero h2').textContent,version:'Paper 26.3',online_count:a.players.length,latency_ms:11,human_players:Array.from(a.players),players:Array.from(a.players)},kook:{channels:a.voiceChannels.map(c=>({name:c.name,users:c.members.map(n=>({name:n,avatar:asset('assets/avatar-'+(a.players.indexOf(n)+1)+'.svg')}))}))}},
 servers:a.servers.map(s=>({name:s.name,description:s.description,cover_url:asset(s.cover),is_running:s.running,online_players:s.players,memory_usage:s.memory})),
 chat:a.messages.map(m=>({player:m.player,message:m.text,time:m.time})),activity:[],playtime:a.rankings.map(r=>({server_name:r.name,playtime_minutes:r.hours*60})),dailyDate:'2026-10-25',daily:[{player:'Na2PtCl6',playtime_minutes:136}],dailyWeek:a.dailyBars.map((n,i)=>({date:'2026-10-'+(19+i),available:true,minutes:n})),liveRooms:[{room_id:'fixture',title:'Na2PtCl6 的直播间'}]}})()`);
 await writeFile(join(output,'fixture.json'),JSON.stringify(fixture,null,2));
 const metrics=[];
 for(const [page,theme] of [['launcher','light'],['community','light'],['servers','light'],['profile','light'],['launcher','dark']]) {
  await evaluate(`window.designApp.setPage('${page}');window.designApp.setTheme('${theme}')`);await pause(650);
  const data=await evaluate(`(()=>{let names=['.navigation-rail','.page-header','.instance-library','.library-search','.library-selectors','.instance-row','.instance-detail','.instance-cover','.instance-title','.split-button','.detail-tabs','.server-hero','.hero-map','.players-panel','.kook-panel','.activity-note','.playtime-panel','.daily-panel'];return names.flatMap(selector=>{let e=document.querySelector(selector);if(!e||!e.checkVisibility())return [];let r=e.getBoundingClientRect(),s=getComputedStyle(e);return [{selector,x:r.x,y:r.y,width:r.width,height:r.height,fontSize:s.fontSize,lineHeight:s.lineHeight,radius:s.borderRadius,background:s.backgroundColor}]})})()`);
  metrics.push({page,theme,elements:data});
  const shot=await command('Page.captureScreenshot',{format:'png'});await writeFile(join(output,page+'-'+theme+'.png'),Buffer.from(shot.data,'base64'));
 }
 await writeFile(join(output,'metrics.json'),JSON.stringify(metrics,null,2));
 console.log('Reference DOM metrics and screenshots captured at 1440 x 960 client area.');
} finally {socket.close();browser.kill();}
