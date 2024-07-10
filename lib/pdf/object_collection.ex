defmodule Pdf.ObjectCollection do
  @moduledoc false

  alias Pdf.Object

  def start_link, do: GenServer.start_link(__MODULE__.Server, [])

  def create_object(pid, object) do
    GenServer.call(pid, {:create_object, object})
  end

  def get_object(pid, key) do
    GenServer.call(pid, {:get_object, key})
  end

  def update_object(pid, key, value) do
    GenServer.call(pid, {:update_object, key, value})
  end

  def call(pid, object_key, method, args) do
    GenServer.call(pid, {:call, object_key, method, args})
  end

  def all(pid) do
    GenServer.call(pid, :all)
  end

  defmodule Server do
    use GenServer

    defmodule State do
      @moduledoc false
      defstruct size: 0, objects: %{}
    end

    @impl true
    def init(_), do: {:ok, %State{}}

    @impl true
    def handle_call({:create_object, object}, _from, state) do
      new_size = state.size + 1
      key = {:object, new_size, 0}
      {:reply, key, %{state | size: new_size, objects: Map.put(state.objects, key, object)}}
    end

    def handle_call({:get_object, key}, _from, state) do
      object = Map.get(state.objects, key)
      {:reply, object, state}
    end

    def handle_call({:update_object, key, value}, _from, state) do
      {:reply, :ok, %{state | objects: Map.put(state.objects, key, value)}}
    end

    def handle_call({:call, object_key, method, args}, _from, state) do
      object = Map.get(state.objects, object_key)
      result = Kernel.apply(object.__struct__, method, [object | args])
      {:reply, object_key, %{state | objects: Map.put(state.objects, object_key, result)}}
    end

    def handle_call(:all, _from, state) do
      result =
        state.objects
        |> Enum.map(fn {{:object, number, _generation}, object} ->
          Object.new(number, object)
        end)

      {:reply, result, state}
    end
  end
end
