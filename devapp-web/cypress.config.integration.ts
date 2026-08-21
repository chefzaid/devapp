import { defineConfig } from 'cypress';

export default defineConfig({
  e2e: {
    baseUrl: process.env['WEB_URL'] || 'http://localhost:4200',
    allowCypressEnv: false,
    supportFile: false,
    specPattern: 'cypress/e2e/live-cluster.cy.ts',
    env: {
      OIDC_USERNAME: process.env['OIDC_USERNAME'] || 'user',
      OIDC_PASSWORD: process.env['OIDC_PASSWORD'] || 'password',
    },
  },
});
