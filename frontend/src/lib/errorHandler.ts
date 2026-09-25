import { AxiosError } from 'axios'

interface ApiErrorResponse {
  message?: string
  errors?: Record<string, string[]>
}

/**
 * Extracts a user-friendly error message from an unknown caught error.
 * Handles AxiosError responses, native Error objects, and unknown types.
 */
export function getErrorMessage(error: unknown, fallback = 'An unexpected error occurred'): string {
  if (error instanceof AxiosError) {
    const data = error.response?.data as ApiErrorResponse | undefined
    return data?.message || error.message || fallback
  }

  if (error instanceof Error) {
    return error.message || fallback
  }

  if (typeof error === 'string') {
    return error
  }

  return fallback
}
