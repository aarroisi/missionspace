import { useState, useEffect, useCallback } from 'react'
import {
  isPushSupported,
  getPushPermission,
  subscribeToPush,
  unsubscribeFromPush,
  isCurrentlySubscribed,
} from '@/lib/push'

export function useWebPush() {
  const [isSupported] = useState(isPushSupported)
  const [isSubscribed, setIsSubscribed] = useState(false)
  const [permission, setPermission] = useState(getPushPermission)
  const [isLoading, setIsLoading] = useState(false)

  useEffect(() => {
    if (!isSupported) return
    isCurrentlySubscribed().then(setIsSubscribed)
  }, [isSupported])

  const subscribe = useCallback(async () => {
    setIsLoading(true)
    try {
      const success = await subscribeToPush()
      setIsSubscribed(success)
      setPermission(getPushPermission())
      return success
    } finally {
      setIsLoading(false)
    }
  }, [])

  const unsubscribe = useCallback(async () => {
    setIsLoading(true)
    try {
      await unsubscribeFromPush()
      setIsSubscribed(false)
    } finally {
      setIsLoading(false)
    }
  }, [])

  return {
    isSupported,
    isSubscribed,
    permission,
    isLoading,
    subscribe,
    unsubscribe,
  }
}
