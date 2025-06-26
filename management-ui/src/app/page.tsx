'use client'

import { useState, useEffect } from 'react'
import Dashboard from '@/components/Dashboard'
import Sidebar from '@/components/Sidebar'

export default function Home() {
  const [activeTab, setActiveTab] = useState('dashboard')

  return (
    <div className="flex h-screen bg-gray-100">
      <Sidebar activeTab={activeTab} setActiveTab={setActiveTab} />
      <main className="flex-1 overflow-auto">
        <div className="p-8">
          <Dashboard />
        </div>
      </main>
    </div>
  )
}
