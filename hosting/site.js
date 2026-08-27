import * as THREE from '/vendor/three.module.min.js';

const screens = [
  {
    label: 'Kennzeichensuche',
    title: 'Kennzeichen suchen',
    image: '/assets/site/screen-suche.jpeg',
    cropBottomNavigation: true,
    description: 'Wähle Land und Zulassungsregion, gib das Kennzeichen ein und finde ein registriertes Fahrzeug. Eine Suche allein öffnet noch keinen direkten Kontakt.',
    features: [
      'Kennzeichen in Deutschland, Österreich und der Schweiz suchen',
      'Zulassungsregion und Kennzeichen kontrolliert eingeben',
      'Fahrzeug- und Verifizierungsstatus übersichtlich erkennen',
      'Kontakt erst über eine bewusste Anfrage herstellen',
    ],
  },
  {
    label: 'Fahrzeug melden',
    title: 'Wichtige Hinweise senden',
    image: '/assets/site/screen-melden.jpeg',
    cropBottomNavigation: true,
    description: 'Informiere einen Fahrzeughalter über offene Türen, Licht, Schäden, blockierte Wege oder akute Gefahren. Der Hinweis funktioniert ohne persönlichen Chat.',
    features: [
      'Passende Hinweiskategorie auswählen',
      'Fahrzeug über Land, Region und Kennzeichen zuordnen',
      'Hinweis ohne Ausweis- oder Fahrzeugdokument versenden',
      'Akute Gefahren klar von normalen Hinweisen trennen',
    ],
  },
  {
    label: 'Kontaktanfragen',
    title: 'Kontakt bewusst freigeben',
    image: '/assets/site/screen-anfrage.jpeg',
    cropBottomNavigation: true,
    description: 'Der Empfänger sieht Anlass und Fahrzeugbezug der Anfrage und entscheidet selbst über Annahme oder Ablehnung. Erst danach kann ein privater Chat entstehen.',
    features: [
      'Eingehende und gesendete Anfragen getrennt verwalten',
      'Anlass und Fahrzeugbezug vor der Entscheidung sehen',
      'Anfrage bewusst annehmen oder ablehnen',
      'Direkten Chat ausschließlich nach Zustimmung öffnen',
    ],
  },
  {
    label: 'Private Chats',
    title: 'Privat und bewusst sprechen',
    image: '/assets/site/store-04-private-chats.jpeg',
    sourceQuad: [[445, 352], [784, 347], [640, 1410], [283, 1354]],
    straightenSlopes: [-0.015, -0.04],
    verticalSourceOffset: 0.014,
    description: 'Private Nachrichten setzen eine freigegebene Verbindung voraus. So beginnt ein direkter Austausch erst dann, wenn beide Seiten ihn bewusst zulassen.',
    features: [
      'Private Unterhaltungen nach angenommener Anfrage führen',
      'Nachrichtenstatus und neue Inhalte direkt erkennen',
      'Unerwünschte Kontakte blockieren oder melden',
      'Anfragen und Chats in einer gemeinsamen Ansicht verwalten',
    ],
  },
  {
    label: 'Storys & Feed',
    title: 'Fahrzeugmomente teilen',
    image: '/assets/site/store-05-storys-feed.jpeg',
    sourceQuad: [[449, 411], [784, 408], [642, 1451], [288, 1376]],
    straightenSlopes: [-0.02, -0.09],
    verticalSourceOffset: 0.024,
    description: 'Storys und der persönliche Feed bringen aktuelle Aufnahmen, Beiträge und Reaktionen aus der eigenen Fahrzeug-Community an einen gemeinsamen Ort.',
    features: [
      'Eigene und neue Storys über Profilbilder erkennen',
      'Aktuelle Beiträge gefolgter Profile im Feed sehen',
      'Beiträge liken, kommentieren und auf Kommentare antworten',
      'Inhalte teilen, melden und über die Privatsphäre steuern',
    ],
  },
  {
    label: 'Profil & Beiträge',
    title: 'Profil und Beiträge verbinden',
    image: '/assets/site/community-posts-clean.jpg',
    cropBottomNavigation: true,
    description: 'Das Profil zeigt Beiträge, Community-Verbindungen und das ausgewählte Fahrzeug zusammen. Sichtbare Inhalte bleiben über die Privatsphäre steuerbar.',
    features: [
      'Zwischen persönlichem Feed und eigenem Profil wechseln',
      'Beiträge, Follower und gefolgte Profile überblicken',
      'Profilbild, Standort und Fahrzeugbezug selbst pflegen',
      'Öffentliche Inhalte von privaten Kontodaten trennen',
    ],
  },
  {
    label: 'Fahrzeugprofil',
    title: 'Dein Fahrzeug an einem Ort',
    image: '/assets/site/store-07-fahrzeugprofil.jpeg',
    sourceQuad: [[442, 323], [791, 315], [664, 1396], [294, 1323]],
    straightenSlopes: [0.02, -0.08],
    verticalSourceOffset: 0.014,
    description: 'Präsentiere dein Fahrzeug mit Bild, Modell und zentralen Daten. Das Profil verbindet technische Angaben mit Beiträgen und der eigenen Fahrzeuggeschichte.',
    features: [
      'Hauptfahrzeug auswählen und sichtbar hervorheben',
      'Fahrzeugbild, Modell und Aktivstatus zusammenfassen',
      'Wichtige Eckdaten und Fahrzeuggeschichte bündeln',
      'Weitere Fahrzeuge sauber getrennt verwalten',
    ],
  },
  {
    label: 'Fahrzeugdaten',
    title: 'Technische Daten im Blick',
    image: '/assets/site/store-08-fahrzeugdaten.jpeg',
    sourceQuad: [[449, 408], [783, 405], [656, 1448], [297, 1363]],
    straightenSlopes: [0.02, -0.08],
    verticalSourceOffset: 0.014,
    description: 'Marke, Modell, Baureihe, Baujahr, Motor und Leistung bleiben übersichtlich zusammengefasst und können im eigenen Fahrzeugprofil gepflegt werden.',
    features: [
      'Marke, Modell, Baureihe und Baujahr strukturiert pflegen',
      'Motor, Leistung, Kraftstoff und Karosserie zusammenfassen',
      'Umbauten, Details und wichtige Stationen dokumentieren',
      'Fahrzeugdaten im Profil kontrolliert präsentieren',
    ],
  },
];

