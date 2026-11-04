'use strict';

// Relative URL: the browser asks nginx, and nginx forwards /api/ to the backend Service
async function refresh() {
  try {
    const res = await fetch('/api/info', { cache: 'no-store' });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();

    const env = document.getElementById('env');
    env.textContent = data.environment;
    env.className = `env ${data.environment}`;

    document.getElementById('message').textContent = data.message;
    document.getElementById('version').textContent = data.version;
    document.getElementById('hostname').textContent = data.hostname;
    document.getElementById('time').textContent = data.time;
    document.getElementById('error').textContent = '';
  } catch (err) {
    document.getElementById('error').textContent = `Backend unreachable: ${err.message}`;
  }
}

refresh();
setInterval(refresh, 2000);
