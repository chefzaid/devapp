import { TestBed } from '@angular/core/testing';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { UserService } from './user.service';
import { User } from '../models/user.model';

describe('UserService', () => {
  let service: UserService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule]
    });
    service = TestBed.inject(UserService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    http.verify();
  });

  it('should fetch users', () => {
    const mockUsers: User[] = [{ id: 1, name: 'test' }];

    service.getAllUsers().subscribe(data => {
      expect(data).toEqual(mockUsers);
    });

    const req = http.expectOne('/api/users');
    expect(req.request.method).toBe('GET');
    req.flush(mockUsers);
  });

  it('should create user', () => {
    const user: User = { id: 1, name: 'test' };

    service.createUser(user).subscribe(data => {
      expect(data).toEqual(user);
    });

    const req = http.expectOne('/api/users');
    expect(req.request.method).toBe('POST');
    req.flush(user);
  });

  it('should fetch user by id', () => {
    const user: User = { id: 2, name: 'alice' };

    service.getUserById(2).subscribe(data => {
      expect(data).toEqual(user);
    });

    const req = http.expectOne('/api/users/2');
    expect(req.request.method).toBe('GET');
    req.flush(user);
  });

  it('should return server message when available', (done) => {
    service.getAllUsers().subscribe({
      next: () => fail('expected error'),
      error: (error) => {
        expect(error).toBe('backend failure');
        done();
      }
    });

    const req = http.expectOne('/api/users');
    req.flush({ message: 'backend failure' }, { status: 500, statusText: 'Server Error' });
  });

  it('should return formatted error code message when server message is missing', (done) => {
    service.getAllUsers().subscribe({
      next: () => fail('expected error'),
      error: (error) => {
        expect(error).toContain('Error Code: 500');
        done();
      }
    });

    const req = http.expectOne('/api/users');
    req.flush({}, { status: 500, statusText: 'Server Error' });
  });

  it('should return client-side error message', (done) => {
    service.getAllUsers().subscribe({
      next: () => fail('expected error'),
      error: (error) => {
        expect(error).toContain('client issue');
        done();
      }
    });

    const req = http.expectOne('/api/users');
    req.error(new ErrorEvent('NetworkError', { message: 'client issue' }));
  });
});
