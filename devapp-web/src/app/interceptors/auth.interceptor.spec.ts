import { TestBed } from '@angular/core/testing';
import { HttpInterceptorFn, HttpRequest, HttpHandlerFn, HttpEvent, HttpHeaders } from '@angular/common/http';
import { authInterceptor } from './auth.interceptor';
import { AuthService } from '../services/auth.service';
import { Observable, of } from 'rxjs';

describe('authInterceptor', () => {
  let authServiceSpy: jasmine.SpyObj<AuthService>;

  beforeEach(() => {
    const spy = jasmine.createSpyObj('AuthService', ['getToken']);
    TestBed.configureTestingModule({
      providers: [
        { provide: AuthService, useValue: spy }
      ]
    });
    authServiceSpy = TestBed.inject(AuthService) as jasmine.SpyObj<AuthService>;
  });

  it('should add Authorization header when token is present', (done) => {
    authServiceSpy.getToken.and.returnValue('fake-token');

    const next: HttpHandlerFn = (req: HttpRequest<unknown>): Observable<HttpEvent<unknown>> => {
      expect(req.headers.has('Authorization')).toBeTrue();
      expect(req.headers.get('Authorization')).toBe('Bearer fake-token');
      return of({} as HttpEvent<unknown>);
    };

    const req = new HttpRequest('GET', '/api/test');

    TestBed.runInInjectionContext(() => {
        authInterceptor(req, next).subscribe(() => done());
    });
  });

  it('should not add Authorization header when token is missing', (done) => {
    authServiceSpy.getToken.and.returnValue('');

    const next: HttpHandlerFn = (req: HttpRequest<unknown>): Observable<HttpEvent<unknown>> => {
      expect(req.headers.has('Authorization')).toBeFalse();
      return of({} as HttpEvent<unknown>);
    };

    const req = new HttpRequest('GET', '/api/test');

    TestBed.runInInjectionContext(() => {
        authInterceptor(req, next).subscribe(() => done());
    });
  });
});
