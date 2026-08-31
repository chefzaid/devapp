import { ChangeDetectionStrategy, Component, OnInit, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { UserService } from '../services/user.service';
import { NotificationService } from '../services/notification.service';
import { CreateUserRequest, UpdateUserRequest, User } from '../models/user.model';

@Component({
  selector: 'app-user',
  templateUrl: './user.component.html',
  styleUrls: ['./user.component.css'],
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [FormsModule]
})
export class UserComponent implements OnInit {
  readonly users = signal<User[]>([]);
  newUser: CreateUserRequest = this.emptyUser();
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);
  readonly creating = signal(false);
  readonly editingUserId = signal<number | null>(null);
  editUser: UpdateUserRequest = this.emptyUser();
  readonly saving = signal(false);
  readonly pendingDeleteUserId = signal<number | null>(null);
  readonly deletingUserId = signal<number | null>(null);

  constructor(
    private readonly userService: UserService,
    private readonly notificationService: NotificationService
  ) { }

  ngOnInit(): void {
    this.loadUsers();
  }

  loadUsers(): void {
    this.loading.set(true);
    this.error.set(null);
    this.userService.getAllUsers().subscribe({
      next: (data) => {
        this.users.set(data);
        this.loading.set(false);
        this.notificationService.success(`Loaded ${data.length} users successfully`);
      },
      error: (error) => {
        this.error.set(String(error));
        this.loading.set(false);
        this.notificationService.error(`Failed to load users: ${error}`);
        console.error('Error loading users:', error);
      }
    });
  }

  createUser(): void {
    if (!this.isValidUser(this.newUser)) {
      this.error.set('Name, username and email are required');
      return;
    }

    this.creating.set(true);
    this.error.set(null);
    this.userService.createUser(this.newUser).subscribe({
      next: (user) => {
        this.users.update(users => [...users, user]);
        this.newUser = this.emptyUser();
        this.creating.set(false);
        this.notificationService.success(`User "${user.name}" created successfully`);
      },
      error: (error) => {
        this.error.set(String(error));
        this.creating.set(false);
        this.notificationService.error(`Failed to create user: ${error}`);
        console.error('Error creating user:', error);
      }
    });
  }

  startEditing(user: User): void {
    this.editingUserId.set(user.id);
    this.editUser = { name: user.name, username: user.username, email: user.email };
    this.pendingDeleteUserId.set(null);
    this.error.set(null);
  }

  cancelEditing(): void {
    this.editingUserId.set(null);
    this.editUser = this.emptyUser();
  }

  updateUser(): void {
    const userId = this.editingUserId();
    if (userId === null || !this.isValidUser(this.editUser)) {
      this.error.set('Name, username and email are required');
      return;
    }

    this.saving.set(true);
    this.error.set(null);
    this.userService.updateUser(userId, this.editUser).subscribe({
      next: (updated) => {
        this.users.update(users => users.map(user => user.id === updated.id ? updated : user));
        this.saving.set(false);
        this.cancelEditing();
        this.notificationService.success(`User "${updated.name}" updated successfully`);
      },
      error: (error) => {
        this.error.set(String(error));
        this.saving.set(false);
        this.notificationService.error(`Failed to update user: ${error}`);
      }
    });
  }

  requestDelete(userId: number): void {
    this.pendingDeleteUserId.set(userId);
    this.error.set(null);
  }

  cancelDelete(): void {
    this.pendingDeleteUserId.set(null);
  }

  deleteUser(user: User): void {
    this.deletingUserId.set(user.id);
    this.error.set(null);
    this.userService.deleteUser(user.id).subscribe({
      next: () => {
        this.users.update(users => users.filter(candidate => candidate.id !== user.id));
        if (this.editingUserId() === user.id) {
          this.cancelEditing();
        }
        this.pendingDeleteUserId.set(null);
        this.deletingUserId.set(null);
        this.notificationService.success(`User "${user.name}" deleted successfully`);
      },
      error: (error) => {
        this.error.set(String(error));
        this.deletingUserId.set(null);
        this.notificationService.error(`Failed to delete user: ${error}`);
      }
    });
  }

  private isValidUser(user: CreateUserRequest | UpdateUserRequest): boolean {
    return Boolean(user.name.trim() && user.username.trim() && user.email.trim());
  }

  private emptyUser(): CreateUserRequest {
    return { name: '', username: '', email: '' };
  }
}
