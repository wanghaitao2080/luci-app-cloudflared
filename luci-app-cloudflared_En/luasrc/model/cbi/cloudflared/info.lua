local fs = require "nixio.fs"
local http = require "luci.http"
local conffile = "/tmp/cloudflared.info"

-- clear logs
if http.formvalue("_clear") then
	fs.writefile(conffile, "")
end

-- refresh logs (re-read on page load)
if http.formvalue("_refresh") then
end

local m = SimpleForm("logview", "")
m.reset = false
m.submit = false

-- HTML escaping so log content is displayed safely and completely
local function escapeHtml(s)
	if not s then return "" end
	s = tostring(s)
	s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	s = s:gsub('"', "&quot;"):gsub("'", "&#39;")
	return s
end

-- English labels for known fields (unknown fields fall back to the raw key)
local KV_LABELS = {
	error = "Error", ip = "IP Address", connIndex = "Conn Index", event = "Event",
	type = "Type", dest = "Destination", dst = "Destination", host = "Host",
	path = "Path", port = "Port", rtt = "RTT", edgeIPVersion = "Edge IP Version",
	edgeIpVersion = "Edge IP Version", retries = "Retries", location = "Location",
}

local LEVEL_LABEL = {
	debug = "Debug", info = "Info", warn = "Warning", warning = "Warning",
	error = "Error", fatal = "Fatal",
}

local LEVEL_CLASS = {
	debug = "lv-debug", info = "lv-info", warn = "lv-warn", warning = "lv-warn",
	error = "lv-error", fatal = "lv-fatal",
}

-- Log timestamps are UTC (RFC3339) from zerolog; keep the raw format,
-- no timezone conversion.
local function humanTime(iso)
	iso = tostring(iso or "")
	if iso ~= "" then
		return iso:gsub("T", " "):gsub("Z", "")
	end
	return iso
end

