defmodule Play.Scene.Asteroids do
  @moduledoc """
  Asteroids animation/game
  """

  use Scenic.Scene
  import Scenic.Primitives

  alias Scenic.Graph
  alias Play.Component.Nav

  defmodule State do
    defstruct [:t, :x, :graph, :last_run_time, :player_coords]
  end

  # Steps
  # [x] Draw a circle to represent an asteroid
  # [x] Draw the circle empty
  # [x] Animate the circle
  # [x] Live reloading!
  # [x] Press `r` to reload!
  # [x] Make multiple circles
  # [x] Draw the player

  # Questions: Should there be a process per asteroid?

  @movement_keys ["W", "A", "S", "D"]

  # Note: Asteroids start off the screen
  @initial_graph Graph.build()
                 |> circle(30, id: :asteroid1, stroke: {3, :white}, t: {0, -100})
                 |> circle(30, id: :asteroid2, stroke: {3, :white}, t: {0, -100})
                 |> rect({10, 10}, id: :player, stroke: {1, :white})
                 |> Nav.add_to_graph(__MODULE__)

  @impl Scenic.Scene
  def init(_, _opts) do
    Process.register(self(), __MODULE__)
    push_graph(@initial_graph)
    schedule_animations()

    initial_state = %State{
      graph: @initial_graph,
      t: 0,
      x: 110,
      player_coords: initial_player_coordinates()
    }

    {:ok, initial_state}
  end

  def initial_player_coordinates do
    width = screen_width() / 2
    height = screen_height() / 2
    {width, height}
  end

  def screen_width do
    {width, _height} = Application.get_env(:play, :viewport)[:size]
    width
  end

  def screen_height do
    {_width, height} = Application.get_env(:play, :viewport)[:size]
    height
  end

  def handle_info({:animate, expected_run_time}, state) do
    diff = time_diff(state, expected_run_time)
    %{graph: graph, t: t, x: x, player_coords: player_coords} = state

    # x = x - 1 / 4
    # speed = 5 / s
    # diff = 0.1s
    # diff = 100 ms
    # speed = 10 u/s
    speed = 100

    dist =
      case diff do
        0 -> 0
        diff -> speed / 1000 * diff
      end

    x = x + dist

    graph =
      graph
      |> Graph.modify(:asteroid1, &circle(&1, 30, t: {x, 100}))
      |> Graph.modify(:asteroid2, &circle(&1, 30, t: {x, 200}))
      |> Graph.modify(:player, &rect(&1, {10, 10}, t: player_coords))
      |> push_graph()

    new_state = %{state | t: t + 1, x: x, graph: graph, last_run_time: expected_run_time}
    {:noreply, new_state}
  end

  defp time_diff(state, expected_run_time) do
    last_run_time = Map.get(state, :last_run_time) || expected_run_time
    DateTime.diff(expected_run_time, last_run_time, :millisecond)
  end

  @impl Scenic.Scene
  def filter_event(event, sec, state) do
    IO.inspect(event, label: "event")
    IO.inspect(sec, label: "sec")

    {:continue, event, state}
  end

  @impl Scenic.Scene
  def handle_input(input, viewport_context, state) do
    # IO.inspect(input, label: "#{__MODULE__} received input")
    do_handle_input(input, viewport_context, state)
  end

  def do_handle_input({:key, {"R", :press, _}}, _viewport_context, state) do
    GenServer.call(Play.Component.Nav, :reload_current_scene)

    {:noreply, state}
  end

  def do_handle_input({:key, {key, action, _}}, _viewport_context, state)
      when key in @movement_keys and action in [:press, :repeat, :release] do
    %{player_coords: {width, height}} = state
    dist = 5

    player_coords =
      case key do
        "W" -> {width, height - dist}
        "A" -> {width - dist, height}
        "S" -> {width, height + dist}
        "D" -> {width + dist, height}
      end

    {:noreply, %{state | player_coords: player_coords}}
  end

  def do_handle_input(input, _, state) do
    IO.inspect(input, label: "#{__MODULE__} ignoring input")
    {:noreply, state}
  end

  # def handle_input(_, _, state), do: {:noreply, state}

  defp schedule_animations() do
    pid = self()
    # Process.send_after(self(), :animate, 2)
    func = fn expected_run_time ->
      Process.send(pid, {:animate, expected_run_time}, [])
    end

    SchedEx.run_in(func, 1, repeat: true, time_scale: Play.GameTimer)
  end
end
