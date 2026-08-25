(() => {
  const header = document.querySelector('[data-site-header]');
  const menuButton = document.querySelector('.menu-button');
  const mobileNavigation = document.querySelector('#mobile-navigation');
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  const setHeaderState = () => {
    header?.classList.toggle('is-scrolled', window.scrollY > 12);
  };

  setHeaderState();
  window.addEventListener('scroll', setHeaderState, { passive: true });

  const closeMenu = () => {
    if (!menuButton || !mobileNavigation) return;
    menuButton.setAttribute('aria-expanded', 'false');
    menuButton.setAttribute('aria-label', 'Menü öffnen');
    mobileNavigation.hidden = true;
  };

  menuButton?.addEventListener('click', () => {
    if (!mobileNavigation) return;
    const willOpen = menuButton.getAttribute('aria-expanded') !== 'true';
    menuButton.setAttribute('aria-expanded', String(willOpen));
    menuButton.setAttribute('aria-label', willOpen ? 'Menü schließen' : 'Menü öffnen');
    mobileNavigation.hidden = !willOpen;
  });

  mobileNavigation?.querySelectorAll('a').forEach((link) => {
    link.addEventListener('click', closeMenu);
  });

  window.addEventListener('resize', () => {
    if (window.innerWidth > 820) closeMenu();
  });

  const workflowButtons = [...document.querySelectorAll('.workflow-item')];
  const workflowImage = document.querySelector('[data-workflow-image]');

  workflowButtons.forEach((button) => {
    button.addEventListener('click', () => {
      const image = button.dataset.image;
      const alt = button.dataset.alt;
      if (!image || !workflowImage) return;

      workflowButtons.forEach((item) => item.classList.toggle('is-active', item === button));
      workflowImage.src = `/assets/site/${image}`;
      workflowImage.alt = alt || 'plaqa App-Vorschau';
    });
  });

  document.querySelectorAll('.faq-item > button').forEach((button) => {
    button.addEventListener('click', () => {
      const item = button.closest('.faq-item');
      if (!item) return;
      const shouldOpen = !item.classList.contains('is-open');

      document.querySelectorAll('.faq-item').forEach((entry) => {
        entry.classList.remove('is-open');
        entry.querySelector('button')?.setAttribute('aria-expanded', 'false');
      });

      if (shouldOpen) {
        item.classList.add('is-open');
        button.setAttribute('aria-expanded', 'true');
      }
    });
  });

  const previewTrack = document.querySelector('[data-preview-track]');
  const movePreviewTrack = (direction) => {
    if (!previewTrack) return;
    const firstItem = previewTrack.querySelector('figure');
    const distance = firstItem ? firstItem.getBoundingClientRect().width + 18 : 320;
    previewTrack.scrollBy({ left: distance * direction, behavior: reduceMotion ? 'auto' : 'smooth' });
  };

  document.querySelector('[data-gallery-prev]')?.addEventListener('click', () => movePreviewTrack(-1));
  document.querySelector('[data-gallery-next]')?.addEventListener('click', () => movePreviewTrack(1));

  const navLinks = [...document.querySelectorAll('.desktop-nav a')];
  const sectionIds = navLinks.map((link) => link.getAttribute('href')).filter((href) => href?.startsWith('#'));
  const sections = sectionIds.map((id) => document.querySelector(id)).filter(Boolean);

  if ('IntersectionObserver' in window && sections.length) {
    const navigationObserver = new IntersectionObserver((entries) => {
      const visible = entries
        .filter((entry) => entry.isIntersecting)
        .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
      if (!visible) return;
      navLinks.forEach((link) => {
        link.classList.toggle('is-active', link.getAttribute('href') === `#${visible.target.id}`);
      });
    }, { rootMargin: '-25% 0px -60%', threshold: [0.1, 0.35] });
    sections.forEach((section) => navigationObserver.observe(section));
  }

})();
