"""
Daily watchlist ingestion: fetch OHLC, pick top absolute % mover, PutItem to DynamoDB.
"""

from __future__ import annotations

import logging
import os
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from typing import Any

import boto3
import requests
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

logger = logging.getLogger()
logger.setLevel(logging.INFO)

WATCHLIST = ["AAPL", "MSFT", "GOOGL", "AMZN", "TSLA", "NVDA"]

MASSIVE_BASE_URL = "https://api.massive.com"
FINNHUB_QUOTE_URL = "https://finnhub.io/api/v1/quote"

MAX_TRADE_DATE_LOOKBACK_DAYS = 7


class StockApiError(Exception):
    """Base stock API failure."""


class RetryableStockApiError(StockApiError):
    """Transient failures worth retrying (rate limits, 5xx)."""


def compute_percent_change(open_price: float, close_price: float) -> float:
    """((close - open) / open) * 100"""
    if open_price == 0:
        raise ValueError("open_price must be non-zero")
    return ((close_price - open_price) / open_price) * 100


def _candidate_trade_dates(reference: date | None = None) -> list[date]:
    """Recent weekdays, newest first (skip weekends; holidays handled via API 404)."""
    start = reference or datetime.now(timezone.utc).date()
    candidates: list[date] = []
    cursor = start
    for _ in range(MAX_TRADE_DATE_LOOKBACK_DAYS + 3):
        if cursor.weekday() < 5:
            candidates.append(cursor)
        if len(candidates) >= MAX_TRADE_DATE_LOOKBACK_DAYS:
            break
        cursor -= timedelta(days=1)
    return candidates


@retry(
    retry=retry_if_exception_type((requests.RequestException, RetryableStockApiError)),
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=4),
    reraise=True,
)
def _http_get_json(
    url: str,
    *,
    params: dict[str, Any] | None = None,
    headers: dict[str, str] | None = None,
) -> dict[str, Any]:
    response = requests.get(url, params=params, headers=headers, timeout=10)

    if response.status_code == 429 or response.status_code >= 500:
        raise RetryableStockApiError(f"HTTP {response.status_code} for {url}")

    if response.status_code >= 400:
        raise StockApiError(f"HTTP {response.status_code} for {url}: {response.text[:200]}")

    payload = response.json()
    if not isinstance(payload, dict):
        raise StockApiError(f"unexpected JSON type from {url}")
    return payload


def fetch_massive_open_close(ticker: str, trade_date: date, api_key: str) -> dict[str, float | str]:
    """Massive.com Daily Open/Close for one ticker/date."""
    url = f"{MASSIVE_BASE_URL}/v1/open-close/{ticker}/{trade_date.isoformat()}"
    headers = {"Authorization": f"Bearer {api_key}", "Accept": "application/json"}
    params = {"adjusted": "true", "apiKey": api_key}

    data = _http_get_json(url, params=params, headers=headers)

    status = str(data.get("status", "")).upper()
    if status and status not in {"OK", "DELAYED"}:
        raise StockApiError(f"Massive status={data.get('status')!r} for {ticker} on {trade_date}")

    open_price = data.get("open")
    close_price = data.get("close")
    if open_price is None or close_price is None:
        raise StockApiError(f"Massive missing open/close for {ticker} on {trade_date}")

    return {
        "ticker": ticker,
        "trade_date": str(data.get("from") or trade_date.isoformat()),
        "open": float(open_price),
        "close": float(close_price),
        "source": "massive",
    }


def fetch_finnhub_quote(ticker: str, api_key: str, trade_date: date) -> dict[str, float | str]:
    """Finnhub fallback: quote endpoint supplies day open (o) and last/close (c)."""
    data = _http_get_json(FINNHUB_QUOTE_URL, params={"symbol": ticker, "token": api_key})

    open_price = data.get("o")
    close_price = data.get("c")
    if open_price in (None, 0) or close_price in (None, 0):
        raise StockApiError(f"Finnhub missing open/close for {ticker}: {data}")

    return {
        "ticker": ticker,
        "trade_date": trade_date.isoformat(),
        "open": float(open_price),
        "close": float(close_price),
        "source": "finnhub",
    }


def resolve_trade_date(api_key: str) -> date:
    """Pick the latest weekday Massive has data for (probe with AAPL)."""
    for trade_date in _candidate_trade_dates():
        try:
            fetch_massive_open_close("AAPL", trade_date, api_key)
            logger.info("Resolved trade date via Massive: %s", trade_date.isoformat())
            return trade_date
        except Exception as exc:  # noqa: BLE001
            logger.warning("No Massive data for AAPL on %s: %s", trade_date.isoformat(), exc)

    fallback = _candidate_trade_dates()[0]
    logger.warning("Falling back to calendar weekday %s (Finnhub path likely)", fallback.isoformat())
    return fallback


