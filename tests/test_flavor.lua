-- Tests for flavor.lua

local flavor = require("flavor")

local M = {}

-- Fake rng: always returns lo.
local function make_lo_rng()
  return { int = function(self, lo, hi) return lo end }
end

-- Fake rng: always returns a fixed value, ignoring lo/hi.
local function make_fixed_rng(value)
  return { int = function(self, lo, hi) return value end }
end

-- Sink that records every call as { text = ..., color = ... }.
local function make_sink()
  local calls = {}
  local fn = function(text, color)
    calls[#calls + 1] = { text = text, color = color }
  end
  return fn, calls
end

function M.test_substitution(t)
  local sink, calls = make_sink()
  flavor.init({
    pools = {
      cache_open = {
        color = 23,
        templates = { "You pry the {feature} open - {contents}." },
      },
    },
    rng = make_lo_rng(),
    sink = sink,
  })

  flavor.emit("cache_open", { feature = "crate", contents = "a rusty key" })

  t.eq(#calls, 1, "sink should be called exactly once")
  t.eq(
    calls[1].text,
    "You pry the crate open - a rusty key.",
    "slots should be substituted into the template"
  )
end

function M.test_missing_slot_becomes_question_marks(t)
  local sink, calls = make_sink()
  flavor.init({
    pools = {
      cache_open = {
        color = 23,
        templates = { "You pry the {feature} open - {contents}." },
      },
    },
    rng = make_lo_rng(),
    sink = sink,
  })

  flavor.emit("cache_open", { feature = "crate" })

  t.eq(
    calls[1].text,
    "You pry the crate open - ???.",
    "missing slot should be substituted with ???"
  )
end

function M.test_unknown_event_key(t)
  local sink, calls = make_sink()
  flavor.init({
    pools = {},
    rng = make_lo_rng(),
    sink = sink,
  })

  flavor.emit("x", { foo = "bar" })

  t.eq(#calls, 1, "sink should be called exactly once for unknown event")
  t.eq(calls[1].text, "[flavor missing: x]", "unknown event should report missing key")
  t.eq(calls[1].color, nil, "unknown event should pass nil color")
end

function M.test_anti_repeat(t)
  local sink, calls = make_sink()
  flavor.init({
    pools = {
      wind = {
        color = 5,
        templates = { "The wind howls.", "The wind moans." },
      },
    },
    rng = make_fixed_rng(1),
    sink = sink,
  })

  flavor.emit("wind", {})
  flavor.emit("wind", {})

  t.eq(#calls, 2, "sink should be called twice")
  t.ok(calls[1].text ~= calls[2].text, "second emit must not repeat the same template")
  t.eq(calls[1].text, "The wind howls.", "first emit should use template picked by rng (index 1)")
  t.eq(calls[2].text, "The wind moans.", "second emit must use the OTHER template")
end

function M.test_emit_once_fires_exactly_once(t)
  local sink, calls = make_sink()
  flavor.init({
    pools = {
      discover = {
        color = 7,
        templates = { "You discover the {thing}." },
      },
    },
    rng = make_lo_rng(),
    sink = sink,
  })

  flavor.emit_once("discover", { thing = "shrine" })
  flavor.emit_once("discover", { thing = "shrine" })
  flavor.emit_once("discover", { thing = "shrine" })

  t.eq(#calls, 1, "emit_once should only invoke the sink once per init()")
end

function M.test_emit_once_resets_on_reinit(t)
  local sink, calls = make_sink()
  local pools = {
    discover = {
      color = 7,
      templates = { "You discover the {thing}." },
    },
  }

  flavor.init({ pools = pools, rng = make_lo_rng(), sink = sink })
  flavor.emit_once("discover", { thing = "shrine" })

  flavor.init({ pools = pools, rng = make_lo_rng(), sink = sink })
  flavor.emit_once("discover", { thing = "shrine" })

  t.eq(#calls, 2, "emit_once tracking should reset on a fresh init()")
end

function M.test_color_passthrough(t)
  local sink, calls = make_sink()
  flavor.init({
    pools = {
      cache_open = {
        color = 23,
        templates = { "Something happens." },
      },
      no_color = {
        templates = { "Something else happens." },
      },
    },
    rng = make_lo_rng(),
    sink = sink,
  })

  flavor.emit("cache_open", {})
  flavor.emit("no_color", {})

  t.eq(calls[1].color, 23, "pool color should pass through to the sink")
  t.eq(calls[2].color, nil, "missing pool color should pass through as nil")
end

return M
