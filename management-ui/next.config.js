/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  experimental: {
    serverComponentsExternalPackages: ['dockerode']
  },
  env: {
    DOCKER_SOCKET: process.env.DOCKER_SOCKET || '/var/run/docker.sock',
    COMPOSE_PROJECT_NAME: process.env.COMPOSE_PROJECT_NAME || 'nexus-docker'
  }
}

module.exports = nextConfig
