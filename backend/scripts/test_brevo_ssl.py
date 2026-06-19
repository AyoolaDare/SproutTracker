import argparse
import smtplib
import sys
from email.mime.text import MIMEText
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import get_settings


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Send a test email through Brevo SMTP SSL.")
    parser.add_argument("--to", required=True, help="Recipient email address.")
    parser.add_argument("--from-email", required=True, help="Verified Brevo sender email address.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    settings = get_settings()

    smtp_host = settings.SMTP_HOST or "smtp-relay.brevo.com"
    smtp_port = 465
    smtp_user = settings.SMTP_USER
    smtp_pass = settings.SMTP_PASSWORD

    if not smtp_user or not smtp_pass:
        print("Brevo SMTP user/password missing in backend/.env")
        return 1

    msg = MIMEText("This is a Brevo SMTP SSL test email from Sprout Track.")
    msg["Subject"] = "Sprout Track Brevo SMTP SSL Test"
    msg["From"] = args.from_email
    msg["To"] = args.to

    try:
        with smtplib.SMTP_SSL(smtp_host, smtp_port, timeout=30) as server:
            server.login(smtp_user, smtp_pass)
            server.sendmail(msg["From"], [msg["To"]], msg.as_string())
        print("Email sent successfully with SSL.")
        return 0
    except smtplib.SMTPAuthenticationError as exc:
        reason = exc.smtp_error.decode("utf-8", errors="replace") if isinstance(exc.smtp_error, bytes) else str(exc.smtp_error)
        print(f"SMTP auth failed code={exc.smtp_code} reason={reason}")
    except Exception as exc:
        print(f"SMTP SSL send failed ({type(exc).__name__}) {str(exc)[:300]}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
