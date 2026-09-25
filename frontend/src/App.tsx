import { Routes, Route, Navigate } from 'react-router-dom'
import { useAuthStore } from '@/stores/authStore'
import Layout from '@/components/Layout'
import Login from '@/pages/Login'
import Register from '@/pages/Register'
import Dashboard from '@/pages/Dashboard'
import Servers from '@/pages/Servers'
import ServerDetail from '@/pages/ServerDetail'
import Nodes from '@/pages/admin/Nodes'
import Users from '@/pages/admin/Users'
import DeployWizard from '@/pages/admin/DeployWizard'
import Settings from '@/pages/Settings'
import NotFound from '@/pages/NotFound'

function PrivateRoute({ children }: { children: React.ReactNode }) {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated)
  return isAuthenticated ? <>{children}</> : <Navigate to="/login" />
}

function AdminRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, user } = useAuthStore()
  const isAdmin = user?.role === 'Admin' || user?.role === 'SuperAdmin'
  
  if (!isAuthenticated) return <Navigate to="/login" />
  if (!isAdmin) return <Navigate to="/" />
  
  return <>{children}</>
}

function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/register" element={<Register />} />
      
      <Route
        path="/"
        element={
          <PrivateRoute>
            <Layout />
          </PrivateRoute>
        }
      >
        <Route index element={<Dashboard />} />
        <Route path="servers" element={<Servers />} />
        <Route path="servers/:id" element={<ServerDetail />} />
        <Route path="settings" element={<Settings />} />
        
        {/* Admin Routes */}
        <Route
          path="admin/nodes"
          element={
            <AdminRoute>
              <Nodes />
            </AdminRoute>
          }
        />
        <Route
          path="admin/users"
          element={
            <AdminRoute>
              <Users />
            </AdminRoute>
          }
        />
        <Route
          path="admin/deploy"
          element={
            <AdminRoute>
              <DeployWizard />
            </AdminRoute>
          }
        />
      </Route>
      
      <Route path="*" element={<NotFound />} />
    </Routes>
  )
}

export default App