(() => {
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  initializeHeaderNavigation();
  initializeDetailPattern();
  initializePhoneStage({reduceMotion});
})();

function initializeHeaderNavigation() {
  const header = document.querySelector('[data-site-header]');
  const menuButton = document.querySelector('.menu-button');
  const mobileNavigation = document.querySelector('#mobile-navigation');
  const links = [...document.querySelectorAll('[data-section-link]')];
  const sections = ['start', 'service']
    .map((id) => document.getElementById(id))
    .filter(Boolean);
  let frameRequested = false;

  const closeMenu = () => {
    if (!menuButton || !mobileNavigation) return;
    menuButton.setAttribute('aria-expanded', 'false');
    menuButton.setAttribute('aria-label', 'Menü öffnen');
    mobileNavigation.hidden = true;
  };

  const updateNavigation = () => {
    frameRequested = false;
    header?.classList.toggle('is-scrolled', window.scrollY > 12);
    const marker = window.scrollY + (header?.offsetHeight || 0) + window.innerHeight * 0.32;
    let activeId = sections[0]?.id || 'start';
    sections.forEach((section) => {
      if (section.offsetTop <= marker) activeId = section.id;
    });
    links.forEach((link) => {
      const active = link.getAttribute('href') === `#${activeId}`;
      link.classList.toggle('is-active', active);
      if (active) link.setAttribute('aria-current', 'page');
      else link.removeAttribute('aria-current');
    });
  };

  const requestNavigationUpdate = () => {
    if (frameRequested) return;
    frameRequested = true;
    requestAnimationFrame(updateNavigation);
  };

  menuButton?.addEventListener('click', () => {
    if (!mobileNavigation) return;
    const willOpen = menuButton.getAttribute('aria-expanded') !== 'true';
    menuButton.setAttribute('aria-expanded', String(willOpen));
    menuButton.setAttribute('aria-label', willOpen ? 'Menü schließen' : 'Menü öffnen');
    mobileNavigation.hidden = !willOpen;
  });
  mobileNavigation?.querySelectorAll('a').forEach((link) => link.addEventListener('click', closeMenu));
  window.addEventListener('scroll', requestNavigationUpdate, {passive: true});
  window.addEventListener('resize', () => {
    if (window.innerWidth > 980) closeMenu();
    requestNavigationUpdate();
  });
  updateNavigation();
}

function initializeDetailPattern() {
  const pattern = document.querySelector('.screen-detail__pattern');
  if (!pattern) return;
  for (let index = 0; index < 26; index += 1) {
    const mark = document.createElement('span');
    mark.textContent = 'q';
    mark.style.left = `${(index * 37) % 96}%`;
    mark.style.top = `${(index * 43) % 94}%`;
    mark.style.transform = `rotate(${(index % 5) * 8 - 16}deg)`;
    pattern.append(mark);
  }
}

