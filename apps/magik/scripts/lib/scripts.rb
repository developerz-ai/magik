# frozen_string_literal: true

# The `scripts/lib` front door. Requiring it loads the helper library and does
# nothing else — no file is read, no subprocess starts, no constant is mutated.
# A check file requires this one and gets the whole contract.
#
# @see MagikScripts::Check
# @see MagikScripts::Registry
module MagikScripts
end

require_relative "repo"
require_relative "finding"
require_relative "result"
require_relative "check"
require_relative "registry"
require_relative "runner"
require_relative "markdown"
require_relative "tiers"
