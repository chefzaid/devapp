import { defineConfig } from 'cypress';

export default defineConfig({
  e2e: {
    baseUrl: 'http://localhost:4200',
    allowCypressEnv: false,
    supportFile: false,
    specPattern: 'cypress/e2e/home.cy.ts',
  },
});
