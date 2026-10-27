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
  async function check(name,expression){tests.push({name,passed:!!await evaluate(expression)});}
  async function settle(){await evaluate('new Promise(resolve=>Alpine.nextTick(resolve))');}
  async function shot(name){await settle();await pause(250);const r=await command('Page.captureScreenshot',{format:'png'});await writeFile(join(output,name+'.png'),Buffer.from(r.data,'base64'));}
  await command('Page.navigate',{url:file});await pause(1500);await evaluate('document.fonts.ready');
  await evaluate("document.querySelector('[aria-label=\"实例目录\"]').click()");await settle();
  await check('目录菜单只淡入，无空间动画',"(()=>{const e=document.querySelector('.m3-select-menu');return e.checkVisibility()&&e.getAnimations().every(a=>a.transitionProperty==='opacity')&&['none','matrix(1, 0, 0, 1, 0, 0)'].includes(getComputedStyle(e).transform)})()");
  await check('箭头无旋转过渡',"getComputedStyle(document.querySelector('.m3-select-chevron')).transitionDuration==='0s'");
  await check('目录菜单与启动菜单样式一致',"(()=>{const a=getComputedStyle(document.querySelector('.m3-select-menu')),b=getComputedStyle(document.querySelector('.launch-menu'));return ['backgroundColor','borderRadius','padding','boxShadow'].every(k=>a[k]===b[k])})()");
  await shot('selector-static');
  await evaluate("document.querySelector('[aria-label=\"导入或关联目录\"]').click()");await settle();await pause(200);
  await check('三点菜单出现时关闭目录菜单',"window.designApp.libraryMenu&&!document.querySelector('.m3-select-menu').checkVisibility()");
  await check('三点菜单不会被选择栏遮住',"(()=>{const menu=document.querySelector('.library-menu');return [...menu.querySelectorAll('button')].every(b=>{const r=b.getBoundingClientRect();return menu.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2))})})()");
  await shot('library-menu-fixed');
  await evaluate("document.querySelector('[aria-label=\"实例分组\"]').click()");await settle();
  await check('分组菜单打开时关闭三点菜单',"!window.designApp.libraryMenu && document.querySelectorAll('.m3-select-menu')[1].checkVisibility()");
  await check('分组菜单只使用透明度过渡',"document.querySelectorAll('.m3-select-menu')[1].getAnimations().every(a=>a.transitionProperty==='opacity') && ['none','matrix(1, 0, 0, 1, 0, 0)'].includes(getComputedStyle(document.querySelectorAll('.m3-select-menu')[1]).transform)");
  await evaluate("document.querySelectorAll('.m3-select-menu')[1].querySelector('[data-value=生存]').click()");await settle();
  await check('选择分组仍正确过滤，列表不做重排动效',"window.designApp.groupFilter==='生存'&&window.designApp.filteredInstances.length===2&&[...document.querySelectorAll('.instance-row')].every(e=>!e.style.translate&&!e.style.opacity)");
  await evaluate("window.designApp.groupFilter='all';window.designApp.setTheme('dark');document.querySelector('[aria-label=\"导入或关联目录\"]').click()");await shot('library-menu-fixed-dark');
  await check('深色主题三点菜单仍在选择栏上方',"(()=>{const m=document.querySelector('.library-menu'),r=m.querySelectorAll('button')[2].getBoundingClientRect();return m.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2))})()");
  tests.push({name:'无运行时异常',passed:runtimeErrors.length===0,details:runtimeErrors});
  await writeFile(join(output,'menu-fix-checks.json'),JSON.stringify(tests,null,2));console.log(JSON.stringify(tests,null,2));if(tests.some(t=>!t.passed))process.exitCode=1;
}finally{socket.close();browser.kill();}
