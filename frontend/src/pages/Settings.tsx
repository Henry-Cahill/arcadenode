import { useState } from 'react'
import { useForm } from 'react-hook-form'
import toast from 'react-hot-toast'
import { authService } from '@/services/api'
import { useAuthStore } from '@/stores/authStore'
import { getErrorMessage } from '@/lib/errorHandler'
import { usePageTitle } from '@/lib/usePageTitle'
import { ArcadeNodeIcon } from '@/components/ArcadeNodeIcon'

interface ProfileForm {
  firstName: string
  lastName: string
  email: string
}

interface PasswordForm {
  currentPassword: string
  newPassword: string
  confirmPassword: string
}

export default function Settings() {
  usePageTitle('Settings')
  const { user, updateUser } = useAuthStore()
  const [isProfileLoading, setIsProfileLoading] = useState(false)
  const [isPasswordLoading, setIsPasswordLoading] = useState(false)

  const profileForm = useForm<ProfileForm>({
    defaultValues: {
      firstName: user?.firstName || '',
      lastName: user?.lastName || '',
      email: user?.email || '',
    },
  })

  const passwordForm = useForm<PasswordForm>()

  const onProfileSubmit = async (data: ProfileForm) => {
    setIsProfileLoading(true)
    try {
      await authService.updateProfile(data.firstName, data.lastName, data.email)
      updateUser(data)
      toast.success('Profile updated successfully')
    } catch (error) {
      toast.error(getErrorMessage(error, 'Failed to update profile'))
    } finally {
      setIsProfileLoading(false)
    }
  }

  const onPasswordSubmit = async (data: PasswordForm) => {
    if (data.newPassword !== data.confirmPassword) {
      toast.error('Passwords do not match')
      return
    }

    setIsPasswordLoading(true)
    try {
      await authService.changePassword(data.currentPassword, data.newPassword)
      passwordForm.reset()
      toast.success('Password changed successfully')
    } catch (error) {
      toast.error(getErrorMessage(error, 'Failed to change password'))
    } finally {
      setIsPasswordLoading(false)
    }
  }

  return (
    <div className="max-w-2xl">
      <h1 className="text-2xl font-bold text-white mb-6">Settings</h1>

      {/* Profile Settings */}
      <div className="bg-panel-card border border-panel-border rounded-xl p-6 mb-6">
        <h2 className="text-lg font-semibold text-white mb-4">Profile Information</h2>
        <form onSubmit={profileForm.handleSubmit(onProfileSubmit)} className="space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-300 mb-1">First Name</label>
              <input
                type="text"
                {...profileForm.register('firstName')}
                className="w-full px-4 py-2 bg-panel-dark border border-panel-border rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary-500"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-300 mb-1">Last Name</label>
              <input
                type="text"
                {...profileForm.register('lastName')}
                className="w-full px-4 py-2 bg-panel-dark border border-panel-border rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary-500"
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-300 mb-1">Email</label>
            <input
              type="email"
              {...profileForm.register('email', { required: true })}
              className="w-full px-4 py-2 bg-panel-dark border border-panel-border rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary-500"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-300 mb-1">Username</label>
            <input
              type="text"
              value={user?.username}
              disabled
              className="w-full px-4 py-2 bg-panel-dark border border-panel-border rounded-lg text-gray-400 cursor-not-allowed"
            />
            <p className="mt-1 text-xs text-gray-500">Username cannot be changed</p>
          </div>

          <button
            type="submit"
            disabled={isProfileLoading}
            className="px-4 py-2 bg-primary-600 hover:bg-primary-700 disabled:bg-primary-800 text-white font-medium rounded-lg transition-colors"
          >
            {isProfileLoading ? 'Saving...' : 'Save Changes'}
          </button>
        </form>
      </div>

      {/* Password Settings */}
      <div className="bg-panel-card border border-panel-border rounded-xl p-6">
        <h2 className="text-lg font-semibold text-white mb-4">Change Password</h2>
        <form onSubmit={passwordForm.handleSubmit(onPasswordSubmit)} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-1">Current Password</label>
            <input
              type="password"
              {...passwordForm.register('currentPassword', { required: true })}
              className="w-full px-4 py-2 bg-panel-dark border border-panel-border rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary-500"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-300 mb-1">New Password</label>
            <input
              type="password"
              {...passwordForm.register('newPassword', { required: true, minLength: 8 })}
              className="w-full px-4 py-2 bg-panel-dark border border-panel-border rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary-500"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-300 mb-1">
              Confirm New Password
            </label>
            <input
              type="password"
              {...passwordForm.register('confirmPassword', { required: true })}
              className="w-full px-4 py-2 bg-panel-dark border border-panel-border rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary-500"
            />
          </div>

          <button
            type="submit"
            disabled={isPasswordLoading}
            className="px-4 py-2 bg-primary-600 hover:bg-primary-700 disabled:bg-primary-800 text-white font-medium rounded-lg transition-colors"
          >
            {isPasswordLoading ? 'Changing...' : 'Change Password'}
          </button>
        </form>
      </div>

      {/* About Section */}
      <div className="bg-gradient-to-r from-violet-900/20 to-fuchsia-900/20 border border-violet-500/20 rounded-xl p-6 mt-6">
        <div className="flex items-center gap-3 mb-3">
          <div className="w-10 h-10 bg-gradient-to-br from-violet-500 to-fuchsia-500 rounded-xl flex items-center justify-center">
            <ArcadeNodeIcon className="w-6 h-6 text-white" />
          </div>
          <div>
            <h3 className="text-lg font-semibold bg-gradient-to-r from-violet-400 to-fuchsia-400 bg-clip-text text-transparent">ArcadeNode</h3>
            <p className="text-xs text-gray-500">Game Server Management Panel</p>
          </div>
        </div>
        <p className="text-sm text-gray-400">
          Hosting Project Zomboid, Arma Reforger & Minecraft servers with ease.
        </p>
      </div>
    </div>
  )
}
