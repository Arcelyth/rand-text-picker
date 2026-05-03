defmodule RandTextPicker do
  use GenServer
  require Logger

  @target_ip {127, 0, 0, 1}
  @interval 10000  # interval time

  def start_link(opts) do
    port = Keyword.get(opts, :port, 8080)
    dir = Keyword.get(opts, :dir, "./")
    case File.ls(dir) do
      {:ok, files} -> 
        fs = files |> Enum.filter(fn file -> String.ends_with?(file, ".txt") end)
        Logger.info("#{inspect(fs)}")
        GenServer.start_link(__MODULE__, {port, dir}, name: __MODULE__)
      {:error, _} -> Logger.info("Failed to get files from: #{dir}")
    end
  end

  @impl true
  def init({port, dir}) do
    case :gen_udp.open(0, [:binary, active: false]) do
      {:ok, socket} ->
        Logger.info("UDP Sender start. Target port: #{port}")
        schedule_next_tick()
        {:ok, %{socket: socket, port: port, count: 0, dir: dir}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(:tick, state) do
    case picker(state.dir) do 
      {:ok, file} -> 
        msg = file
        case :gen_udp.send(state.socket, @target_ip, state.port, msg) do
          :ok ->
            Logger.info("Send message: #{msg}")
          {:error, reason} ->
            Logger.error("Failed to send message: #{inspect(reason)}")
        end
        schedule_next_tick()
        {:noreply, %{state | count: state.count + 1}}
      {:error, _} -> {:noreply, state}
    end 
  end

  defp schedule_next_tick do
    Process.send_after(self(), :tick, @interval)
  end
  
  defp picker(dir) do 
    case File.ls(dir) do
      {:ok, files} -> 
        rand_file = files 
          |> Enum.filter(&String.ends_with?(&1, ".txt"))
          |> Enum.random()
        case File.read("#{dir}#{rand_file}") do
          {:ok, content} -> 
            res = content 
              |> String.split("\n")
              |> Enum.reject(&(String.trim(&1) == ""))
              |> Enum.random()
            {:ok, res}
          {:error, _} -> 
            {:error, "error"}
        end
      {:error, _} -> 
        Logger.error("Failed to get files from: #{dir}")
        {:error, "error"}
    end
  end 
end
