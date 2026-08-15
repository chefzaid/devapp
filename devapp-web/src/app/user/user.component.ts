import { ChangeDetectionStrategy, Component, OnInit, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { UserService } from '../services/user.service';
import { NotificationService } from '../services/notification.service';
import { CreateUserRequest, User } from '../models/user.model';

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
    if (!this.newUser.name.trim()) {
      this.error.set('Name, username and email are required');
      return;
    }

    if (!this.newUser.username.trim() || !this.newUser.email.trim()) {
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

  private emptyUser(): CreateUserRequest {
    return { name: '', username: '', email: '' };
  }
}
