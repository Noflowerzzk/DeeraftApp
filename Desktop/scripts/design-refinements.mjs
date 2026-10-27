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
try{
  const file=pathToFileURL(join(workspace,'design','m3-expressive','index.html')).href;
  const tests=[];
  async function check(name,expression){const passed=!!await evaluate(expression);tests.push({name,passed});if(!passed)console.log('FAIL',name);}
  async function waitFor(expression){for(let i=0;i<100;i++){if(await evaluate(expression))return;await pause(50);}throw Error('Timeout: '+expression);}
  async function key(key,code=key){await command('Input.dispatchKeyEvent',{type:'keyDown',key,code,windowsVirtualKeyCode:{Enter:13,Escape:27,ArrowDown:40,ArrowUp:38,Home:36,End:35,Tab:9}[key]||0});await command('Input.dispatchKeyEvent',{type:'keyUp',key,code});}
  async function shot(name){await evaluate("new Promise(resolve=>Alpine.nextTick(resolve))");await evaluate("Promise.all(document.getAnimations().filter(a=>Number.isFinite(a.effect.getTiming().iterations)).map(a=>a.finished.catch(()=>{})))");const shot=await command('Page.captureScreenshot',{format:'png'});await writeFile(join(output,name+'.png'),Buffer.from(shot.data,'base64'));}
  await command('Page.navigate',{url:file});await waitFor('!!window.designApp');await evaluate('document.fonts.ready');await pause(500);
  await check('实例筛选为自绘Material菜单，不使用原生select',"document.querySelectorAll('.library-selectors select').length===0 && document.querySelectorAll('.library-selectors [role=combobox]').length===2");
  await evaluate("document.querySelector('[aria-label=\"实例目录\"]').click()");
  await waitFor("document.querySelector('[aria-label=\"实例目录\"]').getAttribute('aria-expanded')==='true' && document.querySelector('.m3-select-menu').checkVisibility()");
  await check('菜单有来源说明与选中标记',"document.querySelectorAll('.m3-select-menu')[0].querySelectorAll('[role=option]').length===4 && document.querySelector('.m3-select-menu [aria-selected=true]').textContent.includes('全部目录')");
  await waitFor("getComputedStyle(document.querySelector('.m3-select-menu')).clipPath==='none'");await shot('material-menu-light');
  await key('End');await waitFor("document.activeElement.dataset.value==='PCL'");await check('End定位末项',"document.activeElement.dataset.value==='PCL'");
  await key('Enter');await waitFor("window.designApp.sourceFilter==='PCL'");
  await check('Enter选择、同步筛选并归还焦点',"window.designApp.filteredInstances.length===1 && document.activeElement.getAttribute('aria-label')==='实例目录'");
  await evaluate("document.querySelector('[aria-label=\"实例目录\"]').focus()");await key('ArrowDown');await waitFor("document.querySelector('[aria-label=\"实例目录\"]').getAttribute('aria-expanded')==='true'");
  await key('Home');await waitFor("document.activeElement.dataset.value==='all'");await key('Enter');await waitFor("window.designApp.sourceFilter==='all'");
  await evaluate("document.querySelector('[aria-label=\"实例分组\"]').click()");await waitFor("document.querySelector('[aria-label=\"实例分组\"]').getAttribute('aria-expanded')==='true'");
  await waitFor("document.activeElement.closest('[aria-label=\"实例分组选项\"]')!==null");await key('End');await waitFor("document.activeElement.dataset.value==='生存'");await key('Enter');await waitFor("window.designApp.groupFilter==='生存'");
  await check('分组菜单保持交叉过滤',"window.designApp.filteredInstances.length===2");
  await evaluate("document.querySelector('[aria-label=\"实例分组\"]').click()");await key('Escape');await waitFor("document.querySelector('[aria-label=\"实例分组\"]').getAttribute('aria-expanded')==='false'");
  await check('Escape关闭并保留焦点',"document.activeElement.getAttribute('aria-label')==='实例分组'");
  await evaluate("document.querySelector('[aria-label=\"实例目录\"]').click()");await evaluate("document.querySelector('h1').click()");await waitFor("document.querySelector('[aria-label=\"实例目录\"]').getAttribute('aria-expanded')==='false'");
  await check('点击外部关闭',"document.querySelector('.m3-select-menu').inert");
  const motion=await evaluate(`new Promise(resolve=>{const menu=document.querySelector('.m3-select-menu'),button=document.querySelector('[aria-label="实例目录"]');button.click();const start=performance.now(),samples=[];function tick(){samples.push({t:performance.now()-start,opacity:Number(menu.style.opacity),transform:menu.style.transform});if(performance.now()-start<450)requestAnimationFrame(tick);else resolve(samples);}requestAnimationFrame(tick);})`);
  tests.push({name:'目录菜单按新批注即时切换，无位置或透明度动画',passed:motion.every(s=>s.transform===''&&s.opacity===0),samples:motion});
  await evaluate("document.querySelector('[aria-label=\"实例目录\"]').click()");await pause(50);await evaluate("document.querySelector('[aria-label=\"实例目录\"]').click()");await waitFor("document.querySelector('.m3-select-menu').checkVisibility()");
  await check('菜单途中反向后稳定展开',"document.querySelector('.m3-select-menu').checkVisibility() && document.querySelector('[aria-label=\"实例目录\"]').getAttribute('aria-expanded')==='true'");
  await evaluate("window.designApp.setTheme('dark')");await waitFor("getComputedStyle(document.querySelector('.m3-select-menu')).clipPath==='none'");await shot('material-menu-dark');await key('Escape');await evaluate("window.designApp.setTheme('light');window.designApp.groupFilter='all'");
  await evaluate("document.querySelector('.detail-tabs button:nth-of-type(2)').click()");await waitFor("window.designApp.detailTab==='模组'");
  await pause(500);await check('标签指示条移动到选中项',"Math.abs(parseFloat(document.querySelector('.detail-tab-indicator').style.left)-(document.querySelector('.detail-tabs button.active').offsetLeft+document.querySelector('.detail-tabs button.active').offsetWidth*.28))<1");
  await evaluate("window.designApp.openThirdParty()");await waitFor("window.designApp.thirdPartyOpen && document.querySelector('[aria-label=\"第三方服务器配置\"]').checkVisibility()");await pause(500);
  await check('对话框弹簧结束后稳定',"parseFloat(document.querySelector('[aria-label=\"第三方服务器配置\"]').style.opacity)===1");await evaluate("window.designApp.closePanels()");
  await command('Page.navigate',{url:file+'?state=server-status'});await waitFor("!!window.designApp && window.designApp.thirdPartyServers.length===3");await evaluate('document.fonts.ready');await pause(500);
  await check('第三方列表直接显示在线、版本、人数和延迟',"document.querySelector('[data-motion-key=demo-online]').textContent.includes('Paper 1.21.4') && document.querySelector('[data-motion-key=demo-online]').textContent.includes('3 / 20') && document.querySelector('[data-motion-key=demo-online]').textContent.includes('38 ms')");
  await check('离线和查询失败为不同状态，未知人数不冒充0',"window.designApp.statusFor('demo-offline').label==='离线' && window.designApp.statusFor('demo-unknown').label==='查询失败' && document.querySelector('[data-motion-key=demo-offline] .server-population').textContent==='—'");
  await command('Emulation.setDeviceMetricsOverride',{width:1743,height:1244,deviceScaleFactor:1,mobile:false});await pause(400);
  await evaluate("document.querySelector('.third-party-section').scrollIntoView({block:'end'})");await shot('third-party-statuses');
  await evaluate("document.querySelector('[data-motion-key=demo-unknown] .refresh-server').click()");await waitFor("window.designApp.statusFor('demo-unknown').state==='checking'");
  await check('查询期间禁用重复刷新并显示检测中',"document.querySelector('[data-motion-key=demo-unknown] .refresh-server').disabled && document.querySelector('[data-motion-key=demo-unknown]').textContent.includes('检测中')");
  await waitFor("window.designApp.statusFor('demo-unknown').state==='unavailable'");
  await check('原型未接查询服务时不伪造成功',"window.designApp.statusFor('demo-unknown').players===null && window.designApp.statusFor('demo-unknown').label==='查询失败'");
  await evaluate("window.designApp.refreshServerStatus('demo-online');window.designApp.removeThirdParty('demo-online')");await pause(1100);
  await check('移除服务器后丢弃迟到的状态响应',"!window.designApp.serverStatuses['demo-online'] && !window.designApp.thirdPartyServers.some(s=>s.id==='demo-online')");
  await evaluate("localStorage.removeItem('deeraft-design-server-config');window.designApp.setPage('launcher')");await waitFor("window.designApp.page==='launcher'");await pause(300);
  await evaluate("window.designApp.toggleMotion();document.querySelector('[aria-label=\"实例目录\"]').click()");await waitFor("document.querySelector('.m3-select-menu').checkVisibility()");
  await check('减少动态效果时菜单直接落位',"getComputedStyle(document.querySelector('.m3-select-menu')).transform==='none'");
  await key('Escape');await evaluate("window.designApp.toggleMotion()");
  for(const [width,height] of [[1080,800],[920,720]]){
    await command('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});await pause(300);await evaluate("document.querySelector('[aria-label=\"实例目录\"]').click()");await pause(400);
    await check('窄窗口'+width+'菜单不超出视口',"(()=>{const r=document.querySelector('.m3-select-menu').getBoundingClientRect();return r.left>=0&&r.right<=innerWidth&&r.bottom<=innerHeight&&document.documentElement.scrollWidth===innerWidth})()");await shot('material-menu-'+width);await key('Escape');
  }
  tests.push({name:'无浏览器运行时异常',passed:runtimeErrors.length===0,details:runtimeErrors});
  await writeFile(join(output,'refinements-checks.json'),JSON.stringify(tests,null,2));console.log(JSON.stringify(tests.map(({samples,...t})=>t),null,2));if(tests.some(t=>!t.passed))process.exitCode=1;
}finally{socket.close();browser.kill();}
