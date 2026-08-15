import { HttpErrorResponse } from '@angular/common/http';

interface ProblemDetails {
  detail?: string;
  message?: string;
  title?: string;
}

export function apiErrorMessage(error: HttpErrorResponse): string {
  if (error.error instanceof ErrorEvent) {
    return error.error.message;
  }

  const problem = error.error as ProblemDetails | string | null;
  if (typeof problem === 'string' && problem.trim()) {
    return problem;
  }
  if (problem && typeof problem === 'object') {
    return problem.detail ?? problem.message ?? problem.title ?? `Request failed (${error.status})`;
  }
  return error.message || `Request failed (${error.status})`;
}
