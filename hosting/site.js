const menuButton = document.querySelector('.menu-button');
const mobileMenu = document.querySelector('#mobile-menu');

if (menuButton && mobileMenu) {
  menuButton.addEventListener('click', () => {
    const expanded = menuButton.getAttribute('aria-expanded') === 'true';
    menuButton.setAttribute('aria-expanded', String(!expanded));
    mobileMenu.hidden = expanded;
  });

  mobileMenu.querySelectorAll('a').forEach((link) => {
    link.addEventListener('click', () => {
      menuButton.setAttribute('aria-expanded', 'false');
      mobileMenu.hidden = true;
    });
  });
}

if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
  const stage = document.querySelector('.device-stage');
  const phones = document.querySelectorAll('.phone');

  if (stage && phones.length) {
    let frame = null;
    stage.addEventListener('pointermove', (event) => {
      if (window.innerWidth < 981) return;
      const rect = stage.getBoundingClientRect();
      const x = (event.clientX - rect.left) / rect.width - 0.5;
      const y = (event.clientY - rect.top) / rect.height - 0.5;

      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        phones.forEach((phone, index) => {
          const depth = index === 1 ? 9 : 5;
          phone.style.translate = `${x * depth}px ${y * depth}px`;
        });
      });
    });

    stage.addEventListener('pointerleave', () => {
      phones.forEach((phone) => { phone.style.translate = ''; });
    });
  }
}

/* Plaqa: How-it-works screen switching */

const howSteps = [...document.querySelectorAll('.how-step')];
const howScreen = document.querySelector('#how-screen');

if (howSteps.length && howScreen) {
  const activateStep = (step) => {
    if (step.classList.contains('is-active')) return;

    howSteps.forEach((item) => item.classList.remove('is-active'));
    step.classList.add('is-active');

    const nextScreen = step.dataset.screen;
    if (!nextScreen) return;

    howScreen.classList.add('is-switching');

    window.setTimeout(() => {
      howScreen.src = `/assets/site/${nextScreen}`;
      howScreen.classList.remove('is-switching');
    }, 180);
  };

  howSteps.forEach((step) => {
    step.addEventListener('mouseenter', () => activateStep(step));
    step.addEventListener('click', () => activateStep(step));
  });

  if ('IntersectionObserver' in window) {
    const observer = new IntersectionObserver(
      (entries) => {
        entries
          .filter((entry) => entry.isIntersecting)
          .sort((a, b) => b.intersectionRatio - a.intersectionRatio)
          .slice(0, 1)
          .forEach((entry) => activateStep(entry.target));
      },
      {
        threshold: [0.45, 0.6, 0.75],
        rootMargin: '-18% 0px -28% 0px'
      }
    );

    howSteps.forEach((step) => observer.observe(step));
  }
}

/* ===== plaqa brand word renderer ===== */

function applyPlaqaBranding() {
  const walker = document.createTreeWalker(
    document.body,
    NodeFilter.SHOW_TEXT,
    {
      acceptNode(node) {
        if (!node.nodeValue || !/\bplaqa\b/i.test(node.nodeValue)) {
          return NodeFilter.FILTER_REJECT;
        }

        const parent = node.parentElement;

        if (!parent) {
          return NodeFilter.FILTER_REJECT;
        }

        if (
          parent.closest('.plaqa-word') ||
          ['SCRIPT', 'STYLE', 'NOSCRIPT'].includes(parent.tagName)
        ) {
          return NodeFilter.FILTER_REJECT;
        }

        return NodeFilter.FILTER_ACCEPT;
      }
    }
  );

  const nodes = [];

  while (walker.nextNode()) {
    nodes.push(walker.currentNode);
  }

  nodes.forEach((node) => {
    const pieces = node.nodeValue.split(/(\bplaqa\b)/ig);
    const fragment = document.createDocumentFragment();

    pieces.forEach((piece) => {
      if (/^plaqa$/i.test(piece)) {
        const word = document.createElement('span');
        word.className = 'plaqa-word';
        word.setAttribute('aria-label', 'plaqa');

        const letters = [
          ['p', 'plaqa-blue'],
          ['l', 'plaqa-blue'],
          ['a', 'plaqa-blue'],
          ['q', 'plaqa-orange'],
          ['a', 'plaqa-blue']
        ];

        letters.forEach(([letter, className]) => {
          const span = document.createElement('span');
          span.className = className;
          span.textContent = letter;
          span.setAttribute('aria-hidden', 'true');
          word.appendChild(span);
        });

        fragment.appendChild(word);
      } else {
        fragment.appendChild(document.createTextNode(piece));
      }
    });

    node.replaceWith(fragment);
  });
}

applyPlaqaBranding();


