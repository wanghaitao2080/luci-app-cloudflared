
local http = require "luci.http"

a=Map("cloudflared",translate("Cloudflared"),translate("Cloudflare's tunnel client - formerly known as Argo Tunnel, free intranet penetration, enabling external network access to intranet services"))
a:section(SimpleSection).template  = "cloudflared/cloudflared_status"

t=a:section(NamedSection,"config","cloudflared")
t.anonymous=true
t.addremove=false

e=t:option(Flag,"enabled",translate("Enable"))
e.default=0
e.rmempty=false

btncq = t:option(Button, "btncq", translate("Restart"))
btncq.inputtitle = translate("Restart")
btncq.description = translate("Quickly restart once without modifying parameters")
btncq.inputstyle = "apply"
btncq:depends("enabled", "1")
btncq.write = function()
  os.execute("/etc/init.d/cloudflared restart ")
end

e=t:option(Flag,"cmdenabled",translate("Custom CMD"),
	translate("Use custom commands. If you don't understand, don't enable it."))
e.default=0
e.rmempty=false

cfbin = t:option(Value, "cfbin", translate("cloudflared program path"),
	translate("Customize the cloudflared storage path and make sure to fill in the complete path and cloudflared name"))
cfbin.placeholder = "/usr/bin/cloudflared"
cfbin.rmempty=false

-- Token only supports a single value (cloudflared --token is a single-value flag),
-- use a 3-row textarea so the long token is easy to review
e=t:option(TextValue,"token",translate('Token'),
	translate("You need to go to the official website to create a tunnel first, <br>and then copy a long string of token values ​​starting with eyJh.<br> Be careful to copy correctly, otherwise the startup will fail.<br>If prompted for a credit card when creating a tunnel, go back and reopen the page to skip it."))
e.rows = function() return 3 end
e.placeholder = "eyJhIjoiMzQ3NTNhNDBlZTg4NTYzMDU5YmUzN2U2ZDY4YjEzY2QiLCJ0IjoiNTJkMjkwYTktNmFiNy00NDM5LThlODYtMzhmYTI0NTBhZjNhIiwicyI6IlptRXlOekl4TURZdFpUa3dPUzAwTnprM0xUbGlaR1l0TWpNNVpUUTBNV0k0TTJNMSJ9"
e:depends("cmdenabled", 0)

custom_cmd = t:option(DynamicList, "custom_cmd", translate("Custom startup parameters"),
                       translate("There is no need to add the program path here, just add the startup parameters normally. <br>Detailed command startup parameters:<a href='https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/tunnel-run-parameters/' target='_blank'>cloudflared doc</a><br>Note: Each parameter must be added separately, for example, add the first parameter:tunnel <br> Second parameter:--no-autoupdate The third parameter--logfile /tmp/cloudflared.info The fourth parameter:run <br>You cannot add two parameters in one box, you can only click + input in multiple input boxes<br>If you need to output the log path, please set it: --logfile /tmp/cloudflared.info"))
custom_cmd.placeholder = "--logfile /tmp/cloudflared.info"
custom_cmd:depends("cmdenabled", 1)

loglevel = t:option(ListValue, "loglevel", translate("Log level"),
	translate("Specifies the verbosity of logging. The default info level doesn't produce much output, <br>but you may want to issue a warning when using this level in production.<br>Level from low to high：debug < info < warn < Error < Fatal"))
loglevel:value("off")
loglevel:value("info")
loglevel:value("debug")
loglevel:value("warn")
loglevel:value("error")
loglevel:value("fatal")
loglevel:depends("cmdenabled", 0)

update = t:option(Flag, "update", translate("Auto update"),
	translate("Disabled by default. When enabled, cloudflared periodically checks for and downloads updates.<br><b>Note: auto update is not supported on mips processors</b>; enabling it may cause startup failures, keep it disabled."))
update.rmempty = false
update:depends("cmdenabled", 0)

protocol = t:option(ListValue, "protocol", translate("Connection protocol"),
	translate("Transport protocol used to connect to the Cloudflare edge:<br>auto - automatic selection (recommended; starts with QUIC and falls back to HTTP/2)<br>http2 - HTTP/2 over TCP, more stable on some networks<br>quic - QUIC over UDP"))
protocol:value("auto")
protocol:value("http2")
protocol:value("quic")
protocol.default = "auto"
protocol.rmempty = true
protocol:depends("cmdenabled", 0)

