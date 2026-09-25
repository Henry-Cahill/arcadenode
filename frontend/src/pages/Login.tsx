import { useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { useForm } from 'react-hook-form'
import toast from 'react-hot-toast'
import { authService } from '@/services/api'
import { useAuthStore } from '@/stores/authStore'
import { getErrorMessage } from '@/lib/errorHandler'
import { usePageTitle } from '@/lib/usePageTitle'
import { ArcadeNodeIcon } from '@/components/ArcadeNodeIcon'

interface LoginForm {
  username: string
  password: string
}

export default function Login() {
  usePageTitle('Login')
  const navigate = useNavigate()
  const login = useAuthStore((state) => state.login)
  const [isLoading, setIsLoading] = useState(false)

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginForm>()

  const onSubmit = async (data: LoginForm) => {
    setIsLoading(true)
    try {
      const response = await authService.login(data.username, data.password)
      login(response.token, response.user)
      toast.success('Welcome back!')
      navigate('/')
    } catch (error) {
      toast.error(getErrorMessage(error, 'Invalid credentials'))
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-panel-darker px-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <div className="flex justify-center mb-4">
            <div className="w-16 h-16 bg-gradient-to-br from-violet-500 to-fuchsia-500 rounded-2xl flex items-center justify-center shadow-lg shadow-violet-500/25">
              <ArcadeNodeIcon className="w-10 h-10 text-white" />
            </div>
          </div>
          <h1 className="text-3xl font-bold bg-gradient-to-r from-violet-400 to-fuchsia-400 bg-clip-text text-transparent">ArcadeNode</h1>
          <p className="text-gray-400 mt-2">Sign in to manage your game servers</p>
        </div>

        <div className="bg-panel-card border border-panel-border rounded-xl p-6">
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-300 mb-1">
                Username or Email
              </label>
              <input
                type="text"
                {...register('username', { required: 'Username is required' })}
                className="w-full px-4 py-2 bg-panel-dark border border-panel-border rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                placeholder="Enter your username"
              />
              {errors.username && (
                <p className="mt-1 text-sm text-red-400">{errors.username.message}</p>
              )}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-300 mb-1">
                Password
              </label>
              <input
                type="password"
                {...register('password', { required: 'Password is required' })}
                className="w-full px-4 py-2 bg-panel-dark border border-panel-border rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                placeholder="Enter your password"
              />
              {errors.password && (
                <p className="mt-1 text-sm text-red-400">{errors.password.message}</p>
              )}
            </div>

            <button
              type="submit"
              disabled={isLoading}
              className="w-full py-2 px-4 bg-primary-600 hover:bg-primary-700 disabled:bg-primary-800 disabled:cursor-not-allowed text-white font-medium rounded-lg transition-colors"
            >
              {isLoading ? 'Signing in...' : 'Sign In'}
            </button>
          </form>

          <p className="mt-4 text-center text-sm text-gray-400">
            Don't have an account?{' '}
            <Link to="/register" className="text-primary-400 hover:text-primary-300">
              Register
            </Link>
          </p>
        </div>

        <p className="mt-6 text-center text-xs text-gray-600">
          ArcadeNode — Game Server Management
        </p>
      </div>
    </div>
  )
}
