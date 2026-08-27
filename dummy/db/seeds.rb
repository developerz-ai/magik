# frozen_string_literal: true
#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: none of these methods exist, and loading this file would
# raise NoMethodError. See dummy/README.md.
#
# db/seeds.rb — the smallest data set the app is usable with.
#
# TWO RULES, and both are load-bearing.
#
# 1. IDEMPOTENT. `find_or_create_by`, never `create`. Seeds are run again on
#    every fresh checkout, after every reset, and by every new contributor. A
#    seed file that fails the second time is a seed file people stop running.
#
# 2. NOT FIXTURES. Tests build their own data from inferred factories — see
#    dummy/test/. Seeding a database that tests then depend on couples every
#    test to this file, and changing a seed becomes a test failure somewhere
#    unrelated.

seeds do
  account = Account.find_or_create_by!(subdomain: "acme") do |a|
    a.name = "Acme GmbH"
    a.country = "DE"
    a.currency = "EUR"
    a.plan = :team
  end

  # Everything below is tenant-scoped, so it has to say which tenant. There is
  # no ambient current_tenant in a seed run, and `magik check --scale` flags a
  # query here that forgot one.
  as_tenant(account) do
    Customer.find_or_create_by!(email: "ap@northwind.example") do |c|
      c.name = "Northwind Traders"
      c.vat_id = "GB123456789"
    end

    Customer.find_or_create_by!(email: "billing@globex.example") do |c|
      c.name = "Globex Corporation"
    end
  end
end