region = t:option(ListValue, "region", translate("Connection region"),
	translate("Cloudflare edge region; picking the nearest region lowers latency. The official docs only list \"us\"; enam/weur/apac etc. are commonly used datacenter region codes and are resolved by Cloudflare's server side. Choose \"Custom\" to type a region code or datacenter ID (e.g. ssub, 002)"))
region:value("", translate("Automatic (global)"))
region:value("us", translate("United States"))
region:value("enam", translate("Eastern North America"))
region:value("wnam", translate("Western North America"))
region:value("sam", translate("South America"))
region:value("weur", translate("Western Europe"))
region:value("eeur", translate("Eastern / Central Europe"))
region:value("apac", translate("Asia-Pacific"))
region:value("oc", translate("Oceania"))
region:value("me", translate("Middle East"))
region:value("in", translate("India"))
region:value("af", translate("Africa"))
region:value("other", translate("Custom..."))
region.rmempty = true
region:depends("cmdenabled", 0)

region_custom = t:option(Value, "region_custom", translate("Custom region code"),
	translate("Only applies when \"Custom\" is selected. Type a Cloudflare edge region code or datacenter ID, e.g. ssub, 002"))
region_custom.placeholder = "ssub"
region_custom.rmempty = true
region_custom:depends("region", "other")

edge_ip_version = t:option(ListValue, "edge_ip_version", translate("Edge IP version"),
	translate("IP address version used to connect to the Cloudflare edge: auto / 4 (IPv4) / 6 (IPv6). For networks in some regions, IPv4 is recommended to avoid IPv6 connection issues"))
edge_ip_version:value("auto")
edge_ip_version:value("4")
edge_ip_version:value("6")
edge_ip_version.default = "auto"
edge_ip_version.rmempty = true
edge_ip_version:depends("cmdenabled", 0)

retries = t:option(Value, "retries", translate("Connection retries"),
	translate("Maximum number of retries for connection/protocol errors before falling back to a lower protocol. Leave empty to use the built-in default"))
retries.placeholder = "5"
retries.rmempty = true
retries:depends("cmdenabled", 0)

ha_connections = t:option(Value, "ha_connections", translate("HA connections"),
	translate("Number of high availability connections established with the Cloudflare edge. Higher values improve availability but use more resources. Leave empty to use the built-in default"))
ha_connections.placeholder = "4"
ha_connections.rmempty = true
ha_connections:depends("cmdenabled", 0)

metrics = t:option(Value, "metrics", translate("Metrics address"),
	translate("Starts a local HTTP metrics service for monitoring and health checks, format ip:port, e.g. 127.0.0.1:41610.<br>Once a valid address is set and the service is reachable, click the endpoints below the input to view: /metrics - runtime metrics; /healthcheck - liveness check; /ready - readiness check.<br>Content is fetched by the LuCI backend on the device and shown in a modal; no other page is opened. Leave empty to disable"))
metrics.placeholder = "127.0.0.1:41610"
metrics.rmempty = true
metrics:depends("cmdenabled", 0)


e=t:option(DummyValue,"opennewwindow" , 
	translate("<input type=\"button\" class=\"cbi-button cbi-button-apply\" value=\"cloudflare.com\" onclick=\"window.open('https://one.dash.cloudflare.com')\" />"))
e.description = translate("Go to the official Zero Trust website to create or manage your cloudflared tunnel")