function initializePhoneStage({reduceMotion}) {
  const stage = document.querySelector('[data-phone-stage]');
  const canvas = document.querySelector('[data-phone-canvas]');
  const fallback = document.querySelector('[data-phone-fallback]');
  const fallbackImage = document.querySelector('[data-fallback-image]');
  const hit = document.querySelector('[data-open-current]');
  const previous = document.querySelector('[data-carousel-prev]');
  const next = document.querySelector('[data-carousel-next]');
  const dotsRoot = document.querySelector('[data-carousel-dots]');
  const currentIndex = document.querySelector('[data-current-index]');
  const currentLabel = document.querySelector('[data-current-label]');
  if (!stage || !canvas || !dotsRoot) return;

  const detail = document.querySelector('[data-screen-detail]');
  const detailImage = document.querySelector('[data-detail-image]');
  const detailAvif = document.querySelector('[data-detail-avif]');
  const detailWebp = document.querySelector('[data-detail-webp]');
  const detailNumber = document.querySelector('[data-detail-number]');
  const detailTitle = document.querySelector('[data-detail-title]');
  const detailDescription = document.querySelector('[data-detail-description]');
  const detailFeatures = document.querySelector('[data-detail-features]');
  const closeDetail = document.querySelector('[data-close-detail]');
  const detailPrevious = document.querySelector('[data-detail-prev]');
  const detailNext = document.querySelector('[data-detail-next]');
  let activeIndex = 0;
  let rotation = 0;
  let targetRotation = 0;
  let pointerStart = 0;
  let rotationStart = 0;
  let dragging = false;
  let moved = false;
  let pointerStartedOnHit = false;
  let detailOpening = false;
  let focusProgress = 0;
  let targetFocus = 0;
  let detailHistoryActive = false;
  let idleAt = performance.now();
  let lastWheelAt = 0;
  const step = Math.PI * 2 / screens.length;
  const dots = screens.map((screen, index) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.setAttribute('aria-label', `${screen.label} auswählen`);
    button.addEventListener('click', () => select(index));
    dotsRoot.append(button);
    return button;
  });

  const updateUi = () => {
    const screen = screens[activeIndex];
    dots.forEach((dot, index) => {
      const active = index === activeIndex;
      dot.classList.toggle('is-active', active);
      if (active) dot.setAttribute('aria-current', 'true');
      else dot.removeAttribute('aria-current');
    });
    if (currentIndex) currentIndex.textContent = String(activeIndex + 1).padStart(2, '0');
    if (currentLabel) currentLabel.textContent = screen.label;
    if (hit) hit.setAttribute('aria-label', `${screen.label} im Detail öffnen`);
    if (fallbackImage) {
      fallbackImage.src = screen.displayImage || screen.image;
      fallbackImage.alt = `${screen.label} in der plaqa App`;
      screen.ready?.then(() => {
        if (screens[activeIndex] === screen && screen.displayImage) {
          fallbackImage.src = screen.displayImage;
        }
      });
    }
  };

  const select = (index, {updateDetail = false} = {}) => {
    activeIndex = (index + screens.length) % screens.length;
    targetRotation = -activeIndex * step;
    while (targetRotation - rotation > Math.PI) targetRotation -= Math.PI * 2;
    while (targetRotation - rotation < -Math.PI) targetRotation += Math.PI * 2;
    idleAt = performance.now();
    updateUi();
    if (updateDetail && detail?.open) {
      renderDetail(screens[activeIndex]);
      window.history.replaceState({plaqaScreen: activeIndex}, '', `#app-screen-${activeIndex + 1}`);
    }
  };

  const renderDetail = (screen) => {
    const modernSource = screen.image.replace(/\.(?:jpe?g)$/i, '');
    if (detailAvif && detailWebp) {
      if (screen.sourceQuad) {
        detailAvif.removeAttribute('srcset');
        detailWebp.removeAttribute('srcset');
      } else {
        detailAvif.srcset = `${modernSource}.avif`;
        detailWebp.srcset = `${modernSource}.webp`;
      }
    }
    if (detailImage) {
      detailImage.classList.add('is-changing');
      window.setTimeout(() => {
        detailImage.src = screen.displayImage || screen.image;
        detailImage.alt = `${screen.label} in der plaqa App`;
        detailImage.classList.remove('is-changing');
        screen.ready?.then(() => {
          if (detail?.open && screens[activeIndex] === screen && screen.displayImage) {
            detailImage.src = screen.displayImage;
          }
        });
      }, reduceMotion ? 0 : 120);
    }
    if (detailNumber) detailNumber.textContent = `${String(activeIndex + 1).padStart(2, '0')} / 08`;
    if (detailTitle) detailTitle.textContent = screen.title;
    if (detailDescription) {
      detailDescription.replaceChildren();
      const paragraph = document.createElement('p');
      paragraph.textContent = screen.description;
      detailDescription.append(paragraph);
    }
    if (detailFeatures) {
      detailFeatures.replaceChildren(...screen.features.map((feature, index) => {
        const item = document.createElement('li');
        const number = document.createElement('span');
        const text = document.createElement('strong');
        number.textContent = String(index + 1).padStart(2, '0');
        text.textContent = feature;
        item.append(number, text);
        return item;
      }));
    }
  };

  const openDetail = () => {
    if (!detail || moved || detail.open || detailOpening) return;
    detailOpening = true;
    targetFocus = 1;
    stage.classList.add('is-opening');
    renderDetail(screens[activeIndex]);
    window.setTimeout(() => {
      detail.showModal();
      document.body.classList.add('detail-open');
      requestAnimationFrame(() => detail.classList.add('is-visible'));
      window.history.pushState({plaqaScreen: activeIndex}, '', `#app-screen-${activeIndex + 1}`);
      detailHistoryActive = true;
      detailOpening = false;
      closeDetail?.focus({preventScroll: true});
    }, reduceMotion ? 0 : 520);
  };

  const closeDetailView = () => {
    if (!detail?.open) return;
    targetFocus = 0;
    stage.classList.remove('is-opening');
    detail.classList.remove('is-visible');
    window.setTimeout(() => {
      detail.close();
      document.body.classList.remove('detail-open');
      hit?.focus({preventScroll: true});
    }, reduceMotion ? 0 : 430);
  };

  const dismissDetail = () => {
    if (detailHistoryActive) {
      window.history.back();
      return;
    }
    closeDetailView();
  };

  previous?.addEventListener('click', () => select(activeIndex - 1));
  next?.addEventListener('click', () => select(activeIndex + 1));
  detailPrevious?.addEventListener('click', () => select(activeIndex - 1, {updateDetail: true}));
  detailNext?.addEventListener('click', () => select(activeIndex + 1, {updateDetail: true}));
  hit?.addEventListener('click', (event) => {
    if (event.detail === 0) openDetail();
  });
  fallback?.querySelector('[data-fallback-open]')?.addEventListener('click', openDetail);
  closeDetail?.addEventListener('click', dismissDetail);
  detail?.addEventListener('cancel', (event) => {
    event.preventDefault();
    dismissDetail();
  });
  window.addEventListener('popstate', () => {
    if (!detail?.open) return;
    detailHistoryActive = false;
    closeDetailView();
  });

  stage.addEventListener('pointerdown', (event) => {
    dragging = true;
    moved = false;
    pointerStartedOnHit = Boolean(hit && event.composedPath().includes(hit));
    pointerStart = event.clientX;
    rotationStart = rotation;
    stage.classList.add('is-dragging');
    stage.setPointerCapture(event.pointerId);
    idleAt = performance.now();
  });
  stage.addEventListener('pointermove', (event) => {
    if (!dragging) return;
    const distance = event.clientX - pointerStart;
    moved ||= Math.abs(distance) > 7;
    targetRotation = rotationStart + distance * 0.006;
  });
  const releasePointer = (event) => {
    if (!dragging) return;
    const shouldOpen = event.type === 'pointerup' && pointerStartedOnHit && !moved;
    dragging = false;
    pointerStartedOnHit = false;
    stage.classList.remove('is-dragging');
    if (stage.hasPointerCapture(event.pointerId)) stage.releasePointerCapture(event.pointerId);
    select(Math.round(-targetRotation / step));
    if (shouldOpen) openDetail();
  };
  stage.addEventListener('pointerup', releasePointer);
  stage.addEventListener('pointercancel', releasePointer);
  stage.addEventListener('wheel', (event) => {
    const now = performance.now();
    if (now - lastWheelAt < 500) return;
    const horizontal = Math.abs(event.deltaX) > Math.abs(event.deltaY) || event.shiftKey;
    if (!horizontal && Math.abs(event.deltaY) < 50) return;
    const value = horizontal ? event.deltaX || event.deltaY : event.deltaY;
    select(activeIndex + Math.sign(value));
    lastWheelAt = now;
  }, {passive: true});
  window.addEventListener('keydown', (event) => {
    if (detail?.open) {
      if (event.key === 'ArrowLeft') select(activeIndex - 1, {updateDetail: true});
      if (event.key === 'ArrowRight') select(activeIndex + 1, {updateDetail: true});
      return;
    }
    if (event.key === 'ArrowLeft') select(activeIndex - 1);
    if (event.key === 'ArrowRight') select(activeIndex + 1);
  });

  updateUi();

  try {
    const renderer = new THREE.WebGLRenderer({
      canvas,
      antialias: true,
      alpha: false,
      powerPreference: 'high-performance',
    });
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.34;
    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x000000);
    const camera = new THREE.PerspectiveCamera(28, 1, 0.1, 100);
    const carousel = new THREE.Group();
    scene.add(carousel);
    scene.add(new THREE.HemisphereLight(0xe7efff, 0x07101b, 2.35));

    const blueLight = new THREE.DirectionalLight(0x0869ff, 3.2);
    blueLight.position.set(-8, 5, 10);
    scene.add(blueLight);
    const orangeLight = new THREE.DirectionalLight(0xff6f1a, 2.5);
    orangeLight.position.set(8, 3, 7);
    scene.add(orangeLight);
    const topLight = new THREE.DirectionalLight(0xffffff, 2.8);
    topLight.position.set(0, 10, 4);
    scene.add(topLight);
    const frontLight = new THREE.DirectionalLight(0xf4f7ff, 3.3);
    frontLight.position.set(0, 1, 12);
    scene.add(frontLight);
    const lowerFill = new THREE.PointLight(0x4b7dff, 18, 25, 2);
    lowerFill.position.set(-1, -4, 7);
    scene.add(lowerFill);

    const floor = new THREE.Mesh(
      new THREE.PlaneGeometry(40, 24),
      new THREE.MeshStandardMaterial({color: 0x060a10, metalness: 0.7, roughness: 0.26}),
    );
    floor.rotation.x = -Math.PI / 2;
    floor.position.y = -3.45;
    scene.add(floor);

    const floorGrid = new THREE.GridHelper(38, 38, 0x155ec4, 0x172231);
    floorGrid.position.y = -3.42;
    floorGrid.material.transparent = true;
    floorGrid.material.opacity = 0.24;
    floorGrid.material.depthWrite = false;
    scene.add(floorGrid);

    const rearWall = new THREE.Mesh(
      new THREE.PlaneGeometry(34, 18),
      new THREE.MeshBasicMaterial({color: 0x03070c}),
    );
    rearWall.position.set(0, 4.9, -8.2);
    scene.add(rearWall);

    const horizon = new THREE.Mesh(
      new THREE.BoxGeometry(34, 0.018, 0.025),
      new THREE.MeshBasicMaterial({color: 0x19406d, transparent: true, opacity: 0.68}),
    );
    horizon.position.set(0, -0.72, -8.05);
    scene.add(horizon);

    const studioBlue = new THREE.Mesh(
      new THREE.BoxGeometry(0.035, 11.5, 0.025),
      new THREE.MeshBasicMaterial({color: 0x0869ff, transparent: true, opacity: 0.62}),
    );
    studioBlue.position.set(-8.7, 2.2, -8.02);
    scene.add(studioBlue);

    const studioOrange = studioBlue.clone();
    studioOrange.material = new THREE.MeshBasicMaterial({color: 0xff6a1a, transparent: true, opacity: 0.55});
    studioOrange.position.x = 9.2;
    scene.add(studioOrange);

    const anisotropy = Math.min(renderer.capabilities.getMaxAnisotropy(), 8);
    let carouselRadius = 5.5;
    screens.forEach((screen, index) => {
      const angle = index * step;
      const phone = createPhone(screen, index, anisotropy);
      phone.userData.carouselAngle = angle;
      phone.position.set(Math.sin(angle) * carouselRadius, -0.16, Math.cos(angle) * carouselRadius);
      phone.rotation.y = angle;
      phone.scale.setScalar(0.72);
      carousel.add(phone);
    });

    let pixelRatio = Math.min(window.devicePixelRatio || 1, 2);
    let cameraBaseZ = 18.4;
    let lastFrame = performance.now();
    let sampleTime = 0;
    let sampleFrames = 0;
    let vectorScale = new THREE.Vector3(0.72, 0.72, 0.72);
    let stageVisible = true;

    if ('IntersectionObserver' in window) {
      const stageObserver = new IntersectionObserver(([entry]) => {
        stageVisible = entry?.isIntersecting ?? true;
        lastFrame = performance.now();
      }, {rootMargin: '120px 0px'});
      stageObserver.observe(stage);
    }

    const resize = () => {
      const width = Math.max(stage.clientWidth, 1);
      const height = Math.max(stage.clientHeight, 1);
      renderer.setPixelRatio(pixelRatio);
      renderer.setSize(width, height, false);
      camera.aspect = width / height;
      camera.fov = width < 720 ? 34 : width < 1100 ? 31 : 28;
      camera.updateProjectionMatrix();
      carouselRadius = width < 720 ? 3 : width < 1100 ? 5 : 5.5;
      carousel.children.forEach((phone) => {
        const angle = phone.userData.carouselAngle;
        phone.position.set(Math.sin(angle) * carouselRadius, -0.16, Math.cos(angle) * carouselRadius);
      });
      cameraBaseZ = width < 720 ? 15.5 : width < 1100 ? 18.7 : 18.4;
      carousel.scale.setScalar(width < 720 ? 0.98 : width < 1100 ? 0.92 : 1);
      carousel.position.x = width >= 1100 ? 1.35 : width >= 800 ? 0.65 : 0;
      carousel.position.y = width < 720 ? -0.4 : -0.18;
    };
    resize();
    window.addEventListener('resize', resize);

    const render = (now) => {
      if (document.hidden || !stageVisible) {
        lastFrame = now;
        window.setTimeout(() => requestAnimationFrame(render), 240);
        return;
      }
      const elapsed = Math.min(now - lastFrame, 80);
      lastFrame = now;
      if (!dragging && !reduceMotion && !detail?.open && now - idleAt > 7200) select(activeIndex + 1);
      const damping = reduceMotion ? 1 : 1 - Math.pow(0.001, elapsed / 1000);
      rotation += (targetRotation - rotation) * damping;
      focusProgress += (targetFocus - focusProgress) * (reduceMotion ? 1 : 0.07);
      carousel.rotation.y = rotation;
      camera.position.set(0, 0.1, cameraBaseZ - focusProgress * 8.1);
      camera.lookAt(carousel.position.x * 0.42, -0.12, carouselRadius * focusProgress);
      carousel.children.forEach((phone, index) => {
        const desired = 0.72 + (index === activeIndex ? focusProgress * 0.1 : 0);
        vectorScale.set(desired, desired, desired);
        phone.scale.lerp(vectorScale, 0.1);
      });
      renderer.render(scene, camera);
      sampleTime += elapsed;
      sampleFrames += 1;
      if (sampleFrames === 120) {
        const averageFrame = sampleTime / sampleFrames;
        if (averageFrame > 23 && pixelRatio > 1) {
          pixelRatio = Math.max(1, pixelRatio * 0.78);
          resize();
        }
        sampleTime = 0;
        sampleFrames = 0;
      }
      requestAnimationFrame(render);
    };
    requestAnimationFrame(render);
  } catch {
    canvas.hidden = true;
    if (fallback) fallback.hidden = false;
    hit?.setAttribute('hidden', '');
  }
}

