# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `screen` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/screens/sign_in.rb  <->  screen :SignIn
#
# Auto-routed to /sign-in.
#
# THE TWO DECLARATIONS THIS FILE EXISTS FOR, and they are both in its first
# line:
#
#   policy: :public   opting out of authorization is a DECLARATION, not an
#                     omission. A surface with neither a verb nor this line
#                     fails the boot with MAGIK_POLICY_UNDECLARED, so "we
#                     forgot" and "we decided" cannot look the same in a diff.
#                     This is the one screen in Ledgerline where the answer is
#                     honestly "anyone" — you cannot require a session on the
#                     page that creates one.
#
#   layout: :None     the shell is a sidebar full of links to pages a signed-out
#                     visitor cannot open. An auth screen wants no shell, and
#                     `MAGIK_LAYOUT_MISSING` means it has to say so rather than
#                     inherit one by silence.
#
# `auth do strategy :email_password end` in config/app.rb generates this screen
# and the `sign_in` action behind it (spec Phase 7, Rodauth-backed). It is
# redeclared here because that is how a generated screen is overridden — the
# same grammar, the same file path, no template to eject.
#
# Demonstrates: screen, policy: :public, layout: :None, form + field + submit
# from the component kit (Phase 2), overriding a generated auth screen (Phase 7).

screen :SignIn, policy: :public, layout: :None do
  title { t("auth.sign_in.title") }

  # No `state`. There is nothing to read before someone has said who they are,
  # and a signed-out screen that queries is a signed-out screen leaking rows.

  body do
    card title: t("auth.sign_in.title") do
      form action: :sign_in do
        field :email,    :email,    label: t("auth.sign_in.email")
        field :password, :password, label: t("auth.sign_in.password")
        submit t("auth.sign_in.submit")
      end
    end
  end
end