/* =========================================================
   plaqa — SUBTLE DEVICE PARALLAX
   ========================================================= */

(() => {
  const stage = document.querySelector('.device-stage');
  const left = document.querySelector('.phone-left');
  const center = document.querySelector('.phone-center');
  const right = document.querySelector('.phone-right');

  if (!stage || !left || !center || !right) return;

  if (
    window.matchMedia('(prefers-reduced-motion: reduce)').matches ||
    window.matchMedia('(pointer: coarse)').matches
  ) {
    return;
  }

  let targetX = 0;
  let targetY = 0;
  let currentX = 0;
  let currentY = 0;

  const update = () => {
    currentX += (targetX - currentX) * 0.065;
    currentY += (targetY - currentY) * 0.065;

    left.style.translate =
      `${currentX * -7}px ${currentY * -4}px`;

    center.style.translate =
      `${currentX * 5}px ${currentY * 3}px`;

    right.style.translate =
      `${currentX * 8}px ${currentY * -3}px`;

    requestAnimationFrame(update);
  };

  stage.addEventListener('pointermove', (event) => {
    const rect = stage.getBoundingClientRect();

    targetX =
      ((event.clientX - rect.left) / rect.width - .5) * 2;

    targetY =
      ((event.clientY - rect.top) / rect.height - .5) * 2;
  });

  stage.addEventListener('pointerleave', () => {
    targetX = 0;
    targetY = 0;
  });

  update();
})();


/* =========================================================
   plaqa — SUBTLE DEVICE PARALLAX
   ========================================================= */

(() => {
  const stage = document.querySelector('.device-stage');
  const left = document.querySelector('.phone-left');
  const center = document.querySelector('.phone-center');
  const right = document.querySelector('.phone-right');

  if (!stage || !left || !center || !right) return;

  if (
    window.matchMedia('(prefers-reduced-motion: reduce)').matches ||
    window.matchMedia('(pointer: coarse)').matches
  ) {
    return;
  }

  let targetX = 0;
  let targetY = 0;
  let currentX = 0;
  let currentY = 0;

  const update = () => {
    currentX += (targetX - currentX) * 0.065;
    currentY += (targetY - currentY) * 0.065;

    left.style.translate =
      `${currentX * -7}px ${currentY * -4}px`;

    center.style.translate =
      `${currentX * 5}px ${currentY * 3}px`;

    right.style.translate =
      `${currentX * 8}px ${currentY * -3}px`;

    requestAnimationFrame(update);
  };

  stage.addEventListener('pointermove', (event) => {
    const rect = stage.getBoundingClientRect();

    targetX =
      ((event.clientX - rect.left) / rect.width - .5) * 2;

    targetY =
      ((event.clientY - rect.top) / rect.height - .5) * 2;
  });

  stage.addEventListener('pointerleave', () => {
    targetX = 0;
    targetY = 0;
  });

  update();
})();


/* =========================================================
   plaqa — 3D LIGHT PARALLAX V2
   bewegt die Bühne statt die einzelnen transform-Werte
   ========================================================= */

(() => {
  const stage = document.querySelector('.device-stage');

  if (!stage) return;

  if (
    window.matchMedia('(prefers-reduced-motion: reduce)').matches ||
    window.matchMedia('(pointer: coarse)').matches
  ) {
    return;
  }

  let tx = 0;
  let ty = 0;
  let cx = 0;
  let cy = 0;

  stage.addEventListener('pointermove', (event) => {
    const rect = stage.getBoundingClientRect();

    tx = ((event.clientX - rect.left) / rect.width - .5);
    ty = ((event.clientY - rect.top) / rect.height - .5);
  });

  stage.addEventListener('pointerleave', () => {
    tx = 0;
    ty = 0;
  });

  const render = () => {
    cx += (tx - cx) * .055;
    cy += (ty - cy) * .055;

    stage.style.setProperty(
      '--mouse-x',
      `${cx * 12}px`
    );

    stage.style.setProperty(
      '--mouse-y',
      `${cy * 8}px`
    );

    requestAnimationFrame(render);
  };

  render();
})();


/* ===== PLAQA SHOWCASE JS START ===== */

