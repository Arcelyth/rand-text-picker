defmodule RandTextPicker do
  use GenServer
  require Logger

  @target_ip {127, 0, 0, 1}
  @interval 10000  # interval time

  def start_link(port) do
    GenServer.start_link(__MODULE__, port, name: __MODULE__)
  end

  @impl true
  def init(port) do
    case :gen_udp.open(0, [:binary, active: false]) do
      {:ok, socket} ->
        Logger.info("UDP Sender start. Target port: #{port}")
        schedule_next_tick()
        {:ok, %{socket: socket, port: port, count: 0}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(:tick, state) do
    msg = "test"
    
    case :gen_udp.send(state.socket, @target_ip, state.port, msg) do
      :ok ->
        Logger.info("Send message: #{msg}")
      {:error, reason} ->
        Logger.error("Failed to send message: #{inspect(reason)}")
    end

    schedule_next_tick()

    {:noreply, %{state | count: state.count + 1}}
  end

  defp schedule_next_tick do
    Process.send_after(self(), :tick, @interval)
  end
end
