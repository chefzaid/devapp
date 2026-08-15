import { ChangeDetectionStrategy, Component, OnInit, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { OrderService } from '../services/order.service';
import { UserService } from '../services/user.service';
import { CreateOrderRequest, Order } from '../models/order.model';
import { User } from '../models/user.model';

@Component({
  selector: 'app-order',
  templateUrl: './order.component.html',
  styleUrls: ['./order.component.css'],
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [FormsModule]
})
export class OrderComponent implements OnInit {
  readonly orders = signal<Order[]>([]);
  readonly users = signal<User[]>([]);
  newOrder: CreateOrderRequest = this.initOrder();
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);
  readonly creating = signal(false);
  readonly loadingUsers = signal(false);

  constructor(
    private readonly orderService: OrderService,
    private readonly userService: UserService
  ) { }

  ngOnInit(): void {
    this.loadOrders();
    this.loadUsers();
  }

  loadOrders(): void {
    this.loading.set(true);
    this.error.set(null);
    this.orderService.getAllOrders().subscribe({
      next: (data) => {
        this.orders.set(data);
        this.loading.set(false);
      },
      error: (error) => {
        this.error.set(String(error));
        this.loading.set(false);
        console.error('Error loading orders:', error);
      }
    });
  }

  loadUsers(): void {
    this.loadingUsers.set(true);
    this.userService.getAllUsers().subscribe({
      next: (data) => {
        this.users.set(data);
        this.loadingUsers.set(false);
      },
      error: (error) => {
        console.error('Error loading users:', error);
        this.loadingUsers.set(false);
      }
    });
  }

  createOrder(): void {
    if (this.newOrder.userId <= 0 || this.newOrder.productId <= 0) {
      this.error.set('Please select a user and enter a positive product ID');
      return;
    }

    this.creating.set(true);
    this.error.set(null);
    this.orderService.createOrder(this.newOrder).subscribe({
      next: (order) => {
        this.orders.update(orders => [...orders, order]);
        this.newOrder = this.initOrder();
        this.creating.set(false);
      },
      error: (error) => {
        this.error.set(String(error));
        this.creating.set(false);
        console.error('Error creating order:', error);
      }
    });
  }

  initOrder(): CreateOrderRequest {
    return { userId: 0, productId: 0 };
  }
}