(() => {
  const showcase = document.querySelector('#plaqa-showcase');

  if (!showcase) return;

  if (
    window.matchMedia('(prefers-reduced-motion: reduce)').matches ||
    window.matchMedia('(pointer: coarse)').matches
  ) {
    return;
  }

  let targetX = 0;
  let targetY = 0;

  let currentX = 0;
  let currentY = 0;

  showcase.addEventListener('pointermove', (event) => {
    const rect = showcase.getBoundingClientRect();

    targetX =
      ((event.clientX - rect.left) / rect.width - 0.5) * 2;

    targetY =
      ((event.clientY - rect.top) / rect.height - 0.5) * 2;
  });

  showcase.addEventListener('pointerleave', () => {
    targetX = 0;
    targetY = 0;
  });

  const animate = () => {
    currentX += (targetX - currentX) * 0.055;
    currentY += (targetY - currentY) * 0.055;

    showcase.style.setProperty(
      '--showcase-x',
      `${currentX * 8}px`
    );

    showcase.style.setProperty(
      '--showcase-y',
      `${currentY * 5}px`
    );

    showcase.style.setProperty(
      '--showcase-tilt-x',
      `${currentX * 3.2}deg`
    );

    showcase.style.setProperty(
      '--showcase-tilt-y',
      `${currentY * 2.1}deg`
    );

    requestAnimationFrame(animate);
  };

  animate();
})();

/* ===== PLAQA SHOWCASE JS END ===== */


/* ===== PLAQA DEVICE ZONES V3 START ===== */

(() => {

  const showcase =
    document.querySelector('#plaqa-showcase');

  if (!showcase) return;


  /*
    WICHTIG:
    Wir reagieren NICHT mehr auf die bewegten Handys.

    Stattdessen wird die feste Fläche des Hero-Bereichs
    in drei unsichtbare Zonen geteilt.

    Links   = Melden
    Mitte   = Suche
    Rechts  = Anfrage
  */


  showcase.dataset.focus = 'center';


  let active = 'center';


  const setActive = (next) => {

    if (next === active) return;

    active = next;

    showcase.dataset.focus = next;

  };


  showcase.addEventListener(
    'pointermove',
    (event) => {

      /*
        Auf Touch-Geräten nichts machen.
      */

      if (event.pointerType === 'touch') {
        return;
      }


      const rect =
        showcase.getBoundingClientRect();


      const relativeX =
        (event.clientX - rect.left) /
        rect.width;


      /*
        HYSTERESE:
        Zwischen den Zonen bleiben kleine tote Bereiche.

        Dadurch springt das Gerät nicht,
        wenn die Maus genau an einer Grenze steht.
      */


      if (active === 'left') {

        if (relativeX > 0.40) {
          setActive('center');
        }

        return;
      }


      if (active === 'right') {

        if (relativeX < 0.60) {
          setActive('center');
        }

        return;
      }


      /*
        Aktuell Mitte:
        Erst deutlich links/rechts wechseln.
      */

      if (relativeX < 0.30) {

        setActive('left');

      } else if (relativeX > 0.70) {

        setActive('right');

      } else {

        setActive('center');

      }

    }
  );


  showcase.addEventListener(
    'pointerleave',
    () => {

      setActive('center');

    }
  );


  /*
    Optional:
    Klick fixiert ebenfalls sauber das Gerät,
    solange die Maus über der jeweiligen Zone ist.
  */

  showcase.addEventListener(
    'click',
    (event) => {

      const rect =
        showcase.getBoundingClientRect();

      const relativeX =
        (event.clientX - rect.left) /
        rect.width;


      if (relativeX < 0.33) {

        setActive('left');

      } else if (relativeX > 0.67) {

        setActive('right');

      } else {

        setActive('center');

      }

    }
  );

})();

/* ===== PLAQA DEVICE ZONES V3 END ===== */


/* ===== PLAQA VEHICLE SECTION JS START ===== */

(() => {

  const tabs =
    [...document.querySelectorAll('.vehicle-tab')];

  const screen =
    document.querySelector('#vehicle-screen');

  if (!tabs.length || !screen) return;


  /*
    Bilder vorladen, damit beim Wechsel nichts flackert.
  */

  tabs.forEach((tab) => {

    const src =
      tab.dataset.vehicleScreen;

    if (!src) return;

    const image = new Image();

    image.src =
      `/assets/site/${src}`;

  });


  const activate = (tab) => {

    if (tab.classList.contains('is-active')) {
      return;
    }


    tabs.forEach((item) =>
      item.classList.remove('is-active')
    );


    tab.classList.add('is-active');


    const next =
      tab.dataset.vehicleScreen;

    const alt =
      tab.dataset.vehicleAlt || 'plaqa Fahrzeugprofil';


    if (!next) return;


    screen.classList.add('is-switching');


    window.setTimeout(() => {

      screen.src =
        `/assets/site/${next}`;

      screen.alt =
        alt;

      screen.classList.remove('is-switching');

    }, 170);

  };


  tabs.forEach((tab) => {

    tab.addEventListener(
      'mouseenter',
      () => activate(tab)
    );

    tab.addEventListener(
      'click',
      () => activate(tab)
    );

  });

})();

/* ===== PLAQA VEHICLE SECTION JS END ===== */


/* ===== PLAQA HINTS SECTION JS START ===== */

