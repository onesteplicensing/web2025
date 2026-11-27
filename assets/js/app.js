// Showcase Slider
const track = document.querySelector('.showcase-track');
const items = Array.from(track.children);
if (track.children.length < 10) {
    items.forEach(item => {
        const clone = item.cloneNode(true);
        track.appendChild(clone);
    });
}

// Tabs timeline
const _timeline = document.getElementById("timeline");

// "-b" timeline templates (e.g. timeline-two-images-b): on each page load, pick
// one of the pane's hand-tuned layouts (.layout-N in _timeline.scss) and give
// each card a small random extra tilt. Every layout keeps the cards clear of the
// text and of each other; its gaps assume the extra tilt stays within ±4deg.
const MAX_JITTER_DEG = 4;
_timeline.querySelectorAll('.tab-pane[data-layouts]').forEach(pane => {
    const layouts = Number(pane.dataset.layouts);
    pane.classList.add(`layout-${1 + Math.floor(Math.random() * layouts)}`);
    pane.querySelectorAll('.img-container').forEach(card => {
        const jitter = (Math.random() * 2 - 1) * MAX_JITTER_DEG;
        card.style.setProperty('--jitter', `${jitter.toFixed(1)}deg`);
    });
});

const tabsContainer = _timeline.querySelector('.nav-pills');
const tabs = tabsContainer.querySelectorAll('button');
let currentTabIndex = 0;
let _tabsInterval;

function scrollTabIntoView(tab) {
    const tabLeft = tab.offsetLeft;
    const tabWidth = tab.offsetWidth;
    const containerWidth = tabsContainer.offsetWidth;

    const targetScrollLeft = tabLeft - (containerWidth / 2) + (tabWidth / 2);

    tabsContainer.scrollTo({
        left: targetScrollLeft,
        behavior: 'smooth'
    });
}

function startInterval() {
    _tabsInterval = setInterval(() => {

        tabs[currentTabIndex].classList.remove('active');
        const currentPaneId = tabs[currentTabIndex].getAttribute('data-bs-target');
        document.querySelector(currentPaneId).classList.remove('show', 'active');

        currentTabIndex = (currentTabIndex + 1) % tabs.length;

        const nextTab = new bootstrap.Tab(tabs[currentTabIndex]);
        nextTab.show();

        scrollTabIntoView(tabs[currentTabIndex]);
    }, 3000);
}

startInterval();

_timeline.addEventListener('mouseover', () => {
    clearInterval(_tabsInterval);
});

_timeline.addEventListener('mouseleave', () => {
    startInterval();
});