function createPhone(screenData, index, anisotropy) {
  const phone = new THREE.Group();
  const bodyGeometry = new THREE.ExtrudeGeometry(roundedRectangle(2.94, 6.16, 0.38), {
    depth: 0.31,
    bevelEnabled: true,
    bevelSegments: 5,
    bevelSize: 0.035,
    bevelThickness: 0.035,
    curveSegments: 14,
  });
  bodyGeometry.center();
  const colorway = index % 2 === 0
    ? {
        body: 0xe9682f,
        frame: 0xffa06a,
        back: 0xc95524,
        camera: 0xed7139,
        controls: 0xffaa75,
        lensRing: 0xf58a52,
      }
    : {
        body: 0x66beba,
        frame: 0xa7e8e2,
        back: 0x3f8f8d,
        camera: 0x72c9c3,
        controls: 0xb9eee9,
        lensRing: 0x8edbd5,
      };
  const body = new THREE.Mesh(bodyGeometry, new THREE.MeshPhysicalMaterial({
    color: colorway.body,
    metalness: 0.88,
    roughness: 0.18,
    clearcoat: 0.48,
    clearcoatRoughness: 0.18,
  }));
  phone.add(body);

  const frontFrame = new THREE.Mesh(
    new THREE.ShapeGeometry(roundedFrame(2.87, 6.08, 0.35, 0.055)),
    new THREE.MeshPhysicalMaterial({
      color: 0x090b0e,
      metalness: 0.38,
      roughness: 0.2,
      clearcoat: 0.86,
      side: THREE.DoubleSide,
    }),
  );
  frontFrame.position.z = 0.216;
  phone.add(frontFrame);

  const glass = new THREE.Mesh(
    createRoundedPlaneGeometry(2.81, 6, 0.32),
    new THREE.MeshPhysicalMaterial({color: 0x020304, metalness: 0.05, roughness: 0.1, clearcoat: 1}),
  );
  glass.position.z = 0.218;
  phone.add(glass);

  const texture = new THREE.CanvasTexture(createScreenCanvas(screenData, index));
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.anisotropy = anisotropy;
  screenData.ready?.then(() => { texture.needsUpdate = true; });
  const screen = new THREE.Mesh(
    createRoundedPlaneGeometry(2.72, 5.96, 0.29),
    new THREE.MeshBasicMaterial({map: texture, toneMapped: false}),
  );
  screen.position.z = 0.226;
  phone.add(screen);

  const frontGlare = new THREE.Mesh(
    new THREE.PlaneGeometry(0.3, 5.42),
    new THREE.MeshBasicMaterial({
      color: 0xddeeff,
      transparent: true,
      opacity: 0.04,
      depthWrite: false,
      blending: THREE.AdditiveBlending,
    }),
  );
  frontGlare.position.set(-0.82, -0.02, 0.232);
  frontGlare.rotation.z = -0.11;
  phone.add(frontGlare);

  const island = new THREE.Mesh(
    new THREE.CapsuleGeometry(0.09, 0.42, 6, 16),
    new THREE.MeshBasicMaterial({color: 0x000000}),
  );
  island.rotation.z = Math.PI / 2;
  island.position.set(0, 2.61, 0.24);
  phone.add(island);

  const backGlass = new THREE.Mesh(
    new THREE.ShapeGeometry(roundedRectangle(2.7, 4.14, 0.3)),
    new THREE.MeshPhysicalMaterial({
      color: colorway.back,
      metalness: 0.34,
      roughness: 0.3,
      clearcoat: 0.58,
      clearcoatRoughness: 0.2,
      side: THREE.DoubleSide,
    }),
  );
  backGlass.position.set(0, -0.77, -0.21);
  backGlass.rotation.y = Math.PI;
  phone.add(backGlass);

  const cameraPlateGeometry = new THREE.ExtrudeGeometry(roundedRectangle(2.72, 1.43, 0.27), {
    depth: 0.115,
    bevelEnabled: true,
    bevelSegments: 4,
    bevelSize: 0.045,
    bevelThickness: 0.035,
    curveSegments: 12,
  });
  cameraPlateGeometry.center();
  const cameraPlate = new THREE.Mesh(
    cameraPlateGeometry,
    new THREE.MeshPhysicalMaterial({color: colorway.camera, metalness: 0.78, roughness: 0.18, clearcoat: 0.7}),
  );
  cameraPlate.position.set(0, 2.18, -0.255);
  phone.add(cameraPlate);
  [[0.91, 2.48], [0.39, 2.22], [0.91, 1.92]].forEach(([x, y]) => {
    const lensRing = new THREE.Mesh(
      new THREE.CylinderGeometry(0.255, 0.255, 0.075, 40),
      new THREE.MeshStandardMaterial({color: colorway.lensRing, metalness: 0.94, roughness: 0.12}),
    );
    lensRing.rotation.x = Math.PI / 2;
    lensRing.position.set(x, y, -0.34);
    phone.add(lensRing);
    const lens = new THREE.Mesh(
      new THREE.CylinderGeometry(0.194, 0.194, 0.095, 40),
      new THREE.MeshPhysicalMaterial({color: 0x07101d, metalness: 0.82, roughness: 0.04, clearcoat: 1}),
    );
    lens.rotation.x = Math.PI / 2;
    lens.position.set(x, y, -0.385);
    phone.add(lens);
    const lensCore = new THREE.Mesh(
      new THREE.CircleGeometry(0.092, 32),
      new THREE.MeshBasicMaterial({color: 0x10294a, side: THREE.DoubleSide}),
    );
    lensCore.rotation.y = Math.PI;
    lensCore.position.set(x + 0.018, y + 0.018, -0.438);
    phone.add(lensCore);
  });

  const flash = new THREE.Mesh(
    new THREE.CircleGeometry(0.115, 32),
    new THREE.MeshBasicMaterial({color: 0xfff4cf, side: THREE.DoubleSide}),
  );
  flash.rotation.y = Math.PI;
  flash.position.set(-0.92, 2.5, -0.377);
  phone.add(flash);

  const lidar = new THREE.Mesh(
    new THREE.CircleGeometry(0.125, 32),
    new THREE.MeshPhysicalMaterial({color: 0x080b0f, metalness: 0.42, roughness: 0.12, side: THREE.DoubleSide}),
  );
  lidar.rotation.y = Math.PI;
  lidar.position.set(-0.92, 1.92, -0.377);
  phone.add(lidar);

  const microphone = new THREE.Mesh(
    new THREE.CircleGeometry(0.026, 18),
    new THREE.MeshBasicMaterial({color: 0x101419, side: THREE.DoubleSide}),
  );
  microphone.rotation.y = Math.PI;
  microphone.position.set(-0.78, 2.2, -0.38);
  phone.add(microphone);

  const sideButtonMaterial = new THREE.MeshStandardMaterial({color: colorway.controls, metalness: 0.94, roughness: 0.14});
  [[-1.51, 1.77, 0.32], [-1.51, 1.12, 0.48], [-1.51, 0.54, 0.48], [1.51, 1.18, 0.86], [1.51, -1.06, 0.54]].forEach(([x, y, height]) => {
    const button = new THREE.Mesh(new THREE.BoxGeometry(0.075, height, 0.105), sideButtonMaterial);
    button.position.set(x, y, 0);
    phone.add(button);
  });

  const usbPort = new THREE.Mesh(
    new THREE.BoxGeometry(0.42, 0.055, 0.09),
    new THREE.MeshBasicMaterial({color: 0x11161a}),
  );
  usbPort.position.set(0, -3.16, 0);
  phone.add(usbPort);
  return phone;
}

