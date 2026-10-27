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
  if(mode==='tokens'){
    const root=join(workspace,'.oil-ui','m3-expressive','styles');
    const manifest=JSON.parse(await readFile(join(root,'manifest.json'),'utf8'));
    const seen=new Set();
    for(const entry of manifest){
      if(seen.has(entry.url))continue;seen.add(entry.url);
      const html=await readFile(join(root,entry.file.replace('.json','.html')),'utf8');
      if(!html.includes('theme-provider'))continue;
      await command('Page.navigate',{url:entry.url});await pause(2300);
      await evaluate("document.querySelector('mio-carbon-data-module')?.scrollIntoView({block:'center'})");
      await pause(2500);
      const text=await evaluate(`(()=>{const results=[];function walk(root){for(const e of root.querySelectorAll('*'))if(e.shadowRoot){const clone=document.createElement('div');clone.innerHTML=e.shadowRoot.innerHTML;clone.querySelectorAll('style,script,svg').forEach(n=>n.remove());results.push({host:e.tagName,text:clone.textContent.replace(/\\s+/g,' ').trim(),html:e.shadowRoot.innerHTML});walk(e.shadowRoot);}}walk(document);return results;})()`);
      await writeFile(join(root,entry.file.replace('.json','--shadow.json')),JSON.stringify(text,null,2));
      console.log(entry.url,text.map(x=>x.host+':'+x.text.length).join(', '));
    }
  }else if(mode==='styles'){
    const queue=['https://m3.material.io/styles'];
    const visited=new Set();const manifest=[];
    while(queue.length){
      const url=queue.shift();if(visited.has(url))continue;visited.add(url);
      await command('Page.navigate',{url});
      await pause(1800);
      for(let i=0;i<30;i++){
        try{if(await evaluate("document.readyState==='complete' && document.body.innerText.length>1000"))break;}catch{}
        await pause(300);
      }
      const data=await evaluate(`({url:location.href,title:document.title,text:document.body.innerText,headings:[...document.querySelectorAll('h1,h2,h3,h4')].map(e=>({tag:e.tagName,text:e.textContent})),links:[...new Set([...document.querySelectorAll('a[href]')].map(e=>e.href).filter(h=>h.startsWith('https://m3.material.io/styles')).map(h=>h.split('#')[0].split('?')[0]))],tables:[...document.querySelectorAll('table')].map(e=>e.innerText),media:[...document.querySelectorAll('img,video')].map(e=>({tag:e.tagName,alt:e.alt||'',src:e.currentSrc||e.src,poster:e.poster||''}))})`);
      const name=new URL(url).pathname.replace(/^\//,'').replaceAll('/','--');
      await writeFile(join(output,name+'.json'),JSON.stringify(data,null,2));
      await writeFile(join(output,name+'.html'),await evaluate('document.documentElement.outerHTML'));
      manifest.push({url:data.url,file:name+'.json',title:data.title,characters:data.text.length,headings:data.headings.map(h=>h.text)});
      for(const link of data.links)if(!visited.has(link)&&!queue.includes(link))queue.push(link);
      await writeFile(join(output,'manifest.json'),JSON.stringify(manifest,null,2));
      console.log(manifest.length,data.url,data.title,data.text.length,'chars;',queue.length,'pending');
      if(visited.size>150)throw new Error('Styles crawl exceeded the safety bound; inspect the remaining routes.');
    }
    console.log('Complete:',manifest.length,'styles documents; no pending internal styles links.');
  }else if(mode==='references'){
    const pages=[
      ['home','https://m3.material.io/'],
      ['expressive','https://m3.material.io/blog/building-with-m3-expressive'],
      ['motion','https://m3.material.io/styles/motion/overview/specs'],
      ['rail','https://m3.material.io/components/navigation-rail/overview'],
      ['button-groups','https://m3.material.io/components/button-groups/overview'],
      ['layout','https://m3.material.io/foundations/layout/canonical-examples/supporting-pane']
    ];
    for(const[name,url]of pages){
      await command('Page.navigate',{url});
      for(let i=0;i<45;i++){await pause(500);if(await evaluate('document.body?.innerText.length>1200'))break;}
      await pause(1500);
      const data=await evaluate(`({url:location.href,title:document.title,text:document.body.innerText,headings:[...document.querySelectorAll('h1,h2,h3')].map(e=>({tag:e.tagName,text:e.textContent})),media:[...document.querySelectorAll('img,video,iframe')].map(e=>({tag:e.tagName,alt:e.alt||'',src:e.currentSrc||e.src,poster:e.poster||''})),colors:[...new Set([...document.querySelectorAll('button,h1,h2')].map(e=>getComputedStyle(e).color))]})`);
      await writeFile(join(output,name+'.json'),JSON.stringify(data,null,2));
      await writeFile(join(output,name+'.html'),await evaluate('document.documentElement.outerHTML'));
      const shot=await command('Page.captureScreenshot',{format:'png'});await writeFile(join(output,name+'.png'),Buffer.from(shot.data,'base64'));
      console.log(name, data.title, data.text.length, 'characters', data.media.length,'media elements');
    }
  }else{
    const file=pathToFileURL(join(workspace,'design','m3-expressive','index.html')).href;
    await command('Page.navigate',{url:file});await pause(1800);
    const checks=[];
    for(const[page,theme]of [['launcher','light'],['community','light'],['servers','light'],['chat','light'],['profile','light'],['launcher','dark']]){
      await evaluate(`window.designApp.setPage('${page}');window.designApp.setTheme('${theme}')`);await pause(800);
      const shot=await command('Page.captureScreenshot',{format:'png'});await writeFile(join(output,page+'-'+theme+'.png'),Buffer.from(shot.data,'base64'));
      checks.push(await evaluate(`({page:'${page}',theme:'${theme}',width:innerWidth,overflow:document.documentElement.scrollWidth>innerWidth,images:[...document.images].filter(i=>!i.complete||i.naturalWidth===0).map(i=>i.src),text:document.body.innerText.slice(0,180)})`));
    }
    await writeFile(join(output,'checks.json'),JSON.stringify(checks,null,2));
    const tests=[];
    async function check(name,expression){const value=await evaluate(expression);tests.push({name,passed:!!value});}
    await evaluate("window.designApp.setTheme('light');window.designApp.setPage('launcher');window.designApp.selectInstance('nacreate');window.designApp.detailTab='概览'");await pause(400);
    await evaluate("document.querySelectorAll('.instance-row')[1].click()");await pause(80);
    await check('选择实例同步详情标题',"document.querySelector('.instance-title').textContent==='CTF_s3'");
    await evaluate("window.designApp.instanceFilter='收藏'");await pause(50);
    await check('收藏过滤',"document.querySelectorAll('.instance-row').length===2");
    await evaluate("window.designApp.instanceFilter='已关联'");await pause(50);
    await check('PCL/HMCL关联实例过滤',"document.querySelectorAll('.instance-row').length===2 && window.designApp.filteredInstances.every(i=>i.source!=='local')");
    await evaluate("window.designApp.instanceFilter='全部';window.designApp.search='not-present'");await pause(50);
    await check('空搜索结果',"document.querySelectorAll('.instance-row').length===0 && document.querySelector('.empty-state').checkVisibility()");
    await evaluate("window.designApp.search='';window.designApp.selectInstance('nacreate')");await pause(50);
    await evaluate("document.querySelector('.detail-tabs button:nth-of-type(2)').click()");await pause(400);
    await evaluate("document.querySelector('.mod-row .switch').click()");await pause(400);
    await check('模组开关与无障碍状态同步',"document.querySelector('.mod-row .switch').getAttribute('aria-checked')==='false'");
    const mods=await command('Page.captureScreenshot',{format:'png'});await writeFile(join(output,'launcher-mods.png'),Buffer.from(mods.data,'base64'));
    await evaluate("window.designApp.detailTab='概览';document.querySelector('.launch-primary').click()");await pause(60);
    await check('启动即时反馈并禁用重复点击',"window.designApp.launchState==='preparing' && document.querySelector('.launch-primary').disabled");
    await pause(2300);
    await check('准备状态转为运行',"window.designApp.launchState==='running'");
    await evaluate("document.querySelector('.launch-primary').click()");await pause(40);
    await check('结束恢复就绪',"window.designApp.launchState==='idle'");
    await evaluate("document.querySelector('.download-trigger').click()");await pause(90);
    await evaluate("window.designApp.toggleDownloads(false)");await pause(50);
    await evaluate("window.designApp.toggleDownloads(true)");await pause(900);
    await check('侧栏可打断并反向继续',"window.designApp.downloadsOpen && Math.abs(window.designApp.downloadSpring.value)<0.02");
    const drawer=await command('Page.captureScreenshot',{format:'png'});await writeFile(join(output,'downloads.png'),Buffer.from(drawer.data,'base64'));
    await evaluate("window.designApp.closePanels();window.designApp.openSettings()");await pause(200);
    const settings=await command('Page.captureScreenshot',{format:'png'});await writeFile(join(output,'settings.png'),Buffer.from(settings.data,'base64'));
    await command('Input.dispatchKeyEvent',{type:'keyDown',key:'Escape',code:'Escape',windowsVirtualKeyCode:27});await pause(80);
    await check('Escape关闭浮层',"!window.designApp.settingsOpen && !window.designApp.downloadsOpen");
    await evaluate("window.designApp.setPage('community')");await pause(350);
    await evaluate("[...document.querySelectorAll('.server-hero button')].find(b=>b.textContent.includes('启动并加入')).click()");await pause(2700);
    await check('社区选择对应版本并开始启动链路',"window.designApp.page==='launcher' && window.designApp.selectedId==='ctf' && window.designApp.launchState==='running'");
    await evaluate("window.designApp.selected.running=false;window.designApp.selectInstance('nacreate');window.designApp.detailTab='概览';window.designApp.toast=''");
    for(const size of [[1080,800],[920,720]]){
      await command('Emulation.setDeviceMetricsOverride',{width:size[0],height:size[1],deviceScaleFactor:1,mobile:false});await pause(500);
      await check('窗口'+size.join('×')+'无页面横向溢出',"document.documentElement.scrollWidth===innerWidth");
      const shot=await command('Page.captureScreenshot',{format:'png'});await writeFile(join(output,'launcher-'+size.join('x')+'.png'),Buffer.from(shot.data,'base64'));
    }
    await check('Material图标与字体已加载',"document.fonts.check('24px \"Material Symbols Rounded\"') && document.fonts.check('16px \"Noto Sans SC\"')");
    await check('相同玩家跨区域使用同一头像',"window.designApp.avatarFor('Na2PtCl6')==='assets/avatar-2.svg' && window.designApp.avatarFor('Blackscience')==='assets/avatar-3.svg'");
    tests.push({name:'无浏览器运行时异常',passed:runtimeErrors.length===0,details:runtimeErrors});
    await writeFile(join(output,'interaction-checks.json'),JSON.stringify(tests,null,2));
    console.log(JSON.stringify({checks,tests},null,2));
    if(tests.some(test=>!test.passed))process.exitCode=1;
  }
}finally{socket.close();browser.kill();}
