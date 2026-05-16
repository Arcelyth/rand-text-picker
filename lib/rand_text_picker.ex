defmodule RandTextPicker do
  use GenServer
  require Logger

  @target_ip {127, 0, 0, 1}
  @id "rand_text_picker"

  def start_link(opts) do
    port = Keyword.get(opts, :port, 8080)
    dir = Keyword.get(opts, :dir, "./")
    interval = Keyword.get(opts, :interval, 10000)

    GenServer.start_link(__MODULE__, {port, dir, interval}, name: __MODULE__)
  end

  @impl true
  def init({port, dir, interval}) do
    case :gen_udp.open(0, [:binary, active: false]) do
      {:ok, socket} ->
        Logger.info("UDP Sender start. Target port: #{port}")
        schedule_next_tick(interval)
        {:ok, %{socket: socket, port: port, count: 0, dir: dir, interval: interval}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(:tick, state) do
    case picker(state.dir) do 
      {:ok, file} ->         
        payload = %{
          id: @id,
          content: file,
          max_width: 34, 
          max_height: 5,
          duration: 3.5,
          color: [0, 255, 0],
          show: true,
        }
        msg = Jason.encode!(payload)
        
        case :gen_udp.send(state.socket, @target_ip, state.port, msg) do
          :ok ->
            Logger.info("Send message: #{msg}")
          {:error, reason} ->
            Logger.error("Failed to send message: #{inspect(reason)}")
        end
        schedule_next_tick(state.interval)
        {:noreply, %{state | count: state.count + 1}}
      {:error, _} -> {:noreply, state}
    end 
  end

  defp schedule_next_tick(interval) do
    Process.send_after(self(), :tick, interval)
  end
  
  defp picker(dir) do 
    files = dir |> Path.join("**/*.txt") |> Path.wildcard()

    case files do 
      [] -> 
        Logger.error("Failed to get files from: #{dir}")
        {:error, "error"}
      _ -> 
        rand_file = Enum.random(files)
        case File.read(rand_file) do
          {:ok, content} ->
            lines =
              content
              |> String.split("\n")
              |> Enum.reject(&(String.trim(&1) == ""))

            case lines do
              [] -> {:error, "empty file"}
              _ -> {:ok, Enum.random(lines)}
            end
          {:error, _} ->
            {:error, "error"}
        end
    end
  end 
end
