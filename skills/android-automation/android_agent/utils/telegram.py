"""
Telegram notification utility — shared by run.py and runner.py.
Uses stdlib urllib only (no requests dependency). Never raises.
"""
import os


def notify_telegram(text: str, photo_b64: str = None) -> None:
    """
    Send a Telegram message or photo via the Bot API.
    Reads BOT_TOKEN and CHAT_ID from environment. Never raises.

    Args:
        text: Message text or photo caption (capped at 1024 chars for captions).
        photo_b64: Base64-encoded PNG to attach. None sends a text-only message.
    """
    import base64 as _b64
    import urllib.parse
    import urllib.request

    bot_token = os.environ.get("BOT_TOKEN", "")
    chat_id = os.environ.get("CHAT_ID", "")
    if not bot_token or not chat_id:
        return

    try:
        if photo_b64:
            img_bytes = _b64.b64decode(photo_b64)
            boundary = b"----TgBoundary7f3a9e"

            def _field(name: str, value: bytes) -> bytes:
                return (
                    b"--" + boundary
                    + b'\r\nContent-Disposition: form-data; name="' + name.encode() + b'"'
                    + b"\r\n\r\n" + value + b"\r\n"
                )

            body = (
                _field("chat_id", str(chat_id).encode())
                + _field("caption", text[:1024].encode())
                + b"--" + boundary
                + b'\r\nContent-Disposition: form-data; name="photo"; filename="screen.png"'
                + b"\r\nContent-Type: image/png\r\n\r\n"
                + img_bytes + b"\r\n"
                + b"--" + boundary + b"--\r\n"
            )
            req = urllib.request.Request(
                f"https://api.telegram.org/bot{bot_token}/sendPhoto",
                data=body,
                headers={"Content-Type": f"multipart/form-data; boundary={boundary.decode()}"},
                method="POST",
            )
        else:
            data = urllib.parse.urlencode({"chat_id": chat_id, "text": text}).encode()
            req = urllib.request.Request(
                f"https://api.telegram.org/bot{bot_token}/sendMessage",
                data=data,
                method="POST",
            )
        urllib.request.urlopen(req, timeout=5)
    except Exception:
        pass
