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
            <div class="card bg-base-100 shadow-sm">
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
            <.document_results document={@document} />
          </div>
        </div>
      </div>
    </Layouts.sidebar>
    """
  end

  # -- Result components --

  defp document_results(%{document: %{status: "parsed", document_type: "lab_results"}} = assigns) do
    assigns =
      assign(assigns, :grouped, Enum.group_by(assigns.document.biomarkers, & &1.category))

    ~H"""
    <div class="space-y-4">
      <div :if={@document.summary} class="card bg-base-100 shadow-sm">
        <div class="card-body">
          <h3 class="card-title text-sm">{gettext("Summary")}</h3>
          <p class="text-sm text-base-content/80">{@document.summary}</p>
        </div>
      </div>

      <div :for={{category, biomarkers} <- @grouped} class="card bg-base-100 shadow-sm">
        <div class="card-body">
          <h3 class="card-title text-sm">{category || gettext("Other")}</h3>
          <div class="overflow-x-auto">
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>{gettext("Biomarker")}</th>
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
                  <td class="text-right font-mono">{bm.value}</td>
                  <td class="text-base-content/60">{bm.unit}</td>
                  <td class="text-base-content/60 text-xs">{bm.reference_range_text}</td>
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
    <div class="card bg-base-100 shadow-sm">
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
    <div class="flex items-center gap-3 p-8">
      <span class="loading loading-spinner loading-md" />
      <p class="text-base-content/60">{gettext("Parsing document...")}</p>
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

  attr :status, :string, required: true

  defp biomarker_status_badge(%{status: "normal"} = assigns) do
    ~H"""
    <span class="badge badge-success badge-xs">{gettext("normal")}</span>
    """
  end

  defp biomarker_status_badge(%{status: "low"} = assigns) do
    ~H"""
    <span class="badge badge-info badge-xs">{gettext("low")}</span>
    """
  end

  defp biomarker_status_badge(%{status: "high"} = assigns) do
    ~H"""
    <span class="badge badge-error badge-xs">{gettext("high")}</span>
    """
  end

  defp biomarker_status_badge(assigns) do
    ~H"""
    <span class="badge badge-ghost badge-xs">{gettext("unknown")}</span>
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

    {:ok,
     socket
     |> assign(page_title: document.filename)
     |> assign(person: person)
     |> assign(document: document)
     |> assign(signed_url: signed_url)
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
      {:noreply, assign(socket, :document, document)}
    else
      {:noreply, socket}
    end
  end

  # -- Helpers --

  defp biomarker_row_class("high"), do: "text-error font-medium"
  defp biomarker_row_class("low"), do: "text-info font-medium"
  defp biomarker_row_class(_), do: ""

  defp render_markdown(nil), do: "—"
  defp render_markdown(""), do: "—"

  defp render_markdown(content) do
    content
    |> Earmark.as_html!(smartypants: false)
    |> Phoenix.HTML.raw()
  end
end
