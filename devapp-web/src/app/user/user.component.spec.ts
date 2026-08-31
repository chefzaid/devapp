import { beforeEach, describe, expect, it, type MockedObject, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';

import { UserComponent } from './user.component';
import { UserService } from '../services/user.service';
import { NotificationService } from '../services/notification.service';
import { User } from '../models/user.model';

describe('UserComponent', () => {
  let component: UserComponent;
  let fixture: ComponentFixture<UserComponent>;
  let userService: MockedObject<UserService>;
  let notifications: MockedObject<NotificationService>;

  const alice: User = {
    id: 1,
    name: 'Alice Example',
    username: 'alice',
    email: 'alice@example.com'
  };

  beforeEach(() => {
    userService = {
      getAllUsers: vi.fn().mockReturnValue(of([])),
      createUser: vi.fn(),
      updateUser: vi.fn(),
      deleteUser: vi.fn()
    } as unknown as MockedObject<UserService>;
    notifications = {
      success: vi.fn(),
      error: vi.fn()
    } as unknown as MockedObject<NotificationService>;

    TestBed.configureTestingModule({
      imports: [UserComponent],
      providers: [
        { provide: UserService, useValue: userService },
        { provide: NotificationService, useValue: notifications }
      ]
    });
    fixture = TestBed.createComponent(UserComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('creates and loads users', () => {
    userService.getAllUsers.mockReturnValue(of([alice]));

    component.loadUsers();

    expect(component.users()).toEqual([alice]);
    expect(component.loading()).toBe(false);
    expect(component.error()).toBeNull();
    expect(notifications.success).toHaveBeenCalled();
  });

  it('reports a load failure', () => {
    userService.getAllUsers.mockReturnValue(throwError(() => 'load failed'));

    component.loadUsers();

    expect(component.error()).toBe('load failed');
    expect(component.loading()).toBe(false);
    expect(notifications.error).toHaveBeenCalled();
  });

  it('validates every required create field', () => {
    component.newUser = { name: 'Alice', username: '', email: '' };

    component.createUser();

    expect(component.error()).toContain('required');
    expect(userService.createUser).not.toHaveBeenCalled();
  });

  it('creates a user and resets the form', () => {
    component.newUser = { name: alice.name, username: alice.username, email: alice.email };
    userService.createUser.mockReturnValue(of(alice));

    component.createUser();

    expect(component.users()).toEqual([alice]);
    expect(component.newUser).toEqual({ name: '', username: '', email: '' });
    expect(component.creating()).toBe(false);
    expect(notifications.success).toHaveBeenCalled();
  });

  it('reports a create failure', () => {
    component.newUser = { name: alice.name, username: alice.username, email: alice.email };
    userService.createUser.mockReturnValue(throwError(() => 'create failed'));

    component.createUser();

    expect(component.error()).toBe('create failed');
    expect(component.creating()).toBe(false);
    expect(notifications.error).toHaveBeenCalled();
  });

  it('updates a user and closes the edit form', () => {
    const updated = { ...alice, name: 'Alice Updated' };
    component.users.set([alice]);
    component.startEditing(alice);
    component.editUser.name = updated.name;
    userService.updateUser.mockReturnValue(of(updated));

    component.updateUser();

    expect(userService.updateUser).toHaveBeenCalledWith(1, {
      name: 'Alice Updated', username: 'alice', email: 'alice@example.com'
    });
    expect(component.users()).toEqual([updated]);
    expect(component.editingUserId()).toBeNull();
    expect(component.saving()).toBe(false);
  });

  it('reports an update failure', () => {
    component.startEditing(alice);
    userService.updateUser.mockReturnValue(throwError(() => 'update failed'));

    component.updateUser();

    expect(component.error()).toBe('update failed');
    expect(component.saving()).toBe(false);
    expect(notifications.error).toHaveBeenCalled();
  });

  it('deletes a user after confirmation', () => {
    component.users.set([alice]);
    component.requestDelete(alice.id);
    userService.deleteUser.mockReturnValue(of(undefined));

    component.deleteUser(alice);

    expect(userService.deleteUser).toHaveBeenCalledWith(1);
    expect(component.users()).toEqual([]);
    expect(component.pendingDeleteUserId()).toBeNull();
    expect(component.deletingUserId()).toBeNull();
  });
});
