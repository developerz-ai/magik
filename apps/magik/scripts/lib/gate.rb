# frozen_string_literal: true

require "json"
require "open3"

require_relative "registry"

module MagikScripts
  # The adapter that lets `bin/check` run `scripts/checks/` without knowing what
  # is in it.
  #
  # `bin/check` owns the gate: the step list, the ordering, the reporting and
  # the exit codes. This module hands it one ready-made `Step` per check,
  # discovered from the headers, so adding a check is adding a file — no edit to
  # `bin/check`, and therefore no way for the gate and the check list to
  # disagree.
  #
  # Each step runs its check as a **subprocess** with `--json`. That costs one
  # Ruby boot per check, and it buys the property the whole directory is built
  # on: what the gate runs is exactly what a person runs by hand, with the same
  # exit code, and one check crashing cannot take the gate down with it.
  #
  # Wiring, in full — two lines in `bin/check`:
  #
  #     require_relative "../scripts/lib/gate"      # next to the other requires
  #
  #     STEPS = [
  #       *MagikScripts::Gate.steps(Step),          # first: source scans, no gem loading
  #       Step.new(name: "rubocop", ...),
  #       ...
  #     ].freeze
  module Gate
    # How much of a failing check's output to keep, head and tail. Matches
    # `bin/check`'s own excerpt budget.
    # @return [Array(Integer, Integer)]
    EXCERPT = [25, 15].freeze

    module_function

    # One step per discovered check, in cost order.
    #
    # @param step_struct [Class] `bin/check`'s `Step` struct
    # @return [Array<Struct>] ready to splice into `STEPS`
    def steps(step_struct)
      Registry.discover.map do |entry|
        command = "#{entry.command} --json"
        step_struct.new(name: entry.name, title: entry.summary, command: -> { command },
                        body: -> { outcome(entry, command) })
      end
    end

    # Run one check and translate its verdict into `bin/check`'s outcome hash.
    #
    # @param entry [MagikScripts::Registry::Entry]
    # @param command [String] what was announced, for the report
    # @return [Hash{Symbol => Object}]
    def outcome(entry, command)
      out, status = Open3.capture2e("ruby", Repo.path(entry.path).to_s, "--json",
                                    chdir: Repo.root.to_s)
      data = parse(out)
      return unreadable(entry, command, out, status) if data.nil?

      translate(entry, command, data, status)
    end

    # @param entry [MagikScripts::Registry::Entry]
    # @param command [String]
    # @param data [Hash] the check's `--json` document
    # @param status [Process::Status]
    # @return [Hash{Symbol => Object}]
    def translate(entry, command, data, status)
      return passed(command, data) if data["ok"]

      { status: data["status"], reason: data["reason"] || "check_failed:#{entry.name}",
        expected: data["expected"], got: excerpt(rendered(data)), command: command,
        exit_code: status.exitstatus, fix: data["fix"] }
    end

    # @param command [String]
    # @param data [Hash]
    # @return [Hash{Symbol => Object}]
    def passed(command, data)
      { status: "pass", reason: nil, expected: nil, got: data["got"].to_s, command: command,
        exit_code: 0, fix: nil }
    end

    # A check that did not print a JSON document is a bug in the check, not a
    # finding about the repository, and it says so.
    #
    # @param entry [MagikScripts::Registry::Entry]
    # @param command [String]
    # @param out [String] whatever it did print
    # @param status [Process::Status]
    # @return [Hash{Symbol => Object}]
    def unreadable(entry, command, out, status)
      { status: "fail", reason: "check_json_unparseable:#{entry.name}",
        expected: "a single JSON object on stdout from #{entry.path} --json",
        got: excerpt(out), command: command, exit_code: status.exitstatus,
        fix: "#{entry.command} --json   # this is a bug in the check itself" }
    end

    # @param out [String]
    # @return [Hash, nil]
    def parse(out)
      parsed = JSON.parse(out.to_s)
      parsed.is_a?(Hash) && parsed.key?("ok") ? parsed : nil
    rescue JSON::ParserError
      nil
    end

    # The findings, rendered the way the check would have rendered them.
    #
    # @param data [Hash]
    # @return [String]
    def rendered(data)
      findings = Array(data["findings"]).map do |finding|
        head = finding["at"] ? "#{finding["code"]} (#{finding["at"]})" : finding["code"]
        "  #{head}\n    cause: #{finding["cause"]}\n    fix:   #{finding["fix"]}"
      end
      ([data["got"].to_s, ""] + findings).join("\n").strip
    end

    # @param text [String]
    # @return [String] head-and-tail, so a fix line is never buried
    def excerpt(text)
      head, tail = EXCERPT
      lines = text.to_s.lines
      return text.to_s.rstrip if lines.size <= head + tail + 1

      elided = lines.size - head - tail
      (lines.first(head) + ["\n... #{elided} lines elided — run the check on its own ...\n\n"] +
        lines.last(tail)).join.rstrip
    end
  end
end