function createScreenCanvas(screen, index) {
  if (screen.canvas) return screen.canvas;
  const canvas = document.createElement('canvas');
  canvas.width = 921;
  canvas.height = 2048;
  const context = canvas.getContext('2d');
  context.fillStyle = '#04070b';
  context.fillRect(0, 0, canvas.width, canvas.height);
  const image = new Image();
  screen.canvas = canvas;
  screen.ready = new Promise((resolve) => {
    image.addEventListener('load', () => {
      if (screen.sourceQuad) {
        drawPerspectiveCrop(
          context,
          image,
          screen.sourceQuad,
          canvas.width,
          canvas.height,
          screen.straightenSlopes,
          screen.verticalSourceOffset,
        );
        screen.displayImage = canvas.toDataURL('image/jpeg', 0.94);
        resolve(screen.image);
        return;
      }
      const sourceHeight = image.naturalHeight * (screen.cropBottomNavigation ? 0.945 : 1);
      const sourceWidth = Math.min(image.naturalWidth, sourceHeight * (canvas.width / canvas.height));
      const sourceX = (image.naturalWidth - sourceWidth) / 2;
      context.drawImage(
        image,
        sourceX,
        0,
        sourceWidth,
        sourceHeight,
        0,
        0,
        canvas.width,
        canvas.height,
      );
      screen.displayImage = canvas.toDataURL('image/jpeg', 0.94);
      resolve(screen.image);
    }, {once: true});
    image.addEventListener('error', () => resolve(screen.image), {once: true});
    const load = () => { image.src = screen.image; };
    if (index === 0) load();
    else window.setTimeout(load, 120 + index * 90);
  });
  return canvas;
}

