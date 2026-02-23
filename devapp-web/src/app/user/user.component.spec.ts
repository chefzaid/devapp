import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';

import { UserComponent } from './user.component';
import { UserService } from '../services/user.service';
import { NotificationService } from '../services/notification.service';

describe('UserComponent', () => {
  let component: UserComponent;
  let fixture: ComponentFixture<UserComponent>;
  let userServiceSpy: jasmine.SpyObj<UserService>;
  let notificationServiceSpy: jasmine.SpyObj<NotificationService>;

  beforeEach(() => {
    userServiceSpy = jasmine.createSpyObj('UserService', ['getAllUsers', 'createUser']);
    notificationServiceSpy = jasmine.createSpyObj('NotificationService', ['success', 'error']);
    userServiceSpy.getAllUsers.and.returnValue(of([]));

    TestBed.configureTestingModule({
      imports: [UserComponent],
      providers: [
        { provide: UserService, useValue: userServiceSpy },
        { provide: NotificationService, useValue: notificationServiceSpy }
      ]
    });
    fixture = TestBed.createComponent(UserComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should load users successfully', () => {
    const users = [{ id: 1, name: 'Alice' }];
    userServiceSpy.getAllUsers.and.returnValue(of(users));

    component.loadUsers();

    expect(component.users).toEqual(users);
    expect(component.loading).toBeFalse();
    expect(component.error).toBeNull();
    expect(notificationServiceSpy.success).toHaveBeenCalled();
  });

  it('should handle load users failure', () => {
    userServiceSpy.getAllUsers.and.returnValue(throwError(() => 'load failed'));

    component.loadUsers();

    expect(component.error).toBe('load failed');
    expect(component.loading).toBeFalse();
    expect(notificationServiceSpy.error).toHaveBeenCalled();
  });

  it('should validate empty user name before create', () => {
    component.newUser = { name: '   ' };

    component.createUser();

    expect(component.error).toBe('Name is required');
    expect(userServiceSpy.createUser).not.toHaveBeenCalled();
  });

  it('should create user successfully', () => {
    component.newUser = { name: 'Bob' };
    userServiceSpy.createUser.and.returnValue(of({ id: 2, name: 'Bob' }));

    component.createUser();

    expect(component.users.length).toBe(1);
    expect(component.users[0].name).toBe('Bob');
    expect(component.newUser.name).toBe('');
    expect(component.creating).toBeFalse();
    expect(notificationServiceSpy.success).toHaveBeenCalled();
  });

  it('should handle create user failure', () => {
    component.newUser = { name: 'Bob' };
    userServiceSpy.createUser.and.returnValue(throwError(() => 'create failed'));

    component.createUser();

    expect(component.error).toBe('create failed');
    expect(component.creating).toBeFalse();
    expect(notificationServiceSpy.error).toHaveBeenCalled();
  });
});
