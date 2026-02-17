defmodule MeddieWeb.AskMeddieLive.Show do
  use MeddieWeb, :live_view

  alias Meddie.Conversations
  alias Meddie.Conversations.Chat
  alias Meddie.People

  require Logger

  @daily_message_limit 200

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.sidebar
      flash={@flash}
      current_scope={@current_scope}
      user_spaces={@user_spaces}
      people={@people}
      page_title={gettext("Ask Meddie")}
    >
      <div class="flex h-[calc(100vh-4.25rem)] -m-4 sm:-m-6 lg:-m-8">
        <%!-- Left panel: conversation list --%>
        <aside class="hidden lg:flex flex-col w-72 border-r border-base-300/50 bg-base-200/30 shrink-0">
          <div class="flex items-center justify-between px-4 py-3 border-b border-base-300/50">
            <span class="font-bold text-sm">{gettext("Ask Meddie")}</span>
            <.link navigate={~p"/ask-meddie/new"} class="btn btn-ghost btn-sm btn-square">
              <.icon name="hero-pencil-square-micro" class="size-4" />
            </.link>
          </div>
          <nav class="flex-1 overflow-y-auto p-2 space-y-0.5">
            <.link
              :for={conv <- @conversations}
              navigate={~p"/ask-meddie/#{conv}"}
              class={[
                "flex flex-col gap-0.5 px-3 py-2.5 rounded-lg text-sm transition-all duration-150 block",
                active_conversation?(@conversation, conv) && "bg-primary/10 text-primary font-semibold",
                !active_conversation?(@conversation, conv) && "hover:bg-base-300/50"
              ]}
            >
              <span class="truncate font-medium">{conv.title || gettext("New conversation")}</span>
              <span class="text-xs text-base-content/40 truncate">
                {conv_person_name(conv, @people)}
                &middot;
                {Calendar.strftime(conv.updated_at, "%m/%d")}
              </span>
            </.link>
            <div :if={@conversations == []} class="text-center py-8 text-base-content/40 text-xs">
              {gettext("No conversations yet.")}
            </div>
          </nav>
        </aside>

        <%!-- Right panel: chat --%>
        <div class="flex-1 flex flex-col min-w-0">
          <%!-- Chat header --%>
          <div class="flex items-center gap-3 px-4 py-2.5 border-b border-base-300/50 shrink-0">
            <.link navigate={~p"/ask-meddie"} class="btn btn-ghost btn-sm lg:hidden">
              <.icon name="hero-bars-3-micro" class="size-4" />
            </.link>
            <div class="flex-1 min-w-0">
              <h1 class="text-sm font-bold truncate">
                {if @conversation, do: @conversation.title || gettext("New conversation"), else: gettext("New conversation")}
              </h1>
              <p class="text-xs text-base-content/40">
                {gettext("Meddie provides informational responses only. This is not medical advice.")}
              </p>
            </div>
            <button
              :if={@conversation}
              phx-click="delete_conversation"
              data-confirm={gettext("Delete this conversation?")}
              class="btn btn-ghost btn-sm text-error"
            >
              <.icon name="hero-trash-micro" class="size-4" />
            </button>
          </div>

          <%!-- Messages area --%>
          <div
            id="chat-messages"
            phx-hook="ChatStream"
            class="flex-1 overflow-y-auto space-y-4 px-4 py-4"
          >
            <%!-- Quick questions (empty conversation with person) --%>
            <div :if={@messages == [] && @selected_person && !@streaming} class="flex flex-col items-center justify-center h-full gap-4">
              <p class="text-base-content/50 text-sm">{gettext("Ask Meddie about %{name}'s health data", name: @selected_person.name)}</p>
              <div class="flex flex-wrap justify-center gap-2">
                <button
                  :for={q <- quick_questions(@selected_person)}
                  phx-click="quick_question"
                  phx-value-text={q}
                  class="btn btn-outline btn-sm"
                >
                  {q}
                </button>
              </div>
            </div>

            <%!-- Empty state (no person) --%>
            <div :if={@messages == [] && !@selected_person && !@streaming} class="flex flex-col items-center justify-center h-full gap-2">
              <.icon name="hero-chat-bubble-left-right" class="size-12 text-base-content/20" />
              <p class="text-base-content/50 text-sm">{gettext("Start a conversation with Meddie")}</p>
            </div>

            <%!-- Message list --%>
            <div :for={msg <- @messages} class={["flex", message_alignment(msg.role)]}>
              <div class={["max-w-[80%] rounded-2xl px-4 py-3 text-sm", message_style(msg.role)]}>
                <div :if={msg.role == "system"} class="flex items-center gap-2">
                  <.icon name="hero-information-circle-micro" class="size-4 shrink-0" />
                  <span>{msg.content}</span>
                  <%= if profile_update_message?(msg) do %>
                    <button
                      :for={mu <- profile_updates_for_message(@profile_updates, msg.id)}
                      :if={!mu.reverted}
                      phx-click="undo_profile_update"
                      phx-value-id={mu.id}
                      class="btn btn-ghost btn-xs"
                    >
                      {gettext("Undo")}
                    </button>
                  <% end %>
                </div>
                <div :if={msg.role != "system"} class="prose prose-sm max-w-none">
                  {render_markdown(msg.content)}
                </div>
              </div>
            </div>

            <%!-- Streaming message --%>
            <div :if={@streaming} class="flex justify-start">
              <div class="max-w-[80%] rounded-2xl px-4 py-3 text-sm bg-base-200">
                <div class="prose prose-sm max-w-none">
                  <span data-streaming-target class="whitespace-pre-wrap"></span>
                  <span class="loading loading-dots loading-xs ml-1"></span>
                </div>
              </div>
            </div>
          </div>

          <%!-- Input area with person picker --%>
          <div class="shrink-0 border-t border-base-300/50 px-4 py-3">
            <form phx-submit="send_message" class="flex items-center gap-2">
              <%!-- Person picker (opens upward) --%>
              <div :if={can_change_person?(@conversation, @messages)} class="dropdown dropdown-top">
                <div tabindex="0" role="button" class="btn btn-ghost btn-sm btn-square">
                  <.icon name="hero-user-micro" class="size-4" />
                </div>
                <ul
                  tabindex="0"
                  class="dropdown-content menu p-2 shadow-elevated-lg bg-base-100 rounded-xl w-56 z-50 border border-base-300/50 mb-2"
                >
                  <li>
                    <button type="button" phx-click="select_person" phx-value-person-id="">
                      <span class={[!@selected_person && "font-bold"]}>{gettext("No person")}</span>
                    </button>
                  </li>
                  <li :for={person <- @people}>
                    <button type="button" phx-click="select_person" phx-value-person-id={person.id}>
                      <span class={[@selected_person && @selected_person.id == person.id && "font-bold"]}>
                        {person.name}
                      </span>
                    </button>
                  </li>
                </ul>
              </div>
              <span :if={@selected_person && !can_change_person?(@conversation, @messages)} class="badge badge-ghost badge-sm gap-1">
                <.icon name="hero-user-micro" class="size-3" />
                {@selected_person.name}
              </span>
              <input
                type="text"
                name="message"
                value=""
                placeholder={if @streaming, do: gettext("Meddie is typing..."), else: gettext("Ask a question...")}
                disabled={@streaming}
                autocomplete="off"
                class="input input-bordered flex-1 min-w-0"
                phx-debounce="100"
              />
              <button
                type="submit"
                disabled={@streaming}
                class="btn btn-primary btn-square"
              >
                <.icon name="hero-paper-airplane-micro" class="size-5" />
              </button>
            </form>
          </div>
        </div>
      </div>
    </Layouts.sidebar>
    """
  end

  # -- Lifecycle --

  @impl true
  def mount(params, _session, socket) do
    scope = socket.assigns.current_scope
    linked_person = People.get_linked_person(scope)
    conversations = Conversations.list_conversations(scope)

    {:ok,
     socket
     |> assign(page_title: gettext("Ask Meddie"))
     |> assign(linked_person: linked_person)
     |> assign(conversations: conversations)
     |> assign(conversation: nil)
     |> assign(messages: [])
     |> assign(selected_person: nil)
     |> assign(streaming: false)
     |> assign(streaming_text: "")
     |> assign(profile_updates: [])
     |> assign(person_id_param: params["person_id"])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    person_id = params["person_id"] || socket.assigns.person_id_param
    people = socket.assigns.people

    selected_person =
      cond do
        person_id -> Enum.find(people, &(&1.id == person_id))
        socket.assigns.linked_person -> socket.assigns.linked_person
        true -> nil
      end

    socket
    |> assign(conversation: nil)
    |> assign(messages: [])
    |> assign(selected_person: selected_person)
    |> assign(profile_updates: [])
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    scope = socket.assigns.current_scope
    conversation = Conversations.get_conversation!(scope, id)
    people = socket.assigns.people

    selected_person =
      if conversation.person_id,
        do: Enum.find(people, &(&1.id == conversation.person_id)),
        else: nil

    profile_updates = load_all_profile_updates(conversation.messages)

    socket
    |> assign(conversation: conversation)
    |> assign(messages: conversation.messages)
    |> assign(selected_person: selected_person)
    |> assign(profile_updates: profile_updates)
  end

  # -- Events --

  @impl true
  def handle_event("send_message", %{"message" => content}, socket) do
    content = String.trim(content)

    cond do
      content == "" ->
        {:noreply, socket}

      socket.assigns.streaming ->
        {:noreply, socket}

      rate_limited?(socket) ->
        {:noreply, put_flash(socket, :error, gettext("You've reached the daily message limit. Try again tomorrow."))}

      true ->
        send_message(socket, content)
    end
  end

  def handle_event("select_person", %{"person-id" => ""}, socket) do
    socket =
      socket
      |> assign(selected_person: nil)
      |> maybe_update_conversation_person(nil)

    {:noreply, socket}
  end

  def handle_event("select_person", %{"person-id" => person_id}, socket) do
    case Enum.find(socket.assigns.people, &(&1.id == person_id)) do
      nil ->
        {:noreply, socket}

      person ->
        socket =
          socket
          |> assign(selected_person: person)
          |> maybe_update_conversation_person(person.id)

        {:noreply, socket}
    end
  end

  def handle_event("quick_question", %{"text" => text}, socket) do
    if socket.assigns.streaming do
      {:noreply, socket}
    else
      send_message(socket, text)
    end
  end

  def handle_event("delete_conversation", _params, socket) do
    scope = socket.assigns.current_scope

    if socket.assigns.conversation do
      {:ok, _} = Conversations.delete_conversation(scope, socket.assigns.conversation)
    end

    {:noreply, push_navigate(socket, to: ~p"/ask-meddie")}
  end

  def handle_event("undo_profile_update", %{"id" => pu_id}, socket) do
    case Conversations.revert_profile_update(pu_id) do
      {:ok, pu} ->
        # Restore previous value to person
        person = Enum.find(socket.assigns.people, &(&1.id == pu.person_id))

        if person do
          People.update_person(socket.assigns.current_scope, person, %{
            pu.field => pu.previous_value
          })
        end

        # Refresh profile_updates list
        profile_updates =
          Enum.map(socket.assigns.profile_updates, fn existing ->
            if existing.id == pu.id, do: %{existing | reverted: true}, else: existing
          end)

        {:noreply, assign(socket, profile_updates: profile_updates)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not revert update."))}
    end
  end

  # -- Streaming handle_info --

  @impl true
  def handle_info({:chat_token, chunk}, socket) do
    {:noreply,
     socket
     |> update(:streaming_text, &(&1 <> chunk))
     |> push_event("chat:token", %{text: chunk})}
  end

  def handle_info({:chat_complete}, socket) do
    full_text = socket.assigns.streaming_text

    # Parse and strip metadata JSON block
    {display_text, profile_updates_data, memory_saves_data} = Chat.parse_response_metadata(full_text)

    # Save assistant message
    conversation = socket.assigns.conversation
    {:ok, assistant_msg} = Conversations.create_message(conversation, %{"role" => "assistant", "content" => display_text})

    scope = socket.assigns.current_scope

    # Apply profile updates (person profile fields)
    Chat.apply_profile_updates(
      scope,
      conversation,
      socket.assigns.selected_person,
      assistant_msg,
      profile_updates_data
    )

    # Apply memory saves (semantic facts)
    Chat.apply_memory_saves(scope, memory_saves_data)

    # Reload messages
    messages = Conversations.list_messages(conversation)
    profile_updates = load_all_profile_updates(messages)

    conversations = Conversations.list_conversations(socket.assigns.current_scope)

    socket =
      socket
      |> assign(streaming: false, streaming_text: "")
      |> assign(messages: messages)
      |> assign(profile_updates: profile_updates)
      |> assign(conversations: conversations)
      |> push_event("chat:complete", %{})

    # Generate title async if first exchange
    socket = maybe_generate_title(socket, messages)

    {:noreply, socket}
  end

  def handle_info({:chat_error, reason}, socket) do
    Logger.error("Chat stream error: #{inspect(reason)}")

    {:noreply,
     socket
     |> assign(streaming: false, streaming_text: "")
     |> push_event("chat:error", %{message: "error"})
     |> put_flash(:error, gettext("Something went wrong. Please try again."))}
  end

  def handle_info({:title_generated, title}, socket) do
    if socket.assigns.conversation do
      {:ok, conversation} = Conversations.update_conversation(socket.assigns.conversation, %{"title" => title})
      conversations = Conversations.list_conversations(socket.assigns.current_scope)
      {:noreply, assign(socket, conversation: conversation, conversations: conversations)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(:people_changed, socket) do
    people = People.list_people(socket.assigns.current_scope)
    {:noreply, assign(socket, :people, people)}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # -- Private: send message flow --

  defp send_message(socket, content) do
    scope = socket.assigns.current_scope

    # Ensure conversation exists
    {socket, conversation} = ensure_conversation(socket)

    # Resolve person if needed
    socket = maybe_resolve_person(socket, conversation, content)
    conversation = socket.assigns.conversation

    # Save user message
    {:ok, _user_msg} = Conversations.create_message(conversation, %{"role" => "user", "content" => content})

    # Reload messages
    messages = Conversations.list_messages(conversation)

    # Spawn streaming task
    lv_pid = self()
    selected_person = socket.assigns.selected_person

    Task.start(fn ->
      try do
        memory_facts = Meddie.Memory.search_for_prompt(scope, content)
        system_prompt = Chat.build_system_prompt(scope, selected_person, memory_facts)
        ai_messages = Chat.prepare_ai_messages(messages)

        callback = fn %{content: chunk} ->
          send(lv_pid, {:chat_token, chunk})
        end

        case Meddie.AI.chat_stream(ai_messages, system_prompt, callback) do
          :ok -> send(lv_pid, {:chat_complete})
          {:error, reason} -> send(lv_pid, {:chat_error, reason})
        end
      rescue
        e -> send(lv_pid, {:chat_error, Exception.message(e)})
      end
    end)

    # Update conversation updated_at
    Conversations.update_conversation(conversation, %{})

    {:noreply,
     socket
     |> assign(messages: messages)
     |> assign(streaming: true, streaming_text: "")}
  end

  defp ensure_conversation(socket) do
    if socket.assigns.conversation do
      {socket, socket.assigns.conversation}
    else
      scope = socket.assigns.current_scope

      attrs =
        if socket.assigns.selected_person,
          do: %{"person_id" => socket.assigns.selected_person.id},
          else: %{}

      {:ok, conversation} = Conversations.create_conversation(scope, attrs)
      conversations = Conversations.list_conversations(scope)

      socket =
        socket
        |> assign(conversation: conversation)
        |> assign(conversations: conversations)
        |> push_patch(to: ~p"/ask-meddie/#{conversation}", replace: true)

      {socket, conversation}
    end
  end

  defp maybe_resolve_person(socket, conversation, message) do
    # Only resolve if no person selected
    if socket.assigns.selected_person do
      socket
    else
      resolved_person = Chat.resolve_person(message, socket.assigns.people, socket.assigns.current_scope)

      if resolved_person do
        Conversations.update_conversation(conversation, %{"person_id" => resolved_person.id})
        conversation = %{conversation | person_id: resolved_person.id}

        socket
        |> assign(selected_person: resolved_person)
        |> assign(conversation: conversation)
      else
        socket
      end
    end
  end

  defp load_all_profile_updates(messages) do
    messages
    |> Enum.flat_map(fn msg ->
      Conversations.list_profile_updates_for_message(msg.id)
    end)
  end

  # -- Private: title generation --

  defp maybe_generate_title(socket, messages) do
    conversation = socket.assigns.conversation

    if conversation && is_nil(conversation.title) do
      user_msgs = Enum.filter(messages, &(&1.role == "user"))
      assistant_msgs = Enum.filter(messages, &(&1.role == "assistant"))

      if length(user_msgs) >= 1 and length(assistant_msgs) >= 1 do
        first_user = hd(user_msgs).content
        first_assistant = hd(assistant_msgs).content
        lv_pid = self()

        Task.start(fn ->
          case Meddie.AI.generate_title(first_user, first_assistant) do
            {:ok, title} -> send(lv_pid, {:title_generated, title})
            _ -> :ok
          end
        end)
      end
    end

    socket
  end

  # -- Private: rate limiting --

  defp rate_limited?(socket) do
    count = Conversations.count_messages_today(socket.assigns.current_scope)
    count >= @daily_message_limit
  end

  # -- Private: helpers --

  defp maybe_update_conversation_person(socket, person_id) do
    if socket.assigns.conversation && can_change_person?(socket.assigns.conversation, socket.assigns.messages) do
      {:ok, conversation} = Conversations.update_conversation(socket.assigns.conversation, %{"person_id" => person_id})
      assign(socket, conversation: conversation)
    else
      socket
    end
  end

  defp can_change_person?(nil, _messages), do: true
  defp can_change_person?(_conversation, []), do: true
  defp can_change_person?(_conversation, _messages), do: false

  defp message_alignment("user"), do: "justify-end"
  defp message_alignment(_), do: "justify-start"

  defp message_style("user"), do: "bg-primary text-primary-content"
  defp message_style("system"), do: "bg-warning/10 text-warning-content text-xs"
  defp message_style(_), do: "bg-base-200"

  defp profile_update_message?(msg) do
    msg.role == "system" and
      (String.contains?(msg.content, gettext("Saved to")) or
         String.contains?(msg.content, gettext("Removed from")))
  end

  defp profile_updates_for_message(profile_updates, message_id) do
    Enum.filter(profile_updates, &(&1.message_id == message_id))
  end

  defp render_markdown(nil), do: ""
  defp render_markdown(""), do: ""

  defp render_markdown(content) do
    content
    |> Earmark.as_html!(smartypants: false)
    |> Phoenix.HTML.raw()
  end

  defp quick_questions(person) do
    base = [
      gettext("How am I doing overall?"),
      gettext("Summarize my latest results")
    ]

    extra =
      cond do
        has_content?(person.medications) and has_content?(person.supplements) ->
          [gettext("Any interactions between my supplements and medications?")]

        has_content?(person.health_notes) ->
          [gettext("What should I monitor given my health history?")]

        true ->
          [gettext("What should I pay attention to?")]
      end

    base ++ extra
  end

  defp has_content?(nil), do: false
  defp has_content?(""), do: false
  defp has_content?(_), do: true

  defp active_conversation?(current, conv) do
    current && current.id == conv.id
  end

  defp conv_person_name(conv, people) do
    case Enum.find(people, &(&1.id == conv.person_id)) do
      nil -> gettext("General")
      person -> person.name
    end
  end
end
