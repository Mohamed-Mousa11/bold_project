// Tiny "test" script used by CI to make sure required env vars are present.
// This keeps the Test stage simple but still validates configuration basics.
const requiredVars = ['PORT', 'DB_HOST', 'DB_USER', 'DB_NAME', 'DB_PASSWORD'];

const missing = requiredVars.filter((name) => !process.env[name]);

if (missing.length > 0) {
  console.error('Config health check failed. Missing env vars:', missing.join(', '));
  process.exit(1);
}

console.log('Config health check passed.');