function drawPerspectiveCrop(
  context,
  image,
  sourceQuad,
  width,
  height,
  straightenSlopes = null,
  verticalSourceOffset = 0,
) {
  const columns = 12;
  const rows = 28;
  context.fillStyle = '#04070b';
  context.fillRect(0, 0, width, height);
  context.imageSmoothingEnabled = true;
  context.imageSmoothingQuality = 'high';

  const sourcePoint = createProjectiveQuadMapper(sourceQuad);
  const correctedV = (u, v) => {
    const shiftedV = v + verticalSourceOffset;
    if (!straightenSlopes) return shiftedV;
    const [topSlope, bottomSlope] = straightenSlopes;
    const slope = topSlope + (bottomSlope - topSlope) * v;
    return shiftedV + slope * (u - 0.5) * (width / height);
  };

  for (let row = 0; row < rows; row += 1) {
    const v0 = row / rows;
    const v1 = (row + 1) / rows;
    for (let column = 0; column < columns; column += 1) {
      const u0 = column / columns;
      const u1 = (column + 1) / columns;
      const source00 = sourcePoint(u0, correctedV(u0, v0));
      const source10 = sourcePoint(u1, correctedV(u1, v0));
      const source11 = sourcePoint(u1, correctedV(u1, v1));
      const source01 = sourcePoint(u0, correctedV(u0, v1));
      const destination00 = [u0 * width, v0 * height];
      const destination10 = [u1 * width, v0 * height];
      const destination11 = [u1 * width, v1 * height];
      const destination01 = [u0 * width, v1 * height];
      drawImageTriangle(context, image, source00, source10, source11, destination00, destination10, destination11);
      drawImageTriangle(context, image, source00, source11, source01, destination00, destination11, destination01);
    }
  }
}

