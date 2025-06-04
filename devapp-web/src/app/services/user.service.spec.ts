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

    const req = http.expectOne('http://localhost:8080/api/users');
    expect(req.request.method).toBe('GET');
    req.flush(mockUsers);
  });

  it('should create user', () => {
    const user: User = { id: 1, name: 'test' };

    service.createUser(user).subscribe(data => {
      expect(data).toEqual(user);
    });

    const req = http.expectOne('http://localhost:8080/api/users');
    expect(req.request.method).toBe('POST');
    req.flush(user);
  });
});
