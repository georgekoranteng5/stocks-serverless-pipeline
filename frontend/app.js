/* API_URL is injected at deploy time — do not hardcode the gateway URL here.
   scripts/deploy_frontend.sh writes frontend/config.js from Terraform output. */
(function () {
  const statusEl = document.getElementById("status");
  const tableWrap = document.getElementById("table-wrap");
  const tbody = document.getElementById("movers-body");

  function formatPercent(value) {
    const n = Number(value);
    if (Number.isNaN(n)) return "—";
    const sign = n > 0 ? "+" : "";
    return `${sign}${n.toFixed(2)}%`;
  }

  function formatPrice(value) {
    const n = Number(value);
    if (Number.isNaN(n)) return "—";
    return `$${n.toFixed(2)}`;
  }

  function changeClass(value) {
    const n = Number(value);
    if (n > 0) return "gain";
    if (n < 0) return "loss";
    return "flat";
  }

  function showStatus(message, kind) {
    statusEl.hidden = false;
    statusEl.textContent = message;
    statusEl.className = `status ${kind || ""}`.trim();
    tableWrap.hidden = true;
  }

  function renderRows(movers) {
    tbody.replaceChildren();

    for (const row of movers) {
      const tr = document.createElement("tr");
      const change = Number(row.percent_change);

      tr.innerHTML = `
        <td>${row.date ?? "—"}</td>
        <td class="ticker">${row.ticker ?? "—"}</td>
        <td class="change ${changeClass(change)}">${formatPercent(change)}</td>
        <td>${formatPrice(row.closing_price)}</td>
      `;
      tbody.appendChild(tr);
    }

    statusEl.hidden = true;
    tableWrap.hidden = false;
  }

  async function loadMovers() {
    const apiUrl = window.API_URL;
    if (!apiUrl) {
      showStatus(
        "Missing API URL. Run scripts/deploy_frontend.sh after terraform apply.",
        "error"
      );
      return;
    }

    showStatus("Loading…", "loading");

    try {
      const response = await fetch(apiUrl);
      if (!response.ok) {
        throw new Error(`API returned ${response.status}`);
      }

      const data = await response.json();
      if (!Array.isArray(data)) {
        throw new Error("Unexpected API response shape");
      }

      if (data.length === 0) {
        showStatus("No data yet — wait for the daily ingestion run.", "empty");
        return;
      }

      renderRows(data);
    } catch (err) {
      console.error(err);
      showStatus("Could not load movers. Check the API URL and CORS.", "error");
    }
  }

  loadMovers();
})();
