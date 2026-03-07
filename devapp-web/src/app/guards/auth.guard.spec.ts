import { TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { AuthService } from '../services/auth.service';
import { authGuard } from './auth.guard';

describe('AuthGuard', () => {
  let authServiceSpy: jasmine.SpyObj<AuthService>;
  let routerSpy: jasmine.SpyObj<Router>;

  beforeEach(() => {
    const authSpy = jasmine.createSpyObj('AuthService', ['isLoggedIn']);
    const rSpy = jasmine.createSpyObj('Router', ['parseUrl']);

    TestBed.configureTestingModule({
      providers: [
        { provide: AuthService, useValue: authSpy },
        { provide: Router, useValue: rSpy }
      ]
    });

    authServiceSpy = TestBed.inject(AuthService) as jasmine.SpyObj<AuthService>;
    routerSpy = TestBed.inject(Router) as jasmine.SpyObj<Router>;
  });

  it('should return true if user is logged in', () => {
    authServiceSpy.isLoggedIn.and.returnValue(true);

    const result = TestBed.runInInjectionContext(() => authGuard());

    expect(result).toBeTrue();
    expect(authServiceSpy.isLoggedIn).toHaveBeenCalled();
  });

  it('should return UrlTree to login if user is not logged in', () => {
    authServiceSpy.isLoggedIn.and.returnValue(false);
    const urlTree = {} as any;
    routerSpy.parseUrl.and.returnValue(urlTree);

    const result = TestBed.runInInjectionContext(() => authGuard());

    expect(result).toBe(urlTree);
    expect(authServiceSpy.isLoggedIn).toHaveBeenCalled();
    expect(routerSpy.parseUrl).toHaveBeenCalledWith('/login');
  });
});
