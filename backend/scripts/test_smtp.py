import argparse
import smtplib
import ssl
import sys
from email.message import EmailMessage
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import get_settings


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Test SMTP credentials from backend/.env.")
    parser.add_argument("--to", default="", help="Recipient email for a real send test.")
    parser.add_argument("--from-email", default="", help="Verified sender email. Defaults to SMTP_FROM_EMAIL.")
    parser.add_argument("--subject", default="Sprout Track SMTP test")
    parser.add_argument("--debug", action="store_true", help="Print SMTP conversation without message body.")
    parser.add_argument("--host", default="", help="Override SMTP host for testing.")
    parser.add_argument("--port", type=int, default=0, help="Override SMTP port for testing.")
    parser.add_argument("--ssl", action="store_true", help="Use implicit SSL instead of STARTTLS.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    settings = get_settings()

    if not settings.SMTP_HOST or not settings.SMTP_USER or not settings.SMTP_PASSWORD:
        print("smtp: not ready - SMTP_HOST, SMTP_USER, and SMTP_PASSWORD are required")
        return 1

    sender = args.from_email or settings.SMTP_FROM_EMAIL
    if args.to and not sender:
        print("smtp: not ready - provide --from-email or set SMTP_FROM_EMAIL to a verified sender")
        return 1

    try:
        host = args.host or settings.SMTP_HOST
        port = args.port or settings.SMTP_PORT
        smtp_cls = smtplib.SMTP_SSL if args.ssl else smtplib.SMTP
        with smtp_cls(host, port, timeout=30) as server:
            if args.debug:
                server.set_debuglevel(1)
            server.ehlo()
            print(f"smtp_connect: ok host={host} port={port} ssl={args.ssl}")
            print(f"smtp_features: {sorted(server.esmtp_features.keys())}")
            if not args.ssl:
                server.starttls(context=ssl.create_default_context())
                server.ehlo()
                print("smtp_starttls: ok")
            server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
            print("smtp_auth: ok")

            if args.to:
                message = EmailMessage()
                message["From"] = f"{settings.SMTP_FROM_NAME} <{sender}>"
                message["To"] = args.to
                message["Subject"] = args.subject
                message.set_content(
                    "Sprout Track SMTP is working.\n\n"
                    "This is a test email from the FastAPI backend configuration."
                )
                server.send_message(message)
                print(f"smtp_send: ok to={args.to}")
            else:
                print("smtp_send: skipped - pass --to recipient@example.com to send a test email")
        return 0
    except smtplib.SMTPAuthenticationError as exc:
        reason = exc.smtp_error.decode("utf-8", errors="replace") if isinstance(exc.smtp_error, bytes) else str(exc.smtp_error)
        print(f"smtp_auth: failed code={exc.smtp_code} reason={reason[:300]}")
    except smtplib.SMTPSenderRefused:
        print("smtp_send: failed - sender is not accepted/verified by the SMTP provider")
    except smtplib.SMTPRecipientsRefused:
        print("smtp_send: failed - recipient was refused")
    except Exception as exc:
        print(f"smtp: failed ({type(exc).__name__}) {str(exc)[:300]}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
