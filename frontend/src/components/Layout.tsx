import { Outlet, NavLink, useNavigate } from 'react-router-dom'
import { useAuthStore } from '@/stores/authStore'
import { ArcadeNodeIcon } from '@/components/ArcadeNodeIcon'
import {
  HomeIcon,
  ServerIcon,
  CogIcon,
  UsersIcon,
  CubeIcon,
  ArrowRightOnRectangleIcon,
  Bars3Icon,
  XMarkIcon,
  RocketLaunchIcon,
} from '@heroicons/react/24/outline'
import { useState } from 'react'
import clsx from 'clsx'

export default function Layout() {
  const { user, logout } = useAuthStore()
  const navigate = useNavigate()
  const [sidebarOpen, setSidebarOpen] = useState(false)

  const isAdmin = user?.role === 'Admin' || user?.role === 'SuperAdmin'

  const handleLogout = () => {
    logout()
    navigate('/login')
  }

  const navItems = [
    { name: 'Dashboard', href: '/', icon: HomeIcon },
    { name: 'Servers', href: '/servers', icon: ServerIcon },
    { name: 'Settings', href: '/settings', icon: CogIcon },
  ]

  const adminItems = [
    { name: 'Deploy Server', href: '/admin/deploy', icon: RocketLaunchIcon },
    { name: 'Nodes', href: '/admin/nodes', icon: CubeIcon },
    { name: 'Users', href: '/admin/users', icon: UsersIcon },
  ]

  return (
    <div className="min-h-screen bg-panel-darker">
      {/* Mobile sidebar backdrop */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/50 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside
        className={clsx(
          'fixed inset-y-0 left-0 z-50 w-64 bg-panel-dark border-r border-panel-border transform transition-transform lg:translate-x-0',
          sidebarOpen ? 'translate-x-0' : '-translate-x-full'
        )}
      >
        <div className="flex h-16 items-center justify-between px-4 border-b border-panel-border">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 bg-gradient-to-br from-violet-500 to-fuchsia-500 rounded-lg flex items-center justify-center">
              <ArcadeNodeIcon className="w-5 h-5 text-white" />
            </div>
            <span className="text-xl font-bold bg-gradient-to-r from-violet-400 to-fuchsia-400 bg-clip-text text-transparent">ArcadeNode</span>
          </div>
          <button
            className="lg:hidden text-gray-400 hover:text-white"
            onClick={() => setSidebarOpen(false)}
          >
            <XMarkIcon className="h-6 w-6" />
          </button>
        </div>

        <nav className="flex flex-col h-[calc(100%-4rem)] px-3 py-4">
          <div className="flex-1 space-y-1">
            {navItems.map((item) => (
              <NavLink
                key={item.href}
                to={item.href}
                end={item.href === '/'}
                className={({ isActive }) =>
                  clsx(
                    'flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors',
                    isActive
                      ? 'bg-primary-600 text-white'
                      : 'text-gray-400 hover:bg-panel-card hover:text-white'
                  )
                }
                onClick={() => setSidebarOpen(false)}
              >
                <item.icon className="h-5 w-5" />
                {item.name}
              </NavLink>
            ))}

            {isAdmin && (
              <>
                <div className="pt-4 pb-2">
                  <p className="px-3 text-xs font-semibold text-gray-500 uppercase tracking-wider">
                    Administration
                  </p>
                </div>
                {adminItems.map((item) => (
                  <NavLink
                    key={item.href}
                    to={item.href}
                    className={({ isActive }) =>
                      clsx(
                        'flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors',
                        isActive
                          ? 'bg-primary-600 text-white'
                          : 'text-gray-400 hover:bg-panel-card hover:text-white'
                      )
                    }
                    onClick={() => setSidebarOpen(false)}
                  >
                    <item.icon className="h-5 w-5" />
                    {item.name}
                  </NavLink>
                ))}
              </>
            )}
          </div>

          <div className="border-t border-panel-border pt-4">
            <div className="px-3 py-2">
              <p className="text-sm font-medium text-white">{user?.username}</p>
              <p className="text-xs text-gray-500">{user?.email}</p>
            </div>
            <button
              onClick={handleLogout}
              className="flex w-full items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium text-gray-400 hover:bg-red-500/10 hover:text-red-400 transition-colors"
            >
              <ArrowRightOnRectangleIcon className="h-5 w-5" />
              Logout
            </button>
          </div>
        </nav>
      </aside>

      {/* Main content */}
      <div className="lg:pl-64">
        {/* Top bar */}
        <header className="sticky top-0 z-40 flex h-16 items-center gap-4 border-b border-panel-border bg-panel-dark px-4 lg:px-6">
          <button
            className="lg:hidden text-gray-400 hover:text-white"
            onClick={() => setSidebarOpen(true)}
          >
            <Bars3Icon className="h-6 w-6" />
          </button>
        </header>

        {/* Page content */}
        <main className="p-4 lg:p-6 min-h-[calc(100vh-4rem)]">
          <Outlet />
        </main>

        {/* Footer */}
        <footer className="border-t border-panel-border bg-panel-dark px-4 lg:px-6 py-4">
          <div className="flex flex-col sm:flex-row items-center justify-between gap-2 text-sm text-gray-500">
            <div className="flex items-center gap-2">
              <div className="w-5 h-5 bg-gradient-to-br from-violet-500 to-fuchsia-500 rounded flex items-center justify-center">
                <ArcadeNodeIcon className="w-3 h-3 text-white" />
              </div>
              <span className="font-medium bg-gradient-to-r from-violet-400 to-fuchsia-400 bg-clip-text text-transparent">ArcadeNode</span>
            </div>
            <div className="flex items-center gap-4">
              <span className="text-xs px-2 py-0.5 bg-accent-zomboid/10 text-accent-zomboid rounded">Zomboid</span>
              <span className="text-xs px-2 py-0.5 bg-accent-arma/10 text-accent-arma rounded">Arma</span>
              <span className="text-xs px-2 py-0.5 bg-accent-minecraft/10 text-accent-minecraft rounded">Minecraft</span>
            </div>
          </div>
        </footer>
      </div>
    </div>
  )
}