-- Override render: inject the token live-validation script below the form,
-- showing a distinct message for each error type
local _render = a.render
function a.render(self, ...)
	_render(self, ...)
	http.write([[
<div id="metricsModal" class="mmodal">
  <div class="mmodal-content">
    <div class="mmodal-head"><span id="metricsUrl"></span><button type="button" class="mmodal-close" onclick="closeMetricsModal()">Close</button></div>
    <div id="metricsRaw"></div>
  </div>
</div>
<script>
// Live token validation: distinct messages for wrong prefix / incomplete / bad format,
// green message when the token looks valid
(function() {
	function init() {
		var inputs = document.querySelectorAll('input.cbi-input-text[name*=".token"], textarea.cbi-input-textarea[name*=".token"]');
		inputs.forEach(function(inp) {
			if (inp.dataset.tkChecked === "1") return;
			inp.dataset.tkChecked = "1";
			var tip = document.createElement("span");
			tip.className = "token-tip";
			inp.parentNode.appendChild(tip);
			// Soft wrapping must be set via JS since wrap is an HTML attribute
			inp.setAttribute("wrap", "soft");
			function check() {
				var val = (inp.value || "").trim();
				if (val === "") { tip.style.display = "none"; return; }
				tip.style.display = "block";
				if (val.indexOf("eyJh") !== 0) {
					tip.textContent = "Token must start with eyJh";
					tip.className = "token-tip err"; return;
				}
				if (val.length < 100) {
					tip.textContent = "Token is incomplete, please copy the full string";
					tip.className = "token-tip err"; return;
				}
				var ok = false;
				try {
					var s = val.replace(/-/g, "+").replace(/_/g, "/");
					var obj = JSON.parse(atob(s));
					ok = obj && typeof obj === "object";
				} catch (e) { }
				if (!ok) {
					tip.textContent = "Invalid token format, please get a new one";
					tip.className = "token-tip err"; return;
				}
				tip.textContent = "Token looks valid";
				tip.className = "token-tip ok";
			}
			inp.addEventListener("input", check);
			inp.addEventListener("blur", check);
			check();
		});
		// Live metrics address format validation; drives the /metrics /healthcheck /ready links
		// in the description (they light up only while the service is reachable)
		var mInput = document.querySelector('input.cbi-input-text[name*=".metrics"]');
		if (mInput) {
			// Inject endpoint links dynamically (CBI descriptions do not render raw HTML)
			var epsWrap = document.createElement("div");
			epsWrap.className = "metrics-links";
			["/metrics", "/healthcheck", "/ready"].forEach(function(ep) {
				var a = document.createElement("a");
				a.className = "mt-link";
				a.setAttribute("data-ep", ep);
				a.textContent = ep;
				epsWrap.appendChild(a);
			});
			mInput.parentNode.insertBefore(epsWrap, mInput.nextSibling);
			function parseMetrics(v) {
				var s = v;
				if (/^https?:\/\//i.test(s)) s = s.replace(/^https?:\/\//i, "");
				var idx = s.lastIndexOf(":");
				if (idx < 1) return { ok: false, msg: "Format should be ip:port, e.g. 127.0.0.1:41610" };
				var host = s.slice(0, idx);
				var port = s.slice(idx + 1);
				if (!/^\d+$/.test(port)) return { ok: false, msg: "Port must be a number" };
				var p = parseInt(port, 10);
				if (p < 1 || p > 65535) return { ok: false, msg: "Port must be in range 1-65535" };
				if (host === "" || (host.indexOf(":") !== -1 && !/^\[.*\]$/.test(host)))
					return { ok: false, msg: "IP/hostname format is invalid" };
				return { ok: true, msg: "Address format is valid", port: p };
			}
			var links = Array.prototype.slice.call(document.querySelectorAll('a.mt-link'));
			var mTip = document.createElement("span");
			mTip.className = "metrics-tip";
			mInput.parentNode.appendChild(mTip);
			function proxyUrl(ep) {
				// Anchor to the cloudflared controller path, supporting general/folded page URLs
				var v = (mInput.value || "").trim();
				var pm = v === "" ? null : parseMetrics(v);
				var port = pm && pm.ok ? pm.port : "";
				var p = location.pathname;
				var mark = "/vpn/cloudflared";
				var i = p.indexOf(mark);
				var base = i === -1 ? p : p.slice(0, i + mark.length);
				return base + "/metricsproxy?ep=" + encodeURIComponent(ep) + "&port=" + encodeURIComponent(port);
			}
			function setLinks(bool) {
				links.forEach(function(a) { a.classList.toggle("mt-on", bool); });
			}
			// Links are clickable once a valid address is set; clicking lets the backend
			// proxy read the config and return the content or an error
			function update() {
				var v = (mInput.value || "").trim();
				var pm = v === "" ? { ok: false, msg: "" } : parseMetrics(v);
				if (v === "") { mTip.style.display = "none"; setLinks(false); return; }
				mTip.style.display = "block";
				mTip.textContent = pm.msg;
				mTip.className = pm.ok ? "metrics-tip ok" : "metrics-tip err";
				setLinks(pm.ok);
			}
			links.forEach(function(a) {
				a.addEventListener("click", function(ev) {
					ev.preventDefault();
					var ep = a.getAttribute("data-ep") || "";
					if (!parseMetrics((mInput.value || "").trim()).ok) return;
					fetch(proxyUrl(ep), { cache: "no-store" })
						.then(function(r) { return r.json(); })
						.then(function(j) { showResult(ep, j); })
						.catch(function() { showResult(ep, null); });
				});
			});
			mInput.addEventListener("input", update);
			mInput.addEventListener("blur", update);
			update();
		}
		function escapeHtml(s) {
			return String(s == null ? "" : s)
				.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
				.replace(/"/g, "&quot;").replace(/'/g, "&#39;");
		}
		function readyStatusHtml(status) {
			if (status === 200) return '<span class="mm-badge ok">Serving</span>';
			if (status === 503) return '<span class="mm-badge warn">Not ready</span>';
			return '<span class="mm-badge err">Status ' + escapeHtml(String(status)) + '</span>';
		}
		// Parse the backend response by endpoint type and render it nicely (no raw JSON)
		function showResult(ep, j) {
			var title = document.getElementById("metricsUrl");
			var box = document.getElementById("metricsRaw");
			title.textContent = (j && j.url) || ep;
			var html = "";
			if (!j || !j.ok) {
				html = '<div class="mm-err"><span class="mm-badge err">Fetch failed</span><p>The metrics service is not running or unreachable - make sure cloudflared is started and the address is correct.</p></div>';
			} else if (ep === "/ready") {
				var obj = null;
				try { obj = JSON.parse(j.body); } catch (e) { }
				if (obj) {
					html = '<div class="mm-kv">'
						+ '<div><span class="k">Status</span><span class="v">' + readyStatusHtml(obj.status) + '</span></div>'
						+ '<div><span class="k">Connections</span><span class="v"><span class="mm-badge info">' + escapeHtml(String(obj.readyConnections)) + '</span></span></div>'
						+ '<div><span class="k">Connector ID</span><span class="v"><span class="mm-badge id">' + escapeHtml(String(obj.connectorId)) + '</span></span></div>'
						+ '</div>';
				} else {
					html = '<div class="mm-err"><span class="mm-badge err">Parse failed</span><pre class="mm-pre">' + escapeHtml(j.body) + '</pre></div>';
				}
			} else if (ep === "/healthcheck") {
				var hc = (j.body || "").trim();
				var hcOK = hc === "OK";
				html = '<div class="mm-kv"><div><span class="k">Status</span><span class="v">'
					+ (hcOK ? '<span class="mm-badge ok">OK · Healthy</span>' : '<span class="mm-badge err">Unhealthy · ' + escapeHtml(hc) + '</span>')
					+ '</span></div></div>';
			} else { // /metrics: Prometheus text, no auto-wrapping, horizontal scroll
				html = '<pre class="mm-pre">' + escapeHtml(j.body) + '</pre>';
			}
			box.innerHTML = html;
			document.getElementById("metricsModal").style.display = "flex";
			document.body.style.overflow = "hidden";
		}
		function closeMetricsModal() {
			document.getElementById("metricsModal").style.display = "none";
			document.body.style.overflow = "";
		}
		window.closeMetricsModal = closeMetricsModal;
	}
	if (document.readyState !== "loading") init();
	else document.addEventListener("DOMContentLoaded", init);
})();
</script>
<style>
.token-tip { display: none; font-size: 12px; line-height: 1.4; margin-top: 2px; }
.token-tip.err { color: #dc2626; }
.token-tip.ok { color: #16a34a; }
/* token input: responsive width, fills the container on narrow screens,
   capped at 720px on wide screens, long tokens wrap automatically */
textarea.cbi-input-textarea[name*=".token"] {
	width: min(100%, 720px);
	box-sizing: border-box;
	min-height: 76px;
	resize: vertical;
}
/* Clickable metrics endpoint links in the description: greyed until the service is running */
.mt-link { color: #6366f1; cursor: pointer; text-decoration: none; opacity: 0.35;
	pointer-events: none; transition: opacity .2s ease; }
.mt-link.mt-on { opacity: 1; pointer-events: auto; font-weight: 600; }
.mt-link.mt-on:hover { text-decoration: underline; }
/* Layout for the endpoint links injected below the input */
.metrics-links { display: flex; gap: 16px; margin-top: 6px; }
/* Metrics address live format hint */
.metrics-tip { display: none; font-size: 12px; line-height: 1.4; margin-top: 2px; }
.metrics-tip.err { color: #dc2626; }
.metrics-tip.ok { color: #16a34a; }
/* Metrics result modal (liquid glass): scrolling inside the content, fixed header */
.mmodal { display: none; position: fixed; inset: 0; z-index: 999; padding: 16px; box-sizing: border-box;
	background: rgba(0,0,0,0.45); overflow: hidden; }
.mmodal-content { margin: auto; max-width: 760px; max-height: 88vh; display: flex; flex-direction: column;
	border-radius: 14px; background: rgba(255,255,255,0.94); overflow: hidden;
	-webkit-backdrop-filter: blur(20px) saturate(180%); backdrop-filter: blur(20px) saturate(180%);
	box-shadow: 0 12px 36px rgba(0,0,0,0.20); }
.mmodal-head { display: flex; align-items: center; justify-content: space-between; gap: 10px;
	padding: 12px 16px; border-bottom: 1px solid rgba(15,23,42,0.08); flex: 0 0 auto; }
/* The content area scrolls, so the scrollbar stays inside the modal */
.mmodal-content #metricsRaw { flex: 1 1 auto; overflow: auto; min-height: 0; padding: 14px 16px; }
.mmodal-head span { font-size: 12px; color: #64748b; word-break: break-all; }
.mmodal-close { padding: 4px 12px; border-radius: 8px; border: none; cursor: pointer; font-weight: 700;
	background: linear-gradient(135deg, #f59e0b, #d97706); color: #fff; transition: filter .2s ease, transform .2s ease; }
.mmodal-close:hover { filter: brightness(1.08); transform: translateY(-1px); }
.mmodal-close:active { transform: scale(0.96); }
.mmodal-content pre { margin: 0; padding: 14px; overflow: auto; flex: 1; min-height: 220px;
	font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 12px; line-height: 1.6;
	color: #e2e8f0; background: #14161c; white-space: pre-wrap; word-break: break-word; }
@media (prefers-color-scheme: dark) {
	.mmodal-content { background: rgba(30,34,44,0.95); }
	.mmodal-head { border-bottom-color: rgba(255,255,255,0.10); }
	.mmodal-head span { color: #94a3b8; }
}
/* Modal prettifying: status badges / key-value rows / horizontal-scroll metrics */
.mm-badge { display: inline-block; padding: 2px 12px; border-radius: 999px; font-size: 12px; font-weight: 700; }
.mm-badge.ok { background: rgba(16,185,129,0.15); color: #059669; }
.mm-badge.warn { background: rgba(245,158,11,0.15); color: #b45309; }
.mm-badge.err { background: rgba(239,68,68,0.16); color: #dc2626; }
.mm-badge.info { background: rgba(59,130,246,0.14); color: #2563eb; }
.mm-badge.id { background: rgba(99,102,241,0.12); color: #4f46e5;
	font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 12px; }
/* Key-value rows: glass cards, label left / value right */
.mm-kv { display: grid; gap: 10px; }
.mm-kv > div { display: flex; align-items: center; justify-content: space-between; gap: 14px;
	background: rgba(148,163,184,0.08); border: 1px solid rgba(148,163,184,0.16);
	padding: 10px 14px; border-radius: 10px; transition: background .2s ease; }
.mm-kv > div:hover { background: rgba(148,163,184,0.14); }
.mm-kv .k { font-size: 12px; color: #64748b; white-space: nowrap; }
.mm-kv .v { font-size: 13px; font-weight: 600; color: #334155; word-break: break-all; text-align: right; }
.mm-kv .v.mono { font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 12px; color: #475569; }
.mm-pre { margin: 0; font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 12px; line-height: 1.6;
	color: #1f2937; white-space: pre; overflow-x: auto; }
.mm-err { color: #dc2626; font-size: 13px; }
.mm-err p { margin: 6px 0 0; }
@media (prefers-color-scheme: dark) {
	.mm-kv .k { color: #94a3b8; }
	.mm-kv .v { color: #e2e8f0; }
	.mm-kv .v.mono { color: #cbd5e1; }
	.mm-kv > div { background: rgba(148,163,184,0.10); border-color: rgba(255,255,255,0.08); }
	.mm-kv > div:hover { background: rgba(148,163,184,0.16); }
	.mm-badge.info { color: #93c5fd; }
	.mm-badge.id { color: #a5b4fc; }
	.mm-pre { color: #e2e8f0; }
}
@media (max-width: 640px) {
	.mm-kv > div { flex-direction: column; align-items: flex-start; gap: 4px; padding: 10px 12px; }
	.mm-kv .v { text-align: left; }
}
</style>
]])
end

return a
