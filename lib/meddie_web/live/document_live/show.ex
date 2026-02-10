defmodule MeddieWeb.DocumentLive.Show do
  use MeddieWeb, :live_view

  alias Meddie.Documents
  alias Meddie.People

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.sidebar
      flash={@flash}
      current_scope={@current_scope}
      user_spaces={@user_spaces}
      page_title={@document.filename}
    >
      <div class="max-w-7xl">
        <%!-- Header --%>
        <div class="flex items-center justify-between mb-6">
          <div class="flex items-center gap-3">
            <.link
              navigate={~p"/people/#{@person}?tab=documents"}
              class="btn btn-ghost btn-sm"
            >
              <.icon name="hero-arrow-left-micro" class="size-4" />
            </.link>
            <div>
              <h1 class="text-xl font-bold">{@document.filename}</h1>
              <p class="text-sm text-base-content/50">
                {gettext("Uploaded")} {Calendar.strftime(@document.inserted_at, "%Y-%m-%d %H:%M")}
              </p>
            </div>
          </div>
          <div class="flex gap-2">
            <button
              :if={@document.status == "failed"}
              phx-click="retry"
              class="btn btn-warning btn-sm"
            >
              <.icon name="hero-arrow-path-micro" class="size-4" />
              {gettext("Retry")}
            </button>
            <button
              phx-click="delete"
              data-confirm={
                gettext(
                  "This will permanently delete this document and all extracted data. This action cannot be undone."
                )
              }
              class="btn btn-ghost btn-sm text-error"
            >
              <.icon name="hero-trash-micro" class="size-4" />
              {gettext("Delete")}
            </button>
          </div>
        </div>

        <%!-- Mobile tab switcher --%>
        <div class="flex gap-1 border-b border-base-300 mb-4 lg:hidden">
          <button
            phx-click="switch-panel"
            phx-value-panel="results"
            class={[
              "px-4 py-2 text-sm font-medium border-b-2 -mb-px",
              if(@panel == "results",
                do: "border-primary text-primary",
                else: "border-transparent text-base-content/60"
              )
            ]}
          >
            {gettext("Results")}
          </button>
          <button
            phx-click="switch-panel"
            phx-value-panel="original"
            class={[
              "px-4 py-2 text-sm font-medium border-b-2 -mb-px",
              if(@panel == "original",
                do: "border-primary text-primary",
                else: "border-transparent text-base-content/60"
              )
            ]}
          >
            {gettext("Original")}
          </button>
        </div>

        <%!-- Split layout --%>
        <div class="flex flex-col lg:flex-row gap-6">
          <%!-- Left: Original document --%>
          <div class={["lg:w-1/2 lg:block", if(@panel != "original", do: "hidden")]}>
            <div class="card bg-base-100 shadow-elevated border border-base-300/20 overflow-hidden">
              <div class="card-body p-2">
                <%= if @document.content_type == "application/pdf" do %>
                  <div
                    id="pdf-viewer"
                    phx-hook="PdfViewer"
                    phx-update="ignore"
                    data-url={@signed_url}
                    class="w-full min-h-[600px]"
                  />
                <% else %>
                  <img
                    src={@signed_url}
                    alt={@document.filename}
                    class="w-full rounded-lg"
                  />
                <% end %>
              </div>
            </div>
          </div>

          <%!-- Right: Parsed results --%>
          <div class={["lg:w-1/2 lg:block", if(@panel != "results", do: "hidden")]}>
            <.document_results document={@document} biomarker_history={@biomarker_history} />
          </div>
        </div>
      </div>
    </Layouts.sidebar>
    """
  end

  # -- Result components --

  defp document_results(%{document: %{status: "parsed", document_type: "lab_results"}} = assigns) do
    grouped = Enum.group_by(assigns.document.biomarkers, & &1.category)

    sparklines =
      Map.new(assigns.biomarker_history, fn {{name, unit}, entries} ->
        points = Enum.map(entries, &%{value: &1.numeric_value, status: &1.status})
        {{name, unit}, points}
      end)

    assigns =
      assigns
      |> assign(:grouped, grouped)
      |> assign(:sparklines, sparklines)

    ~H"""
    <div class="space-y-4">
      <div :if={@document.summary} class="card bg-base-100 shadow-elevated border border-base-300/20">
        <div class="card-body">
          <h3 class="card-title text-sm">{gettext("Summary")}</h3>
          <p class="text-sm text-base-content/80">{@document.summary}</p>
        </div>
      </div>

      <div :for={{category, biomarkers} <- @grouped} class="card bg-base-100 shadow-elevated border border-base-300/20">
        <div class="card-body">
          <h3 class="card-title text-sm">{category || gettext("Other")}</h3>
          <div class="overflow-x-auto">
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>{gettext("Biomarker")}</th>
                  <th>{gettext("Trend")}</th>
                  <th class="text-right">{gettext("Value")}</th>
                  <th>{gettext("Unit")}</th>
                  <th>{gettext("Reference")}</th>
                  <th>{gettext("Status")}</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={bm <- biomarkers}
                  class={biomarker_row_class(bm.status)}
                >
                  <td>{bm.name}</td>
                  <td>
                    <.sparkline
                      :if={length(Map.get(@sparklines, {bm.name, Meddie.Documents.normalize_unit(bm.unit)}, [])) > 1}
                      points={Map.get(@sparklines, {bm.name, Meddie.Documents.normalize_unit(bm.unit)}, [])}
                    />
                  </td>
                  <td class="text-right font-mono">{bm.value}</td>
                  <td class="text-base-content/60">{bm.unit}</td>
                  <td class="text-base-content/60 text-xs">
                    <.reference_range_bar
                      :if={bm.reference_range_low && bm.reference_range_high && bm.numeric_value}
                      value={bm.numeric_value}
                      low={bm.reference_range_low}
                      high={bm.reference_range_high}
                      status={bm.status}
                    />
                    <span :if={!bm.reference_range_low || !bm.reference_range_high || !bm.numeric_value}>
                      {bm.reference_range_text}
                    </span>
                  </td>
                  <td><.biomarker_status_badge status={bm.status} /></td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp document_results(%{document: %{status: "parsed"}} = assigns) do
    assigns = assign(assigns, :rendered, render_markdown(assigns.document.summary))

    ~H"""
    <div class="card bg-base-100 shadow-elevated border border-base-300/20">
      <div class="card-body">
        <h3 class="card-title text-sm">{gettext("Summary")}</h3>
        <div class="text-sm text-base-content/80 markdown-content">
          {@rendered}
        </div>
      </div>
    </div>
    """
  end

  defp document_results(%{document: %{status: "parsing"}} = assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center gap-4 p-12 text-center">
      <div class="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
        <span class="loading loading-spinner loading-md text-primary" />
      </div>
      <p class="text-base-content/60 font-medium">{gettext("Parsing document...")}</p>
    </div>
    """
  end

  defp document_results(%{document: %{status: "failed"}} = assigns) do
    ~H"""
    <div class="alert alert-error">
      <.icon name="hero-exclamation-triangle" class="size-5" />
      <div>
        <p class="font-medium">{gettext("Parsing failed")}</p>
        <p :if={@document.error_message} class="text-sm">{@document.error_message}</p>
      </div>
    </div>
    """
  end

  defp document_results(assigns) do
    ~H"""
    <div class="flex items-center gap-3 p-8">
      <span class="loading loading-dots loading-sm" />
      <p class="text-base-content/60">{gettext("Waiting to be parsed...")}</p>
    </div>
    """
  end

  # -- Lifecycle --

  @impl true
  def mount(%{"person_id" => person_id, "id" => id}, _session, socket) do
    scope = socket.assigns.current_scope
    person = People.get_person!(scope, person_id)
    document = Documents.get_document!(scope, id)

    if connected?(socket) do
      Documents.subscribe_person_documents(person.id)
    end

    {:ok, signed_url} = Meddie.Storage.presigned_url(document.storage_path)

    biomarker_history = load_biomarker_history(scope, person, document)

    {:ok,
     socket
     |> assign(page_title: document.filename)
     |> assign(person: person)
     |> assign(document: document)
     |> assign(signed_url: signed_url)
     |> assign(biomarker_history: biomarker_history)
     |> assign(panel: "results")}
  end

  # -- Events --

  @impl true
  def handle_event("retry", _params, socket) do
    document = socket.assigns.document

    {:ok, document} =
      Documents.update_document(document, %{"status" => "pending", "error_message" => nil})

    %{document_id: document.id}
    |> Meddie.Workers.ParseDocument.new()
    |> Oban.insert()

    {:noreply,
     socket
     |> assign(document: document)
     |> put_flash(
       :info,
       gettext("Parsing job enqueued. The document will be re-analyzed shortly.")
     )}
  end

  def handle_event("delete", _params, socket) do
    document = socket.assigns.document
    person = socket.assigns.person

    Meddie.Storage.delete(document.storage_path)
    {:ok, _} = Documents.delete_document(socket.assigns.current_scope, document)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Document deleted successfully."))
     |> push_navigate(to: ~p"/people/#{person}?tab=documents")}
  end

  def handle_event("switch-panel", %{"panel" => panel}, socket) do
    {:noreply, assign(socket, :panel, panel)}
  end

  # -- PubSub --

  @impl true
  def handle_info({:document_updated, document}, socket) do
    if document.id == socket.assigns.document.id do
      document = Meddie.Repo.preload(document, :biomarkers, force: true)
      scope = socket.assigns.current_scope
      person = socket.assigns.person
      biomarker_history = load_biomarker_history(scope, person, document)

      {:noreply,
       socket
       |> assign(:document, document)
       |> assign(:biomarker_history, biomarker_history)}
    else
      {:noreply, socket}
    end
  end

  # -- Helpers --

  defp load_biomarker_history(scope, person, document) do
    biomarker_names =
      document.biomarkers
      |> Enum.filter(& &1.numeric_value)
      |> Enum.map(& &1.name)
      |> Enum.uniq()

    if biomarker_names != [] do
      Documents.list_biomarker_history(scope, person.id, biomarker_names)
    else
      %{}
    end
  end

  defp render_markdown(nil), do: "—"
  defp render_markdown(""), do: "—"

  defp render_markdown(content) do
    content
    |> Earmark.as_html!(smartypants: false)
    |> Phoenix.HTML.raw()
  end
end
