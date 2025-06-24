import { Injectable } from '@angular/core';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { Order } from '../models/order.model';
import { environment } from '../../environments/environment';

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

    createOrder(order: Order): Observable<Order> {
        return this.http.post<Order>(this.baseUrl, order).pipe(
            catchError(this.handleError)
        );
    }

    private handleError(error: HttpErrorResponse): Observable<never> {
        let errorMessage = 'An unknown error occurred!';
        if (error.error instanceof ErrorEvent) {
            // Client-side error
            errorMessage = `Error: ${error.error.message}`;
        } else {
            // Server-side error
            errorMessage = `Error Code: ${error.status}\nMessage: ${error.message}`;
            if (error.error?.message) {
                errorMessage = error.error.message;
            }
        }
        console.error(errorMessage);
        return throwError(() => errorMessage);
    }
}