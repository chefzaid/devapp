import { Injectable } from '@angular/core';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { User } from '../models/user.model';
import { environment } from '../../environments/environment';

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

    createUser(user: User): Observable<User> {
        return this.http.post<User>(this.baseUrl, user).pipe(
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
            if (error.error && error.error.message) {
                errorMessage = error.error.message;
            }
        }
        console.error(errorMessage);
        return throwError(() => errorMessage);
    }
}