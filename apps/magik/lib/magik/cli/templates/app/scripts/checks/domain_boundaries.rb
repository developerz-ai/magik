#!/usr/bin/env ruby
# frozen_string_literal: true

# @check   domain-boundaries
# @summary No domain reaches into another domain's models except through what that domain exposes.
# @order   10
#
# Magik enforces domain boundaries at boot. This check answers the same question
# without booting — which matters because, until the framework is implemented,
# boot is not available, and after it is, a finding at commit time is cheaper
# than a finding at deploy time.
#
# The rule, from `domains/<name>/domain.rb`:
#
#   * a domain may name another domain's constant only if it `depends_on` that
#     domain AND that domain `exposes` the constant
#   * a domain may not depend on itself, and a dependency on a domain that does
#     not exist is a typo, not a design
#
#   APP_DOMAIN_BOUNDARY_VIOLATION   a cross-domain reference with no exposure
#   APP_DOMAIN_UNDECLARED_DEPENDENCY  a reference into a domain this one does not depend on
#   APP_DOMAIN_UNKNOWN_DEPENDENCY   `depends_on :Nope` naming no domain
#
# A flat app has no `domains/` directory and this check is not applicable — that
# is a pass, and it says so.

require_relative "../lib/scripts"

module AppScripts
  module Checks
    # Cross-domain reachability, as an assertion.
    class DomainBoundaries < Check
      # One domain, flattened to data so the rule below is pure.
      Domain = Struct.new(:name, :path, :depends_on, :exposes, :declares, :references, keyword_init: true)

      # `domain :Billing` — the constant this file declares.
      DOMAIN_NAME = /^\s*domain\s+:([A-Z]\w*)/
      # `depends_on :Identity, :Catalog`
      DEPENDS_ON = /^\s*depends_on\s+(.+)$/
      # `exposes :Invoice, :charge`
      EXPOSES = /^\s*exposes\s+(.+)$/
      # `model :Invoice` / `ledger :Receivables` — what a domain owns.
      DECLARES = /^\s*(?:model|ledger|flow)\s+:([A-Z]\w*)/
      # A bare constant reference in application code.
      CONSTANT = /(?<![:\w.])([A-Z][A-Za-z0-9]+)(?=\.|\(|\s|,|\)|$)/

      # The pure rule. Give it domains, get findings — no filesystem, so a test
      # can hand it a fixture and assert the negative case.
      #
      # @param domains [Array<Domain>]
      # @return [Array<AppScripts::Finding>]
      def self.findings_for(domains)
        owner = domains.each_with_object({}) do |domain, map|
          domain.declares.each { |constant| map[constant] = domain.name }
        end
        known = domains.map(&:name)

        domains.flat_map do |domain|
          unknown_dependencies(domain, known) + crossings(domain, owner, domains)
        end
      end

      # @return [Array<AppScripts::Finding>]
      def self.unknown_dependencies(domain, known)
        (domain.depends_on - known).map do |missing|
          Finding.new(code: "APP_DOMAIN_UNKNOWN_DEPENDENCY", at: domain.path,
                      cause: "#{domain.name} declares `depends_on :#{missing}` and no domain :#{missing} exists",
                      fix: "magik domains --json   # then correct the name in #{domain.path}")
        end
      end

      # @return [Array<AppScripts::Finding>]
      def self.crossings(domain, owner, domains)
        by_name = domains.to_h { |candidate| [candidate.name, candidate] }

        domain.references.filter_map do |(constant, at)|
          holder = owner[constant]
          next if holder.nil? || holder == domain.name

          crossing_finding(domain, by_name.fetch(holder), constant, at)
        end
      end

      # @return [AppScripts::Finding]
      def self.crossing_finding(domain, holder, constant, at)
        unless domain.depends_on.include?(holder.name)
          return Finding.new(code: "APP_DOMAIN_UNDECLARED_DEPENDENCY", at: at,
                             cause: "#{domain.name} names #{holder.name}::#{constant} and does not " \
                                    "`depends_on :#{holder.name}`",
                             fix: "add `depends_on :#{holder.name}` to #{holder.path.sub(%r{/[^/]+\z}, "")}" \
                                  "/domain.rb, or stop reaching across")
        end

        Finding.new(code: "APP_DOMAIN_BOUNDARY_VIOLATION", at: at,
                    cause: "#{domain.name} names #{constant}, which #{holder.name} owns and does not expose",
                    fix: "add `exposes :#{constant}` to #{holder.path}, or subscribe to an event instead")
      end

      # @return [AppScripts::Result]
      def run
        declarations = Root.glob("domains/*/domain.rb")
        return not_applicable(because: "this app is flat — no domains/ directory", expected: expectation) if
          declarations.empty?

        domains = declarations.map { |rel| read_domain(rel) }
        findings = self.class.findings_for(domains)
        return failure(reason: "boundary_violation", expected: expectation, fix: fix_line, findings: findings) if
          findings.any?

        ok(expected: expectation,
           got: "#{domains.size} domains, #{domains.sum { |d| d.references.size }} constant references checked")
      end

      private

      # @param rel [String] path to a `domain.rb`
      # @return [Domain]
      def read_domain(rel)
        body = Root.read(rel)
        dir = File.dirname(rel)
        sources = Root.glob("#{dir}/**/*.rb") - [rel]

        Domain.new(name: body[DOMAIN_NAME, 1] || File.basename(dir).capitalize, path: rel,
                   depends_on: symbols(body, DEPENDS_ON), exposes: symbols(body, EXPOSES),
                   declares: sources.flat_map { |s| Root.read(s).scan(DECLARES).flatten },
                   references: references(sources, symbols(body, EXPOSES)))
      end

      # @return [Array<String>] the constants named in every matching line
      def symbols(body, pattern)
        body.scan(pattern).flatten.flat_map { |list| list.scan(/:([A-Za-z_]\w*)/).flatten }
      end

      # @return [Array<Array(String, String)>] constant and `file:line`
      def references(sources, exposed)
        sources.flat_map do |rel|
          Root.read(rel).each_line.with_index(1).flat_map do |line, number|
            next [] if line.lstrip.start_with?("#")

            line.scan(CONSTANT).flatten.reject { |c| exposed.include?(c) }.map { |c| [c, "#{rel}:#{number}"] }
          end
        end.uniq
      end

      # @return [String]
      def expectation
        "every constant a domain names is either its own or exposed by a domain it depends on"
      end

      # @return [String]
      def fix_line
        "ruby scripts/checks/domain_boundaries.rb   # each finding above names the edit that clears it"
      end
    end
  end
end

exit AppScripts::Runner.main(__FILE__, AppScripts::Checks::DomainBoundaries) if $PROGRAM_NAME == __FILE__