function m.render(self, ...)

	SimpleForm.render(self, ...)

	local raw = fs.readfile(conffile) or ""
	local items = {}
	local jsonCount = 0
	local textCount = 0

	-- process line by line: JSON lines => structured cards,
	-- plain lines => raw cards, nothing is skipped
	for line in raw:gmatch("[^\r\n]+") do
		local ok, obj = pcall(function() return luci.jsonc.parse(line) end)
		local item
		if ok and type(obj) == "table" then
			jsonCount = jsonCount + 1
			item = { isJson = true, obj = obj }
		else
			textCount = textCount + 1
			item = { isJson = false, text = line }
		end
		table.insert(items, item)
	end

	-- reverse order so the newest log appears at the top
	local log_items = {}
	for i = #items, 1, -1 do
		table.insert(log_items, items[i])
	end

	http.write([[
<style>
.controls { display: flex; align-items: center; margin-bottom: 14px; gap: 10px; flex-wrap: wrap; }
.controls .log-count { margin-left: auto; font-size: 12px; font-weight: 600; color: #6b7280; }
.btn { display: inline-flex; align-items: center; gap: 6px; padding: 7px 14px; border-radius: 10px;
	border: 1px solid rgba(255,255,255,0.5); cursor: pointer; font-size: 13px; font-weight: 600;
	color: #fff; transition: transform .2s cubic-bezier(.4,0,.2,1), box-shadow .2s ease, filter .2s ease; }
.btn:hover { transform: translateY(-1px); filter: brightness(1.08); box-shadow: 0 6px 18px rgba(0,0,0,0.15); }
.btn:active { transform: scale(0.97); }
.btn-clear { background: linear-gradient(135deg, #ef4444, #dc2626); }
.switch { display: inline-flex; align-items: center; gap: 8px; cursor: pointer;
	-webkit-user-select: none; user-select: none; }
.switch input { display: none; }
.switch .track { width: 42px; height: 24px; border-radius: 999px; background: #cbd5e1; position: relative;
	flex: 0 0 auto; box-shadow: inset 0 1px 3px rgba(0,0,0,0.15); transition: background .25s ease; }
.switch .track::after { content: ""; position: absolute; top: 2px; left: 2px; width: 20px; height: 20px;
	border-radius: 50%; background: #fff; box-shadow: 0 2px 4px rgba(0,0,0,0.25);
	transition: transform .25s cubic-bezier(.4,0,.2,1); }
.switch input:checked + .track { background: linear-gradient(135deg, #3b82f6, #2563eb); }
.switch input:checked + .track::after { transform: translateX(18px); }
.switch .lbl { font-size: 13px; color: #334155; transition: color .2s ease; }

.log-list { display: flex; flex-direction: column; gap: 12px; }

.log-card { background: rgba(255,255,255,0.55);
	-webkit-backdrop-filter: blur(20px) saturate(180%); backdrop-filter: blur(20px) saturate(180%);
	border: 1px solid rgba(255,255,255,0.65); border-radius: 16px; padding: 13px 16px;
	box-shadow: 0 8px 28px rgba(31,38,135,0.10); word-break: break-word; overflow-wrap: anywhere;
	transition: transform .25s ease, box-shadow .25s ease; }
.log-card:hover { transform: translateY(-2px); box-shadow: 0 12px 36px rgba(31,38,135,0.16); }
.log-card.text { background: rgba(107,114,128,0.10); border-color: rgba(107,114,128,0.25); }
.log-card-header { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.log-time { font-size: 12px; color: #6b7280; }
.log-level { font-size: 11px; font-weight: 700; letter-spacing: .05em; padding: 3px 9px; border-radius: 999px; }
.lv-debug { background: rgba(96,165,250,0.15); color: #2563eb; }
.lv-info  { background: rgba(16,185,129,0.15); color: #059669; }
.lv-warn  { background: rgba(245,158,11,0.15); color: #b45309; }
.lv-error { background: rgba(239,68,68,0.16); color: #dc2626; }
.lv-fatal { background: rgba(239,68,68,0.24); color: #b91c1c; }
.log-json-btn { margin-left: auto; padding: 3px 10px; border: 1px solid rgba(99,102,241,0.4);
	border-radius: 8px; background: rgba(99,102,241,0.10); color: #6366f1; font-size: 11px;
	font-weight: 700; cursor: pointer; transition: all .2s ease; }
.log-json-btn:hover { background: rgba(99,102,241,0.20); transform: translateY(-1px); }
.log-json-btn:active { transform: scale(0.96); }
.log-message { margin: 9px 0 0; font-size: 14px; font-weight: 600; line-height: 1.55;
	white-space: pre-wrap; word-break: break-word; overflow-wrap: anywhere; }
.log-kv { display: grid; grid-template-columns: max-content 1fr; gap: 6px 14px; margin-top: 10px;
	width: 100%; box-sizing: border-box; }
.log-kv .k { font-size: 12px; color: #6b7280; white-space: nowrap; line-height: 1.5; padding-top: 1px; }
.log-kv .v { font-size: 13px; color: #334155; word-break: break-word; overflow-wrap: anywhere;
	font-family: ui-monospace, Menlo, Consolas, monospace; line-height: 1.5; }
.log-kv .kv-err .k, .log-kv .kv-err .v { color: #dc2626; font-weight: 600; }
.log-raw-text { font-size: 13px; line-height: 1.6; white-space: pre-wrap; word-break: break-word;
	overflow-wrap: anywhere; font-family: ui-monospace, Menlo, Consolas, monospace; }

.modal { display: none; position: fixed; z-index: 999; left: 0; top: 0; width: 100%; height: 100%;
	overflow: auto; background-color: rgba(0,0,0,0.35); padding: 16px; box-sizing: border-box; }
.modal-content { background: rgba(255,255,255,0.92);
	-webkit-backdrop-filter: blur(20px); backdrop-filter: blur(20px);
	padding: 20px; border-radius: 16px; width: 100%; max-width: 780px;
	max-height: 90vh; overflow: auto; position: relative; margin: auto;
	box-shadow: 0 12px 36px rgba(0,0,0,0.18); }
.modal-content pre { margin: 0; padding: 14px; border-radius: 10px;
	font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 12px; line-height: 1.6;
	white-space: pre-wrap; word-break: break-word; overflow-wrap: anywhere;
	color: #1f2937; background: #f1f5f9; border: 1px solid rgba(15,23,42,0.10);
	box-shadow: inset 0 1px 3px rgba(0,0,0,0.06); }
.modal-close { position: sticky; top: 0; float: right; padding: 6px 12px; border-radius: 8px;
	background: linear-gradient(135deg, #f59e0b, #d97706); color: #fff; cursor: pointer; border: none;
	font-weight: 700; transition: transform .2s ease, filter .2s ease; }
.modal-close:hover { filter: brightness(1.08); transform: translateY(-1px); }
.modal-close:active { transform: scale(0.96); }

#topBtn { display: none; position: fixed; bottom: 96px; right: 18px; z-index: 1000; font-size: 13px;
	padding: 10px 12px; border: none; border-radius: 12px; cursor: pointer; color: #fff;
	background: linear-gradient(135deg, #6366f1, #4f46e5); box-shadow: 0 8px 24px rgba(79,70,229,0.35);
	transition: transform .2s ease, box-shadow .2s ease; }
#topBtn:hover { transform: translateY(-2px); box-shadow: 0 10px 28px rgba(79,70,229,0.45); }
#topBtn:active { transform: scale(0.96); }

@media (max-width: 640px) {
	.log-card { padding: 11px 12px; border-radius: 12px; }
	.log-message { font-size: 13px; }
	.log-kv { grid-template-columns: 1fr; gap: 4px 0; }
	.log-kv .k { white-space: normal; }
	.controls { gap: 8px; }
	.controls .log-count { margin-left: 0; width: 100%; text-align: right; }
}

@media (prefers-color-scheme: dark) {
	body { background-color: #0f1115; color: #e5e7eb; }
	.log-card { background: rgba(30,34,44,0.55); border-color: rgba(255,255,255,0.10);
		box-shadow: 0 8px 28px rgba(0,0,0,0.35); }
	.log-card:hover { box-shadow: 0 12px 36px rgba(0,0,0,0.45); }
	.log-card.text { background: rgba(148,163,184,0.10); }
	.log-time { color: #94a3b8; }
	.lv-debug { background: rgba(96,165,250,0.18); color: #8ab4ff; }
	.lv-info  { background: rgba(16,185,129,0.18); color: #6ee7b7; }
	.lv-warn  { background: rgba(245,158,11,0.18); color: #fcd34d; }
	.lv-error { background: rgba(239,68,68,0.20); color: #fda4af; }
	.lv-fatal { background: rgba(239,68,68,0.30); color: #fecaca; }
	.log-message { color: #e5e7eb; }
	.log-kv .k { color: #94a3b8; }
	.log-kv .v { color: #cbd5e1; }
	.log-kv .kv-err .k, .log-kv .kv-err .v { color: #fda4af; }
	.log-json-btn { border-color: rgba(129,140,248,0.4); background: rgba(99,102,241,0.15); color: #a5b4fc; }
	.controls .log-count { color: #94a3b8; }
	.modal { background-color: rgba(0,0,0,0.5); }
	.modal-content { background: rgba(30,34,44,0.92); }
	.modal-content pre { color: #e2e8f0; background: #14161c; border-color: rgba(255,255,255,0.08);
		box-shadow: inset 0 1px 3px rgba(0,0,0,0.3); }
	.modal-close { background: linear-gradient(135deg, #d97706, #b45309); }
	.btn { border-color: rgba(255,255,255,0.12); }
	.switch .track { background: #475569; }
	.switch .lbl { color: #cbd5e1; }
}
</style>

<div class="controls">
  <button onclick="clearLogs()" class="btn btn-clear">
    Clear log
  </button>
  <label class="switch" title="Auto refresh the log every 8 seconds">
    <input type="checkbox" id="autorefreshToggle">
    <span class="track"></span>
    <span class="lbl">Auto refresh</span>
  </label>
  <div class="log-count">]] .. (jsonCount + textCount) .. [[ log entries</div>
</div>

<div class="log-list">
]])

	for idx, item in ipairs(log_items) do
		if item.isJson then
			local o = item.obj
			local lvl = o.level or ""
			local lvlLabel = LEVEL_LABEL[lvl] or lvl
			local lvlClass = LEVEL_CLASS[lvl] or "lv-info"
			local time = humanTime(o.time)
			local msg = o.message or ""

			-- collect every field except level/time/message so nothing is dropped
			local kvs = {}
			for k, v in pairs(o) do
				if k ~= "level" and k ~= "time" and k ~= "message" then
					local vs
					if type(v) == "table" then
						local ok, js = pcall(function() return luci.jsonc.stringify(v) end)
						vs = ok and js or tostring(v)
					else
						vs = tostring(v)
					end
					table.insert(kvs, { k, vs })
				end
			end
			table.sort(kvs, function(a, b) return a[1] < b[1] end)

			http.write("<div class='log-card'>")
			http.write("<div class='log-card-header'>")
			if time ~= "" then http.write("<span class='log-time'>" .. escapeHtml(time) .. "</span>") end
			if lvl ~= "" then http.write("<span class='log-level " .. lvlClass .. "'>" .. escapeHtml(lvlLabel) .. "</span>") end
			local jsonStr = luci.jsonc.stringify(o)
			http.write("<button class='log-json-btn' data-json='" .. escapeHtml(jsonStr) .. "' onclick='openJson(this)'>JSON</button>")
			http.write("</div>")
			if msg ~= "" then http.write("<div class='log-message'>" .. escapeHtml(msg) .. "</div>") end
			if #kvs > 0 then
				http.write("<div class='log-kv'>")
				for _, kv in ipairs(kvs) do
					local label = KV_LABELS[kv[1]] or kv[1]
					local errCls = (kv[1] == "error") and " kv-err" or ""
					http.write("<div class='kv-row" .. errCls .. "'><span class='k'>" .. escapeHtml(label) .. "</span><span class='v'>" .. escapeHtml(kv[2]) .. "</span></div>")
				end
				http.write("</div>")
			end
			http.write("</div>")
		else
			http.write("<div class='log-card text'><div class='log-raw-text'>" .. escapeHtml(item.text) .. "</div></div>")
		end
	end

	http.write([[
</div>

<div id="jsonModal" class="modal">
  <div class="modal-content">
    <button class="modal-close" onclick="closeJson()">Close</button>
    <pre id="jsonRaw"></pre>
  </div>
</div>

<button id="topBtn" onclick="topFunction()">
  Back to top
</button>

<script>
// prettify the raw JSON and render it inside a code-styled block
function openJson(btn) {
	var raw = btn.getAttribute("data-json") || "";
	var el = document.getElementById("jsonRaw");
	var pretty;
	try { pretty = JSON.stringify(JSON.parse(raw), null, 2); }
	catch (e) { pretty = raw; }
	el.textContent = pretty;
	document.getElementById("jsonModal").style.display = "flex";
	document.body.style.overflow = "hidden";
}
function closeJson() {
	document.getElementById("jsonModal").style.display = "none";
	document.body.style.overflow = "";
}
window.onclick = function(event) {
	if (event.target == document.getElementById("jsonModal")) closeJson();
}
function topFunction() { document.documentElement.scrollTop = 0; document.body.scrollTop = 0; }
window.onscroll = function() {
	var btn = document.getElementById("topBtn");
	btn.style.display = (document.body.scrollTop > 200 || document.documentElement.scrollTop > 200) ? "block" : "none";
}
function clearLogs(){ window.location.href = "?form=logview&_clear=1"; }

(function() {
	var toggle = document.getElementById("autorefreshToggle");
	var saved = localStorage.getItem("cf_autorefresh");
	// Auto refresh defaults to ON for first use; afterwards the user's choice is remembered.
	if (saved === null || saved === "1") {
		toggle.checked = true;
		localStorage.setItem("cf_autorefresh", "1");
	}
	// Auto refresh: fetch the latest logs in the background and update the list/count
	// without a full page reload. Scroll position is preserved and the DOM is only
	// rebuilt when content actually changed, so there is no flickering.
	var refreshing = false;
	function autoRefresh() {
		if (refreshing) return;
		refreshing = true;
		var st = document.documentElement.scrollTop || document.body.scrollTop || 0;
		fetch("?form=logview&_refresh=1", { cache: "no-store" })
			.then(function(r) { return r.text(); })
			.then(function(html) {
				var doc = new DOMParser().parseFromString(html, "text/html");
				var newList = doc.querySelector(".log-list");
				var curList = document.querySelector(".log-list");
				var newCount = doc.querySelector(".log-count");
				var curCount = document.querySelector(".log-count");
				if (newList && curList && newList.innerHTML !== curList.innerHTML) {
					curList.innerHTML = newList.innerHTML;
					if (newCount && curCount) curCount.innerHTML = newCount.innerHTML;
				}
				window.scrollTo(0, st);
			})
			.catch(function() { window.scrollTo(0, st); })
			.then(function() { refreshing = false; });
	}
	toggle.addEventListener("change", function() {
		localStorage.setItem("cf_autorefresh", toggle.checked ? "1" : "0");
		if (toggle.checked) autoRefresh();
	});
	setInterval(function() {
		if (document.getElementById("autorefreshToggle").checked) autoRefresh();
	}, 8000);
})();
</script>

]])
end

return m