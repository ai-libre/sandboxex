defmodule Kairos.Wearables do
  @moduledoc """
  Dominio Wearables: Integración con dispositivos inteligentes (smart glasses).

  Backend production-ready para ecosistema de wearables como MentraOS.

  ## Capacidades

  - **GlassesSession**: Gestión de sesiones de dispositivos conectados
  - **DisplayUpdate**: Sincronización de UI con throttling (200-300ms)
  - **AudioTranscription**: Transcripción de audio con múltiples providers
  - **Merit Integration**: Análisis de calidad de interacciones desde wearables

  ## Arquitectura

  Reemplaza backend Express/MongoDB con Phoenix/Ash:
  - WebSocket → Phoenix Channels
  - MongoDB → PostgreSQL con Ash
  - Manual validation → Ash Policies
  - REST endpoints → GraphQL (AshGraphql)

  ## Constraints

  - Bluetooth Low Energy: Throttle display updates a 200-300ms
  - Battery optimization: Minimize push frequency
  - Offline support: Queue updates cuando no hay conexión
  """

  use Ash.Domain

  resources do
    resource Kairos.Wearables.GlassesSession
    resource Kairos.Wearables.DisplayUpdate
    resource Kairos.Wearables.AudioTranscription
  end
end
