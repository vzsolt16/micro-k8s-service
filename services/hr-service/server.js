const express = require('express');
const { Pool } = require('pg');
const http = require('http');

const app = express();
const PORT = process.env.PORT || 8080;
const POD_NAME = process.env.HOSTNAME || 'unknown-pod';
const AUTH_SERVICE_URL = process.env.AUTH_SERVICE_URL;

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

function callAuth() {
  return new Promise((resolve, reject) => {
    if (!AUTH_SERVICE_URL) return reject(new Error('AUTH_SERVICE_URL not set'));
    const req = http.get(AUTH_SERVICE_URL, { timeout: 5000 }, (resp) => {
      let data = '';
      resp.on('data', (chunk) => (data += chunk));
      resp.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('timeout', () => req.destroy(new Error('auth-service timeout')));
    req.on('error', reject);
  });
}

async function initDb() {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS employees (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT NOW()
      );
    `);
    const { rows } = await client.query('SELECT COUNT(*)::int AS count FROM employees');
    if (rows[0].count === 0) {
      await client.query("INSERT INTO employees (name) VALUES ('Jane Doe')");
    }
  } finally {
    client.release();
  }
}

app.get('/health', (req, res) => res.status(200).json({ status: 'ok', pod: POD_NAME }));

app.get('/hr', async (req, res) => {
  try {
    const auth = await callAuth();
    if (!auth.authorized) {
      return res.status(401).json({ service: 'hr', pod: POD_NAME, error: 'not authorized' });
    }
    const { rows } = await pool.query('SELECT * FROM employees ORDER BY id DESC LIMIT 1');
    res.status(200).json({
      service: 'hr',
      pod: POD_NAME,
      db_row: rows[0],
      auth,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ service: 'hr', pod: POD_NAME, error: err.message });
  }
});

async function start() {
  let retries = 15;
  while (retries > 0) {
    try {
      await initDb();
      break;
    } catch (err) {
      console.log(`Waiting for DB... (${err.message})`);
      retries -= 1;
      await new Promise((r) => setTimeout(r, 3000));
    }
  }
  app.listen(PORT, () => console.log(`hr-service listening on ${PORT}, pod=${POD_NAME}`));
}

start();
