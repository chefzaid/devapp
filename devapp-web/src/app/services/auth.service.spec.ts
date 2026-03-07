import { TestBed } from '@angular/core/testing';
import { AuthService } from './auth.service';
import { OAuthService } from 'angular-oauth2-oidc';
import { BehaviorSubject, Subject } from 'rxjs';

describe('AuthService', () => {
  let service: AuthService;
  let oauthServiceSpy: jasmine.SpyObj<OAuthService>;

  beforeEach(() => {
    const spy = jasmine.createSpyObj('OAuthService', [
      'configure',
      'loadDiscoveryDocumentAndTryLogin',
      'hasValidAccessToken',
      'getAccessToken',
      'initCodeFlow',
      'logOut'
    ], {
      events: new Subject()
    });
    spy.loadDiscoveryDocumentAndTryLogin.and.returnValue(Promise.resolve(true));
    spy.hasValidAccessToken.and.returnValue(false);

    TestBed.configureTestingModule({
      providers: [
        AuthService,
        { provide: OAuthService, useValue: spy }
      ]
    });
    oauthServiceSpy = TestBed.inject(OAuthService) as jasmine.SpyObj<OAuthService>;
    service = TestBed.inject(AuthService);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });

  it('should configure oauth on creation', () => {
    expect(oauthServiceSpy.configure).toHaveBeenCalled();
    expect(oauthServiceSpy.loadDiscoveryDocumentAndTryLogin).toHaveBeenCalled();
  });

  it('should call initCodeFlow on login', () => {
    service.login();
    expect(oauthServiceSpy.initCodeFlow).toHaveBeenCalled();
  });

  it('should call logOut on logout', () => {
    service.logout();
    expect(oauthServiceSpy.logOut).toHaveBeenCalled();
  });

  it('should return token from oauthService', () => {
    oauthServiceSpy.getAccessToken.and.returnValue('test-token');
    expect(service.getToken()).toBe('test-token');
  });

  it('should delegate isLoggedIn to hasValidAccessToken', () => {
    oauthServiceSpy.hasValidAccessToken.and.returnValue(true);
    expect(service.isLoggedIn()).toBeTrue();
  });
});