def fetch_daily_bar(ticker: str, trade_date: date, api_key: str) -> dict[str, float | str]:
    """
    Fetch one ticker's daily open/close for a fixed trade_date.
    Massive first; Finnhub quote as fallback. Retries cover transient failures.
    """
    try:
        return fetch_massive_open_close(ticker, trade_date, api_key)
    except Exception as massive_exc:  # noqa: BLE001
        logger.warning("Massive failed for %s on %s: %s", ticker, trade_date.isoformat(), massive_exc)

    try:
        logger.info("Trying Finnhub fallback for %s", ticker)
        return fetch_finnhub_quote(ticker, api_key, trade_date)
    except Exception as finnhub_exc:  # noqa: BLE001
        logger.warning("Finnhub fallback failed for %s: %s", ticker, finnhub_exc)
        raise StockApiError(
            f"all providers failed for {ticker} on {trade_date.isoformat()}: {finnhub_exc}"
        ) from finnhub_exc


def find_top_mover(results: list[dict[str, Any]]) -> dict[str, Any]:
    """Select the ticker with the largest absolute percent change."""
    return max(results, key=lambda row: abs(row["percent_change"]))


def put_mover_item(table_name: str, item: dict[str, Any]) -> None:
    dynamodb = boto3.resource("dynamodb")
    table = dynamodb.Table(table_name)
    table.put_item(
        Item={
            "date": item["date"],
            "ticker": item["ticker"],
            "percent_change": Decimal(str(round(item["percent_change"], 4))),
            "closing_price": Decimal(str(round(item["closing_price"], 4))),
            "created_at": item["created_at"],
        }
    )


def parse_trade_date_override(event: dict[str, Any] | None) -> date | None:
    """
    Optional backfill/demo override: {"trade_date": "YYYY-MM-DD"}.
    EventBridge schedules send {} / no key → auto-resolve latest session.
    """
    if not event:
        return None
    raw = event.get("trade_date")
    if raw is None or raw == "":
        return None
    try:
        return date.fromisoformat(str(raw))
    except ValueError as exc:
        raise ValueError(f"trade_date must be YYYY-MM-DD, got {raw!r}") from exc


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    table_name = os.environ["DYNAMODB_TABLE_NAME"]
    api_key = os.environ["STOCK_API_KEY"]

    override = parse_trade_date_override(event if isinstance(event, dict) else None)
    if override is not None:
        trade_date = override
        logger.info("Using trade_date override from event: %s", trade_date.isoformat())
    else:
        trade_date = resolve_trade_date(api_key)

    successes: list[dict[str, Any]] = []
    failures: list[str] = []

    for ticker in WATCHLIST:
        try:
            bar = fetch_daily_bar(ticker, trade_date, api_key)
            percent_change = compute_percent_change(float(bar["open"]), float(bar["close"]))
            successes.append(
                {
                    "date": str(bar["trade_date"]),
                    "ticker": ticker,
                    "percent_change": percent_change,
                    "closing_price": float(bar["close"]),
                    "source": bar["source"],
                }
            )
            logger.info(
                "%s %s open=%.4f close=%.4f change=%.4f%% source=%s",
                ticker,
                bar["trade_date"],
                bar["open"],
                bar["close"],
                percent_change,
                bar["source"],
            )
        except Exception as exc:  # noqa: BLE001 — partial success: continue watchlist
            failures.append(ticker)
            logger.error("Failed to fetch %s after retries: %s", ticker, exc, exc_info=True)

    if not successes:
        message = f"All tickers failed: {failures}"
        logger.error(message)
        raise RuntimeError(message)

    winner = find_top_mover(successes)
    # Persist the requested session date (override or resolved), not a per-ticker quirk.
    winner["date"] = trade_date.isoformat()
    winner["created_at"] = datetime.now(timezone.utc).isoformat()

    put_mover_item(table_name, winner)
    logger.info(
        "Stored top mover %s on %s (%.4f%%) closing=%.4f",
        winner["ticker"],
        winner["date"],
        winner["percent_change"],
        winner["closing_price"],
    )

    return {
        "statusCode": 200,
        "body": {
            "date": winner["date"],
            "ticker": winner["ticker"],
            "percent_change": winner["percent_change"],
            "closing_price": winner["closing_price"],
            "created_at": winner["created_at"],
            "failed_tickers": failures,
        },
    }
