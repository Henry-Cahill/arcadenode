import axios from 'axios'
import { useAuthStore } from '@/stores/authStore'

const API_URL = import.meta.env.VITE_API_URL || '/api'

/**
 * Read a cookie value by name.
 */
function getCookie(name: string): string | null {
  const match = document.cookie.match(new RegExp(`(?:^|;\\s*)${name}=([^;]*)`))
  return match ? decodeURIComponent(match[1]) : null
}

const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true, // send/receive cookies for CSRF
})

// Request interceptor to add auth token and CSRF header
api.interceptors.request.use(
  (config) => {
    // Attach JWT bearer token
    const token = useAuthStore.getState().token
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }

    // Attach CSRF token on mutating requests
    const method = config.method?.toUpperCase()
    if (method === 'POST' || method === 'PUT' || method === 'DELETE' || method === 'PATCH') {
      const csrfToken = getCookie('XSRF-TOKEN')
      if (csrfToken) {
        config.headers['X-XSRF-TOKEN'] = csrfToken
      }
    }

    return config
  },
  (error) => {
    return Promise.reject(error)
  }
)

// Response interceptor to handle auth errors
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      useAuthStore.getState().logout()
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)

export default api
