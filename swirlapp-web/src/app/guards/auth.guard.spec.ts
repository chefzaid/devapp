import { beforeEach, describe, expect, it, type MockedObject, vi } from "vitest";
import { TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { AuthService } from '../services/auth.service';
import { authGuard } from './auth.guard';
import { firstValueFrom, of } from 'rxjs';

describe('AuthGuard', () => {
    let authServiceSpy: MockedObject<AuthService>;
    let routerSpy: MockedObject<Router>;

    beforeEach(() => {
        const authSpy = {
            isLoggedIn: vi.fn().mockName("AuthService.isLoggedIn"),
            ready$: of(undefined)
        };
        const rSpy = {
            parseUrl: vi.fn().mockName("Router.parseUrl")
        };

        TestBed.configureTestingModule({
            providers: [
                { provide: AuthService, useValue: authSpy },
                { provide: Router, useValue: rSpy }
            ]
        });

        authServiceSpy = TestBed.inject(AuthService) as MockedObject<AuthService>;
        routerSpy = TestBed.inject(Router) as MockedObject<Router>;
    });

    it('should return true if user is logged in', async () => {
        authServiceSpy.isLoggedIn.mockReturnValue(true);

        const result = await firstValueFrom(TestBed.runInInjectionContext(() => authGuard()));

        expect(result).toBe(true);
        expect(authServiceSpy.isLoggedIn).toHaveBeenCalled();
    });

    it('should return UrlTree to login if user is not logged in', async () => {
        authServiceSpy.isLoggedIn.mockReturnValue(false);
        const urlTree = {} as any;
        routerSpy.parseUrl.mockReturnValue(urlTree);

        const result = await firstValueFrom(TestBed.runInInjectionContext(() => authGuard()));

        expect(result).toBe(urlTree);
        expect(authServiceSpy.isLoggedIn).toHaveBeenCalled();
        expect(routerSpy.parseUrl).toHaveBeenCalledWith('/login');
    });
});
