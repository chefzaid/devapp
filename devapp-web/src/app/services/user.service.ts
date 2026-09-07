import { Injectable } from '@angular/core';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { CreateUserRequest, UpdateUserRequest, User } from '../models/user.model';
import { environment } from '../../environments/environment';
import { apiErrorMessage } from './api-error';

@Injectable({
    providedIn: 'root'
})
export class UserService {
    private readonly baseUrl = `${environment.apiUrl}/users`;

    constructor(private readonly http: HttpClient) { }

    getAllUsers(): Observable<User[]> {
        return this.http.get<User[]>(this.baseUrl).pipe(
            catchError(this.handleError)
        );
    }

    getUserById(id: number): Observable<User> {
        return this.http.get<User>(`${this.baseUrl}/${id}`).pipe(
            catchError(this.handleError)
        );
    }

    createUser(user: CreateUserRequest): Observable<User> {
        return this.http.post<User>(this.baseUrl, user).pipe(
            catchError(this.handleError)
        );
    }

    updateUser(id: number, user: UpdateUserRequest): Observable<User> {
        return this.http.put<User>(`${this.baseUrl}/${id}`, user).pipe(
            catchError(this.handleError)
        );
    }

    deleteUser(id: number): Observable<void> {
        return this.http.delete<void>(`${this.baseUrl}/${id}`).pipe(
            catchError(this.handleError)
        );
    }

    private handleError(error: HttpErrorResponse): Observable<never> {
        const errorMessage = apiErrorMessage(error);
        console.error(errorMessage);
        return throwError(() => errorMessage);
    }
}
