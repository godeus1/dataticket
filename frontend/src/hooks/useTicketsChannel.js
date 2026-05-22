import { useCallback, useState } from 'react'
import { useActionCable } from './useActionCable'

/**
 * Assina o TicketsChannel e mantém um estado de tickets em tempo real.
 *
 * Uso:
 *   const { liveEvent } = useTicketsChannel(token, (event, ticket) => {
 *     if (event === 'ticket_updated') { ... }
 *   })
 *
 * @param {string|null} token    - JWT do usuário autenticado
 * @param {Function}    onEvent  - Callback (event: string, ticket: object) => void
 */
export function useTicketsChannel(token, onEvent) {
  const [connected, setConnected] = useState(false)

  const handleReceived = useCallback(
    (data) => {
      const { event, ticket } = data || {}
      if (event && ticket) {
        onEvent?.(event, ticket)
      }
    },
    [onEvent]
  )

  useActionCable(token, 'TicketsChannel', {}, {
    connected:    () => setConnected(true),
    disconnected: () => setConnected(false),
    received:     handleReceived
  })

  return { connected }
}
