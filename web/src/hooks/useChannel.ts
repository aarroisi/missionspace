import { useEffect, useRef, useState } from 'react'
import { Socket, Channel } from 'phoenix'

const WS_URL = import.meta.env.VITE_WS_URL || '/socket'

let socket: Socket | null = null

function getSocket(): Socket | null {
  if (!socket) {
    const authToken = localStorage.getItem('auth_token')

    if (!authToken) {
      return null
    }

    socket = new Socket(WS_URL, { authToken })
    socket.connect()
  }
  return socket
}

export function useChannel(
  topic: string,
  onMessage?: (event: string, payload: any) => void
): Channel | null {
  const [channel, setChannel] = useState<Channel | null>(null)
  const channelRef = useRef<Channel | null>(null)
  const onMessageRef = useRef(onMessage)

  useEffect(() => {
    onMessageRef.current = onMessage
  }, [onMessage])

  useEffect(() => {
    if (!topic) return

    const sock = getSocket()
    if (!sock) return

    const ch = sock.channel(topic, {})

    ch.join()
      .receive('ok', () => {
        console.log(`Joined ${topic} successfully`)
        channelRef.current = ch
        setChannel(ch)
      })
      .receive('error', (resp) => {
        console.error(`Unable to join ${topic}`, resp)
      })

    ch.onMessage = (event, payload) => {
      onMessageRef.current?.(event, payload)
      return payload
    }

    return () => {
      ch.leave()
      channelRef.current = null
      setChannel(null)
    }
  }, [topic])

  return channel
}

export function disconnectSocket() {
  if (socket) {
    socket.disconnect()
    socket = null
  }
}
