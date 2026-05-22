import { createConsumer } from '@rails/actioncable'
import { useEffect, useRef } from 'react'

// Singleton consumer — uma conexão WebSocket por sessão do browser
let consumer = null

function getConsumer(token) {
  if (!consumer) {
    const url = `${import.meta.env.VITE_CABLE_URL || 'ws://localhost:3000/cable'}?token=${token}`
    consumer = createConsumer(url)
  }
  return consumer
}

export function disconnectCable() {
  if (consumer) {
    consumer.disconnect()
    consumer = null
  }
}

/**
 * Assina um canal do Action Cable.
 *
 * @param {string|null} token  - JWT do usuário autenticado
 * @param {string}      channel - Nome do canal (ex: "TicketsChannel")
 * @param {object}      params  - Parâmetros extras enviados ao subscribed()
 * @param {object}      handlers - { received, connected, disconnected }
 */
export function useActionCable(token, channel, params = {}, handlers = {}) {
  const subscriptionRef = useRef(null)

  useEffect(() => {
    if (!token) return

    const cable = getConsumer(token)

    subscriptionRef.current = cable.subscriptions.create(
      { channel, ...params },
      {
        connected()    { handlers.connected?.() },
        disconnected() { handlers.disconnected?.() },
        received(data) { handlers.received?.(data) }
      }
    )

    return () => {
      subscriptionRef.current?.unsubscribe()
      subscriptionRef.current = null
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, channel])

  return subscriptionRef
}
