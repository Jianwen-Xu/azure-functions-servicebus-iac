"""Service Bus -> Blob archiver.

Consumes messages from the ingest queue and writes each one to the archive
container. Everything authenticates with the Function App's system-assigned
managed identity; there is not a single connection string or account key in
this file or in the app settings that feed it.

Binding configuration comes from app settings set by Terraform:
    ServiceBusConnection__fullyQualifiedNamespace -> servicebus extension uses AAD
    SERVICEBUS_QUEUE_NAME / ARCHIVE_CONTAINER_URL / STORAGE_BLOB_ENDPOINT
"""

from __future__ import annotations

import json
import logging
import os
from datetime import datetime, timezone

import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient, ContentSettings

app = func.FunctionApp()

BLOB_ENDPOINT = os.environ["STORAGE_BLOB_ENDPOINT"]
CONTAINER_URL = os.environ["ARCHIVE_CONTAINER_URL"]
BATCH_SIZE = int(os.environ.get("ARCHIVE_BATCH_SIZE", "100"))

# One credential and one client per worker instance. DefaultAzureCredential
# picks up the managed identity in Azure and the developer's `az login` locally,
# so the same code path runs in both places.
_credential = DefaultAzureCredential()
_blob_service = BlobServiceClient(account_url=BLOB_ENDPOINT, credential=_credential)
_container = _blob_service.get_container_client(CONTAINER_URL)


def _blob_path(message_id: str, enqueued_at: datetime) -> str:
    """Partition by date so listing and lifecycle rules stay cheap."""
    stamp = enqueued_at.astimezone(timezone.utc)
    return f"{stamp:%Y/%m/%d}/{message_id}.json"


def _write(message: func.ServiceBusMessage) -> str | None:
    body = message.get_body()
    try:
        payload = body.decode("utf-8")
    except UnicodeDecodeError:
        # Preserve non-text payloads verbatim rather than dropping them.
        payload = body.hex()

    enqueued = message.enqueued_time_utc or datetime.now(timezone.utc)
    blob_path = _blob_path(message.message_id, enqueued)

    document = {
        "message_id": message.message_id,
        "correlation_id": message.correlation_id,
        "session_id": message.session_id,
        "content_type": message.content_type,
        "delivery_count": message.delivery_count,
        "enqueued_time_utc": enqueued.isoformat(),
        "application_properties": message.application_properties,
        "body": payload,
    }

    _container.upload_blob(
        name=blob_path,
        data=json.dumps(document).encode("utf-8"),
        content_settings=ContentSettings(content_type="application/json"),
        overwrite=True,
    )
    return blob_path


@app.service_bus_queue_trigger(
    arg_name="message",
    queue_name="%SERVICEBUS_QUEUE_NAME%",
    connection="ServiceBusConnection",
)
def archive_message(message: func.ServiceBusMessage) -> None:
    """Triggered per message.

    The Service Bus extension settles (completes/abandons) the message based on
    whether this function raises. Letting an exception escape is what sends a
    message back for redelivery and eventually to the dead-letter queue, so the
    error path here is deliberately "raise, don't swallow".
    """
    try:
        blob_path = _write(message)
    except Exception:
        logging.exception(
            "Failed to archive message %s (delivery %s); abandoning for retry",
            message.message_id,
            message.delivery_count,
        )
        raise

    logging.info(
        "Archived message %s (%d bytes) to %s",
        message.message_id,
        len(message.get_body()),
        blob_path,
    )
