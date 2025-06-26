import { NextRequest, NextResponse } from 'next/server'
import { exec } from 'child_process'
import { promisify } from 'util'

const execAsync = promisify(exec)

export async function GET() {
  try {
    // Get all Nexus containers
    const { stdout } = await execAsync('docker ps -a --filter "name=nexus-" --format "{{.ID}},{{.Names}},{{.Status}},{{.Image}},{{.CreatedAt}}"')
    
    const containers = stdout.trim().split('\n').filter(line => line).map(line => {
      const [id, name, status, image, createdAt] = line.split(',')
      return {
        id,
        name,
        status: status.toLowerCase().includes('up') ? 'running' : 'stopped',
        image,
        createdAt,
        isNexus: name.includes('nexus')
      }
    })

    return NextResponse.json(containers)
  } catch (error) {
    console.error('Failed to fetch containers:', error)
    return NextResponse.json({ error: 'Failed to fetch containers' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const { action, containerId, containerName } = await request.json()
    
    let command = ''
    switch (action) {
      case 'start':
        command = `docker start ${containerId || containerName}`
        break
      case 'stop':
        command = `docker stop ${containerId || containerName}`
        break
      case 'restart':
        command = `docker restart ${containerId || containerName}`
        break
      case 'remove':
        command = `docker rm -f ${containerId || containerName}`
        break
      default:
        return NextResponse.json({ error: 'Invalid action' }, { status: 400 })
    }

    await execAsync(command)
    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('Container action failed:', error)
    return NextResponse.json({ error: 'Container action failed' }, { status: 500 })
  }
}
