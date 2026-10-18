cutils = require ("common-utils")
log = Log.open_topic ("s-deepfilter-bypass")

local FILTER_NAME = "deepfilter-mic"

local function update (source)
  local nodes_om = source:call ("get-object-manager", "node")
  local metadata_om = source:call ("get-object-manager", "metadata")
  local default_md = metadata_om:lookup { Constraint { "metadata.name", "=", "default" } }
  local filters_md = metadata_om:lookup { Constraint { "metadata.name", "=", "filters" } }
  if default_md == nil or filters_md == nil then
    return
  end

  local bypass = false
  local value = default_md:find (0, "default.audio.source")
  local name = value and Json.Raw (value):parse ().name
  if name ~= nil then
    local default_node = nodes_om:lookup { type = "node",
        Constraint { "node.name", "=", name } }
    bypass = default_node ~= nil and
        cutils.parseBool (default_node.properties ["deepfilter.bypass"]) or false
  end

  local want = tostring (bypass)
  for filter in nodes_om:iterate { type = "node",
      Constraint { "filter.smart.name", "=", FILTER_NAME, type = "pw" },
      Constraint { "media.class", "=", "Audio/Source" } } do
    local id = filter ["bound-id"]
    if filters_md:find (id, "filter.smart.disabled") ~= want then
      log:info (string.format ("default source %s: filter.smart.disabled = %s",
          tostring (name), want))
      filters_md:set (id, "filter.smart.disabled", "Spa:String:JSON", want)
    end
  end
end

SimpleEventHook {
  name = "custom/deepfilter-bypass",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "metadata-changed" },
      Constraint { "metadata.name", "=", "default" },
      Constraint { "event.subject.key", "=", "default.audio.source" },
    },
    EventInterest {
      Constraint { "event.type", "=", "node-added" },
      Constraint { "media.class", "#", "Audio/Source*" },
    },
    EventInterest {
      Constraint { "event.type", "=", "metadata-added" },
    },
  },
  execute = function (event)
    update (event:get_source ())
  end
}:register ()
