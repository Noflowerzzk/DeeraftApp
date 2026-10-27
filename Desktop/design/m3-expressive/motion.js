/* M3 motion physics: values verified against the site's public spring tokens.
 * Spatial motion may overshoot; effects are critically damped.
 * Each spring retains its velocity when retargeted. No continuous decorative animation.
 */
(() => {
  const tokens = {
    fastSpatial: { stiffness: 800, damping: 0.6 },
    defaultSpatial: { stiffness: 380, damping: 0.8 },
    slowSpatial: { stiffness: 200, damping: 0.8 },
    fastEffects: { stiffness: 3800, damping: 1 },
    defaultEffects: { stiffness: 1600, damping: 1 },
    slowEffects: { stiffness: 800, damping: 1 }
  };
  const reduced = () => matchMedia('(prefers-reduced-motion: reduce)').matches || document.documentElement.dataset.motion === 'reduced';
  class Spring {
    constructor(value, update, token = 'fastSpatial') {
      this.value = value;
      this.target = value;
      this.velocity = 0;
      this.update = update;
      this.token = tokens[token];
      this.frame = 0;
      this.lastTime = 0;
    }
    to(target) {
      this.target = target;
      if (reduced()) {
        cancelAnimationFrame(this.frame);
        this.frame = 0;
        this.value = target;
        this.velocity = 0;
        this.update(target);
        return;
      }
      if (!this.frame) {
        this.lastTime = performance.now();
        this.frame = requestAnimationFrame(time => this.tick(time));
      }
    }
    tick(time) {
      if(reduced()){this.value=this.target;this.velocity=0;this.update(this.target);this.frame=0;return;}
      let remaining = Math.min((time - this.lastTime) / 1000, 0.05);
      this.lastTime = time;
      const stiffness = this.token.stiffness;
      const drag = 2 * this.token.damping * Math.sqrt(stiffness);
      while (remaining > 0) {
        const step = Math.min(remaining, 1 / 240);
        this.velocity += (-stiffness * (this.value - this.target) - drag * this.velocity) * step;
        this.value += this.velocity * step;
        remaining -= step;
      }
      this.update(this.value);
      if (Math.abs(this.value - this.target) < 0.001 && Math.abs(this.velocity) < 0.01) {
        this.value = this.target;
        this.velocity = 0;
        this.update(this.target);
        this.frame = 0;
      } else this.frame = requestAnimationFrame(next => this.tick(next));
    }
  }
  const springs = new WeakMap();
  function press(element, down) {
    let spring = springs.get(element);
    if (!spring) {
      spring = new Spring(1, value => { element.style.scale = value; });
      springs.set(element, spring);
    }
    spring.to(down ? 0.975 : 1);
  }
  document.addEventListener('pointerdown', event => {
    const button = event.target.closest('.button,.launch-primary,.launch-options,.rail-fab,.icon-button');
    if (!button || button.disabled) return;
    press(button, true);
    const release = () => {
      press(button, false);
      window.removeEventListener('pointerup', release);
      window.removeEventListener('pointercancel', release);
    };
    window.addEventListener('pointerup', release, { once: true });
    window.addEventListener('pointercancel', release, { once: true });
  });
  const disclosures = new WeakMap();
  function disclose(element, open) {
    if(!element)return;
    let state=disclosures.get(element);
    if(!state){
      state={open:false};
      state.spatial=new Spring(0,value=>{
        element.style.transform=`translateY(${8*(1-value)}px)`;
        element.style.clipPath=value===1?'none':`inset(0 0 ${Math.max(0,1-value)*100}% 0 round 12px)`;
        if(!state.open && value===0)element.style.visibility='hidden';
      },'fastSpatial');
      state.effects=new Spring(0,value=>element.style.opacity=Math.max(0,Math.min(1,value)),'fastEffects');
      disclosures.set(element,state);
    }
    state.open=open;
    if(open)element.style.visibility='visible';
    state.spatial.to(open?1:0);state.effects.to(open?1:0);
  }
  const positions=new WeakMap(), movements=new WeakMap();
  function captureList(list) {
    if(!list)return;
    positions.set(list,new Map([...list.querySelectorAll('[data-motion-key]')].map(element=>[element.dataset.motionKey,element.getBoundingClientRect()])));
  }
  function settleList(list) {
    if(!list)return;
    const before=positions.get(list)||new Map();
    for(const element of list.querySelectorAll('[data-motion-key]')){
      const first=before.get(element.dataset.motionKey);
      element.style.translate='none';
      const last=element.getBoundingClientRect();
      let state=movements.get(element);
      if(!state){
        state={x:new Spring(0,()=>apply(),'fastSpatial'),y:new Spring(0,()=>apply(),'fastSpatial')};
        const apply=()=>{element.style.translate=`${state.x.value}px ${state.y.value}px`;};
        movements.set(element,state);
      }
      state.x.value=first?first.left-last.left:0;state.y.value=first?first.top-last.top:12;
      state.x.update(state.x.value);state.y.update(state.y.value);state.x.to(0);state.y.to(0);
      if(!first)feedback(element);
    }
    positions.delete(list);
  }
  const effects=new WeakMap();
  function feedback(element) {
    if(!element)return;
    let spring=effects.get(element);
    if(!spring){spring=new Spring(.35,value=>element.style.opacity=Math.max(0,Math.min(1,value)),'fastEffects');effects.set(element,spring);}
    else spring.value=.35;
    spring.update(spring.value);spring.to(1);
  }
  function enter(element) {
    if(!element)return;
    const spatial=new Spring(12,value=>element.style.translate=`0 ${value}px`,'defaultSpatial');
    spatial.update(12);spatial.to(0);feedback(element);
  }
  function trackTabs(root) {
    if(!root)return;
    const indicator=document.createElement('span');indicator.className='detail-tab-indicator';indicator.setAttribute('aria-hidden','true');root.append(indicator);
    const x=new Spring(0,value=>indicator.style.left=value+'px','fastSpatial');
    const width=new Spring(0,value=>indicator.style.width=value+'px','fastSpatial');
    let first=true;
    const update=()=>{
      const active=root.querySelector('button.active');if(!active || !root.getBoundingClientRect().width)return;
      const target=active.offsetLeft+active.offsetWidth*.28, size=active.offsetWidth*.44;
      if(first){x.value=target;width.value=size;x.update(target);width.update(size);first=false;}
      x.to(target);width.to(size);
    };
    new ResizeObserver(update).observe(root);
    new MutationObserver(update).observe(root,{subtree:true,attributes:true,attributeFilter:['class']});
    document.fonts.ready.then(update);
    update();
  }
  window.DeeraftMotion = { Spring, tokens, reduced, disclose, captureList, settleList, feedback, enter, trackTabs };
})();
