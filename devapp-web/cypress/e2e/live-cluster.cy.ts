const liveDescribe = Cypress.env('LIVE_CLUSTER') ? describe : describe.skip;

liveDescribe('live cluster acceptance', () => {
  it('authenticates through Keycloak and loads both secured workflows', () => {
    cy.visit('/login');
    cy.contains('One small app.');
    cy.contains('button', 'Login with SSO').click();

    cy.location('pathname', { timeout: 20_000 }).should('include', '/auth/realms/devapp/');
    cy.get('#username').type(Cypress.env('OIDC_USERNAME') || 'user');
    cy.get('#password').type(Cypress.env('OIDC_PASSWORD') || 'password', { log: false });
    cy.get('#kc-login').click();

    cy.location('pathname', { timeout: 20_000 }).should('eq', '/users');
    cy.contains('h1', 'People behind the requests.');
    cy.contains('h2', 'User directory');
    cy.get('.user-item', { timeout: 15_000 }).should('have.length.at.least', 1);

    cy.contains('a', 'Orders').click();
    cy.location('pathname').should('eq', '/orders');
    cy.contains('h1', 'Orders that travel the stack.');
    cy.contains('h2', 'Create an order');
  });
});
