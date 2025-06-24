import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { UserService } from '../services/user.service';
import { NotificationService } from '../services/notification.service';
import { User } from '../models/user.model';

@Component({
  selector: 'app-user',
  templateUrl: './user.component.html',
  styleUrls: ['./user.component.css'],
  standalone: true,
  imports: [CommonModule, FormsModule]
})
export class UserComponent implements OnInit {
  users: User[] = [];
  newUser: User = { name: '' };
  loading = false;
  error: string | null = null;
  creating = false;

  constructor(
    private readonly userService: UserService,
    private readonly notificationService: NotificationService
  ) { }

  ngOnInit(): void {
    this.loadUsers();
  }

  loadUsers(): void {
    this.loading = true;
    this.error = null;
    this.userService.getAllUsers().subscribe({
      next: (data) => {
        this.users = data;
        this.loading = false;
        this.notificationService.success(`Loaded ${data.length} users successfully`);
      },
      error: (error) => {
        this.error = error;
        this.loading = false;
        this.notificationService.error(`Failed to load users: ${error}`);
        console.error('Error loading users:', error);
      }
    });
  }

  createUser(): void {
    if (!this.newUser.name.trim()) {
      this.error = 'Name is required';
      return;
    }

    this.creating = true;
    this.error = null;
    this.userService.createUser(this.newUser).subscribe({
      next: (user) => {
        this.users.push(user);
        this.newUser = { name: '' };
        this.creating = false;
        this.notificationService.success(`User "${user.name}" created successfully`);
      },
      error: (error) => {
        this.error = error;
        this.creating = false;
        this.notificationService.error(`Failed to create user: ${error}`);
        console.error('Error creating user:', error);
      }
    });
  }
}