function createProjectiveQuadMapper([topLeft, topRight, bottomRight, bottomLeft]) {
  const [x0, y0] = topLeft;
  const [x1, y1] = topRight;
  const [x2, y2] = bottomRight;
  const [x3, y3] = bottomLeft;
  const deltaX1 = x1 - x2;
  const deltaX2 = x3 - x2;
  const deltaX3 = x0 - x1 + x2 - x3;
  const deltaY1 = y1 - y2;
  const deltaY2 = y3 - y2;
  const deltaY3 = y0 - y1 + y2 - y3;
  const determinant = deltaX1 * deltaY2 - deltaX2 * deltaY1;
  const hasPerspective = Math.abs(determinant) > 0.0001;
  const g = hasPerspective
    ? (deltaX3 * deltaY2 - deltaX2 * deltaY3) / determinant
    : 0;
  const h = hasPerspective
    ? (deltaX1 * deltaY3 - deltaX3 * deltaY1) / determinant
    : 0;
  const a = x1 - x0 + g * x1;
  const b = x3 - x0 + h * x3;
  const c = x0;
  const d = y1 - y0 + g * y1;
  const e = y3 - y0 + h * y3;
  const f = y0;

  return (u, v) => {
    const scale = g * u + h * v + 1;
    return [
      (a * u + b * v + c) / scale,
      (d * u + e * v + f) / scale,
    ];
  };
}