(() => {

  const categories =
    [...document.querySelectorAll('.hint-category')];

  const title =
    document.querySelector('#hint-preview-title');

  const text =
    document.querySelector('#hint-preview-text');

  if (!categories.length || !title || !text) {
    return;
  }


  const activate = (category) => {

    categories.forEach((item) =>
      item.classList.remove('is-active')
    );


    category.classList.add('is-active');


    title.textContent =
      category.dataset.hintTitle || 'Hinweis';


    text.textContent =
      category.dataset.hintText || '';

  };


  categories.forEach((category) => {

    category.addEventListener(
      'mouseenter',
      () => activate(category)
    );


    category.addEventListener(
      'click',
      () => activate(category)
    );

  });

})();

/* ===== PLAQA HINTS SECTION JS END ===== */


/* ===== PLAQA COMMUNITY JS START ===== */

(() => {

  const tabs =
    [...document.querySelectorAll('.community-tab')];

  const screen =
    document.querySelector('#community-screen');

  const title =
    document.querySelector('#community-feature-title');

  const text =
    document.querySelector('#community-feature-text');


  if (!tabs.length || !screen || !title || !text) {
    return;
  }


  const activate = (tab) => {

    tabs.forEach((item) =>
      item.classList.remove('is-active')
    );


    tab.classList.add('is-active');


    const next =
      tab.dataset.communityScreen;


    title.textContent =
      tab.dataset.communityTitle || 'Community';


    text.textContent =
      tab.dataset.communityCopy || '';


    if (!next) {
      return;
    }


    screen.classList.add('is-switching');


    window.setTimeout(() => {

      screen.src =
        `/assets/site/${next}`;

      screen.alt =
        `plaqa ${tab.dataset.communityTitle || 'Community'}`;

      screen.classList.remove('is-switching');

    }, 150);

  };


  tabs.forEach((tab) => {

    tab.addEventListener(
      'mouseenter',
      () => activate(tab)
    );


    tab.addEventListener(
      'click',
      () => activate(tab)
    );

  });

})();

/* ===== PLAQA COMMUNITY JS END ===== */


/* ===== PLAQA SECURITY JS START ===== */

(() => {

  const tabs =
    [...document.querySelectorAll('.security-tab')];

  const screen =
    document.querySelector('#security-screen');

  const title =
    document.querySelector('#security-feature-title');

  const text =
    document.querySelector('#security-feature-text');


  if (!tabs.length || !screen || !title || !text) {
    return;
  }


  /*
    Screens vorladen
  */

  tabs.forEach((tab) => {

    const src =
      tab.dataset.securityScreen;

    if (!src) return;

    const image =
      new Image();

    image.src =
      `/assets/site/${src}`;

  });


  const activate = (tab) => {

    tabs.forEach((item) =>
      item.classList.remove('is-active')
    );


    tab.classList.add('is-active');


    title.textContent =
      tab.dataset.securityTitle || 'Sicherheit';


    text.textContent =
      tab.dataset.securityCopy || '';


    const next =
      tab.dataset.securityScreen;


    if (!next) return;


    screen.classList.add('is-switching');


    window.setTimeout(() => {

      screen.src =
        `/assets/site/${next}`;

      screen.alt =
        `plaqa ${tab.dataset.securityTitle || 'Sicherheit'}`;

      screen.classList.remove('is-switching');

    }, 150);

  };


  tabs.forEach((tab) => {

    tab.addEventListener(
      'mouseenter',
      () => activate(tab)
    );


    tab.addEventListener(
      'click',
      () => activate(tab)
    );

  });

})();

/* ===== PLAQA SECURITY JS END ===== */


/* ===== PLAQA FAQ JS START ===== */

(() => {

  const items =
    [...document.querySelectorAll('.faq-item')];


  if (!items.length) {
    return;
  }


  const openItem = (target) => {

    items.forEach((item) => {

      const button =
        item.querySelector('.faq-question');


      const isTarget =
        item === target;


      item.classList.toggle(
        'is-open',
        isTarget
      );


      if (button) {

        button.setAttribute(
          'aria-expanded',
          isTarget ? 'true' : 'false'
        );

      }

    });

  };


  items.forEach((item) => {

    const button =
      item.querySelector('.faq-question');


    if (!button) return;


    button.addEventListener(
      'click',
      () => {

        /*
          Wenn offen geklickt wird:
          darf die Antwort wieder geschlossen werden.
        */

        if (item.classList.contains('is-open')) {

          item.classList.remove('is-open');

          button.setAttribute(
            'aria-expanded',
            'false'
          );

          return;

        }


        openItem(item);

      }
    );

  });

})();

/* ===== PLAQA FAQ JS END ===== */