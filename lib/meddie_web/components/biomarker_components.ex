defmodule MeddieWeb.BiomarkerComponents do
  @moduledoc """
  Shared biomarker UI components used across LiveViews.
  """
  use Phoenix.Component
  use Gettext, backend: MeddieWeb.Gettext

  @doc """
  Renders a tiny inline SVG sparkline from a list of data points.

  Requires at least 2 points with non-nil values to render.
  Color is determined by the last point's status.

  ## Examples

      <.sparkline points={[%{value: 14.5, status: "normal"}, %{value: 12.1, status: "low"}]} />
  """
  attr :points, :list, required: true, doc: "List of %{value: float, status: string}"
  attr :width, :integer, default: 60
  attr :height, :integer, default: 20
  attr :class, :string, default: ""

  def sparkline(assigns) do
    points = Enum.filter(assigns.points, &(&1.value != nil))

    if length(points) < 2 do
      ~H""
    else
      values = Enum.map(points, & &1.value)
      min_val = Enum.min(values)
      max_val = Enum.max(values)
      padding = 2
      usable_height = assigns.height - padding * 2

      svg_points =
        points
        |> Enum.with_index()
        |> Enum.map(fn {point, i} ->
          x = round(i / (length(points) - 1) * assigns.width)

          y =
            if max_val == min_val do
              round(assigns.height / 2)
            else
              round(padding + usable_height - (point.value - min_val) / (max_val - min_val) * usable_height)
            end

          {x, y}
        end)

      polyline_str = Enum.map_join(svg_points, " ", fn {x, y} -> "#{x},#{y}" end)
      {last_x, last_y} = List.last(svg_points)
      last_status = List.last(points).status

      assigns =
        assigns
        |> assign(:polyline_str, polyline_str)
        |> assign(:last_x, last_x)
        |> assign(:last_y, last_y)
        |> assign(:stroke_color, status_stroke_color(last_status))

      ~H"""
      <svg
        width={@width}
        height={@height}
        viewBox={"0 0 #{@width} #{@height}"}
        class={["inline-block align-middle", @class]}
      >
        <polyline
          points={@polyline_str}
          fill="none"
          stroke={@stroke_color}
          stroke-width="1.5"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
        <circle cx={@last_x} cy={@last_y} r="2" fill={@stroke_color} />
      </svg>
      """
    end
  end

  defp status_stroke_color("normal"), do: "oklch(0.7 0.14 182.503)"
  defp status_stroke_color("high"), do: "oklch(0.58 0.253 17.585)"
  defp status_stroke_color("low"), do: "oklch(0.62 0.214 259.815)"
  defp status_stroke_color(_), do: "oklch(0.55 0.027 264.364)"

  @doc """
  Renders a biomarker status badge with appropriate color.
  """
  attr :status, :string, required: true

  def biomarker_status_badge(%{status: "normal"} = assigns) do
    ~H"""
    <span class="badge badge-success badge-xs">{gettext("normal")}</span>
    """
  end

  def biomarker_status_badge(%{status: "low"} = assigns) do
    ~H"""
    <span class="badge badge-info badge-xs">{gettext("low")}</span>
    """
  end

  def biomarker_status_badge(%{status: "high"} = assigns) do
    ~H"""
    <span class="badge badge-error badge-xs">{gettext("high")}</span>
    """
  end

  def biomarker_status_badge(assigns) do
    ~H"""
    <span class="badge badge-ghost badge-xs">{gettext("unknown")}</span>
    """
  end

  @doc """
  Renders a visual reference range bar showing where a value falls relative to the reference range.

  Renders an SVG with a gray track, a teal reference range segment, and a status-colored
  value marker. Falls back to rendering nothing if reference range or value data is missing.

  ## Examples

      <.reference_range_bar value={14.5} low={13.5} high={18.0} status="normal" />
  """
  attr :value, :float, default: nil
  attr :low, :float, default: nil
  attr :high, :float, default: nil
  attr :status, :string, default: "unknown"
  attr :width, :integer, default: 120
  attr :height, :integer, default: 22

  def reference_range_bar(assigns) do
    if is_nil(assigns.low) or is_nil(assigns.high) or is_nil(assigns.value) or
         assigns.low == assigns.high do
      ~H""
    else
      low = assigns.low
      high = assigns.high
      value = assigns.value
      w = assigns.width
      range = high - low
      padding = range * 0.3

      display_min = low - padding
      display_max = high + padding
      display_range = display_max - display_min

      to_x = fn val -> round((val - display_min) / display_range * w) end

      ref_x1 = to_x.(low)
      ref_x2 = to_x.(high)
      value_x = to_x.(max(display_min, min(display_max, value)))

      track_h = 4
      track_y = 4
      marker_color = status_stroke_color(assigns.status)
      range_color = status_stroke_color("normal")
      label_y = assigns.height - 2

      assigns =
        assigns
        |> assign(:ref_x1, ref_x1)
        |> assign(:ref_x2, ref_x2)
        |> assign(:ref_width, max(ref_x2 - ref_x1, 1))
        |> assign(:value_x, value_x)
        |> assign(:track_h, track_h)
        |> assign(:track_y, track_y)
        |> assign(:marker_color, marker_color)
        |> assign(:range_color, range_color)
        |> assign(:label_y, label_y)
        |> assign(:low_label, format_range_number(low))
        |> assign(:high_label, format_range_number(high))

      ~H"""
      <svg
        width={@width}
        height={@height}
        viewBox={"0 0 #{@width} #{@height}"}
        class="inline-block align-middle"
      >
        <%!-- Gray track --%>
        <rect x="0" y={@track_y} width={@width} height={@track_h} rx="2" fill="oklch(0.8 0 0)" />
        <%!-- Reference range segment --%>
        <rect
          x={@ref_x1}
          y={@track_y}
          width={@ref_width}
          height={@track_h}
          rx="2"
          fill={@range_color}
          opacity="0.4"
        />
        <%!-- Value marker --%>
        <line
          x1={@value_x}
          y1={@track_y - 2}
          x2={@value_x}
          y2={@track_y + @track_h + 2}
          stroke={@marker_color}
          stroke-width="2"
          stroke-linecap="round"
        />
        <%!-- Low label --%>
        <text x={@ref_x1} y={@label_y} font-size="9" fill="oklch(0.55 0 0)" text-anchor="middle">
          {@low_label}
        </text>
        <%!-- High label --%>
        <text x={@ref_x2} y={@label_y} font-size="9" fill="oklch(0.55 0 0)" text-anchor="middle">
          {@high_label}
        </text>
      </svg>
      """
    end
  end

  defp format_range_number(n) when is_float(n) do
    if n == Float.round(n, 0), do: Integer.to_string(trunc(n)), else: Float.to_string(Float.round(n, 1))
  end

  defp format_range_number(n), do: to_string(n)

  @doc """
  Returns CSS classes for a biomarker table row based on status.
  """
  def biomarker_row_class("high"), do: "text-error font-medium"
  def biomarker_row_class("low"), do: "text-info font-medium"
  def biomarker_row_class(_), do: ""
end
