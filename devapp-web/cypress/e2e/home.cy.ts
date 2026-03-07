describe('home page', () => {
  it('loads', () => {
    cy.visit('/');
    cy.contains('Users');
  });
});
