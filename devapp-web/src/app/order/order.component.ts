import { Component, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { OrderService } from '../services/order.service';
import { UserService } from '../services/user.service';
import { Order } from '../models/order.model';
import { User } from '../models/user.model';

@Component({
  selector: 'app-order',
  templateUrl: './order.component.html',
  styleUrls: ['./order.component.css'],
  imports: [FormsModule]
})
export class OrderComponent implements OnInit {
  orders: Order[] = [];
  users: User[] = [];
  newOrder: Order = this.initOrder();
  loading = false;
  error: string | null = null;
  creating = false;
  loadingUsers = false;

  constructor(
    private readonly orderService: OrderService,
    private readonly userService: UserService
  ) { }

  ngOnInit(): void {
    this.loadOrders();
    this.loadUsers();
  }

  loadOrders(): void {
    this.loading = true;
    this.error = null;
    this.orderService.getAllOrders().subscribe({
      next: (data) => {
        this.orders = data;
        this.loading = false;
      },
      error: (error) => {
        this.error = error;
        this.loading = false;
        console.error('Error loading orders:', error);
      }
    });
  }

  loadUsers(): void {
    this.loadingUsers = true;
    this.userService.getAllUsers().subscribe({
      next: (data) => {
        this.users = data;
        this.loadingUsers = false;
      },
      error: (error) => {
        console.error('Error loading users:', error);
        this.loadingUsers = false;
      }
    });
  }

  createOrder(): void {
    if (!this.newOrder.user.id || !this.newOrder.productId) {
      this.error = 'Please select a user and enter a product ID';
      return;
    }

    this.creating = true;
    this.error = null;
    this.orderService.createOrder(this.newOrder).subscribe({
      next: (order) => {
        this.orders.push(order);
        this.newOrder = this.initOrder();
        this.creating = false;
      },
      error: (error) => {
        this.error = error;
        this.creating = false;
        console.error('Error creating order:', error);
      }
    });
  }

  initOrder(): Order {
    return { user: { id: 0, name: '' }, productId: 0, status: 'PENDING' };
  }

  onUserChange(userId: number): void {
    const selectedUser = this.users.find(u => u.id === userId);
    if (selectedUser) {
      this.newOrder.user = selectedUser;
    }
  }
}