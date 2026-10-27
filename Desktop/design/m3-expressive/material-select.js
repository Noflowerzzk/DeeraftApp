/* M3 select-only combobox: local listbox, keyboard support, no native popup. */
document.addEventListener('alpine:init', () => {
  let nextId = 0;
  Alpine.data('materialSelect', options => ({
    value: 'all', open: false, active: 'all', options, menuId: 'material-options-'+(++nextId), typed: '', typedTimer: 0,
    get selectedLabel() { return this.options().find(option => option.value===this.value)?.label || ''; },
    init() { this.$watch('libraryMenu', open => { if(open)this.close(false); }); },
    toggle() { this.open ? this.close(true) : this.focusOption(0); },
    focusOption(direction) {
      this.libraryMenu=false;
      this.$dispatch('select-open',{id:this.menuId});
      this.$refs.trigger.focus({preventScroll:true});
      this.open=true;
      const options=this.options();
      this.active=direction==='first'?options[0].value:direction==='last'?options.at(-1).value:this.value;
      this.$nextTick(() => { if(this.open){this.focusActive();} });
    },
    focusActive() { if(!this.open)return; [...this.$refs.menu.querySelectorAll('[role=option]')].find(item=>item.dataset.value===this.active)?.focus({preventScroll:true}); },
    move(direction) {
      if(!this.open)return;
      const items=this.options(); const index=items.findIndex(option=>option.value===this.active);
      this.active=items[direction==='first'?0:direction==='last'?items.length-1:(index+direction+items.length)%items.length].value;
      this.$nextTick(() => this.focusActive());
    },
    choose(value) {
      this.value=value; this.close(true);
    },
    close(restoreFocus) { this.open=false; if(restoreFocus)this.$refs.trigger.focus({preventScroll:true}); },
    typeahead(event) {
      if(event.key.length!==1 || event.ctrlKey || event.metaKey || event.altKey || event.key===' ')return;
      clearTimeout(this.typedTimer); this.typed+=event.key.toLowerCase();
      this.typedTimer=setTimeout(()=>this.typed='',600);
      const option=this.options().find(option=>option.label.toLowerCase().startsWith(this.typed));
      if(option){this.active=option.value;this.$nextTick(()=>this.focusActive());}
    }
  }));
});
