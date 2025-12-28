const express = require('express');
const { Pool } = require('pg');

const app = express();

const PORT = process.env.PORT || 3000;
const APP_ENV = process.env.APP_ENV || 'local';

const dbConfig = {
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
};

const pool = new Pool(dbConfig);

app.use(express.json());

app.get('/', (req, res) => {
  res.json({
    message: 'Platform Engineering Assessment demo app',
    environment: APP_ENV,
    time: new Date().toISOString(),
  });
});

async function checkDb() {
  // Simple DB health check query – requires only connectivity
  await pool.query('SELECT 1');
}

app.get('/healthz', async (req, res) => {
  try {
    await checkDb();
    res.status(200).json({ status: 'ok' });
  } catch (err) {
    console.error('Health check failed', err);
    res.status(500).json({ status: 'error', error: err.message });
  }
});

app.get('/readyz', async (req, res) => {
  try {
    await checkDb();
    res.status(200).json({ status: 'ready' });
  } catch (err) {
    console.error('Readiness check failed', err);
    res.status(500).json({ status: 'not_ready', error: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`Demo app listening on port ${PORT}, env=${APP_ENV}`);
});
