const express = require('express');
const { Pool } = require('pg');

const app = express();
const PORT = process.env.PORT || 8080;
const POD_NAME = process.env.HOSTNAME || 'unknown-pod';

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

async function initDb() {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS auth_tokens (
        id SERIAL PRIMARY KEY,
        token TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT NOW()
      );
    `);
    const { rows } = await client.query('SELECT COUNT(*)::int AS count FROM auth_tokens');
    if (rows[0].count === 0) {
      await client.query("INSERT INTO auth_tokens (token) VALUES ('seed-token-001')");
    }
  } finally {
    client.release();
  }
}

app.get('/health', (req, res) => res.status(200).json({ status: 'ok', pod: POD_NAME }));

// Single business endpoint: validates/"authorizes" a request and proves which
// pod + which DB row answered, so a demo curl loop can show pod-level load
// balancing happening for real.
app.get('/auth', async (req, res) => {
  try {
    const { rows } = await pool.query('SELECT * FROM auth_tokens ORDER BY id DESC LIMIT 1');
    res.status(200).json({
      service: 'auth',
      pod: POD_NAME,
      authorized: true,
      token_record: rows[0],
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ service: 'auth', pod: POD_NAME, error: err.message });
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
  app.listen(PORT, () => console.log(`auth-service listening on ${PORT}, pod=${POD_NAME}`));
}

start();
