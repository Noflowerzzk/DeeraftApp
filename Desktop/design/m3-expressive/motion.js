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
  window.DeeraftMotion = { Spring, tokens, reduced };
})();
