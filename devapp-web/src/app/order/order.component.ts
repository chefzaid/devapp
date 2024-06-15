import { Component, OnInit } from '@angular/core';
import { OrderService } from '../services/order.service';
import { Order } from '../models/order.model';

@Component({
  selector: 'app-order',
  templateUrl: './order.component.html',
  styleUrls: ['./order.component.css']
})
export class OrderComponent implements OnInit {
  orders: Order[] = [];
  newOrder: Order = this.initOrder();

  constructor(private orderService: OrderService) { }

  ngOnInit(): void {
    this.orderService.getAllOrders().subscribe(data => {
      this.orders = data;
    });
  }

  createOrder(): void {
    this.orderService.createOrder(this.newOrder).subscribe(order => {
      this.orders.push(order);
      this.newOrder = this.initOrder();
    });
  }

  initOrder(): Order {
    return { user: { id: 0, name: '' }, productId: 0 };
  }
}