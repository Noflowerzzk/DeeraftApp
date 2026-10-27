/* Standalone UI design prototype. All data and state changes are illustrative.
 * No account authentication, game launch, file operations, or backend calls occur.
 */
document.addEventListener('alpine:init', () => {
  Alpine.data('deeraft', () => ({
    page: 'launcher',
    theme: 'light',
    railExpanded: false,
    search: '',
    sourceFilter: 'all',
    groupFilter: 'all',
    associationOpen: false,
    associationKey: '',
    associationDraft: '',
    serverLinks: {community: 'ctf'},
    thirdPartyServers: [],
    serverStatuses: {},
    statusDemo: false,
    statusRequests: {},
    thirdPartyOpen: false,
    thirdPartyDraft: {id:'', name:'', address:'', instanceId:''},
    formError: '',
    storageError: '',
    sourcesOpen: false,
    activity: [{id:'initial', player:'123KrF2', instance:'CTF_s3', time:'21:38'}],
    sources: [{id:'local',name:'DeeraftApp',path:'data/instances',type:'Prism'}, {id:'HMCL',name:'HMCL 游戏目录',path:'D:/Games/HMCL/.minecraft',type:'HMCL'}, {id:'PCL',name:'PCL 游戏目录',path:'E:/Minecraft/.minecraft',type:'PCL'}],
    instanceFilter: '全部',
    reverseOrder: false,
    selectedId: 'nacreate',
    detailTab: '概览',
    preparingId: '',
    playerFilter: '真人',
    serverFilter: '全部服务器',
    chatSearchOpen: false,
    chatSearch: '',
    libraryMenu: false,
    instanceMenu: false,
    launchMenu: false,
    downloadsOpen: false,
    settingsOpen: false,
    settingsTab: 'appearance',
    reducedMotion: false,
    prismWindow: '',
    consoleOpen: false,
    consoleName: '',
    consoleCommand: '',
    imagePreview: '',
    toast: '',
    toastAction: '',
    toastTimer: 0,
    navigationEpoch: 0,
    navigation: [
      { id: 'community', name: '社区', icon: 'diversity_3' },
      { id: 'launcher', name: '启动器', icon: 'stadia_controller' },
      { id: 'servers', name: '服务器', icon: 'dns' },
      { id: 'profile', name: '我的', icon: 'person' }
    ],
    instances: [
      { id: 'nacreate', name: 'NaCreate', version: '1.20.1', loader: 'Fabric', loaderVersion: '0.16.10', icon: 'settings', tile: '#f1d7a8', tileInk: '#60421c', cover: 'assets/village.png', favorite: true, source: 'local', java: 17, hours: '164.1', mods: 126, lastPlayed: '昨天 21:37', running: false },
      { id: 'ctf', name: 'CTF_s3', version: '26.3', loader: 'Vanilla', loaderVersion: '', icon: 'flag', tile: '#d5e8e6', tileInk: '#28524f', cover: 'assets/forest.png', favorite: true, source: 'local', java: 25, hours: '2.4', mods: 0, lastPlayed: '10 月 24 日', running: false },
      { id: 'farming', name: 'FarmingTales_2', version: '1.20.1', loader: 'Forge', loaderVersion: '47.3.0', icon: 'psychiatry', tile: '#dee8ba', tileInk: '#4a5729', cover: 'assets/forest.png', favorite: false, source: 'local', java: 17, hours: '17.3', mods: 214, lastPlayed: '10 月 23 日', running: false },
      { id: 'naaero', name: 'NaAero', version: '1.20.1', loader: 'Forge', loaderVersion: '47.3.0', icon: 'flight', tile: '#d8e4f4', tileInk: '#354c6b', cover: 'assets/village.png', favorite: false, source: 'local', java: 17, hours: '11.6', mods: 86, lastPlayed: '10 月 20 日', running: false },
      { id: 'simcity', name: 'SimCity', version: '1.20.1', loader: 'Fabric', loaderVersion: '0.16.10', icon: 'apartment', tile: '#e4dcf2', tileInk: '#5b4477', cover: 'assets/village.png', favorite: false, source: 'local', java: 17, hours: '6.6', mods: 64, lastPlayed: '10 月 18 日', running: false },
      { id: 'hmcl', name: '1.21.4 生存', version: '1.21.4', loader: 'Vanilla', loaderVersion: '', icon: 'grass', tile: '#d2e7d1', tileInk: '#2e582c', cover: 'assets/village.png', favorite: false, source: 'HMCL', java: 21, hours: '3.2', mods: 0, lastPlayed: '10 月 16 日', running: false },
      { id: 'pcl', name: 'PCL · Fabric', version: '1.20.1', loader: 'Fabric', loaderVersion: '0.16.10', icon: 'inventory_2', tile: '#efdec9', tileInk: '#65492d', cover: 'assets/forest.png', favorite: false, source: 'PCL', java: 17, hours: '2.1', mods: 42, lastPlayed: '10 月 14 日', running: false }
    ],
    mods: [
      { name: 'Create', version: '0.5.1 · Fabric', icon: 'settings', color: '#ead5b5', enabled: true },
      { name: 'Sodium', version: '0.5.8 · Fabric', icon: 'bolt', color: '#d7e6c5', enabled: true },
      { name: 'Lithium', version: '0.11.2 · Fabric', icon: 'science', color: '#e2daf2', enabled: true },
      { name: 'Mod Menu', version: '7.2.2 · Fabric', icon: 'grid_view', color: '#cfe4ea', enabled: false }
    ],
    players: ['123KrF2', 'Blackscience', 'Na2PtCl6', 'Noflower', 'Remnant'],
    voiceChannels: [
      { name: 'MCPK', members: ['Na2PtCl6', '123KrF2'] },
      { name: 'Apex', members: ['Blackscience'] },
      { name: '其他游戏', members: [] },
      { name: '其他游戏 II', members: [] },
      { name: '派对游戏', members: [] },
      { name: '聊天室', members: [] }
    ],
    servers: [
      { name: 'NaCreate', description: 'Fabric · 1.20.1', cover: 'assets/village.png', running: true, players: 5, memory: '5.2 GB' },
      { name: 'CTF_s2', description: '夺旗 · 1.21.4', cover: 'assets/forest.png', running: false, players: 0, memory: '—' }
    ],
    messages: [
      { player: '123KrF2', avatar: 1, time: '21:32', text: '有人一起吗' },
      { player: 'Na2PtCl6', avatar: 2, time: '21:33', text: '来了，先把东西放回去' },
      { player: 'Blackscience', avatar: 3, time: '21:34', text: '我在基地门口' },
      { player: 'Remnant', avatar: 5, time: '21:35', text: '等我两分钟' },
      { player: 'Noflower', avatar: 4, time: '21:36', text: '这边的路已经修好了' },
      { player: 'Na2PtCl6', avatar: 2, time: '21:37', text: '看到了，走右边就能过去' },
      { player: '123KrF2', avatar: 1, time: '21:38', text: '旗帜放回基地了' }
    ],
    rankings: [
      { name: 'NaCreate', hours: 164.1 }, { name: 'CTF_s2', hours: 29.0 }, { name: 'FarmingTales_2', hours: 17.3 }, { name: 'NaAero', hours: 11.6 }, { name: 'SimCity', hours: 6.6 }
    ],
    dailyBars: [34, 58, 41, 76, 48, 91, 68],
    tasks: [
      { name: 'NaCreate', detail: '正在下载模组', progress: 68, speed: '8.4 MB/s', icon: 'extension', paused: false },
      { name: 'Java 21', detail: '正在下载运行环境', progress: 34, speed: '5.7 MB/s', icon: 'coffee', paused: false }
    ],
    init() {
      const groups = {nacreate:'整合包',ctf:'多人游戏',farming:'整合包',naaero:'整合包',simcity:'整合包',hmcl:'生存',pcl:'生存'};
      this.instances.forEach(instance => { instance.group = groups[instance.id]; });
      try {
        const stored = JSON.parse(localStorage.getItem('deeraft-design-server-config') || 'null');
        if (stored) {
          this.serverLinks = {...this.serverLinks, ...stored.links};
          this.thirdPartyServers = Array.isArray(stored.servers) ? stored.servers : [];
        }
      } catch { this.storageError = '无法读取服务器配置'; }
      const query = new URLSearchParams(location.search);
      if (['chat',...this.navigation.map(item=>item.id)].includes(query.get('page'))) this.page = query.get('page');
      this.setTheme(query.get('theme') === 'dark' ? 'dark' : 'light');
      if (query.get('state') === 'dark') this.setTheme('dark');
      if (query.get('state') === 'server-status') {
        this.statusDemo=true;
        this.page='servers';
        this.thirdPartyServers=[{id:'demo-online',name:'朋友的生存服',address:'play.example.com:25565'},{id:'demo-offline',name:'周末建筑服',address:'build.example.com'},{id:'demo-unknown',name:'模组联机',address:'modded.example.com'}];
        this.serverLinks['demo-online']='hmcl';this.serverLinks['demo-offline']='simcity';this.serverLinks['demo-unknown']='pcl';
        this.serverStatuses={
          'demo-online':{state:'online',label:'在线',version:'Paper 1.21.4',players:'3 / 20',latency:38,updated:'刚刚更新'},
          'demo-offline':{state:'offline',label:'离线',version:'版本 —',players:null,latency:null,updated:'刚刚更新'},
          'demo-unknown':{state:'unavailable',label:'查询失败',version:null,players:null,latency:null,updated:'可重试'}
        };
      }
      if (query.get('state') === 'mods') this.detailTab = '模组';
      this.reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
      document.documentElement.dataset.motion = this.reducedMotion ? 'reduced' : 'full';
      window.designApp = this;
      for(const [key,selector] of [['thirdPartyOpen','[aria-label="第三方服务器配置"]'],['associationOpen','[aria-label="关联实例"]'],['sourcesOpen','.sources-dialog'],['settingsOpen','.settings-dialog']]){
        this.$watch(key,open=>{if(open)this.$nextTick(()=>DeeraftMotion.enter(document.querySelector(selector)));});
      }
      document.addEventListener('keydown', event => {
        if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') {
          event.preventDefault();
          this.setPage('launcher').then(() => this.$nextTick(() => document.querySelector('.library-search input').focus()));
        }
      });
      for (const source of ['assets/forest.png', 'assets/village.png']) {
        const image = new Image(); image.src = source;
      }
      this.$nextTick(() => {
        if (!DeeraftMotion.reduced()) {
          document.querySelector('.page-stage').animate([{ opacity: 0.3, transform: 'translateY(8px)' }, { opacity: 1, transform: 'translateY(0)' }], { duration: 350, easing: 'cubic-bezier(.2,0,0,1)' });
        }
        DeeraftMotion.trackTabs(document.querySelector('.detail-tabs'));
        this.downloadSpring = new DeeraftMotion.Spring(100, value => {
          document.querySelector('.downloads-sheet').style.transform = `translateX(${value}%)`;
        }, 'defaultSpatial');
        if (query.get('state') === 'downloads') this.toggleDownloads(true);
      });
    },
    get selected() { return this.instances.find(instance => instance.id === this.selectedId); },
    get launchState() { return this.selected.running ? 'running' : this.preparingId === this.selectedId ? 'preparing' : 'idle'; },
    get filteredInstances() {
      let items = this.instances.filter(instance => instance.name.toLowerCase().includes(this.search.toLowerCase()));
      if (this.sourceFilter !== 'all') items = items.filter(instance => instance.source === this.sourceFilter);
      if (this.groupFilter !== 'all') items = items.filter(instance => instance.group === this.groupFilter);
      if (this.instanceFilter === '收藏') items = items.filter(instance => instance.favorite);
      if (this.instanceFilter === '已关联') items = items.filter(instance => instance.source !== 'local');
      return this.reverseOrder ? [...items].reverse() : items;
    },
    get visibleServers() { return this.serverFilter === '运行中' ? this.servers.filter(server => server.running) : this.servers; },
    get filteredMessages() { return this.messages.filter(message => (message.text + message.player).includes(this.chatSearch)); },
    get activeTasks() { return this.tasks.filter(task => !task.paused).length; },
    avatarFor(name) {
      const identities = { '123KrF2': 1, 'Na2PtCl6': 2, 'Blackscience': 3, 'Noflower': 4, 'Remnant': 5 };
      return 'assets/avatar-' + (identities[name] || 1) + '.svg';
    },
    async setPage(page) {
      if (this.page === page || !['chat',...this.navigation.map(item=>item.id)].includes(page)) return;
      const epoch = ++this.navigationEpoch;
      const stage = document.querySelector('.page-stage');
      if (!DeeraftMotion.reduced()) {
        await stage.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 80, easing: 'cubic-bezier(.34,.8,.34,1)' }).finished;
      }
      if (epoch !== this.navigationEpoch) return;
      this.page = page;
      this.$nextTick(() => {
        if (!DeeraftMotion.reduced()) stage.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 150, easing: 'cubic-bezier(.34,.8,.34,1)' });
      });
    },
    setTheme(theme) {
      this.theme = theme === 'dark' ? 'dark' : 'light';
      document.documentElement.dataset.theme = this.theme;
    },
    toggleTheme() { this.setTheme(this.theme === 'dark' ? 'light' : 'dark'); },
    toggleMotion() {
      this.reducedMotion = !this.reducedMotion;
      document.documentElement.dataset.motion = this.reducedMotion ? 'reduced' : 'full';
    },
    selectInstance(id) {
      if (this.selectedId === id) return;
      this.selectedId = id;
      this.instanceMenu = false;
      this.$nextTick(() => {
        if (!DeeraftMotion.reduced()) document.querySelector('.instance-title').animate([{ opacity: 0 }, { opacity: 1 }], { duration: 150 });
      });
    },
    selectTab(tab) {
      if (tab === this.detailTab) return;
      const tabs = ['概览', '模组', '世界', '截图', '日志'];
      const direction = tabs.indexOf(tab) > tabs.indexOf(this.detailTab) ? 1 : -1;
      this.detailTab = tab;
      this.$nextTick(() => {
        if (!DeeraftMotion.reduced()) document.querySelector('.detail-tab-body').animate([
          { transform: `translateX(${direction * 24}px)` }, { transform: 'translateX(0)' }
        ], { duration: 300, easing: 'cubic-bezier(.2,0,0,1)' });
      });
    },
    launch(mode) {
      const instance = this.selected;
      if (instance.running) {
        instance.running = false;
        this.showToast('游戏已结束');
        return;
      }
      if (this.preparingId) return;
      this.preparingId = instance.id;
      setTimeout(() => {
        instance.running = true;
        this.preparingId = '';
        const event = {id:crypto.randomUUID(),player:'Na2PtCl6',instance:instance.name,time:new Date().toLocaleTimeString('zh-CN',{hour:'2-digit',minute:'2-digit'})};
        this.activity.unshift(event);
        this.activity = this.activity.slice(0, 5);
        this.showToast(event.player+' 启动了 '+event.instance);
        this.toastAction = '查看';
      }, 2200);
    },
    async joinCommunityServer() { await this.joinServer('community'); },
    linkedName(key) { return this.instances.find(item=>item.id===this.serverLinks[key])?.name || '未关联实例'; },
    openAssociation(key) {
      this.associationKey = key;
      this.associationDraft = this.serverLinks[key] || '';
      this.associationOpen = true;
      this.formError = '';
    },
    saveConfig() {
      if(this.statusDemo)return true;
      try {
        localStorage.setItem('deeraft-design-server-config', JSON.stringify({links:this.serverLinks,servers:this.thirdPartyServers}));
        this.storageError = ''; return true;
      } catch { this.storageError = '无法保存配置，请检查浏览器存储权限'; this.formError = this.storageError; return false; }
    },
    saveAssociation() {
      const previous = {...this.serverLinks};
      this.serverLinks[this.associationKey] = this.associationDraft;
      if (!this.saveConfig()) { this.serverLinks = previous; return; }
      this.associationOpen = false;
      this.showToast('关联已保存');
    },
    async joinServer(key) {
      const instance = this.instances.find(item => item.id === this.serverLinks[key]);
      if (!instance) { this.openAssociation(key); return; }
      if (this.preparingId || instance.running) { this.showToast(instance.running?'该实例正在运行，请在游戏内加入服务器':'正在准备实例，请稍候'); return; }
      this.search = ''; this.sourceFilter = 'all'; this.groupFilter = 'all'; this.instanceFilter = '全部';
      this.selectInstance(instance.id);
      await this.setPage('launcher');
      this.launch('join');
    },
    statusFor(id) { return this.serverStatuses[id] || {state:'unknown',label:'未检测',version:null,players:null,latency:null,updated:''}; },
    refreshServerStatus(id) {
      if(this.statusFor(id).state==='checking')return;
      const request=crypto.randomUUID(); this.statusRequests[id]=request;
      const previous=this.statusFor(id);
      this.serverStatuses[id]={...previous,state:'checking',label:'检测中',updated:''};
      // Design-only transition. The HTML prototype cannot open Minecraft TCP sockets.
      setTimeout(() => {
        if(this.statusRequests[id]!==request || !this.thirdPartyServers.some(server=>server.id===id))return;
        this.serverStatuses[id]={state:'unavailable',label:'查询失败',version:null,players:null,latency:null,updated:'可重试'};
        this.$nextTick(() => DeeraftMotion.feedback(document.querySelector(`[data-motion-key="${id}"] .ping-badge`)));
      }, 900);
    },
    openThirdParty(server) {
      this.thirdPartyDraft = server ? {...server,instanceId:this.serverLinks[server.id]||''} : {id:'',name:'',address:'',instanceId:''};
      this.formError = ''; this.thirdPartyOpen = true;
    },
    saveThirdParty() {
      const value = this.thirdPartyDraft;
      if (!value.name.trim() || !value.address.trim() || /\s|[\/]/.test(value.address)) { this.formError = '请填写名称和有效服务器地址（域名或 IP，可含端口）'; return; }
      const previousServers = [...this.thirdPartyServers], previousLinks = {...this.serverLinks};
      const id = value.id || crypto.randomUUID();
      const server = {id, name:value.name.trim(),address:value.address.trim()};
      this.thirdPartyServers = [...this.thirdPartyServers.filter(item=>item.id!==id), server];
      this.serverLinks[id] = value.instanceId;
      if (!this.saveConfig()) { this.thirdPartyServers=previousServers; this.serverLinks=previousLinks; return; }
      if (!value.id || previousServers.find(server=>server.id===id)?.address!==server.address) { delete this.serverStatuses[id]; delete this.statusRequests[id]; }
      DeeraftMotion.captureList(document.querySelector('.third-party-list'));
      this.thirdPartyOpen = false; this.showToast('服务器已保存');
      this.$nextTick(() => requestAnimationFrame(() => DeeraftMotion.settleList(document.querySelector('.third-party-list'))));
    },
    removeThirdParty(id) {
      DeeraftMotion.captureList(document.querySelector('.third-party-list'));
      const previousServers=[...this.thirdPartyServers], previousLinks={...this.serverLinks};
      this.thirdPartyServers=this.thirdPartyServers.filter(item=>item.id!==id); delete this.serverLinks[id];
      if (!this.saveConfig()) { this.thirdPartyServers=previousServers; this.serverLinks=previousLinks; this.showToast(this.storageError); }
      else { delete this.statusRequests[id]; delete this.serverStatuses[id]; }
      this.$nextTick(() => requestAnimationFrame(() => DeeraftMotion.settleList(document.querySelector('.third-party-list'))));
    },
    toggleDownloads(force) {
      this.downloadsOpen = typeof force === 'boolean' ? force : !this.downloadsOpen;
      this.$nextTick(() => this.downloadSpring.to(this.downloadsOpen ? 0 : 100));
    },
    openSettings(tab = 'appearance') {
      this.settingsTab = tab;
      this.settingsOpen = true;
    },
    openPrism(title) {
      this.prismWindow = title;
      this.instanceMenu = false;
      this.launchMenu = false;
    },
    openConsole(name) { this.consoleName = name; this.consoleOpen = true; },
    closePanels() {
      this.associationOpen = false; this.thirdPartyOpen = false; this.sourcesOpen = false;
      this.settingsOpen = false;
      this.prismWindow = '';
      this.consoleOpen = false;
      this.imagePreview = '';
      this.instanceMenu = false;
      this.launchMenu = false;
      this.libraryMenu = false;
      if (this.downloadsOpen) this.toggleDownloads(false);
    },
    async copyAddress() {
      try { await navigator.clipboard.writeText('mc.ainfinitythecoder.cn'); this.showToast('服务器地址已复制'); }
      catch { this.showToast('mc.ainfinitythecoder.cn'); }
    },
    showToast(message) {
      clearTimeout(this.toastTimer);
      this.toastAction = '';
      this.toast = message;
      this.toastTimer = setTimeout(() => { this.toast = ''; }, 5000);
    }
  }));
});
