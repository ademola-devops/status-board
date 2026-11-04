'use strict';

const express = require('express');
const os = require('os');

const app = express();
const port = process.env.PORT || 5000;

// Values injected by Kubernetes: version from the Deployment, the rest from a ConfigMap
const info = () => ({
  version: process.env.APP_VERSION || 'dev',
  environment: process.env.ENV_NAME || 'local',
  message: process.env.MESSAGE || 'Hello from the status board',
  hostname: os.hostname(),
  time: new Date().toISOString()
});

// Used by Kubernetes readiness and liveness probes, and by the smoke test
app.get('/healthz', (req, res) => res.status(200).send('ok'));

app.get('/api/info', (req, res) => res.json(info()));

app.listen(port, () => console.log(`Backend listening on port ${port}`));
