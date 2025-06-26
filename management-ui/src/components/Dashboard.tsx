'use client'

import { useState, useEffect } from 'react'
import ContainerGrid from './ContainerGrid'
import MetricsPanel from './MetricsPanel'
import LogViewer from './LogViewer'
import DeploymentControls from './DeploymentControls'

interface DashboardProps {
  activeTab?: string
}

export default function Dashboard({ activeTab = 'overview' }: DashboardProps) {
  const [containers, setContainers] = useState([])
  const [metrics, setMetrics] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchContainers()
    fetchMetrics()
    
    // Set up real-time updates
    const interval = setInterval(() => {
      fetchContainers()
      fetchMetrics()
    }, 5000)

    return () => clearInterval(interval)
  }, [])

  const fetchContainers = async () => {
    try {
      const response = await fetch('/api/containers')
      const data = await response.json()
      setContainers(data)
    } catch (error) {
      console.error('Failed to fetch containers:', error)
    } finally {
      setLoading(false)
    }
  }

  const fetchMetrics = async () => {
    try {
      const response = await fetch('/api/metrics')
      const data = await response.json()
      setMetrics(data)
    } catch (error) {
      console.error('Failed to fetch metrics:', error)
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div className="md:flex md:items-center md:justify-between">
        <div className="min-w-0 flex-1">
          <h2 className="text-2xl font-bold leading-7 text-gray-900 sm:truncate sm:text-3xl sm:tracking-tight">
            Nexus CLI Docker Manager
          </h2>
          <p className="mt-1 text-sm text-gray-500">
            Manage your Nexus CLI instances with ease
          </p>
        </div>
        <div className="mt-4 flex md:ml-4 md:mt-0">
          <DeploymentControls onUpdate={fetchContainers} />
        </div>
      </div>

      {metrics && <MetricsPanel metrics={metrics} />}
      
      <ContainerGrid 
        containers={containers} 
        onUpdate={fetchContainers}
      />

      <div className="mt-8">
        <LogViewer />
      </div>
    </div>
  )
}
