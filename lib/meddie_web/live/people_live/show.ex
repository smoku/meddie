defmodule MeddieWeb.PeopleLive.Show do
  use MeddieWeb, :live_view

  alias Meddie.People
  alias Meddie.Documents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.sidebar
      flash={@flash}
      current_scope={@current_scope}
      user_spaces={@user_spaces}
      people={@people}
      active_person_id={@person.id}
      page_title={@person.name}
    >
      <div class="max-w-4xl space-y-6">
        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold">{@person.name}</h1>
          <div class="flex gap-2">
            <.link navigate={~p"/people/#{@person}/edit"} class="btn btn-ghost btn-sm">
              <.icon name="hero-pencil-square-micro" class="size-4" />
              {gettext("Edit")}
            </.link>
            <.link navigate={~p"/ask-meddie/new?person_id=#{@person}"} class="btn btn-ghost btn-sm">
              <.icon name="hero-chat-bubble-left-right-micro" class="size-4" />
              {gettext("Ask Meddie")}
            </.link>
            <button
              phx-click="delete"
              data-confirm={
                gettext(
                  "This will permanently delete this person and all their documents, biomarkers, and conversations. This action cannot be undone."
                )
              }
              class="btn btn-ghost btn-sm text-error"
            >
              <.icon name="hero-trash-micro" class="size-4" />
              {gettext("Delete")}
            </button>
          </div>
        </div>

        <%!-- Tabs --%>
        <div class="flex gap-1 border-b-2 border-base-300/50">
          <.link
            patch={~p"/people/#{@person}?tab=overview"}
            class={[
              "px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors",
              if(@tab == "overview",
                do: "border-primary text-primary bg-primary/5 rounded-t-lg",
                else: "border-transparent text-base-content/60 hover:text-base-content"
              )
            ]}
          >
            {gettext("Overview")}
          </.link>
          <.link
            patch={~p"/people/#{@person}?tab=biomarkers"}
            class={[
              "px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors",
              if(@tab == "biomarkers",
                do: "border-primary text-primary bg-primary/5 rounded-t-lg",
                else: "border-transparent text-base-content/60 hover:text-base-content"
              )
            ]}
          >
            {gettext("Results")}
            <span :if={@biomarkers_total > 0} class="ml-1.5 badge badge-sm">
              {@biomarkers_total}
            </span>
          </.link>
          <.link
            patch={~p"/people/#{@person}?tab=documents"}
            class={[
              "px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors",
              if(@tab == "documents",
                do: "border-primary text-primary bg-primary/5 rounded-t-lg",
                else: "border-transparent text-base-content/60 hover:text-base-content"
              )
            ]}
          >
            {gettext("Documents")}
            <span :if={@documents_count > 0} class="ml-1.5 badge badge-sm">
              {@documents_count}
            </span>
          </.link>
        </div>

        <%!-- Overview tab --%>
        <div :if={@tab == "overview"} class="space-y-6">
          <%!-- Profile card --%>
          <div class="card bg-base-100 shadow-elevated border border-base-300/20">
            <div class="card-body">
              <h3 class="card-title text-base">{gettext("Profile")}</h3>
              <div class="grid grid-cols-2 sm:grid-cols-3 gap-4 mt-2">
                <.info_item label={gettext("Sex")} value={display_sex(@person.sex)} />
                <.info_item
                  label={gettext("Date of birth")}
                  value={
                    if @person.date_of_birth,
                      do: Calendar.strftime(@person.date_of_birth, "%Y-%m-%d"),
                      else: "—"
                  }
                />
                <.info_item
                  label={gettext("Age")}
                  value={if @person.date_of_birth, do: "#{age(@person.date_of_birth)}", else: "—"}
                />
                <.info_item
                  label={gettext("Height")}
                  value={if @person.height_cm, do: "#{@person.height_cm} cm", else: "—"}
                />
                <.info_item
                  label={gettext("Weight")}
                  value={if @person.weight_kg, do: "#{@person.weight_kg} kg", else: "—"}
                />
              </div>
            </div>
          </div>

          <.markdown_card title={gettext("Health Notes")} content={@person.health_notes} />
          <.markdown_card title={gettext("Supplements")} content={@person.supplements} />
          <.markdown_card title={gettext("Medications")} content={@person.medications} />
        </div>

        <%!-- Documents tab --%>
        <div :if={@tab == "documents"} class="space-y-6">
          <%!-- Upload zone --%>
          <form phx-change="validate-upload" phx-submit="save-upload" class="space-y-4">
            <div
              class="border-2 border-dashed border-base-300 rounded-xl p-10 text-center hover:border-primary/50 hover:bg-primary/3 transition-all duration-200"
              phx-drop-target={@uploads.document.ref}
            >
              <.icon name="hero-cloud-arrow-up" class="size-10 mx-auto mb-3 text-base-content/40" />
              <p class="text-sm text-base-content/60 mb-3">
                {gettext("Drag and drop files here, or")}
              </p>
              <.live_file_input upload={@uploads.document} class="hidden" />
              <label for={@uploads.document.ref} class="btn btn-primary btn-sm cursor-pointer">
                {gettext("Browse files")}
              </label>
              <p class="text-xs text-base-content/40 mt-2">
                {gettext("PDF, JPG, PNG up to 20 MB")}
              </p>
            </div>

            <%!-- Upload entries with progress --%>
            <div
              :for={entry <- @uploads.document.entries}
              class="flex items-center gap-3 p-3 bg-base-200 rounded-lg"
            >
              <.icon name="hero-document" class="size-5 shrink-0 text-base-content/50" />
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium truncate">{entry.client_name}</p>
                <div class="w-full bg-base-300 rounded-full h-1.5 mt-1">
                  <div
                    class="bg-primary h-1.5 rounded-full transition-all"
                    style={"width: #{entry.progress}%"}
                  />
                </div>
              </div>
              <button
                type="button"
                phx-click="cancel-upload"
                phx-value-ref={entry.ref}
                class="btn btn-ghost btn-xs"
              >
                <.icon name="hero-x-mark-micro" class="size-4" />
              </button>
            </div>

            <%!-- Upload errors --%>
            <p
              :for={err <- upload_errors(@uploads.document)}
              class="text-error text-xs"
            >
              {upload_error_to_string(err)}
            </p>
          </form>

          <%!-- Document list --%>
          <div id="documents" phx-update="stream" class="space-y-3">
            <div
              id="documents-empty"
              class="hidden only:block text-center py-12 text-base-content/50"
            >
              <.icon name="hero-document-text" class="size-12 mx-auto mb-4" />
              <p class="text-lg">{gettext("No documents yet.")}</p>
              <p class="text-sm mt-1">
                {gettext("Upload a medical document to get started.")}
              </p>
            </div>

            <.link
              :for={{dom_id, doc} <- @streams.documents}
              navigate={~p"/people/#{@person}/documents/#{doc}"}
              id={dom_id}
              class="card bg-base-100 shadow-elevated hover:shadow-elevated-lg hover:-translate-y-0.5 transition-all duration-200 block border border-base-300/30"
            >
              <div class="card-body p-4 flex-row items-center gap-4">
                <.document_type_icon type={doc.document_type} />
                <div class="flex-1 min-w-0">
                  <p class="font-medium text-sm truncate">{doc.filename}</p>
                  <p class="text-xs text-base-content/50 mt-0.5">
                    {if doc.document_date,
                      do: Calendar.strftime(doc.document_date, "%Y-%m-%d"),
                      else: Calendar.strftime(doc.inserted_at, "%Y-%m-%d")}
                  </p>
                </div>
                <span
                  :if={doc.status == "parsed" && doc.document_type == "lab_results"}
                  class="text-xs text-base-content/50"
                >
                  {ngettext("1 biomarker", "%{count} biomarkers", length(doc.biomarkers))}
                </span>
                <.status_badge status={doc.status} />
              </div>
            </.link>
          </div>
        </div>

        <%!-- Biomarkers tab --%>
        <div :if={@tab == "biomarkers"} class="space-y-6">
          <%!-- Summary stats + search --%>
          <div :if={@biomarkers_total > 0} class="flex flex-wrap items-center gap-3 text-sm">
            <span class="font-medium">
              {ngettext("1 biomarker", "%{count} biomarkers", @biomarkers_total)}
            </span>
            <span :if={@biomarker_status_counts["normal"]} class="text-success">
              {@biomarker_status_counts["normal"]} {gettext("normal")}
            </span>
            <span :if={@biomarker_status_counts["high"]} class="text-error">
              {@biomarker_status_counts["high"]} {gettext("high")}
            </span>
            <span :if={@biomarker_status_counts["low"]} class="text-info">
              {@biomarker_status_counts["low"]} {gettext("low")}
            </span>
            <form phx-change="filter-biomarkers" class="ml-auto">
              <input
                type="text"
                name="biomarker_filter"
                value={@biomarker_filter}
                placeholder={gettext("Search biomarkers...")}
                phx-debounce="200"
                class="input input-sm input-bordered w-48"
              />
            </form>
          </div>

          <%!-- Empty state --%>
          <div :if={@biomarkers_total == 0} class="text-center py-12 text-base-content/50">
            <.icon name="hero-beaker" class="size-12 mx-auto mb-4" />
            <p class="text-lg">{gettext("No biomarkers yet.")}</p>
            <p class="text-sm mt-1">
              {gettext("Upload lab results to start tracking biomarkers.")}
            </p>
          </div>

          <%!-- Categorized biomarker cards --%>
          <div
            :for={{category, biomarkers} <- @filtered_biomarker_groups || []}
            class="card bg-base-100 shadow-elevated border border-base-300/20"
          >
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
                      <th>{gettext("Date")}</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for bm <- biomarkers do %>
                      <tr
                        id={"biomarker-row-#{bm.latest.id}"}
                        class={[
                          "cursor-pointer hover:bg-primary/5 transition-colors",
                          biomarker_row_class(bm.latest.status),
                          bm.stale? && "opacity-50"
                        ]}
                        phx-click="toggle-trend"
                        phx-value-key={bm.key}
                      >
                        <td class="font-medium">
                          {bm.name}
                          <span
                            :if={bm.data_point_count > 1}
                            class="text-xs text-base-content/40 ml-1"
                          >
                            ({bm.data_point_count})
                          </span>
                        </td>
                        <td>
                          <.sparkline
                            :if={length(bm.sparkline_points) > 1}
                            points={bm.sparkline_points}
                          />
                        </td>
                        <td class="text-right font-mono">{bm.latest.value}</td>
                        <td class="text-base-content/60">{bm.latest.unit}</td>
                        <td class="text-base-content/60 text-xs">
                          <.reference_range_bar
                            :if={bm.latest.reference_range_low && bm.latest.reference_range_high && bm.latest.numeric_value}
                            value={bm.latest.numeric_value}
                            low={bm.latest.reference_range_low}
                            high={bm.latest.reference_range_high}
                            status={bm.latest.status}
                          />
                          <span :if={!bm.latest.reference_range_low || !bm.latest.reference_range_high || !bm.latest.numeric_value}>
                            {bm.latest.reference_range_text}
                          </span>
                        </td>
                        <td><.biomarker_status_badge status={bm.latest.status} /></td>
                        <td class="text-xs text-base-content/50">
                          {Calendar.strftime(bm.latest_date, "%Y-%m-%d")}
                        </td>
                      </tr>
                      <%!-- Inline trend expansion --%>
                      <%= if @expanded_biomarker == bm.key do %>
                        <tr id={"trend-#{bm.latest.id}"}>
                          <td colspan="7" class="p-4 bg-base-200/20 border-l-4 border-primary/30">
                            <.trend_detail biomarker={bm} person={@person} />
                          </td>
                        </tr>
                      <% end %>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.sidebar>
    """
  end

  # -- Private components --

  attr :biomarker, :map, required: true
  attr :person, :any, required: true

  defp trend_detail(assigns) do
    chart_data = build_chart_data(assigns.biomarker)
    assigns = assign(assigns, :chart_data, Jason.encode!(chart_data))

    ~H"""
    <div class="space-y-4">
      <div
        id={"trend-chart-#{Base.encode16(:crypto.hash(:md5, @biomarker.name), case: :lower)}"}
        phx-hook="TrendChart"
        phx-update="ignore"
        data-chart={@chart_data}
        class="h-48"
      />

      <table class="table table-xs">
        <thead>
          <tr>
            <th>{gettext("Date")}</th>
            <th class="text-right">{gettext("Value")}</th>
            <th>{gettext("Unit")}</th>
            <th>{gettext("Document")}</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={entry <- Enum.reverse(@biomarker.history)}>
            <td class="text-xs">
              {if entry.document.document_date,
                do: Calendar.strftime(entry.document.document_date, "%Y-%m-%d"),
                else: Calendar.strftime(entry.document.inserted_at, "%Y-%m-%d")}
            </td>
            <td class="text-right font-mono">{entry.value}</td>
            <td class="text-base-content/60">{entry.unit}</td>
            <td>
              <.link
                navigate={~p"/people/#{@person}/documents/#{entry.document}"}
                class="link link-primary text-xs"
              >
                {entry.document.filename}
              </.link>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp info_item(assigns) do
    ~H"""
    <div class="pl-3 border-l-2 border-base-300">
      <dt class="text-xs text-base-content/40 uppercase tracking-wider font-medium">{@label}</dt>
      <dd class="mt-0.5 text-sm font-semibold">{@value}</dd>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :content, :string, default: nil

  defp markdown_card(assigns) do
    assigns = assign(assigns, :rendered, render_markdown(assigns.content))

    ~H"""
    <div class="card bg-base-100 shadow-elevated border border-base-300/20">
      <div class="card-body">
        <h3 class="card-title text-base">{@title}</h3>
        <div class="mt-2 text-sm markdown-content text-base-content/80">
          {@rendered}
        </div>
      </div>
    </div>
    """
  end

  attr :status, :string, required: true

  defp status_badge(%{status: "parsed"} = assigns) do
    ~H"""
    <span class="badge badge-success badge-sm">{gettext("Parsed")}</span>
    """
  end

  defp status_badge(%{status: "parsing"} = assigns) do
    ~H"""
    <span class="badge badge-warning badge-sm">
      <span class="loading loading-spinner loading-xs mr-1" />{gettext("Parsing")}
    </span>
    """
  end

  defp status_badge(%{status: "pending"} = assigns) do
    ~H"""
    <span class="badge badge-ghost badge-sm">{gettext("Pending")}</span>
    """
  end

  defp status_badge(%{status: "failed"} = assigns) do
    ~H"""
    <span class="badge badge-error badge-sm">{gettext("Failed")}</span>
    """
  end

  defp status_badge(assigns) do
    ~H"""
    <span class="badge badge-ghost badge-sm">{@status}</span>
    """
  end

  attr :type, :string, required: true

  defp document_type_icon(%{type: "lab_results"} = assigns) do
    ~H"""
    <div class="p-2 bg-info/10 rounded-lg">
      <.icon name="hero-beaker" class="size-5 text-info" />
    </div>
    """
  end

  defp document_type_icon(%{type: "medical_report"} = assigns) do
    ~H"""
    <div class="p-2 bg-success/10 rounded-lg">
      <.icon name="hero-document-text" class="size-5 text-success" />
    </div>
    """
  end

  defp document_type_icon(assigns) do
    ~H"""
    <div class="p-2 bg-base-200 rounded-lg">
      <.icon name="hero-document" class="size-5 text-base-content/50" />
    </div>
    """
  end

  # -- Lifecycle --

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope
    person = People.get_person!(scope, id)

    if connected?(socket) do
      Documents.subscribe_person_documents(person.id)
    end

    documents_count = Documents.count_documents(scope, person.id)

    biomarker_status_counts = Documents.count_person_biomarkers_by_status(scope, person.id)
    biomarkers_total = biomarker_status_counts |> Map.values() |> Enum.sum()

    {:ok,
     socket
     |> assign(page_title: person.name)
     |> assign(person: person)
     |> assign(tab: "overview")
     |> assign(documents_count: documents_count)
     |> assign(biomarker_status_counts: biomarker_status_counts)
     |> assign(biomarkers_total: biomarkers_total)
     |> assign(biomarker_groups: nil)
     |> assign(filtered_biomarker_groups: nil)
     |> assign(biomarker_filter: "")
     |> assign(expanded_biomarker: nil)
     |> stream(:documents, [])
     |> allow_upload(:document,
       accept: ~w(.jpg .jpeg .png .pdf),
       max_file_size: 20_000_000,
       max_entries: 5,
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tab = params["tab"] || "overview"

    socket =
      case tab do
        "documents" ->
          documents =
            Documents.list_documents(socket.assigns.current_scope, socket.assigns.person.id)

          stream(socket, :documents, documents, reset: true)

        "biomarkers" ->
          if socket.assigns.biomarker_groups do
            socket
          else
            load_biomarker_groups(socket)
          end

        _ ->
          socket
      end

    {:noreply, assign(socket, :tab, tab)}
  end

  # -- Events --

  @impl true
  def handle_event("delete", _params, socket) do
    {:ok, _} = People.delete_person(socket.assigns.current_scope, socket.assigns.person)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Person deleted successfully."))
     |> push_navigate(to: ~p"/people")}
  end

  def handle_event("validate-upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save-upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :document, ref)}
  end

  def handle_event("filter-biomarkers", %{"biomarker_filter" => filter}, socket) do
    filtered = filter_biomarker_groups(socket.assigns.biomarker_groups, filter)
    {:noreply, assign(socket, biomarker_filter: filter, filtered_biomarker_groups: filtered)}
  end

  def handle_event("toggle-trend", %{"key" => key}, socket) do
    expanded =
      if socket.assigns.expanded_biomarker == key, do: nil, else: key

    {:noreply, assign(socket, :expanded_biomarker, expanded)}
  end

  # -- PubSub --

  @impl true
  def handle_info(:people_changed, socket) do
    people = People.list_people(socket.assigns.current_scope)
    {:noreply, assign(socket, :people, people)}
  end

  def handle_info({:document_updated, document}, socket) do
    document = Meddie.Repo.preload(document, :biomarkers)
    scope = socket.assigns.current_scope
    person_id = socket.assigns.person.id

    documents_count = Documents.count_documents(scope, person_id)

    biomarker_status_counts = Documents.count_person_biomarkers_by_status(scope, person_id)
    biomarkers_total = biomarker_status_counts |> Map.values() |> Enum.sum()

    {:noreply,
     socket
     |> stream_insert(:documents, document)
     |> assign(documents_count: documents_count)
     |> assign(biomarker_status_counts: biomarker_status_counts)
     |> assign(biomarkers_total: biomarkers_total)
     |> assign(biomarker_groups: nil, filtered_biomarker_groups: nil, expanded_biomarker: nil)}
  end

  # -- Upload progress callback --

  defp handle_progress(:document, entry, socket) do
    if entry.done? do
      result =
        consume_uploaded_entry(socket, entry, fn %{path: tmp_path} ->
          person = socket.assigns.person
          scope = socket.assigns.current_scope

          file_data = File.read!(tmp_path)

          content_hash =
            :crypto.hash(:sha256, file_data) |> Base.encode16(case: :lower)

          if Documents.document_exists_by_hash?(scope, person.id, content_hash) do
            {:ok, :duplicate}
          else
            document_id = Ecto.UUID.generate()

            storage_path =
              "documents/#{scope.space.id}/#{person.id}/#{document_id}/#{entry.client_name}"

            :ok = Meddie.Storage.put(storage_path, file_data, entry.client_type)

            attrs = %{
              "filename" => entry.client_name,
              "content_type" => entry.client_type,
              "file_size" => entry.client_size,
              "storage_path" => storage_path,
              "content_hash" => content_hash
            }

            {:ok, document} = Documents.create_document(scope, person.id, attrs)

            %{document_id: document.id}
            |> Meddie.Workers.ParseDocument.new()
            |> Oban.insert()

            {:ok, document}
          end
        end)

      socket =
        case result do
          :duplicate ->
            put_flash(socket, :info, gettext("This document has already been uploaded."))

          _document ->
            socket
        end

      # Refresh the document list
      documents =
        Documents.list_documents(socket.assigns.current_scope, socket.assigns.person.id)

      documents_count =
        Documents.count_documents(socket.assigns.current_scope, socket.assigns.person.id)

      {:noreply,
       socket
       |> stream(:documents, documents, reset: true)
       |> assign(documents_count: documents_count)}
    else
      {:noreply, socket}
    end
  end

  # -- Helpers --

  defp age(date_of_birth) do
    div(Date.diff(Date.utc_today(), date_of_birth), 365)
  end

  defp render_markdown(nil), do: "—"
  defp render_markdown(""), do: "—"

  defp render_markdown(content) do
    content
    |> Earmark.as_html!(smartypants: false)
    |> Phoenix.HTML.raw()
  end

  defp display_sex("male"), do: gettext("Male")
  defp display_sex("female"), do: gettext("Female")
  defp display_sex(_), do: ""

  defp upload_error_to_string(:too_large), do: gettext("File is too large (max 20 MB)")
  defp upload_error_to_string(:too_many_files), do: gettext("Too many files")

  defp upload_error_to_string(:not_accepted),
    do: gettext("Unsupported file format. Accepted: PDF, JPG, PNG")

  defp upload_error_to_string(_), do: gettext("Upload error")

  # -- Biomarker helpers --

  defp load_biomarker_groups(socket) do
    scope = socket.assigns.current_scope
    person_id = socket.assigns.person.id

    all_biomarkers = Documents.list_person_biomarkers(scope, person_id)
    biomarker_groups = aggregate_biomarkers(all_biomarkers)
    filtered = filter_biomarker_groups(biomarker_groups, socket.assigns.biomarker_filter)

    assign(socket, biomarker_groups: biomarker_groups, filtered_biomarker_groups: filtered)
  end

  defp filter_biomarker_groups(nil, _filter), do: nil
  defp filter_biomarker_groups(groups, ""), do: groups

  defp filter_biomarker_groups(groups, filter) do
    filter_down = String.downcase(filter)

    groups
    |> Enum.map(fn {category, biomarkers} ->
      filtered =
        Enum.filter(biomarkers, fn bm ->
          String.contains?(String.downcase(bm.name), filter_down) ||
            String.contains?(String.downcase(category || ""), filter_down)
        end)

      {category, filtered}
    end)
    |> Enum.reject(fn {_cat, bms} -> bms == [] end)
  end

  defp aggregate_biomarkers(biomarkers) do
    biomarkers
    |> Enum.group_by(&{&1.name, Documents.normalize_unit(&1.unit)})
    |> Enum.map(fn {{name, unit}, entries} ->
      entries =
        Enum.sort_by(entries, fn e ->
          e.document.document_date || DateTime.to_date(e.document.inserted_at)
        end, Date)

      latest = List.last(entries)
      history = Enum.filter(entries, & &1.numeric_value)
      sparkline_points = Enum.map(history, &%{value: &1.numeric_value, status: &1.status})

      latest_date =
        latest.document.document_date || DateTime.to_date(latest.document.inserted_at)

      stale? = Date.diff(Date.utc_today(), latest_date) > 180

      %{
        name: name,
        unit: unit,
        key: "#{name}::#{unit}",
        category: latest.category,
        latest: latest,
        latest_date: latest_date,
        history: entries,
        sparkline_points: sparkline_points,
        stale?: stale?,
        data_point_count: length(entries)
      }
    end)
    |> Enum.sort_by(&{&1.category || "zzz", &1.name, &1.unit || ""})
    |> Enum.group_by(& &1.category)
  end

  defp build_chart_data(biomarker) do
    points =
      biomarker.history
      |> Enum.filter(& &1.numeric_value)
      |> Enum.map(fn entry ->
        date =
          entry.document.document_date || DateTime.to_date(entry.document.inserted_at)

        %{
          x: Date.to_iso8601(date),
          y: entry.numeric_value,
          status: entry.status
        }
      end)

    %{
      points: points,
      reference_low: biomarker.latest.reference_range_low,
      reference_high: biomarker.latest.reference_range_high,
      unit: biomarker.latest.unit,
      name: biomarker.name
    }
  end
end
