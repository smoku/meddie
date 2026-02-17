defmodule Meddie.Accounts.UserNotifier do
  import Swoosh.Email

  alias Meddie.Mailer

  @from {"Meddie", "meddie@meddie.pl"}

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from(@from)
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm an email address change.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Meddie — Potwierdź zmianę adresu e-mail", """
    Cześć #{user.name},

    Kliknij poniższy link, aby potwierdzić zmianę adresu e-mail:

    #{url}

    Jeśli nie prosiłeś/aś o tę zmianę, zignoruj tę wiadomość.

    Meddie
    """)
  end

  @doc """
  Deliver invitation instructions to a new user.

  Accepts a raw email (invitee may not exist yet), the invitation URL,
  and opts with `:inviter_name` and optional `:space_name`.
  """
  def deliver_invitation_instructions(email, url, opts \\ %{}) do
    inviter_name = Map.get(opts, :inviter_name, "Meddie")
    space_name = Map.get(opts, :space_name)

    space_line =
      if space_name do
        ~s(Zostałeś/aś zaproszony/a do przestrzeni "#{space_name}" w Meddie)
      else
        ~s(Zostałeś/aś zaproszony/a do Meddie)
      end

    deliver(email, "Meddie — Zaproszenie", """
    Cześć,

    #{space_line} przez #{inviter_name}.

    Kliknij poniższy link, aby zaakceptować zaproszenie:

    #{url}

    Link jest ważny przez 7 dni. Jeśli nie oczekujesz tego zaproszenia, zignoruj tę wiadomość.

    Meddie
    """)
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Meddie — Resetowanie hasła", """
    Cześć#{if user.name, do: " #{user.name}", else: ""},

    Kliknij poniższy link, aby zresetować swoje hasło:

    #{url}

    Link jest ważny przez 24 godziny. Jeśli nie prosiłeś/aś o zmianę hasła, zignoruj tę wiadomość.

    Meddie
    """)
  end
end