function drawImageTriangle(context, image, source0, source1, source2, destination0, destination1, destination2) {
  const determinant = source0[0] * (source2[1] - source1[1])
    + source1[0] * (source0[1] - source2[1])
    + source2[0] * (source1[1] - source0[1]);
  if (Math.abs(determinant) < 0.0001) return;

  const a = (destination0[0] * (source2[1] - source1[1])
    + destination1[0] * (source0[1] - source2[1])
    + destination2[0] * (source1[1] - source0[1])) / determinant;
  const b = (destination0[1] * (source2[1] - source1[1])
    + destination1[1] * (source0[1] - source2[1])
    + destination2[1] * (source1[1] - source0[1])) / determinant;
  const c = (destination0[0] * (source1[0] - source2[0])
    + destination1[0] * (source2[0] - source0[0])
    + destination2[0] * (source0[0] - source1[0])) / determinant;
  const d = (destination0[1] * (source1[0] - source2[0])
    + destination1[1] * (source2[0] - source0[0])
    + destination2[1] * (source0[0] - source1[0])) / determinant;
  const e = (destination0[0] * (source2[0] * source1[1] - source1[0] * source2[1])
    + destination1[0] * (source0[0] * source2[1] - source2[0] * source0[1])
    + destination2[0] * (source1[0] * source0[1] - source0[0] * source1[1])) / determinant;
  const f = (destination0[1] * (source2[0] * source1[1] - source1[0] * source2[1])
    + destination1[1] * (source0[0] * source2[1] - source2[0] * source0[1])
    + destination2[1] * (source1[0] * source0[1] - source0[0] * source1[1])) / determinant;

  context.save();
  context.beginPath();
  context.moveTo(destination0[0], destination0[1]);
  context.lineTo(destination1[0], destination1[1]);
  context.lineTo(destination2[0], destination2[1]);
  context.closePath();
  context.clip();
  context.setTransform(a, b, c, d, e, f);
  context.drawImage(image, 0, 0);
  context.restore();
}

function roundedRectangle(width, height, radius) {
  const x = -width / 2;
  const y = -height / 2;
  const shape = new THREE.Shape();
  shape.moveTo(x + radius, y);
  shape.lineTo(x + width - radius, y);
  shape.quadraticCurveTo(x + width, y, x + width, y + radius);
  shape.lineTo(x + width, y + height - radius);
  shape.quadraticCurveTo(x + width, y + height, x + width - radius, y + height);
  shape.lineTo(x + radius, y + height);
  shape.quadraticCurveTo(x, y + height, x, y + height - radius);
  shape.lineTo(x, y + radius);
  shape.quadraticCurveTo(x, y, x + radius, y);
  return shape;
}

function createRoundedPlaneGeometry(width, height, radius) {
  const geometry = new THREE.ShapeGeometry(roundedRectangle(width, height, radius), 20);
  const positions = geometry.getAttribute('position');
  const uvs = new Float32Array(positions.count * 2);
  for (let index = 0; index < positions.count; index += 1) {
    uvs[index * 2] = (positions.getX(index) + width / 2) / width;
    uvs[index * 2 + 1] = (positions.getY(index) + height / 2) / height;
  }
  geometry.setAttribute('uv', new THREE.BufferAttribute(uvs, 2));
  return geometry;
}

function roundedFrame(width, height, radius, inset) {
  const frame = roundedRectangle(width, height, radius);
  const innerWidth = width - inset * 2;
  const innerHeight = height - inset * 2;
  const innerRadius = Math.max(radius - inset, 0.08);
  const x = -innerWidth / 2;
  const y = -innerHeight / 2;
  const hole = new THREE.Path();
  hole.moveTo(x + innerRadius, y);
  hole.quadraticCurveTo(x, y, x, y + innerRadius);
  hole.lineTo(x, y + innerHeight - innerRadius);
  hole.quadraticCurveTo(x, y + innerHeight, x + innerRadius, y + innerHeight);
  hole.lineTo(x + innerWidth - innerRadius, y + innerHeight);
  hole.quadraticCurveTo(x + innerWidth, y + innerHeight, x + innerWidth, y + innerHeight - innerRadius);
  hole.lineTo(x + innerWidth, y + innerRadius);
  hole.quadraticCurveTo(x + innerWidth, y, x + innerWidth - innerRadius, y);
  hole.closePath();
  frame.holes.push(hole);
  return frame;
}
