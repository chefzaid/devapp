import { beforeEach, describe, expect, it, type MockedObject, vi } from 'vitest';
import { TestBed } from '@angular/core/testing';
import { HttpEvent, HttpHandlerFn, HttpRequest } from '@angular/common/http';
import { authInterceptor } from './auth.interceptor';
import { AuthService } from '../services/auth.service';
import { firstValueFrom, Observable, of } from 'rxjs';

describe('authInterceptor', () => {
    let authServiceSpy: MockedObject<AuthService>;

    beforeEach(() => {
        const spy = {
            getToken: vi.fn().mockName("AuthService.getToken")
        };
        TestBed.configureTestingModule({
            providers: [
                { provide: AuthService, useValue: spy }
            ]
        });
        authServiceSpy = TestBed.inject(AuthService) as MockedObject<AuthService>;
    });

    it('should add Authorization header when token is present', async () => {
        authServiceSpy.getToken.mockReturnValue('fake-token');

        const next: HttpHandlerFn = (req: HttpRequest<unknown>): Observable<HttpEvent<unknown>> => {
            expect(req.headers.has('Authorization')).toBe(true);
            expect(req.headers.get('Authorization')).toBe('Bearer fake-token');
            return of({} as HttpEvent<unknown>);
        };

        const req = new HttpRequest('GET', '/api/users');

        await firstValueFrom(TestBed.runInInjectionContext(() => authInterceptor(req, next)));
    });

    it('should not add Authorization header when token is missing', async () => {
        authServiceSpy.getToken.mockReturnValue('');

        const next: HttpHandlerFn = (req: HttpRequest<unknown>): Observable<HttpEvent<unknown>> => {
            expect(req.headers.has('Authorization')).toBe(false);
            return of({} as HttpEvent<unknown>);
        };

        const req = new HttpRequest('GET', '/api/users');

        await firstValueFrom(TestBed.runInInjectionContext(() => authInterceptor(req, next)));
    });

    it('should bypass authentication without resolving the service for OIDC requests', async () => {
        const next = vi.fn((req: HttpRequest<unknown>) => {
            expect(req.headers.has('Authorization')).toBe(false);
            return of({} as HttpEvent<unknown>);
        });
        const req = new HttpRequest('GET', '/auth/realms/devapp/.well-known/openid-configuration');

        await firstValueFrom(TestBed.runInInjectionContext(() => authInterceptor(req, next)));

        expect(authServiceSpy.getToken).not.toHaveBeenCalled();
        expect(next).toHaveBeenCalledOnce();
    });

    it.each([
        'https://unrelated.example.test/api/users',
        '//unrelated.example.test/api/orders',
        '/runtime-config.json',
        '/api/users-other',
        '/api/docs',
        '/realms/example/.well-known/openid-configuration'
    ])('does not resolve authentication or send tokens to %s', async (url) => {
        authServiceSpy.getToken.mockReturnValue('private-token');
        const next: HttpHandlerFn = req => {
            expect(req.headers.has('Authorization')).toBe(false);
            return of({} as HttpEvent<unknown>);
        };
        await firstValueFrom(TestBed.runInInjectionContext(() =>
            authInterceptor(new HttpRequest('GET', url), next)));
        expect(authServiceSpy.getToken).not.toHaveBeenCalled();
    });

    it('authenticates a nested same-origin order API request', async () => {
        authServiceSpy.getToken.mockReturnValue('private-token');
        const next: HttpHandlerFn = req => {
            expect(req.headers.get('Authorization')).toBe('Bearer private-token');
            return of({} as HttpEvent<unknown>);
        };
        const url = window.location.origin + '/api/orders/12';
        await firstValueFrom(TestBed.runInInjectionContext(() =>
            authInterceptor(new HttpRequest('GET', url), next)));
    });

});
