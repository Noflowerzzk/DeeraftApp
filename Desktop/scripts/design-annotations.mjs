// Read rendered reference DOM and capture design prototypes in a workspace-local Edge profile.
import { spawn } from 'node:child_process';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';

const mode=process.argv[2]||'references';
const workspace=resolve(import.meta.dirname,'..');
const output=join(workspace,'.oil-ui','m3-expressive',mode==='references'?'references':mode==='styles'?'styles':'shots');
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
await command('Emulation.setDeviceMetricsOverride',{width:1440,height:960,deviceScaleFactor:1,mobile:false});
try {
  const file=pathToFileURL(join(workspace,'design','m3-expressive','index.html')).href;
  const results=[];
  async function check(name,expression){const passed=!!await evaluate(expression);results.push({name,passed});if(!passed)console.log('FAIL',name);}
  async function waitFor(expression){for(let i=0;i<80;i++){if(await evaluate(expression))return;await pause(75);}throw Error('Timeout: '+expression);}
  async function shot(name){await evaluate("Promise.all(document.getAnimations().filter(a=>a.effect?.target?.classList?.contains('page-stage')).map(a=>a.finished.catch(()=>{})))");const image=await command('Page.captureScreenshot',{format:'png'});await writeFile(join(output,name+'.png'),Buffer.from(image.data,'base64'));}
  await command('Page.navigate',{url:file});await waitFor('!!window.designApp');await evaluate('document.fonts.ready');
  await evaluate("localStorage.removeItem('deeraft-design-server-config')");
  await check('聊天不在主导航',"!window.designApp.navigation.some(n=>n.id==='chat') && ![...document.querySelectorAll('.rail-item')].some(n=>n.textContent.includes('聊天'))");
  await check('搜索放在实例栏内',"!!document.querySelector('.instance-library .library-search input') && !document.querySelector('.top-actions input')");
  await check('封面显示游玩时长且概览不重复',"document.querySelector('.cover-label').textContent.includes('164.1 小时') && !document.querySelector('.facts-row').textContent.includes('游玩')");
  // Sample each frame of rail morph: no discrete direction/height/wrapping change.
  const frames=await evaluate(`new Promise(resolve=>{const frames=[];document.querySelector('.menu-toggle').click();const start=performance.now();function tick(){const item=document.querySelector('.rail-item'),label=item.querySelector('.rail-label');frames.push({t:performance.now()-start,h:item.getBoundingClientRect().height,y:label.getBoundingClientRect().top,x:label.getBoundingClientRect().left,w:label.getBoundingClientRect().width,display:getComputedStyle(item).display});if(performance.now()-start<650)requestAnimationFrame(tick);else resolve(frames);}requestAnimationFrame(tick);})`);
  results.push({name:'导航重排保持固定高度与标签宽度，并连续位移',passed:frames.every(f=>Math.abs(f.h-72)<.01&&Math.abs(f.w-80)<.01&&f.display==='block')&&new Set(frames.map(f=>Math.round(f.y))).size>=3 && Math.max(...frames.map(f=>f.y))-Math.min(...frames.map(f=>f.y))<=21,frames});
  await shot('rail-expanded');await evaluate("document.querySelector('.menu-toggle').click()");await pause(650);
  await evaluate("document.querySelector('[aria-label=\"实例目录\"]').value='HMCL';document.querySelector('[aria-label=\"实例目录\"]').dispatchEvent(new Event('change',{bubbles:true}))");await pause(50);
  await check('目录过滤使用独立来源',"window.designApp.filteredInstances.length===1 && window.designApp.filteredInstances[0].source==='HMCL'");
  await evaluate("window.designApp.groupFilter='整合包'");await pause(50);
  await check('目录与分组交叉筛选',"window.designApp.filteredInstances.length===0");
  await evaluate("window.designApp.sourceFilter='all'");await pause(50);
  await check('跨目录分组',"window.designApp.filteredInstances.length===4");
  await evaluate("window.designApp.groupFilter='all';window.designApp.setPage('community')");await waitFor("window.designApp.page==='community'");
  await shot('community-revised');
  await evaluate("document.querySelector('.activity-note').click()");await waitFor("window.designApp.page==='chat' && document.querySelector('[aria-label=\"返回社区\"]').checkVisibility()");
  await check('社区卡片进入聊天并保留返回入口',"document.querySelector('[aria-label=\"返回社区\"]').checkVisibility()");
  await evaluate("document.querySelector('[aria-label=\"返回社区\"]').click()");await waitFor("window.designApp.page==='community'");
  await evaluate("document.querySelector('.server-join-actions .text-button').click()");await waitFor('window.designApp.associationOpen');
  await check('关联选择覆盖所有目录',"document.querySelector('[aria-label=\"关联实例选择\"]').options.length===8 && document.querySelectorAll('[aria-label=\"关联实例选择\"] optgroup').length===3");
  await evaluate("window.designApp.associationDraft='pcl';document.querySelector('[aria-label=\"关联实例\"]').requestSubmit()");await waitFor('!window.designApp.associationOpen');
  await check('关联配置已保存',"JSON.parse(localStorage.getItem('deeraft-design-server-config')).links.community==='pcl'");
  await evaluate("document.querySelector('.server-join-actions .filled').click()");await waitFor("window.designApp.selectedId==='pcl'&&window.designApp.launchState==='running'");
  await check('启动使用配置的实例而非硬编码CTF',"window.designApp.page==='launcher'&&window.designApp.activity[0].instance==='PCL · Fabric'");
  await check('动态通知在右下角且为M3逆色',"window.designApp.toast.includes('Na2PtCl6 启动了 PCL')&&getComputedStyle(document.querySelector('.snackbar')).right==='28px'&&getComputedStyle(document.querySelector('.snackbar')).left!=='50%'");
  await evaluate("window.designApp.setPage('community')");await waitFor("window.designApp.page==='community'");await shot('launch-activity');
  await evaluate("window.designApp.setPage('servers')");await waitFor("window.designApp.page==='servers'");
  await check('系统状态默认折叠为次要入口',"!document.querySelector('.system-details').open");
  await evaluate("document.querySelector('.third-party-section>.section-heading button').click()");await waitFor('window.designApp.thirdPartyOpen');
  await evaluate("window.designApp.thirdPartyDraft={id:'',name:'朋友的服务器',address:'play.example.com:25565',instanceId:'hmcl'}");await pause(100);await evaluate("document.querySelector('[aria-label=\"第三方服务器配置\"]').requestSubmit()");await waitFor('!window.designApp.thirdPartyOpen');
  await check('第三方服务器保存并绑定实例',"window.designApp.thirdPartyServers.length===1&&window.designApp.serverLinks[window.designApp.thirdPartyServers[0].id]==='hmcl'");
  await shot('servers-revised');
  await evaluate("window.designApp.openThirdParty();window.designApp.thirdPartyDraft.name='保留输入';window.designApp.thirdPartyDraft.address='bad address';window.designApp.saveThirdParty()");
  await check('无效地址保留表单并提示',"window.designApp.thirdPartyOpen&&window.designApp.thirdPartyDraft.name==='保留输入'&&!!window.designApp.formError");
  await evaluate("window.designApp.thirdPartyDraft.address='valid.example.com';window.savedSet=Storage.prototype.setItem;Storage.prototype.setItem=function(){throw Error('blocked')};window.designApp.saveThirdParty()");
  await check('保存失败保留输入且不插入记录',"window.designApp.thirdPartyOpen&&window.designApp.thirdPartyDraft.name==='保留输入'&&window.designApp.thirdPartyServers.length===1&&!!window.designApp.formError");
  await evaluate("Storage.prototype.setItem=window.savedSet;window.designApp.closePanels()");
  await command('Page.reload');await waitFor('!!window.designApp&&window.designApp.thirdPartyServers.length===1');
  await check('刷新读回关联与第三方配置',"window.designApp.serverLinks.community==='pcl'&&window.designApp.thirdPartyServers[0].name==='朋友的服务器'");
  await evaluate("window.designApp.setPage('servers')");await waitFor("window.designApp.page==='servers'");
  await evaluate("document.querySelector('.third-party-row .filled').click()");await waitFor("window.designApp.selectedId==='hmcl'&&window.designApp.launchState==='running'");
  await check('第三方快捷启动正确实例',"window.designApp.selected.source==='HMCL'");
  await evaluate("window.designApp.openAssociation('community')");await shot('association-dialog');
  await evaluate("window.designApp.closePanels();window.designApp.sourcesOpen=true");await shot('source-dialog');await evaluate('window.designApp.closePanels()');
  for(const [width,height]of [[1743,1244],[1080,800],[920,720]]){
    await command('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});
    await evaluate("window.designApp.setPage('launcher');window.designApp.railExpanded=false");await pause(700);
    await check('窗口'+width+'实例搜索和筛选可见',"document.querySelector('.library-search input').checkVisibility()&&document.querySelector('[aria-label=\"实例分组\"]').getBoundingClientRect().height>=24&&document.documentElement.scrollWidth===innerWidth");
    await shot('revised-'+width);
  }
  await evaluate("localStorage.removeItem('deeraft-design-server-config')");
  results.push({name:'无浏览器运行时异常',passed:runtimeErrors.length===0,details:runtimeErrors});
  await writeFile(join(output,'annotation-checks.json'),JSON.stringify(results,null,2));
  console.log(JSON.stringify(results.map(({frames,...r})=>r),null,2));
  if(results.some(t=>!t.passed))process.exitCode=1;
} finally {socket.close();browser.kill();}
