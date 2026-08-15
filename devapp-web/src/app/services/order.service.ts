import { Injectable } from '@angular/core';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { CreateOrderRequest, Order } from '../models/order.model';
import { environment } from '../../environments/environment';
import { apiErrorMessage } from './api-error';

@Injectable({
    providedIn: 'root'
})
export class OrderService {
    private readonly baseUrl = `${environment.orderApiUrl}/orders`;

    constructor(private readonly http: HttpClient) { }

    getAllOrders(): Observable<Order[]> {
        return this.http.get<Order[]>(this.baseUrl).pipe(
            catchError(this.handleError)
        );
    }

    getOrderById(id: number): Observable<Order> {
        return this.http.get<Order>(`${this.baseUrl}/${id}`).pipe(
            catchError(this.handleError)
        );
    }

    createOrder(order: CreateOrderRequest): Observable<Order> {
        return this.http.post<Order>(this.baseUrl, order).pipe(
            catchError(this.handleError)
        );
    }

    private handleError(error: HttpErrorResponse): Observable<never> {
        const errorMessage = apiErrorMessage(error);
        console.error(errorMessage);
        return throwError(() => errorMessage);
    }
}
