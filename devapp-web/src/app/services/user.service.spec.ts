import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { UserService } from './user.service';
import { UpdateUserRequest, User } from '../models/user.model';

describe('UserService', () => {
    let service: UserService;
    let http: HttpTestingController;

    beforeEach(() => {
        TestBed.configureTestingModule({
            providers: [provideHttpClient(), provideHttpClientTesting()]
        });
        service = TestBed.inject(UserService);
        http = TestBed.inject(HttpTestingController);
    });

    afterEach(() => {
        http.verify();
    });

    it('should fetch users', () => {
        const mockUsers: User[] = [{ id: 1, name: 'Test User', username: 'test', email: 'test@example.com' }];

        service.getAllUsers().subscribe(data => {
            expect(data).toEqual(mockUsers);
        });

        const req = http.expectOne('/api/users');
        expect(req.request.method).toBe('GET');
        req.flush(mockUsers);
    });

    it('should create user', () => {
        const user: User = { id: 1, name: 'Test User', username: 'test', email: 'test@example.com' };

        service.createUser(user).subscribe(data => {
            expect(data).toEqual(user);
        });

        const req = http.expectOne('/api/users');
        expect(req.request.method).toBe('POST');
        req.flush(user);
    });

    it('should fetch user by id', () => {
        const user: User = { id: 2, name: 'Alice', username: 'alice', email: 'alice@example.com' };

        service.getUserById(2).subscribe(data => {
            expect(data).toEqual(user);
        });

        const req = http.expectOne('/api/users/2');
        expect(req.request.method).toBe('GET');
        req.flush(user);
    });

    it('should update user', () => {
        const update: UpdateUserRequest = {
            name: 'Alice Updated',
            username: 'alice',
            email: 'alice@example.com'
        };
        const user: User = { id: 2, name: 'Alice Updated', username: 'alice', email: 'alice@example.com' };

        service.updateUser(2, update).subscribe(data => expect(data).toEqual(user));

        const req = http.expectOne('/api/users/2');
        expect(req.request.method).toBe('PUT');
        expect(req.request.body).toEqual(update);
        req.flush(user);
    });

    it('should delete user', () => {
        service.deleteUser(2).subscribe();

        const req = http.expectOne('/api/users/2');
        expect(req.request.method).toBe('DELETE');
        req.flush(null);
    });

    it('should return server message when available', async () => {
        service.getAllUsers().subscribe({
            next: () => { throw new Error('expected error'); },
            error: (error) => {
                expect(error).toBe('backend failure');
                ;
            }
        });

        const req = http.expectOne('/api/users');
        req.flush({ message: 'backend failure' }, { status: 500, statusText: 'Server Error' });
    });

    it('should return a fallback title when problem details omit a message', async () => {
        service.getAllUsers().subscribe({
            next: () => { throw new Error('expected error'); },
            error: (error) => {
                expect(error).toBe('Request failed (500)');
                ;
            }
        });

        const req = http.expectOne('/api/users');
        req.flush({}, { status: 500, statusText: 'Server Error' });
    });

    it('should return client-side error message', async () => {
        service.getAllUsers().subscribe({
            next: () => { throw new Error('expected error'); },
            error: (error) => {
                expect(error).toContain('client issue');
                ;
            }
        });

        const req = http.expectOne('/api/users');
        req.error(new ErrorEvent('NetworkError', { message: 'client issue' }));
    });
});
