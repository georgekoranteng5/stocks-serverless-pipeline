"""
GET /movers — return the last 7 calendar days of top-mover winners from DynamoDB.
API Gateway HTTP API (payload 2.0) Lambda proxy integration.
"""

from __future__ import annotations

import json
import logging
import os
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from typing import Any

import boto3
from botocore.exceptions import BotoCoreError, ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

LOOKBACK_DAYS = 7

CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,OPTIONS",
    "Access-Control-Allow-Headers": "content-type",
}


def _json_default(value: Any) -> Any:
    if isinstance(value, Decimal):
        return float(value)
    raise TypeError(f"Object of type {type(value).__name__} is not JSON serializable")


def _response(status_code: int, payload: Any) -> dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": CORS_HEADERS,
        "body": json.dumps(payload, default=_json_default),
    }


def last_n_calendar_dates(n: int = LOOKBACK_DAYS, reference: date | None = None) -> list[str]:
    """YYYY-MM-DD strings for the last n calendar days (newest first)."""
    start = reference or datetime.now(timezone.utc).date()
    return [(start - timedelta(days=i)).isoformat() for i in range(n)]


def fetch_movers_batch(table_name: str, dates: list[str]) -> list[dict[str, Any]]:
    """
    Prefer BatchGetItem over Scan.

    Table PK is `date` only (one item per day), so a single Query cannot span days.
    BatchGetItem fetches up to 7 known keys in one round-trip — O(keys) reads,
    no full-table Scan. Missing dates (weekends / not yet ingested) simply omit.
    """
    client = boto3.client("dynamodb")
    keys = [{"date": {"S": d}} for d in dates]

    response = client.batch_get_item(
        RequestItems={
            table_name: {
                "Keys": keys,
                "ProjectionExpression": "#d, ticker, percent_change, closing_price",
                "ExpressionAttributeNames": {"#d": "date"},
            }
        }
    )

    raw_items = response.get("Responses", {}).get(table_name, [])
    movers: list[dict[str, Any]] = []
    for item in raw_items:
        movers.append(
            {
                "date": item["date"]["S"],
                "ticker": item["ticker"]["S"],
                "percent_change": Decimal(item["percent_change"]["N"]),
                "closing_price": Decimal(item["closing_price"]["N"]),
            }
        )

    # Newest first
    movers.sort(key=lambda row: row["date"], reverse=True)
    return movers


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    table_name = os.environ["DYNAMODB_TABLE_NAME"]
    dates = last_n_calendar_dates()

    logger.info("Fetching movers for dates=%s table=%s", dates, table_name)

    try:
        movers = fetch_movers_batch(table_name, dates)
    except (ClientError, BotoCoreError) as exc:
        logger.error("DynamoDB error: %s", exc, exc_info=True)
        return _response(500, {"error": "Failed to read movers from DynamoDB"})
    except Exception as exc:  # noqa: BLE001
        logger.error("Unexpected error: %s", exc, exc_info=True)
        return _response(500, {"error": "Internal server error"})

    # Empty list is a valid success (fresh deploy before any ingestion).
    return _response(200, movers)
